import SwiftUI

private enum HomeFeedTab: String, CaseIterable, Identifiable, Hashable {
    case myTab = "Моя вкладка"
    case anime = "Аниме"
    case donghua = "Дунхуа"
    case latest = "Последнее"
    case ongoing = "Онгоинги"
    case announcements = "Анонсы"
    case completed = "Завершённые"
    case movies = "Фильмы"
    case ova = "OVA"

    var id: String { rawValue }
}

private enum HomeDestination: Hashable {
    case quickSearch
    case notifications
    case feedSettings
    case myTabSettings
}

private struct HomeTabPageCache {
    var items: [Release]
    var page: Int
    var hasMore: Bool
}

struct HomeView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var selectedTab: HomeFeedTab = .anime
    @State private var tabCache: [HomeFeedTab: HomeTabPageCache] = [:]
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?

    private let api = AnixartAPI()
    private let accentRed = Color(red: 0.94, green: 0.27, blue: 0.36)

    private var currentItems: [Release] {
        tabCache[selectedTab]?.items ?? []
    }

    private var hasMore: Bool {
        tabCache[selectedTab]?.hasMore ?? true
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topSearchBar
                tabsStrip
                Divider()
                feedList
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Release.self) { release in
                ReleaseDetailView(release: release)
                    .environmentObject(session)
            }
            .navigationDestination(for: HomeDestination.self) { dest in
                switch dest {
                case .quickSearch:
                    HomeQuickSearchView()
                        .environmentObject(session)
                case .notifications:
                    NotificationsView()
                case .feedSettings:
                    InDevelopmentView(
                        title: "Настройки",
                        message: "Настройки главной ленты и внешнего вида пока находятся в разработке."
                    )
                case .myTabSettings:
                    InDevelopmentView(
                        title: "Моя вкладка",
                        message: "Настройка персональных фильтров для раздела «Моя вкладка» пока находится в разработке."
                    )
                }
            }
            .task(id: selectedTab) {
                if selectedTab != .myTab, tabCache[selectedTab] == nil {
                    await loadTab(selectedTab, page: 0, append: false)
                }
            }
        }
    }

    // MARK: - Top Bar

    private var topSearchBar: some View {
        HStack(spacing: 10) {
            NavigationLink(value: HomeDestination.quickSearch) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("Поиск аниме")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: HomeDestination.feedSettings) {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(.primary.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            NavigationLink(value: HomeDestination.notifications) {
                Image(systemName: "bell")
                    .font(.title3)
                    .foregroundStyle(.primary.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .overlay(alignment: .topTrailing) {
                        if session.unreadNotificationsCount > 0 {
                            Text(session.unreadNotificationsCount > 99 ? "99+" : "\(session.unreadNotificationsCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(accentRed)
                                .clipShape(Capsule())
                                .offset(x: 2, y: 1)
                        }
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: - Section Tabs

    private var tabsStrip: some View {
        HStack(spacing: 0) {
            NavigationLink(value: HomeDestination.myTabSettings) {
                Image(systemName: "slider.horizontal.3")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.8))
                    .frame(width: 44, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(HomeFeedTab.allCases) { tab in
                            let isSelected = (selectedTab == tab)
                            Button {
                                DebugLogger.log(.nav, "HomeView select tab='\(tab.rawValue)'")
                                selectedTab = tab
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo(tab, anchor: .center)
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Text(tab.rawValue)
                                        .font(.subheadline.weight(isSelected ? .semibold : .medium))
                                        .foregroundStyle(isSelected ? accentRed : .secondary)
                                        .lineLimit(1)

                                    Capsule()
                                        .fill(isSelected ? accentRed : Color.clear)
                                        .frame(height: 2.5)
                                }
                                .padding(.top, 8)
                            }
                            .buttonStyle(.plain)
                            .id(tab)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.trailing, 14)
                }
                .onAppear {
                    proxy.scrollTo(selectedTab, anchor: .center)
                }
                .onChange(of: selectedTab) { _, newTab in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newTab, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Feed List

    private var feedList: some View {
        Group {
            if selectedTab == .myTab {
                ContentUnavailableView {
                    Label("Пока в разработке", systemImage: "wrench.and.screwdriver")
                } description: {
                    Text("Персональный раздел «Моя вкладка» и его настройка пока находятся в разработке.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if (isLoading || (tabCache[selectedTab] == nil && errorMessage == nil)) && currentItems.isEmpty {
                            ProgressView("Загрузка...")
                                .frame(maxWidth: .infinity)
                                .padding(.top, 80)
                        } else if let errorMessage, currentItems.isEmpty {
                    ContentUnavailableView {
                        Label("Не удалось загрузить", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Повторить") {
                            Task { await loadTab(selectedTab, page: 0, append: false) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 60)
                } else if currentItems.isEmpty {
                    ContentUnavailableView(
                        "Список пуст",
                        systemImage: "sparkles.tv",
                        description: Text("Потяните вниз для обновления.")
                    )
                    .padding(.top, 60)
                } else {
                    ForEach(Array(currentItems.enumerated()), id: \.element.id) { idx, release in
                        HStack(alignment: .top, spacing: 4) {
                            NavigationLink(value: release) {
                                ReleaseRow(release: release)
                            }
                            .buttonStyle(.plain)

                            Menu {
                                ForEach(BookmarkStatus.allCases) { status in
                                    Button {
                                        Task { await quickSetBookmark(release: release, status: status) }
                                    } label: {
                                        Label(status.title, systemImage: status.systemImage)
                                    }
                                }
                                Divider()
                                Button {
                                    Task { await quickToggleFavorite(release: release) }
                                } label: {
                                    Label(
                                        (release.isFavorite ?? false) ? "Убрать из избранного" : "В избранное",
                                        systemImage: (release.isFavorite ?? false) ? "heart.slash" : "heart"
                                    )
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .rotationEffect(.degrees(90))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, height: 32)
                                    .contentShape(Rectangle())
                            }
                        }
                        .padding(.horizontal, 14)
                        .onAppear {
                            if idx >= currentItems.count - 3, hasMore, !isLoadingMore {
                                Task {
                                    let nextPage = (tabCache[selectedTab]?.page ?? 0) + 1
                                    await loadTab(selectedTab, page: nextPage, append: true)
                                }
                            }
                        }
                    }

                    if isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .refreshable {
            DebugLogger.log(.nav, "HomeView pull-to-refresh tab='\(selectedTab.rawValue)'")
            await loadTab(selectedTab, page: 0, append: false)
        }
            }
        }
    }

    // MARK: - Networking

    private func fetchReleases(for tab: HomeFeedTab, page: Int) async throws -> [Release] {
        switch tab {
        case .myTab:
            if session.isAuthenticated {
                let prev = page == 0 ? -1 : page - 1
                let recs = try await api.recommendations(page: page, previousPage: prev).content
                if !recs.isEmpty || page > 0 {
                    return recs
                }
            }
            return try await api.filterReleases(page: page, filter: FilterRequest(sort: 2), extendedMode: true).content

        case .anime:
            return try await api.filterReleases(
                page: page,
                filter: FilterRequest(categoryId: 1, country: "Япония", sort: 0),
                extendedMode: true
            ).content

        case .donghua:
            return try await api.filterReleases(
                page: page,
                filter: FilterRequest(country: "Китай", sort: 0),
                extendedMode: true
            ).content

        case .latest:
            return try await api.filterReleases(
                page: page,
                filter: FilterRequest(sort: 0),
                extendedMode: true
            ).content

        case .ongoing:
            return try await api.filterReleases(
                page: page,
                filter: FilterRequest(sort: 0, statusId: 2),
                extendedMode: true
            ).content

        case .announcements:
            return try await api.filterReleases(
                page: page,
                filter: FilterRequest(sort: 0, statusId: 3),
                extendedMode: true
            ).content

        case .completed:
            return try await api.filterReleases(
                page: page,
                filter: FilterRequest(sort: 0, statusId: 1),
                extendedMode: true
            ).content

        case .movies:
            return try await api.filterReleases(
                page: page,
                filter: FilterRequest(categoryId: 2, sort: 0),
                extendedMode: true
            ).content

        case .ova:
            return try await api.filterReleases(
                page: page,
                filter: FilterRequest(categoryId: 3, sort: 0),
                extendedMode: true
            ).content
        }
    }

    private func loadTab(_ tab: HomeFeedTab, page: Int, append: Bool) async {
        if append {
            guard !isLoadingMore else { return }
            isLoadingMore = true
        } else {
            isLoading = true
            errorMessage = nil
        }
        defer {
            if append {
                isLoadingMore = false
            } else {
                isLoading = false
            }
        }

        DebugLogger.log(.nav, "HomeView load tab='\(tab.rawValue)' page=\(page) append=\(append)")

        do {
            let fetched = try await fetchReleases(for: tab, page: page)
            guard !Task.isCancelled else { return }

            let merged: [Release]
            if append, let existing = tabCache[tab]?.items {
                var seen = Set(existing.map(\.id))
                let uniqueNew = fetched.filter { seen.insert($0.id).inserted }
                merged = existing + uniqueNew
            } else {
                merged = fetched
            }

            tabCache[tab] = HomeTabPageCache(
                items: merged,
                page: page,
                hasMore: fetched.count >= 20
            )
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            DebugLogger.log(.ui, "HomeView load error tab='\(tab.rawValue)': \(error.localizedDescription)", level: .error)
            if !append {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func quickSetBookmark(release: Release, status: BookmarkStatus) async {
        guard session.isAuthenticated else {
            session.infoMessage = "Войдите в аккаунт, чтобы добавлять релизы в списки."
            return
        }
        do {
            _ = try await api.addToProfileList(status: status, releaseId: release.id)
            session.infoMessage = "Добавлено в «\(status.title)»."
        } catch {
            session.errorMessage = error.localizedDescription
        }
    }

    private func quickToggleFavorite(release: Release) async {
        guard session.isAuthenticated else {
            session.infoMessage = "Войдите в аккаунт, чтобы добавлять релизы в избранное."
            return
        }
        do {
            if release.isFavorite == true {
                _ = try await api.deleteFavorite(releaseId: release.id)
                session.infoMessage = "Убрано из избранного."
            } else {
                _ = try await api.addFavorite(releaseId: release.id)
                session.infoMessage = "Добавлено в избранное."
            }
        } catch {
            session.errorMessage = error.localizedDescription
        }
    }
}

private struct InDevelopmentView: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Пока в разработке", systemImage: "wrench.and.screwdriver")
        } description: {
            Text(message)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HomeQuickSearchView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var query = ""
    @State private var results: [Release] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var errorMessage: String?

    private let api = AnixartAPI()

    var body: some View {
        List {
            ForEach(results) { release in
                NavigationLink(value: release) {
                    ReleaseRow(release: release)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Поиск аниме")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Название аниме...")
        .onSubmit(of: .search) {
            Task { await performSearch() }
        }
        .overlay {
            if isLoading {
                ProgressView("Поиск...")
            } else if let errorMessage, results.isEmpty {
                ContentUnavailableView("Ошибка", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if hasSearched && results.isEmpty {
                ContentUnavailableView("Ничего не найдено", systemImage: "magnifyingglass")
            } else if !hasSearched {
                ContentUnavailableView("Введите название аниме", systemImage: "magnifyingglass")
            }
        }
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        hasSearched = true
        defer { isLoading = false }
        DebugLogger.log(.nav, "HomeQuickSearchView search '\(trimmed)'")
        do {
            results = try await api.searchReleases(query: trimmed, page: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
