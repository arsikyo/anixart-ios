import Foundation

enum PendingVerificationFlow: Equatable {
    case register(login: String, email: String, password: String, hash: String)
    case oauthRegister(provider: AuthProvider, token: String, login: String, email: String, hash: String)
    case restore(data: String, hash: String)
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var isAuthenticated = KeychainStore.getToken() != nil
    @Published var isGuestMode = false
    @Published private(set) var currentProfile: Profile?
    @Published private(set) var profileInfo: ProfileInfoResponse?
    @Published private(set) var unreadNotificationsCount: Int64 = 0

    @Published private(set) var availableMirrors: [String] = APIConfiguration.cachedMirrors
    @Published private(set) var configURLs: ConfigURLsResponse?
    @Published private(set) var toggles: TogglesResponse?

    @Published var pendingVerification: PendingVerificationFlow?
    @Published var pendingOAuthRegistration: (provider: AuthProvider, token: String, suggestedEmail: String?)?
    @Published var pendingTelegramAuth: OAuthService.TelegramAuthRequest?
    @Published var deepLinkedReleaseID: Int64?
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let api = AnixartAPI()
    private let oauth = OAuthService()
    private let mirrorDiscovery = MirrorDiscoveryService()

    var canEnterMainApp: Bool {
        isAuthenticated || isGuestMode
    }

    func bootstrap() async {
        let result = await mirrorDiscovery.syncConfiguration()
        availableMirrors = result.urls
        configURLs = result.configURLs
        toggles = result.toggles

        if isAuthenticated {
            await refreshProfileAndNotifications()
        }
    }

    func refreshMirrors() async {
        let result = await mirrorDiscovery.syncConfiguration()
        availableMirrors = result.urls
        configURLs = result.configURLs
        toggles = result.toggles
    }

    func refreshProfileAndNotifications() async {
        guard isAuthenticated else { return }
        if let info = try? await api.profileInfo() {
            profileInfo = info
        }
        if let profileID = KeychainStore.getProfileID(),
           let resp = try? await api.profile(id: profileID),
           let profile = resp.profile {
            currentProfile = profile
        }
        if let notif = try? await api.notificationCount() {
            unreadNotificationsCount = notif.count ?? 0
        }
    }

    func enterGuestMode() {
        isGuestMode = true
    }

    func exitGuestMode() {
        isGuestMode = false
    }

