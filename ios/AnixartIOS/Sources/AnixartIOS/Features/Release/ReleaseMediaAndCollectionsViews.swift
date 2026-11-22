import SwiftUI

private struct PlayableVideoURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

@MainActor
struct ReleaseVideosView: View {
    @Environment(\.dismiss) private var dismiss

    let release: Release
    let initialBlocks: [ReleaseVideoBlock]

    @State private var blocks: [ReleaseVideoBlock] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedVideoURL: PlayableVideoURL?

    private let api = AnixartAPI()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroHeader

                if isLoading && blocks.isEmpty {
                    ProgressView("Загрузка видео...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let errorMessage, blocks.isEmpty {
                    ContentUnavailableView {
                        Label("Не удалось загрузить видео", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Повторить") {
                            Task { await loadVideos() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if blocks.isEmpty {
                    ContentUnavailableView("Видео пока нет", systemImage: "play.rectangle.on.rectangle")
                        .padding(.top, 40)
                } else {
                    ForEach(blocks) { block in
                        let videos = block.videos ?? []
                        if !videos.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(block.category?.name ?? "Видео")
                                    .font(.headline)
                                    .padding(.horizontal, 16)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 12) {
                                        ForEach(videos) { video in
                                            Button {
                                                if let url = video.playableURL {
                                                    selectedVideoURL = PlayableVideoURL(url: url)
                                                }
                                            } label: {
                                                videoCard(video, fallbackTitle: block.category?.name)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 28)
        }
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: release.id) {
            if blocks.isEmpty {
                blocks = initialBlocks
            }
            if blocks.isEmpty {
                await loadVideos()
            }
        }
        .sheet(item: $selectedVideoURL) { target in
            ReleaseSafariSheet(url: target.url)
                .ignoresSafeArea()
        }
    }

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            Color.secondary.opacity(0.25)
                .frame(height: 200)
                .overlay {
                    AsyncImage(url: release.imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            EmptyView()
                        }
                    }
                }
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.25), .black.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            VStack(alignment: .leading, spacing: 4) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.top, 50)

                Spacer()

                Text("Видео")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text(release.displayTitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(height: 200)
    }

    private func videoCard(_ video: ReleaseVideoItem, fallbackTitle: String?) -> some View {
        ZStack(alignment: .bottomLeading) {
            Color.secondary.opacity(0.18)
                .frame(width: 224, height: 126)
                .overlay {
                    AsyncImage(url: video.thumbnailURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: "play.rectangle")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.75)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }

            VStack(alignment: .leading) {
                HStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.red)
                        .frame(width: 26, height: 18)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.white)
                        }
                    Spacer()
                }
                Spacer()
                let titleText = (video.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                    ? video.title!
                    : (fallbackTitle ?? "Видео")
                Text(titleText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(10)
        }
        .frame(width: 224, height: 126)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func loadVideos() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let resp = try await api.releaseVideos(releaseId: release.id)
            blocks = resp.blocks ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ScreenshotsGalleryView: View {
    @Environment(\.dismiss) private var dismiss

    let urls: [URL]
    @State var selectedIndex: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(urls.enumerated()), id: \.offset) { idx, url in
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.white.opacity(0.6))
                        default:
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    .tag(idx)
                    .padding()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            HStack {
                Text("\(selectedIndex + 1) / \(urls.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
        }
    }
}

@MainActor
struct ReleaseCollectionsListView: View {
    let release: Release

    @State private var collections: [CollectionItem] = []
    @State private var page = 0
    @State private var hasMore = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = AnixartAPI()

