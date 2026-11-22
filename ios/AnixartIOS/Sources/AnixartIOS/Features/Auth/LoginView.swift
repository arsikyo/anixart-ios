import SwiftUI

private enum AuthMode: String, CaseIterable, Identifiable {
    case signIn = "Вход"
    case signUp = "Регистрация"
    case restore = "Восстановление"

    var id: String { rawValue }
}

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var mode: AuthMode = .signIn
    @State private var login = ""
    @State private var email = ""
    @State private var password = ""
    @State private var restoreQuery = ""

    @State private var verificationCode = ""
    @State private var newPassword = ""

    @State private var oauthLogin = ""
    @State private var oauthEmail = ""

    @State private var telegramClientID = ""
    @State private var manualOAuthToken = ""
    @State private var showAdvancedOAuth = false
    @State private var showAPISettings = false
    @State private var showLogs = false
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                if let pending = session.pendingVerification {
                    verificationSection(for: pending)
                } else if let oauthPending = session.pendingOAuthRegistration {
                    oauthRegistrationSection(provider: oauthPending.provider)
                } else {
                    Section {
                        Picker("Режим", selection: $mode) {
                            ForEach(AuthMode.allCases) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    switch mode {
                    case .signIn:
                        signInSection
                        socialSection
                    case .signUp:
                        signUpSection
                    case .restore:
                        restoreSection
                    }

                    Section {
                        Button("Продолжить без входа (только каталог/расписание)") {
                            DebugLogger.log(.nav, "LoginView enterGuestMode")
                            session.enterGuestMode()
                        }
                        Button("Настройки зеркал API") {
                            showAPISettings = true
                        }
                        // DEBUG_LOGGER_TEMPORARY
                        Button("Логи диагностики") {
                            showLogs = true
                        }
                    } footer: {
                        Text("Активный сервер: \(APIConfiguration.baseURL.absoluteString)")
                    }
                }
            }
            .navigationTitle("Anixart")
            .sheet(isPresented: $showAPISettings) {
                APISettingsView()
            }
            .sheet(isPresented: $showLogs) {
                DebugLogsView()
            }
            .sheet(item: $session.pendingTelegramAuth) { authRequest in
                TelegramOAuthSheet(request: authRequest) { result in
                    Task {
                        isLoading = true
                        await session.completeTelegramAuth(request: authRequest, result: result)
                        isLoading = false
                    }
                }
            }
        }
    }

    private var signInSection: some View {
        Section("Вход по логину или email") {
            TextField("Логин или email", text: $login)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("Пароль", text: $password)
            Button(isLoading ? "Выполняется вход..." : "Войти") {
                isLoading = true
                Task {
                    await session.signIn(login: login, password: password)
                    isLoading = false
                }
            }
            .disabled(login.isEmpty || password.isEmpty || isLoading)
        }
    }

    private var signUpSection: some View {
        Section("Создание аккаунта") {
            TextField("Логин", text: $login)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
            SecureField("Пароль", text: $password)
            Button(isLoading ? "Отправка..." : "Зарегистрироваться") {
                isLoading = true
                Task {
                    await session.startSignUp(login: login, email: email, password: password)
                    isLoading = false
                }
            }
            .disabled(login.isEmpty || email.isEmpty || password.isEmpty || isLoading)
        }
    }

    private var restoreSection: some View {
        Section("Восстановление доступа") {
            TextField("Логин или email", text: $restoreQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button(isLoading ? "Отправка..." : "Отправить код восстановления") {
                isLoading = true
                Task {
                    await session.startRestore(data: restoreQuery)
                    isLoading = false
                }
            }
            .disabled(restoreQuery.isEmpty || isLoading)
        }
    }

    private var socialSection: some View {
        Section("Войти через сервисы") {
            if session.configURLs?.vkAuthAvailable ?? true {
                Button {
                    runOAuth(.vk)
                } label: {
                    Label("VK ID", systemImage: AuthProvider.vk.systemImage)
                }
            }
            if session.configURLs?.yandexAuthAvailable ?? true {
                Button {
                    runOAuth(.yandex)
                } label: {
                    Label("Яндекс ID", systemImage: AuthProvider.yandex.systemImage)
                }
            }
            if session.configURLs?.telegramAuthAvailable ?? true {
                Button {
                    runOAuth(.telegram)
                } label: {
                    Label("Telegram", systemImage: AuthProvider.telegram.systemImage)
                }
            }
            if session.configURLs?.googleAuthAvailable ?? true {
                Button {
                    runOAuth(.google)
                } label: {
                    Label("Google", systemImage: AuthProvider.google.systemImage)
                }
            }

            DisclosureGroup("Параметры OAuth / ручной токен", isExpanded: $showAdvancedOAuth) {
                TextField("Telegram client_id (по умолчанию \(OAuthService.telegramClientID))", text: $telegramClientID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Ручной OAuth-токен (опционально)", text: $manualOAuthToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
    }

    private func verificationSection(for pending: PendingVerificationFlow) -> some View {
        Section("Подтверждение кода") {
            TextField("Код из письма", text: $verificationCode)
                .keyboardType(.numberPad)
            if case .restore = pending {
                SecureField("Новый пароль", text: $newPassword)
            }
            Button(isLoading ? "Проверка..." : "Подтвердить") {
                isLoading = true
                Task {
                    await session.confirmVerification(code: verificationCode, newPassword: newPassword)
                    isLoading = false
                }
            }
            .disabled(verificationCode.isEmpty || isLoading)

            Button("Отправить код повторно") {
                Task { await session.resendVerificationCode() }
            }
            Button("Отменить", role: .cancel) {
                session.pendingVerification = nil
            }
        }
    }

    private func oauthRegistrationSection(provider: AuthProvider) -> some View {
        Section("Завершение регистрации (\(provider.title))") {
            TextField("Логин", text: $oauthLogin)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Email", text: $oauthEmail)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
            Button(isLoading ? "Отправка..." : "Продолжить") {
                isLoading = true
                Task {
                    await session.finishOAuthSignUp(login: oauthLogin, email: oauthEmail)
                    isLoading = false
                }
            }
            .disabled(oauthLogin.isEmpty || oauthEmail.isEmpty || isLoading)
            Button("Отменить", role: .cancel) {
                session.pendingOAuthRegistration = nil
            }
        }
        .onAppear {
            if oauthEmail.isEmpty, let suggested = session.pendingOAuthRegistration?.suggestedEmail {
                oauthEmail = suggested
            }
        }
    }

    private func runOAuth(_ provider: AuthProvider) {
        isLoading = true
        Task {
            await session.signInWithOAuth(
                provider,
                telegramClientID: telegramClientID,
                manualToken: manualOAuthToken
            )
            isLoading = false
        }
    }
}
