import AVFoundation
import AVKit
import Combine
import SwiftUI
import WebKit

@MainActor
private final class PlayerRuntimeObserver: ObservableObject {
    @Published var playbackError: String?
    @Published var webError: String?
    @Published var statusText: String = "Инициализация..."

    private weak var observedPlayer: AVPlayer?
    private weak var observedItem: AVPlayerItem?
    private var cancellables: Set<AnyCancellable> = []
    private var notificationTokens: [NSObjectProtocol] = []

    func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [])
            try audioSession.setActive(true)
            DebugLogger.log(.player, "AVAudioSession configured (.playback / .moviePlayback)")
        } catch {
            DebugLogger.log(.player, "AVAudioSession setup error: \(error.localizedDescription)", level: .warning)
        }
    }

    func attach(player: AVPlayer, item: AVPlayerItem, streamURL: URL) {
        detach()
        observedPlayer = player
        observedItem = item
        playbackError = nil
        statusText = "Буферизация потока..."

        DebugLogger.log(.player, "Attaching AVPlayer to stream: \(streamURL.absoluteString)")

        item.publisher(for: \.status, options: [.initial, .new])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.inspectItemStatus()
                }
            }
            .store(in: &cancellables)

        player.publisher(for: \.timeControlStatus, options: [.initial, .new])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.inspectTimeControlStatus()
                }
            }
            .store(in: &cancellables)

        let failedToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] note in
            let errDesc = (note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription ?? "Неизвестная ошибка воспроизведения"
            Task { @MainActor [weak self] in
                self?.playbackError = errDesc
                self?.statusText = "Ошибка воспроизведения"
                DebugLogger.log(.player, "AVPlayerItemFailedToPlayToEndTime: \(errDesc)", level: .error)
            }
        }
        notificationTokens.append(failedToken)

        let stalledToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { _ in
            DebugLogger.log(.player, "AVPlayerItemPlaybackStalled (буферизация застряла)", level: .warning)
        }
        notificationTokens.append(stalledToken)
    }

    func detach() {
        cancellables.removeAll()
        for token in notificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
        notificationTokens.removeAll()
        observedPlayer = nil
        observedItem = nil
    }

    private func inspectItemStatus() {
        guard let item = observedItem else { return }
        switch item.status {
        case .unknown:
            statusText = "Загрузка метаданных потока..."
            DebugLogger.log(.player, "AVPlayerItem.status = .unknown", level: .debug)
        case .readyToPlay:
            statusText = "Готов к воспроизведению"
            let durationSec = item.duration.isNumeric ? String(format: "%.1fs", item.duration.seconds) : "live/unknown"
            DebugLogger.log(.player, "AVPlayerItem.status = .readyToPlay (duration=\(durationSec))")
        case .failed:
            let nsErr = item.error as NSError?
            let detail = nsErr.map { "\($0.localizedDescription) [\($0.domain):\($0.code)]" } ?? "Неизвестная ошибка AVPlayerItem"
            var logEvents = ""
            if let events = item.errorLog()?.events, !events.isEmpty {
                logEvents = events.map { event in
                    "HTTP/AV \(event.errorStatusCode) domain=\(event.errorDomain) comment=\(event.errorComment ?? "-")"
                }.joined(separator: "; ")
            }
            playbackError = detail
            statusText = "Ошибка потока"
            DebugLogger.log(.player, "AVPlayerItem.status = .failed: \(detail) | errorLog=[\(logEvents)]", level: .error)
        @unknown default:
            break
        }
    }

    private func inspectTimeControlStatus() {
        guard let player = observedPlayer else { return }
        switch player.timeControlStatus {
        case .paused:
            DebugLogger.log(.player, "AVPlayer.timeControlStatus = .paused", level: .debug)
        case .waitingToPlayAtSpecifiedRate:
            let reason = player.reasonForWaitingToPlay?.rawValue ?? "unknown"
            statusText = "Буферизация (\(reason))..."
            DebugLogger.log(.player, "AVPlayer waitingToPlay: reason=\(reason)", level: .debug)
        case .playing:
            statusText = "Воспроизведение"
            playbackError = nil
            DebugLogger.log(.player, "AVPlayer.timeControlStatus = .playing")
        @unknown default:
            break
        }
    }
}

