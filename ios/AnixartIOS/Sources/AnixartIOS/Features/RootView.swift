import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        Group {
            if session.canEnterMainApp {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .sheet(item: Binding(
            get: { session.deepLinkedReleaseID.map { DeepLinkReleaseItem(id: $0) } },
            set: { if $0 == nil { session.deepLinkedReleaseID = nil } }
        )) { item in
            NavigationStack {
                DeepLinkReleaseLoaderView(releaseID: item.id)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Закрыть") { session.deepLinkedReleaseID = nil }
                        }
                    }
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { session.errorMessage = nil }
        } message: {
            Text(session.errorMessage ?? "")
        }
        .alert("Информация", isPresented: Binding(
            get: { session.infoMessage != nil },
            set: { if !$0 { session.infoMessage = nil } }
        )) {
            Button("OK", role: .cancel) { session.infoMessage = nil }
        } message: {
            Text(session.infoMessage ?? "")
        }
    }
}

private struct DeepLinkReleaseItem: Identifiable {
    let id: Int64
}

private struct DeepLinkReleaseLoaderView: View {
    let releaseID: Int64
    @State private var release: Release?
    @State private var error: String?

    var body: some View {
        Group {
            if let release {
                ReleaseDetailView(release: release)
            } else if let error {
                ContentUnavailableView("Ошибка", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ProgressView("Загрузка релиза...")
            }
        }
        .task {
            do {
                release = try await AnixartAPI().release(id: releaseID)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Главная", systemImage: "flame.fill") }

            DiscoverView()
                .tabItem { Label("Обзор", systemImage: "calendar") }

            BookmarksView()
                .tabItem { Label("Закладки", systemImage: "bookmark.fill") }

            SearchView()
                .tabItem { Label("Поиск", systemImage: "magnifyingglass") }

            ProfileView()
                .tabItem { Label("Профиль", systemImage: "person.crop.circle") }
                .badge(session.unreadNotificationsCount > 0 ? Int(session.unreadNotificationsCount) : 0)
        }
    }
}
