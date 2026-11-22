import SwiftUI

private enum BookmarkTab: String, CaseIterable, Identifiable {
    case favorites = "Избранное"
    case watching = "Смотрю"
    case planned = "В планах"
    case completed = "Просмотрено"
    case onHold = "Отложено"
    case dropped = "Брошено"

    var id: String { rawValue }

    var listStatus: BookmarkStatus? {
        switch self {
        case .favorites: return nil
        case .watching: return .watching
        case .planned: return .planned
        case .completed: return .completed
        case .onHold: return .onHold
        case .dropped: return .dropped
        }
    }
}

struct BookmarksView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var selectedTab: BookmarkTab = .watching
    @State private var releases: [Release] = []
    @State private var currentPage = 0
    @State private var tabCache: [BookmarkTab: (items: [Release], page: Int)] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = AnixartAPI()

    var body: some View {
        NavigationStack {
            Group {
                if !session.isAuthenticated {
                    ContentUnavailableView {
                        Label("Закладки недоступны", systemImage: "bookmark.slash")
                    } description: {
                        Text("Войдите в аккаунт Anixart, чтобы управлять списками и избранным.")
                    } actions: {
                        Button("Перейти ко входу") {
                            session.exitGuestMode()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(BookmarkTab.allCases) { tab in
                                    Button {
                                        selectedTab = tab
                                    } label: {
                                        Text(tab.rawValue)
                                            .font(.subheadline.weight(.medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(selectedTab == tab ? Color.accentColor : Color.secondary.opacity(0.14))
                                            .foregroundStyle(selectedTab == tab ? .white : .primary)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                        }

                        List {
                            ForEach(releases) { release in
                                NavigationLink(value: release) {
                                    ReleaseRow(release: release)
                                }
                            }
                            if !releases.isEmpty {
                                Button("Загрузить ещё") {
                                    Task { await load(page: currentPage + 1, append: true) }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .overlay {
                            if isLoading && releases.isEmpty {
                                ProgressView("Загрузка списка...")
                            } else if releases.isEmpty {
                                ContentUnavailableView {
                                    Label("Список пуст", systemImage: "bookmark")
                                } actions: {
                                    Button("Обновить") {
                                        Task { await load(page: 0, append: false) }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        .refreshable {
                            await load(page: 0, append: false)
                        }
                    }
                }
            }
            .navigationTitle("Закладки")
            .navigationDestination(for: Release.self) {
                ReleaseDetailView(release: $0)
                    .environmentObject(session)
            }
            .task(id: selectedTab) {
                guard session.isAuthenticated else { return }
                if let cached = tabCache[selectedTab] {
                    releases = cached.items
                    currentPage = cached.page
                } else {
                    await load(page: 0, append: false)
                }
            }
            .alert("Ошибка", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func load(page: Int, append: Bool) async {
        DebugLogger.log(.nav, "BookmarksView load tab=\(selectedTab.rawValue) page=\(page) append=\(append)")
        isLoading = true
        defer { isLoading = false }
        do {
            let targetTab = selectedTab
            let items: [Release]
            if let status = targetTab.listStatus {
                items = try await api.profileList(status: status, page: page).content
            } else {
                items = try await api.favorites(page: page).content
            }
            let updatedItems: [Release]
            if append && targetTab == selectedTab {
                updatedItems = releases + items
            } else if append {
                updatedItems = (tabCache[targetTab]?.items ?? []) + items
            } else {
                updatedItems = items
            }
            tabCache[targetTab] = (updatedItems, page)
            if targetTab == selectedTab {
                releases = updatedItems
                currentPage = page
            }
        } catch {
            DebugLogger.log(.ui, "BookmarksView load error: \(error.localizedDescription)", level: .error)
            errorMessage = error.localizedDescription
        }
    }
}