@MainActor
struct VideoPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = SessionStore.shared
    @StateObject private var observer = PlayerRuntimeObserver()

    let release: Release
    let source: VideoSource
    let allEpisodes: [Episode]
    var onEpisodeWatched: ((Int) -> Void)?

    @State private var currentEpisode: Episode
    @State private var parseResult: VideoParseResult?
    @State private var selectedVariant: VideoStreamVariant?
    @State private var forceWebPlayer = false
    @State private var isLoadingStream = true
    @State private var player: AVPlayer?
    @State private var showLogs = false
    @State private var reloadNonce = 0

    private let parser = VideoParserService()
    private let api = AnixartAPI()

    init(
        release: Release,
        source: VideoSource,
        initialEpisode: Episode,
        allEpisodes: [Episode],
        onEpisodeWatched: ((Int) -> Void)? = nil
    ) {
        self.release = release
        self.source = source
        self.allEpisodes = allEpisodes
        self.onEpisodeWatched = onEpisodeWatched
        _currentEpisode = State(initialValue: initialEpisode)
    }

    private var currentIndex: Int? {
        allEpisodes.firstIndex(where: { $0.stableId == currentEpisode.stableId })
    }

    private var previousEpisode: Episode? {
        guard let idx = currentIndex, idx > 0 else { return nil }
        return allEpisodes[idx - 1]
    }

    private var nextEpisode: Episode? {
        guard let idx = currentIndex, idx + 1 < allEpisodes.count else { return nil }
        return allEpisodes[idx + 1]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Color.black
                    if isLoadingStream {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                            Text("Подготовка потока...")
                                .foregroundStyle(.white)
                                .font(.subheadline)
                            Text(currentEpisode.url)
                                .foregroundStyle(.white.opacity(0.6))
                                .font(.caption2)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    } else if let result = parseResult {
                        if forceWebPlayer || result.useWebFallback || selectedVariant == nil {
                            WebVideoRepresentable(
                                url: result.originalURL,
                                headers: result.headers,
                                onError: makeWebErrorHandler()
                            )
                        } else if let player {
                            VideoPlayer(player: player)
                        }

                        if let err = activeDisplayError {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.orange)
                                Text("Не удалось воспроизвести видео")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(err)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)

                                HStack(spacing: 10) {
                                    if !forceWebPlayer {
                                        Button("Web-плеер") {
                                            DebugLogger.log(.nav, "Player error overlay -> switch to Web-плеер")
                                            forceWebPlayer = true
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                    Button("Повторить") {
                                        DebugLogger.log(.nav, "Player error overlay -> retry")
                                        reloadNonce += 1
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.white)

                                    Button("Логи") {
                                        showLogs = true
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.orange)
                                }
                            }
                            .padding(20)
                            .background(.black.opacity(0.82))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                controlsBar
            }
            .navigationTitle("\(release.displayTitle) • \(currentEpisode.displayTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") {
                        DebugLogger.log(.nav, "Close VideoPlayerView")
                        observer.detach()
                        player?.pause()
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // DEBUG_LOGGER_TEMPORARY
                    Button {
                        showLogs = true
                    } label: {
                        Image(systemName: "ladybug")
                    }

                    if let variants = parseResult?.variants, !variants.isEmpty {
                        Menu(selectedVariant?.quality ?? "Качество") {
                            ForEach(variants) { variant in
                                Button {
                                    DebugLogger.log(.nav, "Selected video quality: \(variant.quality) -> \(variant.url.absoluteString)")
                                    selectVariant(variant, headers: parseResult?.headers ?? [:])
                                } label: {
                                    HStack {
                                        Text(variant.quality)
                                        if variant.id == selectedVariant?.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showLogs) {
                DebugLogsView()
            }
            .task(id: "\(currentEpisode.stableId)-\(forceWebPlayer)-\(reloadNonce)") {
                await loadCurrentEpisode()
            }
            .onDisappear {
                observer.detach()
                player?.pause()
                player = nil
            }
        }
    }

    private var activeDisplayError: String? {
        if forceWebPlayer || parseResult?.useWebFallback == true || selectedVariant == nil {
            return observer.webError
        }
        return observer.playbackError
    }

    private var controlsBar: some View {
        HStack(spacing: 12) {
            Button {
                if let prev = previousEpisode {
                    DebugLogger.log(.nav, "Player tap Пред. серия -> \(prev.displayTitle)")
                    switchToEpisode(prev)
                }
            } label: {
                Label("Пред.", systemImage: "backward.end.fill")
            }
            .disabled(previousEpisode == nil)

            Spacer()

            Button {
                forceWebPlayer.toggle()
                DebugLogger.log(.nav, "Player toggle mode -> forceWebPlayer=\(forceWebPlayer)")
            } label: {
                Label(
                    forceWebPlayer ? "Нативный плеер" : "Web-плеер",
                    systemImage: forceWebPlayer ? "play.tv" : "safari"
                )
            }
            .buttonStyle(.bordered)

            Spacer()

            Button {
                if let next = nextEpisode {
                    DebugLogger.log(.nav, "Player tap След. серия -> \(next.displayTitle)")
                    switchToEpisode(next)
                }
            } label: {
                Label("След.", systemImage: "forward.end.fill")
            }
            .disabled(nextEpisode == nil)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func switchToEpisode(_ episode: Episode) {
        observer.detach()
        player?.pause()
        player = nil
        currentEpisode = episode
    }

    private func loadCurrentEpisode() async {
        isLoadingStream = true
        observer.detach()
        observer.playbackError = nil
        observer.webError = nil
        observer.configureAudioSession()
        player?.pause()
        player = nil
        defer { isLoadingStream = false }

        DebugLogger.log(
            .player,
            "loadCurrentEpisode: release=\(release.id) source=\(source.name)(\(source.id)) ep=\(currentEpisode.position) iframe=\(String(describing: currentEpisode.iframe)) url='\(currentEpisode.url)' forceWeb=\(forceWebPlayer)"
        )

        let result = await parser.resolve(
            episodeURL: currentEpisode.url,
            forceWeb: forceWebPlayer
        )
        parseResult = result

        if !forceWebPlayer, !result.useWebFallback, let first = result.variants.first {
            DebugLogger.log(.player, "Using native AVPlayer with variant '\(first.quality)' (\(result.variants.count) total)")
            selectVariant(first, headers: result.headers)
        } else {
            DebugLogger.log(.player, "Using WKWebView fallback for \(result.originalURL.absoluteString)", level: .warning)
            selectedVariant = nil
        }

        if session.isAuthenticated, source.id > 0 {
            _ = try? await api.markEpisodeWatched(
                releaseId: release.id,
                sourceId: source.id,
                position: currentEpisode.position
            )
            _ = try? await api.addToHistory(
                releaseId: release.id,
                sourceId: source.id,
                position: currentEpisode.position
            )
            onEpisodeWatched?(currentEpisode.position)
        }
    }

    private func selectVariant(_ variant: VideoStreamVariant, headers: [String: String]) {
        selectedVariant = variant
        observer.detach()
        player?.pause()
        let options: [String: Any] = headers.isEmpty ? [:] : ["AVURLAssetHTTPHeaderFieldsKey": headers]
        let asset = AVURLAsset(url: variant.url, options: options)
        let item = AVPlayerItem(asset: asset)
        let avPlayer = AVPlayer(playerItem: item)
        self.player = avPlayer
        observer.attach(player: avPlayer, item: item, streamURL: variant.url)
        avPlayer.play()
    }

    private func makeWebErrorHandler() -> @Sendable (String?) -> Void {
        let obs = observer
        return { err in
            Task { @MainActor in
                obs.webError = err
            }
        }
    }
}

private struct WebVideoRepresentable: UIViewRepresentable {
    let url: URL
    let headers: [String: String]
    var onError: (@Sendable (String?) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onError: onError)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.customUserAgent = headers["User-Agent"]
            ?? "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onError = onError
        if context.coordinator.lastLoadedURL == url.absoluteString { return }
        context.coordinator.lastLoadedURL = url.absoluteString
        DebugLogger.log(.player, "WKWebView loading: \(url.absoluteString)")
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        webView.load(request)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var lastLoadedURL: String?
        var onError: (@Sendable (String?) -> Void)?

        init(onError: (@Sendable (String?) -> Void)?) {
            self.onError = onError
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DebugLogger.log(.player, "WKWebView didStart: \(webView.url?.absoluteString ?? "-")", level: .debug)
            onError?(nil)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            DebugLogger.log(.player, "WKWebView didCommit: \(webView.url?.absoluteString ?? "-")", level: .debug)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DebugLogger.log(.player, "WKWebView didFinish: \(webView.url?.absoluteString ?? "-")")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let msg = "WKWebView didFail: \(error.localizedDescription)"
            DebugLogger.log(.player, msg, level: .error)
            onError?(msg)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsErr = error as NSError
            let msg = "WKWebView provisional fail [\(nsErr.domain):\(nsErr.code)]: \(error.localizedDescription)"
            DebugLogger.log(.player, msg, level: .error)
            onError?(msg)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if let http = navigationResponse.response as? HTTPURLResponse {
                let urlStr = http.url?.absoluteString ?? "-"
                if http.statusCode >= 400 {
                    DebugLogger.log(.player, "WKWebView HTTP \(http.statusCode) for \(urlStr)", level: .error)
                } else {
                    DebugLogger.log(.player, "WKWebView HTTP \(http.statusCode) for \(urlStr)", level: .debug)
                }
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                DebugLogger.log(.player, "WKWebView popup/target=_blank -> loading inline: \(url.absoluteString)", level: .debug)
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