    var body: some View {
        List {
            ForEach(Array(collections.enumerated()), id: \.element.id) { idx, item in
                NavigationLink {
                    CollectionDetailView(collection: item)
                } label: {
                    HStack(spacing: 12) {
                        Color.secondary.opacity(0.15)
                            .frame(width: 68, height: 68)
                            .overlay {
                                AsyncImage(url: item.imageURL) { phase in
                                    switch phase {
                                    case .success(let image): image.resizable().scaledToFill()
                                    default: Image(systemName: "rectangle.stack").foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title ?? "Без названия")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                            if let creator = item.creator {
                                Text(creator.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 10) {
                                if let count = item.releaseCount {
                                    Text("Релизов: \(count)")
                                }
                                if let fav = item.favoriteCount {
                                    Label("\(fav)", systemImage: "heart")
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onAppear {
                    if idx >= collections.count - 4, hasMore, !isLoading {
                        Task { await load(page: page + 1, append: true) }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("В коллекциях")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading && collections.isEmpty {
                ProgressView("Загрузка коллекций...")
            } else if let errorMessage, collections.isEmpty {
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
            } else if collections.isEmpty {
                ContentUnavailableView("Коллекции не найдены", systemImage: "rectangle.stack")
            }
        }
        .task(id: release.id) {
            if collections.isEmpty {
                await load(page: 0, append: false)
            }
        }
    }

    private func load(page targetPage: Int, append: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        if !append { errorMessage = nil }
        defer { isLoading = false }
        do {
            let resp = try await api.releaseCollections(releaseId: release.id, page: targetPage)
            if append {
                collections.append(contentsOf: resp.content)
            } else {
                collections = resp.content
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

@MainActor
struct AddToCollectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = SessionStore.shared

    let release: Release

    @State private var myCollections: [CollectionItem] = []
    @State private var addedIds: Set<Int64> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    private let api = AnixartAPI()

    var body: some View {
        NavigationStack {
            List {
                if !session.isAuthenticated {
                    ContentUnavailableView {
                        Label("Требуется авторизация", systemImage: "person.crop.circle.badge.exclamationmark")
                    } description: {
                        Text("Войдите в аккаунт Anixart, чтобы добавлять релизы в свои коллекции.")
                    }
                } else if isLoading && myCollections.isEmpty {
                    ProgressView("Загрузка ваших коллекций...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if myCollections.isEmpty {
                    ContentUnavailableView(
                        "У вас пока нет коллекций",
                        systemImage: "rectangle.stack.badge.plus",
                        description: Text("Создайте коллекцию в своём профиле или на сайте Anixart, и она появится здесь.")
                    )
                } else {
                    ForEach(myCollections) { col in
                        let isAdded = addedIds.contains(col.id)
                        Button {
                            Task { await toggleCollection(col) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.title3)
                                    .foregroundStyle(isAdded ? BookmarkStatus.watching.color : AnixartFormat.accentRed)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(col.title ?? "Без названия")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    if let count = col.releaseCount {
                                        Text("Релизов: \(count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Добавить в коллекцию")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
            .task {
                await loadMyCollections()
            }
            .alert("Сообщение", isPresented: Binding(
                get: { errorMessage != nil || statusMessage != nil },
                set: { if !$0 { errorMessage = nil; statusMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? statusMessage ?? "")
            }
        }
    }

    private func loadMyCollections() async {
        guard session.isAuthenticated else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let forRelease = try? await api.myCollectionsForRelease(releaseId: release.id, page: 0).content
            let allMy = try await api.myCollections(page: 0).content
            myCollections = allMy.isEmpty ? (forRelease ?? []) : allMy
            if let existing = forRelease {
                addedIds = Set(existing.map(\.id))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleCollection(_ col: CollectionItem) async {
        let currentlyAdded = addedIds.contains(col.id)
        do {
            if currentlyAdded {
                _ = try await api.removeReleaseFromCollection(collectionId: col.id, releaseId: release.id)
                addedIds.remove(col.id)
                statusMessage = "Удалено из коллекции «\(col.title ?? "")»."
            } else {
                _ = try await api.addReleaseToCollection(collectionId: col.id, releaseId: release.id)
                addedIds.insert(col.id)
                statusMessage = "Добавлено в коллекцию «\(col.title ?? "")»."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
