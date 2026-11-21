import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

enum OAuthError: LocalizedError, Sendable {
    case cancelled
    case missingClientConfiguration(String)
    case invalidCallback
    case tokenExchangeFailed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Авторизация отменена пользователем."
        case .missingClientConfiguration(let detail):
            return detail
        case .invalidCallback:
            return "Не удалось обработать ответ от провайдера авторизации."
        case .tokenExchangeFailed(let detail):
            return "Ошибка обмена OAuth-токена: \(detail)"
        }
    }
}

@MainActor
final class OAuthService: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let yandexClientID = "a980f00536554180b4826f7daa76f060"
    static let yandexRedirectURI = "yxa980f00536554180b4826f7daa76f060://auth/finish"

    static let vkClientID = "54701760"
    static let vkRedirectScheme = "vk54701760"

    static let telegramClientID = "8789559054"
    static let telegramRedirectURI = "https://app1593901251-login.tg.dev/tglogin"
    static let telegramRedirectHost = "app1593901251-login.tg.dev"

    struct TelegramAuthRequest: Identifiable, Sendable {
        let id = UUID()
        let authURL: URL
        let clientID: String
        let codeVerifier: String
        let redirectHost: String
    }

    private var activeSession: ASWebAuthenticationSession?

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    func authenticateYandex() async throws -> String {
        var components = URLComponents(string: "https://oauth.yandex.ru/authorize")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "token"),
            URLQueryItem(name: "client_id", value: Self.yandexClientID),
            URLQueryItem(name: "redirect_uri", value: Self.yandexRedirectURI)
        ]
        guard let url = components.url else { throw OAuthError.invalidCallback }

        let callbackURL = try await startWebSession(url: url, callbackScheme: "yxa980f00536554180b4826f7daa76f060")
        if let token = extractFragmentOrQueryParam(name: "access_token", from: callbackURL) {
            return token
        }
        throw OAuthError.invalidCallback
    }

    func authenticateVK() async throws -> String {
        let pkce = PKCEPair.generate()
        let state = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        var components = URLComponents(string: "https://id.vk.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: Self.vkClientID),
            URLQueryItem(name: "redirect_uri", value: "\(Self.vkRedirectScheme)://vk.ru/blank.html"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "scope", value: "email")
        ]
        guard let url = components.url else { throw OAuthError.invalidCallback }

        let callbackURL = try await startWebSession(url: url, callbackScheme: Self.vkRedirectScheme)
        if let accessToken = extractFragmentOrQueryParam(name: "access_token", from: callbackURL) {
            return accessToken
        }
        if let code = extractFragmentOrQueryParam(name: "code", from: callbackURL) {
            let deviceId = extractFragmentOrQueryParam(name: "device_id", from: callbackURL) ?? ""
            return try await exchangeVKCode(code: code, deviceId: deviceId, codeVerifier: pkce.verifier, state: state)
        }
        throw OAuthError.invalidCallback
    }

    func prepareTelegramAuth(clientID: String) throws -> TelegramAuthRequest {
        let trimmed = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedClientID = trimmed.isEmpty ? Self.telegramClientID : trimmed

        let pkce = PKCEPair.generate()
        var components = URLComponents(string: "https://oauth.telegram.org/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: resolvedClientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid profile"),
            URLQueryItem(name: "redirect_uri", value: Self.telegramRedirectURI),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        guard let url = components.url else { throw OAuthError.invalidCallback }
        return TelegramAuthRequest(
            authURL: url,
            clientID: resolvedClientID,
            codeVerifier: pkce.verifier,
            redirectHost: Self.telegramRedirectHost
        )
    }

    func exchangeTelegramCode(clientID: String, code: String, codeVerifier: String) async throws -> String {
        let client = APIClient()
        let result = try await client.fetchRawString(
            url: URL(string: "https://oauth.telegram.org/token")!,
            method: .post,
            form: [
                "grant_type": "authorization_code",
                "client_id": clientID,
                "code": code,
                "redirect_uri": Self.telegramRedirectURI,
                "code_verifier": codeVerifier
            ]
        )
        guard (200..<300).contains(result.statusCode),
              let data = result.body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = (json["id_token"] as? String).flatMap({ $0.isEmpty ? nil : $0 })
                ?? (json["result"] as? String).flatMap({ $0.isEmpty ? nil : $0 }) else {
            throw OAuthError.tokenExchangeFailed("Telegram /token вернул HTTP \(result.statusCode)")
        }
        return idToken
    }

    private func exchangeVKCode(code: String, deviceId: String, codeVerifier: String, state: String) async throws -> String {
        let client = APIClient()
        let result = try await client.fetchRawString(
            url: URL(string: "https://id.vk.com/oauth2/auth")!,
            method: .post,
            form: [
                "grant_type": "authorization_code",
                "code": code,
                "code_verifier": codeVerifier,
                "client_id": Self.vkClientID,
                "device_id": deviceId,
                "redirect_uri": "\(Self.vkRedirectScheme)://vk.ru/blank.html",
                "state": state
            ]
        )
        guard (200..<300).contains(result.statusCode),
              let data = result.body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw OAuthError.tokenExchangeFailed("VK oauth2/auth вернул HTTP \(result.statusCode)")
        }
        return accessToken
    }

    private func startWebSession(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                Task { @MainActor in
                    self.activeSession = nil
                }
                if let error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: OAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: OAuthError.invalidCallback)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.activeSession = session
            session.start()
        }
    }

    private func extractFragmentOrQueryParam(name: String, from url: URL) -> String? {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let value = components.queryItems?.first(where: { $0.name == name })?.value {
            return value
        }
        if let fragment = url.fragment {
            var fake = URLComponents()
            fake.query = fragment
            if let value = fake.queryItems?.first(where: { $0.name == name })?.value {
                return value
            }
        }
        return nil
    }
}

private struct PKCEPair {
    let verifier: String
    let challenge: String

    static func generate() -> PKCEPair {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let verifier = Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return PKCEPair(verifier: verifier, challenge: challenge)
    }
}
