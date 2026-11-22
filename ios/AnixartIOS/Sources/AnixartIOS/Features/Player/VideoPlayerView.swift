import AVFoundation
import AVKit
import SwiftUI
import WebKit

@MainActor
struct VideoPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = SessionStore.shared

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
                        ProgressView("Подготовка потока...")
                            .tint(.white)
                            .foregroundStyle(.white)
                    } else if let result = parseResult {
                        if forceWebPlayer || result.useWebFallback || selectedVariant == nil {
                            WebVideoRepresentable(
                                url: result.originalURL,
                                headers: result.headers
                            )
                        } else if let player {
                            VideoPlayer(player: player)
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
                        player?.pause()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let variants = parseResult?.variants, !variants.isEmpty {
                        Menu(selectedVariant?.quality ?? "Качество") {
                            ForEach(variants) { variant in
                                Button {
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
            .task(id: "\(currentEpisode.stableId)-\(forceWebPlayer)") {
                await loadCurrentEpisode()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
        }
    }

    private var controlsBar: some View {
        HStack(spacing: 12) {
            Button {
                if let prev = previousEpisode {
                    switchToEpisode(prev)
                }
            } label: {
                Label("Пред.", systemImage: "backward.end.fill")
            }
            .disabled(previousEpisode == nil)

            Spacer()

            Button {
                forceWebPlayer.toggle()
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
        player?.pause()
        player = nil
        currentEpisode = episode
    }

    private func loadCurrentEpisode() async {
        isLoadingStream = true
        player?.pause()
        player = nil
        defer { isLoadingStream = false }

        let result = await parser.resolve(
            episodeURL: currentEpisode.url,
            forceWeb: forceWebPlayer
        )
        parseResult = result

        if !forceWebPlayer, !result.useWebFallback, let first = result.variants.first {
            selectVariant(first, headers: result.headers)
        } else {
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
        player?.pause()
        let options: [String: Any] = headers.isEmpty ? [:] : ["AVURLAssetHTTPHeaderFieldsKey": headers]
        let asset = AVURLAsset(url: variant.url, options: options)
        let item = AVPlayerItem(asset: asset)
        let avPlayer = AVPlayer(playerItem: item)
        self.player = avPlayer
        avPlayer.play()
    }
}

private struct WebVideoRepresentable: UIViewRepresentable {
    let url: URL
    let headers: [String: String]

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.customUserAgent = headers["User-Agent"]
            ?? "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url?.absoluteString == url.absoluteString { return }
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        webView.load(request)
    }
}
