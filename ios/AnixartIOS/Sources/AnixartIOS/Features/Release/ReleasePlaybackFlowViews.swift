import SafariServices
import SwiftUI

private struct OnlinePlaybackTarget: Identifiable {
    let episode: Episode
    var id: String { episode.stableId }
}

private enum VoiceoverFilter: String, CaseIterable, Identifiable {
    case all = "Все"
    case dubs = "Озвучки"
    case subtitles = "Субтитры"

    var id: String { rawValue }
}

private struct StreamingWebTarget: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

@MainActor
struct OnlineWatchView: View {
    @EnvironmentObject private var session: SessionStore

    let release: Release
    let initialVoiceovers: [VoiceoverType]
    let initialStreamingPlatforms: [ReleaseStreamingPlatform]

    @State private var streamingPlatforms: [ReleaseStreamingPlatform] = []
    @State private var isLoadingPlatforms = false
    @State private var webTarget: StreamingWebTarget?

    private let api = AnixartAPI()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Divider()

                Text("Результаты поиска")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if isLoadingPlatforms && streamingPlatforms.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Поиск официальных источников...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else if streamingPlatforms.isEmpty {
                    Text("К сожалению, не удалось найти официальные проверенные стриминговые сервисы")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 10) {
                        ForEach(streamingPlatforms) { platform in
                            Button {
                                if let url = platform.targetURL {
                                    webTarget = StreamingWebTarget(url: url)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Color.secondary.opacity(0.14)
                                        .frame(width: 40, height: 40)
                                        .overlay {
                                            AsyncImage(url: platform.iconURL) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image.resizable().scaledToFill()
                                                default:
                                                    Image(systemName: "play.tv")
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 10))

                                    Text(platform.name ?? "Стриминговый сервис")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Image(systemName: "arrow.up.right")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(14)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                NavigationLink {
                    VoiceoverPickerView(release: release, initialVoiceovers: initialVoiceovers)
                        .environmentObject(session)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Искать другие варианты")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Из непроверенных источников")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(AnixartFormat.accentRed.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("Онлайн просмотр")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: release.id) {
            streamingPlatforms = initialStreamingPlatforms
            if initialStreamingPlatforms.isEmpty {
                isLoadingPlatforms = true
                defer { isLoadingPlatforms = false }
                if let resp = try? await api.releaseStreamingPlatforms(releaseId: release.id) {
                    streamingPlatforms = resp.content
                }
            }
        }
        .sheet(item: $webTarget) { target in
            ReleaseSafariSheet(url: target.url)
                .ignoresSafeArea()
        }
    }
}

@MainActor
struct VoiceoverPickerView: View {
    @EnvironmentObject private var session: SessionStore

    let release: Release
    let initialVoiceovers: [VoiceoverType]

    @State private var voiceovers: [VoiceoverType] = []
    @State private var selectedFilter: VoiceoverFilter = .all
    @State private var showInfoBanner = true
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = AnixartAPI()

    private var filteredVoiceovers: [VoiceoverType] {
        switch selectedFilter {
        case .all:
            return voiceovers
        case .dubs:
            return voiceovers.filter { !$0.isSubtitles }
        case .subtitles:
            return voiceovers.filter { $0.isSubtitles }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Divider()

                HStack(spacing: 8) {
                    ForEach(VoiceoverFilter.allCases) { filter in
                        let isSelected = (selectedFilter == filter)
                        Button {
                            selectedFilter = filter
                        } label: {
                            HStack(spacing: 5) {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                }
                                Text(filter.rawValue)
                                    .font(.subheadline.weight(.medium))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? AnixartFormat.accentRed.opacity(0.16) : Color(.systemBackground))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.28), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)

                if showInfoBanner {
                    HStack(alignment: .top, spacing: 10) {
                        Text("Напротив каждого варианта озвучки указано общее количество доступных серий. Статистика просмотров обновляется ежедневно.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 4)

                        Button {
                            withAnimation { showInfoBanner = false }
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.secondary.opacity(0.24), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                }

                if isLoading && voiceovers.isEmpty {
                    ProgressView("Загрузка озвучек...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                } else if let errorMessage, voiceovers.isEmpty {
                    ContentUnavailableView {
                        Label("Ошибка загрузки", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Повторить") {
                            Task { await loadVoiceovers(force: true) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 32)
                } else if filteredVoiceovers.isEmpty {
                    ContentUnavailableView(
                        "Нет подходящих вариантов",
                        systemImage: "waveform.slash",
                        description: Text("Попробуйте переключить фильтр выше.")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredVoiceovers) { voiceover in
                            NavigationLink {
                                VoiceoverEpisodesView(release: release, voiceover: voiceover)
                                    .environmentObject(session)
                            } label: {
                                voiceoverRow(voiceover)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("Выберите вариант")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    EpisodeUpdatesHistoryView(release: release)
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.primary)
                }
            }
        }
        .task(id: release.id) {
            if voiceovers.isEmpty {
                voiceovers = initialVoiceovers
            }
            if voiceovers.isEmpty {
                await loadVoiceovers(force: false)
            }
        }
    }

    private func voiceoverRow(_ voiceover: VoiceoverType) -> some View {
        HStack(spacing: 12) {
            Color.secondary.opacity(0.14)
                .frame(width: 44, height: 44)
                .overlay {
                    AsyncImage(url: voiceover.iconURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: "mic.fill")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(voiceover.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if voiceover.isSubtitles {
                        Text("СУБТИТРЫ")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.55), lineWidth: 1)
                            )
                    }
                }

                if let count = voiceover.episodesCount {
                    Text(AnixartFormat.pluralEpisodes(count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let views = voiceover.viewCount, views > 0 {
                HStack(spacing: 4) {
                    Text(AnixartFormat.compactViews(views))
                    Image(systemName: "eye")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func loadVoiceovers(force: Bool) async {
        guard force || voiceovers.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            voiceovers = try await api.episodeTypes(releaseId: release.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
struct VoiceoverEpisodesView: View {
    @EnvironmentObject private var session: SessionStore

    let release: Release
    let voiceover: VoiceoverType

    @State private var sources: [VideoSource] = []
    @State private var selectedSource: VideoSource?
    @State private var episodes: [Episode] = []
    @State private var isLoadingSources = true
    @State private var isLoadingEpisodes = false
    @State private var errorMessage: String?
    @State private var activePlayback: OnlinePlaybackTarget?

    private let api = AnixartAPI()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if isLoadingSources && sources.isEmpty {
                    ProgressView("Загрузка плееров...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                } else if let errorMessage, episodes.isEmpty {
                    ContentUnavailableView {
                        Label("Не удалось загрузить серии", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Повторить") {
                            Task { await loadSources() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 36)
                } else {
                    if !sources.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(sources) { source in
                                    let isSelected = (selectedSource?.id == source.id)
                                    Button {
                                        guard !isSelected else { return }
                                        selectedSource = source
                                        Task { await loadEpisodes(for: source) }
                                    } label: {
                                        Text(source.name)
                                            .font(.subheadline.weight(.medium))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(isSelected ? AnixartFormat.accentRed.opacity(0.16) : Color(.secondarySystemBackground))
                                            .foregroundStyle(isSelected ? AnixartFormat.accentRed : .primary)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 6)
                    }

                    if isLoadingEpisodes {
                        ProgressView("Загрузка серий...")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if episodes.isEmpty {
                        ContentUnavailableView("Серии не найдены", systemImage: "film")
                            .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(episodes, id: \.stableId) { episode in
                                HStack(spacing: 12) {
                                    Button {
                                        DebugLogger.log(.nav, "Tap episode row release=\(release.id) ep=\(episode.position) url='\(episode.url)'")
                                        activePlayback = OnlinePlaybackTarget(episode: episode)
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "play.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(AnixartFormat.accentRed)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(episode.displayTitle)
                                                    .font(.subheadline.weight(.medium))
                                                    .foregroundStyle(.primary)
                                                    .multilineTextAlignment(.leading)
                                                if episode.isFiller == true {
                                                    Text("Филлер")
                                                        .font(.caption2)
                                                        .foregroundStyle(.orange)
                                                }
                                            }
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        Task { await toggleEpisodeWatched(episode) }
                                    } label: {
                                        Image(systemName: (episode.isWatched ?? false) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle((episode.isWatched ?? false) ? BookmarkStatus.watching.color : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle(voiceover.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: voiceover.id) {
            if sources.isEmpty {
                await loadSources()
            }
        }
        .fullScreenCover(item: $activePlayback) { target in
            let fallbackSource = selectedSource ?? target.episode.source ?? VideoSource(id: 0, name: voiceover.name, episodesCount: episodes.count, type: voiceover)
            VideoPlayerView(
                release: release,
                source: fallbackSource,
                initialEpisode: target.episode,
                allEpisodes: episodes
            ) { watchedPosition in
                markLocalEpisodeWatched(position: watchedPosition, watched: true)
            }
            .environmentObject(session)
        }
    }

    private func loadSources() async {
        isLoadingSources = true
        errorMessage = nil
        defer { isLoadingSources = false }
        do {
            let loaded = try await api.episodeSources(releaseId: release.id, typeId: voiceover.id)
            sources = loaded
            if let first = loaded.first {
                selectedSource = first
                await loadEpisodes(for: first)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadEpisodes(for source: VideoSource) async {
        isLoadingEpisodes = true
        errorMessage = nil
        defer { isLoadingEpisodes = false }
        do {
            episodes = try await api.episodes(releaseId: release.id, typeId: voiceover.id, sourceId: source.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleEpisodeWatched(_ episode: Episode) async {
        guard session.isAuthenticated,
              let sourceId = selectedSource?.id ?? episode.source?.id else { return }
        let targetWatched = !(episode.isWatched ?? false)
        do {
            if targetWatched {
                _ = try await api.markEpisodeWatched(releaseId: release.id, sourceId: sourceId, position: episode.position)
            } else {
                _ = try await api.markEpisodeUnwatched(releaseId: release.id, sourceId: sourceId, position: episode.position)
            }
            markLocalEpisodeWatched(position: episode.position, watched: targetWatched)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markLocalEpisodeWatched(position: Int, watched: Bool) {
        episodes = episodes.map { ep in
            guard ep.position == position else { return ep }
            return Episode(
                id: ep.id,
                position: ep.position,
                name: ep.name,
                url: ep.url,
                iframe: ep.iframe,
                isWatched: watched,
                isFiller: ep.isFiller,
                addedDate: ep.addedDate,
                source: ep.source,
                release: ep.release,
                releaseId: ep.releaseId,
                sourceId: ep.sourceId
            )
        }
    }
}

@MainActor
struct EpisodeUpdatesHistoryView: View {
    let release: Release

    @State private var items: [EpisodeUpdateItem] = []
    @State private var page = 0
    @State private var hasMore = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = AnixartAPI()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if isLoading && items.isEmpty {
                    ProgressView("Загрузка истории...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if let errorMessage, items.isEmpty {
                    ContentUnavailableView {
                        Label("Ошибка загрузки", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Повторить") {
                            Task { await load(page: 0, append: false) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 40)
                } else if items.isEmpty {
                    ContentUnavailableView("История добавлений пуста", systemImage: "clock")
                        .padding(.top, 60)
                } else {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        HStack(alignment: .center, spacing: 12) {
                            Capsule()
                                .fill(BookmarkStatus.watching.color)
                                .frame(width: 3, height: 34)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(formattedUpdateText(item))
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)

                                if let ts = item.lastEpisodeUpdateDate, ts > 0 {
                                    Text(AnixartFormat.fullDateTime(timestamp: ts))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .onAppear {
                            if idx >= items.count - 4, hasMore, !isLoading {
                                Task { await load(page: page + 1, append: true) }
                            }
                        }
                    }

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .navigationTitle("Статистика добавления")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: release.id) {
            if items.isEmpty {
                await load(page: 0, append: false)
            }
        }
    }

    private func formattedUpdateText(_ item: EpisodeUpdateItem) -> AttributedString {
        var result = AttributedString()

        var ep = AttributedString(item.lastEpisodeUpdateName ?? "Серия")
        ep.font = .subheadline.weight(.semibold)
        result += ep

        if let typeName = item.lastEpisodeTypeUpdateName, !typeName.isEmpty {
            result += AttributedString(", вариант ")
            var typeAttr = AttributedString(typeName)
            typeAttr.font = .subheadline.weight(.semibold)
            result += typeAttr
        }

        if let sourceName = item.lastEpisodeSourceUpdateName, !sourceName.isEmpty {
            result += AttributedString(", источник ")
            var srcAttr = AttributedString(sourceName)
            srcAttr.font = .subheadline.weight(.semibold)
            result += srcAttr
        }

        return result
    }

    private func load(page targetPage: Int, append: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        if !append { errorMessage = nil }
        defer { isLoading = false }
        do {
            let resp = try await api.episodeUpdates(releaseId: release.id, page: targetPage)
            if append {
                items.append(contentsOf: resp.content)
            } else {
                items = resp.content
            }
            page = targetPage
            let totalPages = resp.totalPageCount ?? 1
            hasMore = (targetPage + 1) < totalPages
        } catch {
            if !append {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct ReleaseSafariSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