    func signIn(login: String, password: String) async {
        do {
            let response = try await api.signIn(login: login, password: password)
            guard let profileToken = response.profileToken, !profileToken.token.isEmpty else {
                throw APIError.unexpectedResponse
            }
            completeSession(token: profileToken.token, profile: response.profile, profileId: profileToken.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startSignUp(login: String, email: String, password: String) async {
        do {
            _ = try await api.checkLogin(login)
            let response = try await api.signUp(login: login, email: email, password: password)
            guard let hash = response.hash, !hash.isEmpty else {
                throw APIError.unexpectedResponse
            }
            pendingVerification = .register(login: login, email: email, password: password, hash: hash)
            infoMessage = "Код подтверждения отправлен на \(email)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startRestore(data: String) async {
        do {
            let response = try await api.restorePassword(data: data)
            guard let hash = response.hash, !hash.isEmpty else {
                throw APIError.unexpectedResponse
            }
            pendingVerification = .restore(data: data, hash: hash)
            infoMessage = "Код восстановления отправлен на привязанную почту."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmVerification(code: String, newPassword: String = "") async {
        guard let pending = pendingVerification else { return }
        do {
            switch pending {
            case .register(let login, let email, let password, let hash):
                let resp = try await api.verifyRegistration(
                    login: login,
                    email: email,
                    password: password,
                    hash: hash,
                    code: code
                )
                guard let profileToken = resp.profileToken, !profileToken.token.isEmpty else {
                    throw APIError.unexpectedResponse
                }
                pendingVerification = nil
                completeSession(token: profileToken.token, profile: resp.profile, profileId: profileToken.id)

            case .oauthRegister(let provider, let token, let login, let email, let hash):
                let resp = try await api.verifyRegistration(
                    login: login,
                    email: email,
                    password: "",
                    hash: hash,
                    code: code,
                    vkAccessToken: provider == .vk ? token : nil,
                    googleIdToken: provider == .google ? token : nil,
                    telegramIdToken: provider == .telegram ? token : nil,
                    yandexAccessToken: provider == .yandex ? token : nil
                )
                guard let profileToken = resp.profileToken, !profileToken.token.isEmpty else {
                    throw APIError.unexpectedResponse
                }
                pendingVerification = nil
                pendingOAuthRegistration = nil
                completeSession(token: profileToken.token, profile: resp.profile, profileId: profileToken.id)

            case .restore(let data, let hash):
                let resp = try await api.restoreVerify(data: data, newPassword: newPassword, hash: hash, code: code)
                guard let profileToken = resp.profileToken, !profileToken.token.isEmpty else {
                    throw APIError.unexpectedResponse
                }
                pendingVerification = nil
                completeSession(token: profileToken.token, profile: resp.profile, profileId: profileToken.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resendVerificationCode() async {
        guard let pending = pendingVerification else { return }
        do {
            switch pending {
            case .register(let login, let email, let password, let hash):
                let resp = try await api.resendVerification(login: login, email: email, password: password, hash: hash)
                pendingVerification = .register(login: login, email: email, password: password, hash: resp.hash ?? hash)
                infoMessage = "Повторный код отправлен."
            case .oauthRegister(let provider, let token, let login, let email, let hash):
                let resp = try await api.resendVerification(
                    login: login,
                    email: email,
                    password: "",
                    hash: hash,
                    vkAccessToken: provider == .vk ? token : nil,
                    googleIdToken: provider == .google ? token : nil,
                    telegramIdToken: provider == .telegram ? token : nil,
                    yandexAccessToken: provider == .yandex ? token : nil
                )
                pendingVerification = .oauthRegister(provider: provider, token: token, login: login, email: email, hash: resp.hash ?? hash)
                infoMessage = "Повторный код отправлен."
            case .restore:
                infoMessage = "Запросите восстановление повторно при необходимости."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithOAuth(_ provider: AuthProvider, telegramClientID: String = "", manualToken: String = "") async {
        do {
            let trimmedManual = manualToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedManual.isEmpty {
                try await finishProviderSignIn(provider: provider, token: trimmedManual)
                return
            }

            switch provider {
            case .yandex:
                let token = try await oauth.authenticateYandex()
                try await finishProviderSignIn(provider: .yandex, token: token)
            case .vk:
                let token = try await oauth.authenticateVK()
                try await finishProviderSignIn(provider: .vk, token: token)
            case .telegram:
                pendingTelegramAuth = try oauth.prepareTelegramAuth(clientID: telegramClientID)
            case .google:
                throw OAuthError.missingClientConfiguration("Google Sign-In требует iOS Client ID / GoogleService-Info.plist или вставки googleIdToken вручную.")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeTelegramAuth(request: OAuthService.TelegramAuthRequest, result: Result<String, Error>) async {
        pendingTelegramAuth = nil
        do {
            let code = try result.get()
            let idToken = try await oauth.exchangeTelegramCode(
                clientID: request.clientID,
                code: code,
                codeVerifier: request.codeVerifier
            )
            try await finishProviderSignIn(provider: .telegram, token: idToken)
        } catch let oauthError as OAuthError {
            if case .cancelled = oauthError { return }
            errorMessage = oauthError.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishProviderSignIn(provider: AuthProvider, token: String) async throws {
        let resp = try await api.signInWithProvider(provider, token: token)
        if let profileToken = resp.profileToken, !profileToken.token.isEmpty {
            completeSession(token: profileToken.token, profile: resp.profile, profileId: profileToken.id)
        } else {
            pendingOAuthRegistration = (provider, token, resp.email)
            infoMessage = "Аккаунт \(provider.title) ещё не зарегистрирован — укажите логин и email для завершения."
        }
    }

    func finishOAuthSignUp(login: String, email: String) async {
        guard let pending = pendingOAuthRegistration else { return }
        do {
            let resp = try await api.signUpWithProvider(pending.provider, login: login, email: email, token: pending.token)
            if let profileToken = resp.profileToken, !profileToken.token.isEmpty {
                pendingOAuthRegistration = nil
                completeSession(token: profileToken.token, profile: resp.profile, profileId: profileToken.id)
            } else if let hash = resp.hash, !hash.isEmpty {
                pendingVerification = .oauthRegister(provider: pending.provider, token: pending.token, login: login, email: email, hash: hash)
                infoMessage = "Введите код подтверждения, отправленный на \(email)."
            } else {
                throw APIError.unexpectedResponse
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        KeychainStore.clearSession()
        isAuthenticated = false
        isGuestMode = false
        currentProfile = nil
        profileInfo = nil
        unreadNotificationsCount = 0
        pendingVerification = nil
        pendingOAuthRegistration = nil
    }

    func handleDeepLink(_ url: URL) async {
        // anixart://release/{id} или https://anixart.../release/{id}
        let parts = url.pathComponents.filter { $0 != "/" }
        if url.host == "release", let idStr = parts.first, let id = Int64(idStr) {
            deepLinkedReleaseID = id
            return
        }
        if let idx = parts.firstIndex(of: "release"), idx + 1 < parts.count, let id = Int64(parts[idx + 1]) {
            deepLinkedReleaseID = id
        }
    }

    private func completeSession(token: String, profile: Profile?, profileId: Int64) {
        KeychainStore.setToken(token)
        KeychainStore.setProfileID(profile?.id ?? profileId)
        currentProfile = profile
        isAuthenticated = true
        isGuestMode = false
        Task {
            await refreshProfileAndNotifications()
        }
    }
}
