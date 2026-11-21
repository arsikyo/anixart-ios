import SwiftUI

private struct PlaybackTarget: Identifiable {
    let episode: Episode
    var id: String { episode.stableId }
}

struct ReleaseDetailView: View {
    @EnvironmentObject private var session: SessionStore

    let release: Release

    @State private var fullRelease: Release?
    @State private var voiceovers: [VoiceoverType] = []
    @State private var selectedVoiceover: VoiceoverType?
    @State private var sources: [VideoSource] = []
    @State private var selectedSource: VideoSource?
    @State private var episodes: [Episode] = []
    @State private var relatedReleases: [Release] = []
    @State private var comments: [ReleaseComment] = []

    @State private var isLoadingDetails = true
    @State private var isLoadingSources = false
    @State private var isLoadingEpisodes = false
    @State private var activePlayback: PlaybackTarget?

    @State private var newCommentText = ""
    @State private var isSpoilerComment = false
    @State private var isSubmittingComment = false
    @State private var alertMessage: String?

    private let api = AnixartAPI()

    private var current: Release { fullRelease ?? release }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                actionButtonsSection
                ratingSection
                descriptionSection
                episodesSection
                relatedSection
                commentsSection
            }
            .padding()
        }
        .navigationTitle(current.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: release.id) {
            await loadAll()
        }
        .fullScreenCover(item: $activePlayback) { target in
            if let source = selectedSource ?? target.episode.source {
                VideoPlayerView(
                    release: current,
                    source: source,
                    initialEpisode: target.episode,
                    allEpisodes: episodes
                ) { watchedPosition in
                    markLocalEpisodeWatched(position: watchedPosition, watched: true)
                }
            } else {
                VideoPlayerView(
                    release: current,
                    source: VideoSource(id: 0, name: selectedVoiceover?.name ?? "Плеер", episodesCount: episodes.count, type: selectedVoiceover),
                    initialEpisode: target.episode,
                    allEpisodes: episodes
                ) { watchedPosition in
                    markLocalEpisodeWatched(position: watchedPosition, watched: true)
                }
            }
        }
        .alert("Сообщение", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 14) {
            AsyncImage(url: current.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Color.secondary.opacity(0.2)
                        .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
                default:
                    Color.secondary.opacity(0.15)
                }
            }
            .frame(width: 124, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text(current.displayTitle)
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = current.subtitleTitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let grade = current.grade, grade > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").foregroundStyle(.orange)
                        Text(grade.formatted(.number.precision(.fractionLength(2))))
                            .fontWeight(.semibold)
                        if let votes = current.voteCount {
                            Text("(\(votes))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline)
                }

                Group {
                    if let year = current.year, !year.isEmpty {
                        Text("Год: \(year)")
                    }
                    if let ep = current.episodeText {
                        Text("Серии: \(ep)")
                    }
                    if let statusName = current.status?.name, !statusName.isEmpty {
                        Text("Статус: \(statusName)")
                    }
                    if let studio = current.studio, !studio.isEmpty {
                        Text("Студия: \(studio)")
                    }
                    if let country = current.country, !country.isEmpty {
                        Text("Страна: \(country)")
                    }
                    if let duration = current.duration, duration > 0 {
                        Text("Длительность: \(duration) мин.")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var actionButtonsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let genres = current.genres, !genres.isEmpty {
                Text(genres)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                if let firstEpisode = episodes.first {
                    Button {
                        activePlayback = PlaybackTarget(episode: firstEpisode)
                    } label: {
                        Label("Смотреть", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    Task { await toggleFavorite() }
                } label: {
                    Image(systemName: (current.isFavorite ?? false) ? "heart.fill" : "heart")
                        .foregroundStyle((current.isFavorite ?? false) ? .red : .primary)
                }
                .buttonStyle(.bordered)

                Menu {
                    ForEach(BookmarkStatus.allCases) { status in
                        Button {
                            Task { await setBookmarkStatus(status) }
                        } label: {
                            HStack {
                                Label(status.title, systemImage: status.systemImage)
                                if current.profileListStatus == status.rawValue {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    if let currentStatusRaw = current.profileListStatus,
                       let currentStatus = BookmarkStatus(rawValue: currentStatusRaw) {
                        Divider()
                        Button(role: .destructive) {
                            Task { await removeBookmarkStatus(currentStatus) }
                        } label: {
                            Label("Убрать из списка", systemImage: "trash")
                        }
                    }
                } label: {
                    let activeStatus = current.profileListStatus.flatMap(BookmarkStatus.init(rawValue:))
                    Label(activeStatus?.title ?? "В список", systemImage: activeStatus?.systemImage ?? "bookmark")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var ratingSection: some View {
        HStack(spacing: 8) {
            Text("Ваша оценка:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(1...5, id: \.self) { star in
                Button {
                    Task { await vote(star) }
                } label: {
                    Image(systemName: (current.yourVote ?? 0) >= star ? "star.fill" : "star")
                        .foregroundStyle((current.yourVote ?? 0) >= star ? .orange : .secondary)
                }
                .buttonStyle(.plain)
            }
            if let yourVote = current.yourVote, yourVote > 0 {
                Button("Сбросить") {
                    Task { await clearVote() }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var descriptionSection: some View {
        if let desc = current.description, !desc.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Описание")
                    .font(.headline)
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
    }

    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Серии и озвучка")
                .font(.headline)

            if current.isPlayDisabled == true {
                Text("Воспроизведение ограничено для этого релиза.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if isLoadingDetails && voiceovers.isEmpty {
                ProgressView("Загрузка озвучек...")
            } else if voiceovers.isEmpty {
                Text("Озвучки пока недоступны.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(voiceovers) { type in
                            Button {
                                guard selectedVoiceover?.id != type.id else { return }
                                selectedVoiceover = type
                                Task { await loadSources(for: type) }
                            } label: {
                                Text(type.name)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(selectedVoiceover?.id == type.id ? Color.accentColor : Color.secondary.opacity(0.15))
                                    .foregroundStyle(selectedVoiceover?.id == type.id ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if isLoadingSources {
                    ProgressView("Загрузка плееров...")
                } else if !sources.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sources) { source in
                                Button {
                                    guard selectedSource?.id != source.id else { return }
                                    selectedSource = source
                                    Task { await loadEpisodes(for: source) }
                                } label: {
                                    Text(source.name)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(selectedSource?.id == source.id ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                                        .foregroundStyle(selectedSource?.id == source.id ? Color.accentColor : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 7))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if isLoadingEpisodes {
                    ProgressView("Загрузка серий...")
                } else if episodes.isEmpty {
                    Text("Серии в выбранном источнике не найдены.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(episodes, id: \.stableId) { episode in
                            HStack(spacing: 12) {
                                Button {
                                    activePlayback = PlaybackTarget(episode: episode)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "play.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(Color.accentColor)
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
                                        .foregroundStyle((episode.isWatched ?? false) ? .green : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var relatedSection: some View {
        if !relatedReleases.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Связанные релизы")
                    .font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(relatedReleases) { item in
                            NavigationLink(value: item) {
                                ReleasePosterCard(release: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Комментарии (\(comments.count))")
                .font(.headline)

            if session.isAuthenticated {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Написать комментарий...", text: $newCommentText, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Toggle("Спойлер", isOn: $isSpoilerComment)
                            .labelsHidden()
                        Text("Спойлер")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(isSubmittingComment ? "Отправка..." : "Отправить") {
                            Task { await submitComment() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingComment)
                    }
                }
            }

            if comments.isEmpty {
                Text("Комментариев пока нет.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(comments) { comment in
                        CommentCardView(
                            comment: comment,
                            isOwnComment: comment.profile?.id == session.currentProfile?.id,
                            onVote: { vote in Task { await voteComment(comment, vote: vote) } },
                            onDelete: { Task { await deleteComment(comment) } }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Networking

    private func loadAll() async {
        isLoadingDetails = true
        defer { isLoadingDetails = false }

        async let detailTask = try? api.release(id: release.id, extendedMode: true)
        async let typesTask = try? api.episodeTypes(releaseId: release.id)
        async let commentsTask = try? api.releaseComments(releaseId: release.id, page: 0)

        if let detailed = await detailTask {
            fullRelease = detailed
            if let relatedId = detailed.relatedId, relatedId > 0 {
                relatedReleases = (try? await api.related(relatedId: relatedId, page: 0).content) ?? []
            }
        } else if let relatedId = release.relatedId, relatedId > 0 {
            relatedReleases = (try? await api.related(relatedId: relatedId, page: 0).content) ?? []
        }

        let loadedTypes = await typesTask ?? []
        voiceovers = loadedTypes
        if let firstType = loadedTypes.first {
            selectedVoiceover = firstType
            await loadSources(for: firstType)
        }

        comments = (await commentsTask)?.content ?? []
    }

    private func loadSources(for voiceover: VoiceoverType) async {
        isLoadingSources = true
        sources = []
        selectedSource = nil
        episodes = []
        defer { isLoadingSources = false }

        do {
            let loadedSources = try await api.episodeSources(releaseId: release.id, typeId: voiceover.id)
            sources = loadedSources
            if let firstSource = loadedSources.first {
                selectedSource = firstSource
                await loadEpisodes(for: firstSource)
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func loadEpisodes(for source: VideoSource) async {
        guard let voiceover = selectedVoiceover else { return }
        isLoadingEpisodes = true
        episodes = []
        defer { isLoadingEpisodes = false }

        do {
            episodes = try await api.episodes(releaseId: release.id, typeId: voiceover.id, sourceId: source.id)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func ensureAuthenticated() -> Bool {
        if !session.isAuthenticated {
            alertMessage = "Войдите в аккаунт, чтобы сохранять изменения на сервере."
            return false
        }
        return true
    }

    private func toggleFavorite() async {
        guard ensureAuthenticated() else { return }
        let currentlyFav = current.isFavorite ?? false
        do {
            if currentlyFav {
                _ = try await api.deleteFavorite(releaseId: release.id)
            } else {
                _ = try await api.addFavorite(releaseId: release.id)
            }
            fullRelease = try await api.release(id: release.id, extendedMode: true)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func setBookmarkStatus(_ status: BookmarkStatus) async {
        guard ensureAuthenticated() else { return }
        do {
            _ = try await api.addToProfileList(status: status, releaseId: release.id)
            fullRelease = try await api.release(id: release.id, extendedMode: true)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func removeBookmarkStatus(_ status: BookmarkStatus) async {
        guard ensureAuthenticated() else { return }
        do {
            _ = try await api.deleteFromProfileList(status: status, releaseId: release.id)
            fullRelease = try await api.release(id: release.id, extendedMode: true)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func vote(_ stars: Int) async {
        guard ensureAuthenticated() else { return }
        do {
            _ = try await api.voteRelease(id: release.id, vote: stars)
            fullRelease = try await api.release(id: release.id, extendedMode: true)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func clearVote() async {
        guard ensureAuthenticated() else { return }
        do {
            _ = try await api.deleteVoteRelease(id: release.id)
            fullRelease = try await api.release(id: release.id, extendedMode: true)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func toggleEpisodeWatched(_ episode: Episode) async {
        guard ensureAuthenticated(), let sourceID = selectedSource?.id ?? episode.source?.id else { return }
        let targetWatched = !(episode.isWatched ?? false)
        do {
            if targetWatched {
                _ = try await api.markEpisodeWatched(releaseId: release.id, sourceId: sourceID, position: episode.position)
            } else {
                _ = try await api.markEpisodeUnwatched(releaseId: release.id, sourceId: sourceID, position: episode.position)
            }
            markLocalEpisodeWatched(position: episode.position, watched: targetWatched)
        } catch {
            alertMessage = error.localizedDescription
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
                release: ep.release
            )
        }
    }

    private func submitComment() async {
        guard ensureAuthenticated() else { return }
        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSubmittingComment = true
        defer { isSubmittingComment = false }

        do {
            let resp = try await api.addReleaseComment(releaseId: release.id, message: trimmed, spoiler: isSpoilerComment)
            newCommentText = ""
            isSpoilerComment = false
            if let comment = resp.comment {
                comments.insert(comment, at: 0)
            } else {
                comments = try await api.releaseComments(releaseId: release.id, page: 0).content
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func voteComment(_ comment: ReleaseComment, vote: Int) async {
        guard ensureAuthenticated() else { return }
        do {
            _ = try await api.voteReleaseComment(commentId: comment.id, vote: vote)
            comments = try await api.releaseComments(releaseId: release.id, page: 0).content
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func deleteComment(_ comment: ReleaseComment) async {
        guard ensureAuthenticated() else { return }
        do {
            _ = try await api.deleteReleaseComment(commentId: comment.id)
            comments.removeAll { $0.id == comment.id }
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}

private struct CommentCardView: View {
    let comment: ReleaseComment
    let isOwnComment: Bool
    let onVote: (Int) -> Void
    let onDelete: () -> Void

    @State private var revealSpoiler = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AsyncImage(url: comment.profile?.avatarURL) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: Color.secondary.opacity(0.2)
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())

                Text(comment.profile?.displayName ?? "Пользователь")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if isOwnComment {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                }
            }

            if comment.isDeleted == true {
                Text("Комментарий удалён")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            } else if comment.isSpoiler == true && !revealSpoiler {
                Button("Спойлер — нажать, чтобы показать") {
                    revealSpoiler = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
            } else {
                Text(comment.message ?? "")
                    .font(.subheadline)
            }

            HStack(spacing: 14) {
                Button { onVote(1) } label: {
                    Image(systemName: comment.myVote == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                }
                Text("\(comment.voteCount ?? 0)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button { onVote(-1) } label: {
                    Image(systemName: comment.myVote == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                }
            }
            .font(.caption)
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
