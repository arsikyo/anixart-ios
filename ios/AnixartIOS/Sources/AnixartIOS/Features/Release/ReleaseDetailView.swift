import SwiftUI
import UIKit

private enum ReleaseDetailRoute: Hashable {
    case onlineWatch
    case comments
    case videos
    case collections
}

private struct GallerySelection: Identifiable {
    let index: Int
    var id: Int { index }
}

@MainActor
struct ReleaseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = SessionStore.shared

    let release: Release
    var prefetchedFullRelease: Bool = false

    @State private var fullRelease: Release?
    @State private var voiceovers: [VoiceoverType] = []
    @State private var videoBlocks: [ReleaseVideoBlock] = []
    @State private var streamingPlatforms: [ReleaseStreamingPlatform] = []
    @State private var relatedReleases: [Release] = []
    @State private var comments: [ReleaseComment] = []
    @State private var totalCommentsCount: Int = 0

    @State private var isLoadingDetails = true
    @State private var isDescriptionExpanded = false
    @State private var activeGallery: GallerySelection?

    @State private var showMoreSheet = false
    @State private var showAddToCollection = false
    @State private var showInfoAlert = false
    @State private var showReportSheet = false
    @State private var showRulesAlert = false
    @State private var showLogs = false

    @State private var newCommentText = ""
    @State private var isSpoilerComment = false
    @State private var replyingToComment: ReleaseComment?
    @State private var isSubmittingComment = false
    @State private var alertMessage: String?

    private let api = AnixartAPI()

    private var current: Release { fullRelease ?? release }

    private var activeBookmarkStatus: BookmarkStatus? {
        guard let raw = current.profileListStatus, raw > 0 else { return nil }
        return BookmarkStatus(rawValue: raw)
    }

    private var shareURL: URL {
        URL(string: "https://anixart.tv/release/\(current.id)")!
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroPosterHeader

                VStack(alignment: .leading, spacing: 16) {
                    titleBlock
                    primaryActionsRow
                    watchRow
                    metadataBlock
                    genresBlock
                    descriptionBlock
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                videoSection
                ratingSection
                peopleListsSection
                screenshotsSection
                collectionsLinksSection
                relatedSection
                commentsPreviewSection
            }
        }
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: ReleaseDetailRoute.self) { route in
            switch route {
            case .onlineWatch:
                OnlineWatchView(
                    release: current,
                    initialVoiceovers: voiceovers,
                    initialStreamingPlatforms: streamingPlatforms
                )
                .environmentObject(session)
            case .comments:
                ReleaseCommentsView(
                    release: current,
                    initialTotalCount: max(totalCommentsCount, current.commentCount ?? comments.count)
                )
            case .videos:
                ReleaseVideosView(
                    release: current,
                    initialBlocks: videoBlocks
                )
            case .collections:
                ReleaseCollectionsListView(release: current)
            }
        }
        .sheet(isPresented: $showMoreSheet) {
            moreActionsSheet
                .presentationDetents([.height(275)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddToCollection) {
            AddToCollectionSheet(release: current)
        }
        .sheet(isPresented: $showReportSheet) {
            ReleaseReportSheet(releaseId: current.id) { message in
                alertMessage = message
            }
        }
        .sheet(isPresented: $showLogs) {
            DebugLogsView()
        }
        .fullScreenCover(item: $activeGallery) { selection in
            ScreenshotsGalleryView(urls: current.screenshotURLs, selectedIndex: selection.index)
        }
        .task(id: release.id) {
            DebugLogger.log(.nav, "Open ReleaseDetailView id=\(release.id) title='\(release.displayTitle)'")
            await loadAll()
        }
        .alert(current.displayTitle, isPresented: $showInfoAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(buildInfoAlertText())
        }
        .alert("Правила комментариев", isPresented: $showRulesAlert) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Уважайте других участников, не оскорбляйте пользователей и скрывайте сюжетные повороты под тегом «Спойлер».")
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

    // MARK: - Hero Header

    private var heroPosterHeader: some View {
        ZStack(alignment: .top) {
            Color(.secondarySystemBackground)
                .frame(height: 315)
                .overlay {
                    AsyncImage(url: current.imageURL) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFill()
                                .blur(radius: 26)
                                .opacity(0.28)
                        }
                    }
                }
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, Color(.systemBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                }

            VStack(spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    HStack(spacing: 8) {
                        // DEBUG_LOGGER_TEMPORARY
                        Button {
                            showLogs = true
                        } label: {
                            Image(systemName: "ladybug")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button {
                            showAddToCollection = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 54)

                Color.secondary.opacity(0.16)
                    .frame(width: 158, height: 228)
                    .overlay {
                        AsyncImage(url: current.imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure:
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            default:
                                ProgressView()
                            }
                        }
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
                    .padding(.top, 2)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Title & Actions

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Button {
                    showInfoAlert = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)

                Text(current.displayTitle)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if let subtitle = current.subtitleTitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let ageText = current.ageRatingText {
                    Text(ageText)
                        .font(.caption2.bold())
                        .foregroundStyle(Color(.systemBackground))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
            .padding(.leading, 2)
        }
    }

    private var primaryActionsRow: some View {
        HStack(spacing: 10) {
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
                if let currentStatus = activeBookmarkStatus {
                    Divider()
                    Button(role: .destructive) {
                        Task { await removeBookmarkStatus(currentStatus) }
                    } label: {
                        Label("Убрать из списка", systemImage: "trash")
                    }
                }
            } label: {
                let borderColor = activeBookmarkStatus?.color ?? Color.secondary.opacity(0.4)
                let labelColor = activeBookmarkStatus?.pillForegroundColor ?? Color.primary
                HStack(spacing: 6) {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                    Text(activeBookmarkStatus?.title ?? "В список")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(labelColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background((activeBookmarkStatus?.color ?? Color.clear).opacity(activeBookmarkStatus == nil ? 0 : 0.08))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(borderColor, lineWidth: 1.2)
                )
            }

            Button {
                Task { await toggleFavorite() }
            } label: {
                let isFav = current.isFavorite ?? false
                HStack(spacing: 6) {
                    Image(systemName: isFav ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(isFav ? AnixartFormat.accentRed : .secondary)
                    if let favCount = current.favoritesCount {
                        Text(AnixartFormat.spaced(favCount))
                            .foregroundStyle(isFav ? AnixartFormat.accentRed : .primary)
                    }
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isFav ? AnixartFormat.accentRed.opacity(0.1) : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isFav ? AnixartFormat.accentRed : Color.secondary.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: ReleaseDetailRoute.comments) {
                Image(systemName: "text.bubble")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }

    private var watchRow: some View {
        HStack(spacing: 10) {
            if current.isPlayDisabled == true {
                HStack(spacing: 8) {
                    Image(systemName: "nosign")
                    Text("Воспроизведение ограничено")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.secondary.opacity(0.5))
                .clipShape(Capsule())
            } else {
                NavigationLink(value: ReleaseDetailRoute.onlineWatch) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.subheadline)
                        Text("Воспроизвести")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AnixartFormat.accentRed)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Button {
                showMoreSheet = true
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AnixartFormat.accentRed)
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Metadata, Genres & Description

    private var metadataBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let countryLine = current.countrySeasonYearText {
                HStack(spacing: 10) {
                    Text(current.countryFlagEmoji)
                        .font(.body)
                        .frame(width: 22)
                    Text(countryLine)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }

            if let epLine = current.episodeStatsText {
                HStack(spacing: 10) {
                    Image(systemName: "play.rectangle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                    Text(epLine)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }

            if let statusLine = current.typeAndStatusText {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                    Text(statusLine)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }

            if let creditsLine = current.creditsText {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "person.3")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                    Text(creditsLine)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var genresBlock: some View {
        let tags = current.genreTags
        if !tags.isEmpty {
            Text(genresAttributedString(tags))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private func genresAttributedString(_ tags: [String]) -> AttributedString {
        var result = AttributedString()
        for (idx, tag) in tags.enumerated() {
            var item = AttributedString(tag)
            item.underlineStyle = .single
            result += item
            if idx < tags.count - 1 {
                result += AttributedString(", ")
            }
        }
        return result
    }

    @ViewBuilder
    private var descriptionBlock: some View {
        let desc = current.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !desc.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(isDescriptionExpanded ? nil : 4)
                    .fixedSize(horizontal: false, vertical: true)

                if desc.count > 160 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDescriptionExpanded.toggle()
                        }
                    } label: {
                        Text(isDescriptionExpanded ? "Свернуть" : "Подробнее...")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AnixartFormat.accentRed)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Video Section (Screenshot 7)

    private var videoCategoryCards: [(name: String, imageURL: URL?)] {
        if let banners = current.videoBanners, !banners.isEmpty {
            return banners.map { ($0.name ?? "Видео", $0.imageURL) }
        }
        if !videoBlocks.isEmpty {
            return videoBlocks.compactMap { block in
                guard let name = block.category?.name, !(block.videos?.isEmpty ?? true) else { return nil }
                return (name, block.videos?.first?.thumbnailURL)
            }
        }
        return []
    }

    @ViewBuilder
    private var videoSection: some View {
        let cards = videoCategoryCards
        if !cards.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                    .padding(.horizontal, 16)

                HStack {
                    Text("Видео")
                        .font(.title3.bold())
                    Spacer()
                    NavigationLink(value: ReleaseDetailRoute.videos) {
                        Text("Показать все")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AnixartFormat.accentRed)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                            NavigationLink(value: ReleaseDetailRoute.videos) {
                                ZStack {
                                    Color.secondary.opacity(0.22)
                                        .frame(width: 172, height: 102)
                                        .overlay {
                                            AsyncImage(url: card.imageURL) { phase in
                                                if case .success(let image) = phase {
                                                    image.resizable().scaledToFill()
                                                }
                                            }
                                        }
                                        .clipped()
                                        .overlay(Color.black.opacity(0.45))

                                    Text(card.name)
                                        .font(.headline.weight(.medium))
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 8)
                                }
                                .frame(width: 172, height: 102)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 18)
        }
    }

    // MARK: - Rating Section (Screenshot 7)

    @ViewBuilder
    private var ratingSection: some View {
        let grade = current.grade ?? 0
        let totalVotes = current.voteCount ?? 0
        let maxBarCount = max(1, current.voteBreakdown.map(\.count).max() ?? 1)

        VStack(alignment: .leading, spacing: 14) {
            Divider()

            Text("Рейтинг")
                .font(.title3.bold())

            HStack(alignment: .center, spacing: 20) {
                VStack(spacing: 4) {
                    formattedGradeText(grade)
                    Text(AnixartFormat.pluralVotes(totalVotes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(minWidth: 96)

                VStack(spacing: 5) {
                    ForEach(current.voteBreakdown, id: \.stars) { row in
                        HStack(spacing: 8) {
                            Text("\(row.stars)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 10)

                            GeometryReader { geo in
                                let ratio = totalVotes > 0 ? CGFloat(row.count) / CGFloat(maxBarCount) : 0
                                let fillWidth = row.count > 0 ? max(8, geo.size.width * ratio) : 0
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.2))
                                    if fillWidth > 0 {
                                        Capsule()
                                            .fill(AnixartFormat.accentRed)
                                            .frame(width: fillWidth)
                                    }
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }

            HStack {
                Color.secondary.opacity(0.18)
                    .frame(width: 36, height: 36)
                    .overlay {
                        AsyncImage(url: session.currentProfile?.avatarURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .clipped()
                    .clipShape(Circle())

                ForEach(1...5, id: \.self) { star in
                    Spacer()
                    let isFilled = (current.yourVote ?? 0) >= star
                    Button {
                        Task {
                            if current.yourVote == star {
                                await clearVote()
                            } else {
                                await vote(star)
                            }
                        }
                    } label: {
                        Image(systemName: isFilled ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundStyle(AnixartFormat.accentRed)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
    }

    private func formattedGradeText(_ grade: Double) -> some View {
        let formatted = String(format: "%.2f", grade)
        let prefix = String(formatted.dropLast())
        let lastDigit = String(formatted.suffix(1))

        return HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(prefix)
                .font(.system(size: 38, weight: .semibold, design: .rounded))
            Text(lastDigit)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.primary)
    }

    // MARK: - People Lists Section (Screenshots 7 & 9)

    @ViewBuilder
    private var peopleListsSection: some View {
        let total = current.listStatsTotal
        if total > 0 {
            let entries: [(status: BookmarkStatus, count: Int)] = [
                (.watching, current.watchingCount ?? 0),
                (.planned, current.planCount ?? 0),
                (.completed, current.completedCount ?? 0),
                (.onHold, current.holdOnCount ?? 0),
                (.dropped, current.droppedCount ?? 0)
            ]

            VStack(alignment: .leading, spacing: 12) {
                Divider()

                Text("В списках у людей")
                    .font(.title3.bold())

                GeometryReader { geo in
                    HStack(spacing: 0) {
                        ForEach(entries, id: \.status) { entry in
                            if entry.count > 0 {
                                Rectangle()
                                    .fill(entry.status.color)
                                    .frame(width: max(4, geo.size.width * CGFloat(entry.count) / CGFloat(total)))
                            }
                        }
                    }
                }
                .frame(height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entries, id: \.status) { entry in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(entry.status.color)
                                .frame(width: 12, height: 12)
                            Text(entry.status.title)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(AnixartFormat.spaced(entry.count))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
        }
    }

    // MARK: - Screenshots Section (Screenshot 9)

    @ViewBuilder
    private var screenshotsSection: some View {
        let urls = current.screenshotURLs
        if !urls.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                    .padding(.horizontal, 16)

                Text("Кадры")
                    .font(.title3.bold())
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(Array(urls.enumerated()), id: \.offset) { idx, url in
                            Button {
                                activeGallery = GallerySelection(index: idx)
                            } label: {
                                Color.secondary.opacity(0.16)
                                    .frame(width: 196, height: 112)
                                    .overlay {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image.resizable().scaledToFill()
                                            default:
                                                EmptyView()
                                            }
                                        }
                                    }
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 18)
        }
    }

    // MARK: - Collections Rows (Screenshot 9)

    private var collectionsLinksSection: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.top, 18)

            NavigationLink(value: ReleaseDetailRoute.collections) {
                HStack(spacing: 10) {
                    Text("Показать в коллекциях")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    if let count = current.collectionCount, count > 0 {
                        Text("\(count)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            Button {
                showAddToCollection = true
            } label: {
                HStack {
                    Text("Добавить к себе в коллекцию")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Related Section

    @ViewBuilder
    private var relatedSection: some View {
        if !relatedReleases.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Связанные релизы")
                    .font(.title3.bold())
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(relatedReleases) { item in
                            NavigationLink(value: item) {
                                ReleasePosterCard(release: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 18)
        }
    }

    // MARK: - Comments Preview & Inline Composer (Screenshot 10)

    private var commentsPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Комментарии")
                        .font(.title3.bold())
                    Text("Популярные и актуальные")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                NavigationLink(value: ReleaseDetailRoute.comments) {
                    Text("Показать все")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AnixartFormat.accentRed)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            if isLoadingDetails && comments.isEmpty {
                ProgressView("Загрузка комментариев...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if comments.isEmpty {
                Text("Комментариев пока нет. Будьте первым!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(comments.prefix(5)) { comment in
                        ReleaseCommentRow(
                            comment: comment,
                            isOwnComment: comment.profile?.id == session.currentProfile?.id,
                            onReply: { replyingToComment = comment },
                            onVote: { vote in Task { await voteComment(comment, vote: vote) } },
                            onDelete: { Task { await deleteComment(comment) } }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }

            Divider()
                .padding(.top, 4)

            CommentComposerBar(
                text: $newCommentText,
                isSpoiler: $isSpoilerComment,
                replyingTo: replyingToComment,
                isSending: isSubmittingComment,
                onCancelReply: { replyingToComment = nil },
                onShowRules: { showRulesAlert = true },
                onSend: { Task { await submitComment() } }
            )
        }
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    // MARK: - More Menu Bottom Sheet (Screenshot 6)

    private var moreActionsSheet: some View {
        VStack(alignment: .leading, spacing: 4) {
            ShareLink(item: shareURL) {
                HStack(spacing: 14) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 24)
                    Text("Поделиться")
                    Spacer()
                }
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                UIPasteboard.general.string = shareURL.absoluteString
                showMoreSheet = false
                alertMessage = "Ссылка скопирована в буфер обмена."
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 24)
                    Text("Скопировать ссылку")
                    Spacer()
                }
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                showMoreSheet = false
                alertMessage = "Добавление ярлыка на главный экран на iOS пока не поддерживается."
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "house")
                        .frame(width: 24)
                    Text("На главный экран")
                    Spacer()
                }
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                showMoreSheet = false
                showReportSheet = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "exclamationmark.circle")
                        .frame(width: 24)
                    Text("Пожаловаться")
                    Spacer()
                }
                .font(.body)
                .foregroundStyle(AnixartFormat.accentRed)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Helpers & Networking

    private func buildInfoAlertText() -> String {
        var lines: [String] = []
        if let alt = current.titleAlt, !alt.isEmpty {
            lines.append("Альтернативные названия:\n\(alt)")
        }
        if let note = current.note, !note.isEmpty {
            lines.append("Примечание:\n\(note)")
        }
        if lines.isEmpty {
            return "ID релиза: \(current.id)"
        }
        return lines.joined(separator: "\n\n")
    }

    private func loadAll() async {
        isLoadingDetails = true
        defer { isLoadingDetails = false }

        let api = self.api
        let releaseId = release.id
        let needsFullDetail = !prefetchedFullRelease

        let detailTask: Task<Release?, Never>? = needsFullDetail ? Task {
            try? await api.release(id: releaseId, extendedMode: true)
        } : nil
        let typesTask = Task<[VoiceoverType], Never> {
            (try? await api.episodeTypes(releaseId: releaseId)) ?? []
        }
        let commentsTask = Task<PageableResponse<ReleaseComment>?, Never> {
            try? await api.releaseComments(releaseId: releaseId, page: 0, sort: 3)
        }
        let videosTask = Task<ReleaseVideosResponse?, Never> {
            try? await api.releaseVideos(releaseId: releaseId)
        }

        defer {
            detailTask?.cancel()
            typesTask.cancel()
            commentsTask.cancel()
            videosTask.cancel()
        }

        let detailed: Release?
        if let detailTask {
            detailed = await detailTask.value
        } else {
            detailed = nil
        }
        let loadedTypes = await typesTask.value
        let loadedCommentsResp = await commentsTask.value
        let loadedVideosResp = await videosTask.value

        guard !Task.isCancelled else { return }

        if let detailed {
            fullRelease = detailed
        }
        voiceovers = loadedTypes
        comments = loadedCommentsResp?.content ?? []
        totalCommentsCount = Int(loadedCommentsResp?.totalCount ?? Int64(current.commentCount ?? comments.count))
        videoBlocks = loadedVideosResp?.blocks ?? []
        streamingPlatforms = loadedVideosResp?.streamingPlatforms ?? []

        if let relatedId = (detailed?.relatedId ?? release.relatedId), relatedId > 1 {
            relatedReleases = (try? await api.related(relatedId: relatedId, page: 0).content) ?? []
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

    private func submitComment() async {
        guard ensureAuthenticated() else { return }
        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSubmittingComment = true
        defer { isSubmittingComment = false }

        do {
            let resp = try await api.addReleaseComment(
                releaseId: release.id,
                message: trimmed,
                spoiler: isSpoilerComment,
                parentCommentId: replyingToComment?.id,
                replyToProfileId: replyingToComment?.profile?.id
            )
            newCommentText = ""
            isSpoilerComment = false
            replyingToComment = nil
            if let comment = resp.comment {
                comments.insert(comment, at: 0)
                totalCommentsCount += 1
            } else {
                let loaded = try await api.releaseComments(releaseId: release.id, page: 0, sort: 3)
                comments = loaded.content
                if let total = loaded.totalCount {
                    totalCommentsCount = Int(total)
                }
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func voteComment(_ comment: ReleaseComment, vote: Int) async {
        guard ensureAuthenticated() else { return }
        do {
            _ = try await api.voteReleaseComment(commentId: comment.id, vote: vote)
            comments = try await api.releaseComments(releaseId: release.id, page: 0, sort: 3).content
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func deleteComment(_ comment: ReleaseComment) async {
        guard ensureAuthenticated() else { return }
        do {
            _ = try await api.deleteReleaseComment(commentId: comment.id)
            comments.removeAll { $0.id == comment.id }
            totalCommentsCount = max(0, totalCommentsCount - 1)
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}

@MainActor
private struct ReleaseReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = SessionStore.shared

    let releaseId: Int64
    let onCompleted: (String) -> Void

    @State private var reasons: [ReportReason] = []
    @State private var selectedReasonId: Int64?
    @State private var message = ""
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let api = AnixartAPI()

    var body: some View {
        NavigationStack {
            Form {
                if !session.isAuthenticated {
                    Text("Войдите в аккаунт, чтобы отправить жалобу.")
                        .foregroundStyle(.secondary)
                } else if isLoading && reasons.isEmpty {
                    ProgressView("Загрузка причин...")
                } else {
                    Section("Причина") {
                        ForEach(reasons) { reason in
                            Button {
                                selectedReasonId = reason.id
                            } label: {
                                HStack {
                                    Text(reason.name ?? "Причина #\(reason.id)")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedReasonId == reason.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(AnixartFormat.accentRed)
                                    }
                                }
                            }
                        }
                    }

                    Section("Комментарий") {
                        TextField("Опишите проблему (необязательно)", text: $message, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Пожаловаться")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSubmitting ? "Отправка..." : "Отправить") {
                        Task { await submit() }
                    }
                    .disabled(!session.isAuthenticated || selectedReasonId == nil || isSubmitting)
                }
            }
            .task {
                guard session.isAuthenticated else { return }
                isLoading = true
                defer { isLoading = false }
                do {
                    reasons = try await api.reportReasons()
                    selectedReasonId = reasons.first?.id
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func submit() async {
        guard let reasonId = selectedReasonId else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            _ = try await api.reportRelease(releaseId: releaseId, reasonId: reasonId, message: message.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
            onCompleted("Жалоба отправлена.")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
