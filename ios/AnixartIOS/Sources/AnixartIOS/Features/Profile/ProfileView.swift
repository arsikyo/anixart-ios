import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var friends: [Profile] = []
    @State private var showSettings = false
    @State private var showLogs = false
    @State private var isLoading = false

    private let api = AnixartAPI()

    var body: some View {
        NavigationStack {
            List {
                if !session.isAuthenticated {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Гостевой режим")
                                .font(.headline)
                            Text("Войдите в аккаунт Anixart, чтобы синхронизировать закладки, историю просмотров, оценки и уведомления.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Войти в аккаунт") {
                                session.exitGuestMode()
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    }
                } else if let profile = session.currentProfile {
                    Section {
                        HStack(spacing: 14) {
                            AsyncImage(url: profile.avatarURL) { phase in
                                switch phase {
                                case .success(let image): image.resizable().scaledToFill()
                                default: Color.secondary.opacity(0.2)
                                }
                            }
                            .frame(width: 68, height: 68)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(profile.displayName)
                                        .font(.title3.bold())
                                    if profile.isVerified == true {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundStyle(.blue)
                                    }
                                    if profile.isSponsor == true {
                                        Image(systemName: "crown.fill")
                                            .foregroundStyle(.orange)
                                    }
                                }
                                if let status = profile.status, !status.isEmpty {
                                    Text(status)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if let rating = profile.ratingScore {
                                    Text("Рейтинг: \(rating)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Статистика") {
                        LabeledContent("Смотрю", value: "\(profile.watchingCount ?? 0)")
                        LabeledContent("В планах", value: "\(profile.planCount ?? 0)")
                        LabeledContent("Просмотрено", value: "\(profile.completedCount ?? 0)")
                        LabeledContent("Отложено", value: "\(profile.holdOnCount ?? 0)")
                        LabeledContent("Брошено", value: "\(profile.droppedCount ?? 0)")
                        LabeledContent("Избранное", value: "\(profile.favoriteCount ?? 0)")
                        LabeledContent("Просмотрено серий", value: "\(profile.watchedEpisodeCount ?? 0)")
                    }

                    Section("Активность") {
                        NavigationLink {
                            NotificationsView()
                        } label: {
                            HStack {
                                Label("Уведомления", systemImage: "bell")
                                Spacer()
                                if session.unreadNotificationsCount > 0 {
                                    Text("\(session.unreadNotificationsCount)")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    if !friends.isEmpty {
                        Section("Друзья (\(friends.count))") {
                            ForEach(friends) { friend in
                                NavigationLink {
                                    OtherProfileView(profileID: friend.id)
                                } label: {
                                    HStack(spacing: 10) {
                                        AsyncImage(url: friend.avatarURL) { phase in
                                            switch phase {
                                            case .success(let image): image.resizable().scaledToFill()
                                            default: Color.secondary.opacity(0.2)
                                            }
                                        }
                                        .frame(width: 36, height: 36)
                                        .clipShape(Circle())

                                        Text(friend.displayName)
                                    }
                                }
                            }
                        }
                    }
                } else if isLoading {
                    Section {
                        ProgressView("Загрузка профиля...")
                    }
                }

                Section("Приложение") {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Зеркала API и настройки", systemImage: "server.rack")
                    }

                    // DEBUG_LOGGER_TEMPORARY
                    Button {
                        showLogs = true
                    } label: {
                        Label("Диагностика и логи", systemImage: "ladybug")
                    }

                    if session.isAuthenticated {
                        Button("Выйти из аккаунта", role: .destructive) {
                            session.signOut()
                        }
                    }
                }
            }
            .navigationTitle("Профиль")
            .refreshable {
                await reload()
            }
            .task {
                await reload()
            }
            .sheet(isPresented: $showSettings) {
                APISettingsView()
            }
            .sheet(isPresented: $showLogs) {
                DebugLogsView()
            }
        }
    }

    private func reload() async {
        guard session.isAuthenticated else { return }
        isLoading = true
        defer { isLoading = false }
        await session.refreshProfileAndNotifications()
        if let id = session.currentProfile?.id ?? KeychainStore.getProfileID() {
            friends = (try? await api.friends(profileId: id, page: 0).content) ?? []
        }
    }
}

struct OtherProfileView: View {
    let profileID: Int64

    @State private var profile: Profile?
    @State private var social: ProfileSocialResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let api = AnixartAPI()

    var body: some View {
        List {
            if let profile {
                Section {
                    HStack(spacing: 14) {
                        AsyncImage(url: profile.avatarURL) { phase in
                            switch phase {
                            case .success(let image): image.resizable().scaledToFill()
                            default: Color.secondary.opacity(0.2)
                            }
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.displayName)
                                .font(.title3.bold())
                            if let status = profile.status, !status.isEmpty {
                                Text(status)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let rating = profile.ratingScore {
                                Text("Рейтинг: \(rating)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Статистика") {
                    LabeledContent("Смотрю", value: "\(profile.watchingCount ?? 0)")
                    LabeledContent("В планах", value: "\(profile.planCount ?? 0)")
                    LabeledContent("Просмотрено", value: "\(profile.completedCount ?? 0)")
                    LabeledContent("Серий просмотрено", value: "\(profile.watchedEpisodeCount ?? 0)")
                }

                if let social, hasAnySocial(social) {
                    Section("Соцсети") {
                        if let vk = social.vkPage, !vk.isEmpty { LabeledContent("VK", value: vk) }
                        if let tg = social.tgPage, !tg.isEmpty { LabeledContent("Telegram", value: tg) }
                        if let inst = social.instPage, !inst.isEmpty { LabeledContent("Instagram", value: inst) }
                        if let tt = social.ttPage, !tt.isEmpty { LabeledContent("TikTok", value: tt) }
                        if let dc = social.discordPage, !dc.isEmpty { LabeledContent("Discord", value: dc) }
                    }
                }
            }
        }
        .navigationTitle(profile?.displayName ?? "Профиль")
        .overlay {
            if isLoading && profile == nil {
                ProgressView("Загрузка профиля...")
            } else if let errorMessage, profile == nil {
                ContentUnavailableView(errorMessage, systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
        .task(id: profileID) {
            isLoading = true
            defer { isLoading = false }
            do {
                profile = try await api.profile(id: profileID).profile
                social = try? await api.profileSocial(id: profileID)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func hasAnySocial(_ s: ProfileSocialResponse) -> Bool {
        [s.vkPage, s.tgPage, s.instPage, s.ttPage, s.discordPage]
            .contains { !($0 ?? "").isEmpty }
    }
}

@MainActor
struct NotificationsView: View {
    @ObservedObject private var session = SessionStore.shared

    @State private var items: [ProfileNotification] = []
    @State private var currentPage = 0
    @State private var canLoadMore = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = AnixartAPI()

    var body: some View {
        List {
            ForEach(items) { item in
                Group {
                    if let release = item.release {
                        NavigationLink(value: release) {
                            notificationRow(item)
                        }
                    } else {
                        notificationRow(item)
                    }
                }
            }

            if canLoadMore {
                Button("Загрузить ещё") {
                    Task { await load(page: currentPage + 1) }
                }
            }
        }
        .navigationTitle("Уведомления")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Прочитать все") {
                    Task {
                        _ = try? await api.markNotificationsRead()
                        await session.refreshProfileAndNotifications()
                        await load(page: 0)
                    }
                }
                .disabled(items.isEmpty)
            }
        }
        .overlay {
            if isLoading && items.isEmpty {
                ProgressView("Загрузка...")
            } else if items.isEmpty {
                ContentUnavailableView("Уведомлений нет", systemImage: "bell.slash")
            }
        }
        .navigationDestination(for: Release.self) {
            ReleaseDetailView(release: $0)
                .environmentObject(session)
        }
        .task {
            await load(page: 0)
        }
        .refreshable {
            await load(page: 0)
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

    private func notificationRow(_ item: ProfileNotification) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let author = item.byProfile?.displayName {
                    Text(author)
                        .font(.subheadline.weight(.semibold))
                } else if let releaseTitle = item.release?.displayTitle {
                    Text(releaseTitle)
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                if item.isNew == true {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                }
            }
            if let message = item.message, !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func load(page: Int) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await api.notifications(page: page)
            if page == 0 {
                items = resp.content
            } else {
                items.append(contentsOf: resp.content)
            }
            currentPage = page
            let totalPages = resp.totalPageCount ?? 1
            canLoadMore = page + 1 < totalPages
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
