import SwiftUI

@MainActor
struct APISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = SessionStore.shared

    @State private var baseURLText = APIConfiguration.baseURL.absoluteString
    @State private var isRefreshing = false
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Текущий адрес API") {
                    TextField("https://api-s.anixsekai.com/", text: $baseURLText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    Button("Сохранить адрес") {
                        do {
                            try APIConfiguration.setBaseURL(baseURLText)
                            baseURLText = APIConfiguration.baseURL.absoluteString
                            statusMessage = "Базовый URL обновлён."
                        } catch {
                            statusMessage = error.localizedDescription
                        }
                    }

                    Button("Сбросить по умолчанию") {
                        APIConfiguration.resetToDefault()
                        baseURLText = APIConfiguration.baseURL.absoluteString
                        statusMessage = "Восстановлен адрес по умолчанию."
                    }
                }

                Section("Обнаружение зеркал") {
                    Button(isRefreshing ? "Обновление..." : "Обновить список зеркал и конфиг") {
                        isRefreshing = true
                        Task {
                            await session.refreshMirrors()
                            baseURLText = APIConfiguration.baseURL.absoluteString
                            isRefreshing = false
                            statusMessage = "Конфигурация зеркал синхронизирована."
                        }
                    }
                    .disabled(isRefreshing)

                    ForEach(session.availableMirrors, id: \.self) { mirror in
                        Button {
                            do {
                                try APIConfiguration.setBaseURL(mirror)
                                baseURLText = APIConfiguration.baseURL.absoluteString
                                statusMessage = "Выбрано зеркало: \(baseURLText)"
                            } catch {
                                statusMessage = error.localizedDescription
                            }
                        } label: {
                            HStack {
                                Text(mirror)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if mirror.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                                    == APIConfiguration.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }

                Section("Конфигурация клиента") {
                    LabeledContent("Версия протокола", value: "\(APIConfiguration.appVersionCode)")
                    LabeledContent("Static-домен", value: APIConfiguration.staticDomain)
                    if let config = session.configURLs {
                        LabeledContent("VK OAuth", value: config.vkAuthAvailable ? "Доступен" : "Отключён")
                        LabeledContent("Yandex OAuth", value: config.yandexAuthAvailable ? "Доступен" : "Отключён")
                        LabeledContent("Telegram OAuth", value: config.telegramAuthAvailable ? "Доступен" : "Отключён")
                        LabeledContent("Google OAuth", value: config.googleAuthAvailable ? "Доступен" : "Отключён")
                    }
                }
            }
            .navigationTitle("Настройки API")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .alert("Настройки API", isPresented: Binding(
                get: { statusMessage != nil },
                set: { if !$0 { statusMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(statusMessage ?? "")
            }
        }
    }
}
