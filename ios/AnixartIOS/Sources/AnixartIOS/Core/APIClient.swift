import Foundation

enum APIError: LocalizedError, Sendable {
    case invalidBaseURL
    case malformedURL
    case server(code: Int, message: String? = nil)
    case httpStatus(Int)
    case unexpectedResponse
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Укажите корректный HTTPS-адрес сервера API."
        case .malformedURL:
            return "Не удалось сформировать URL запроса."
        case .server(let code, let message):
            if let message, !message.isEmpty {
                return "\(message) (код \(code))"
            }
            return Self.describe(code: code)
        case .httpStatus(let status):
            return "Ошибка HTTP: \(status)."
        case .unexpectedResponse:
            return "Неожиданный ответ сервера."
        case .decodingFailed(let detail):
            return "Ошибка разбора данных: \(detail)"
        }
    }

    private static func describe(code: Int) -> String {
        switch code {
        case 1: return "Запрос отклонён сервером (код 1)."
        case 2: return "Неверный логин или данные (код 2)."
        case 3: return "Неверный пароль или параметр (код 3)."
        case 402: return "Аккаунт временно заблокирован (код 402)."
        case 403: return "Аккаунт заблокирован навсегда (код 403)."
        default: return "Сервер вернул код \(code)."
        }
    }
}

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

struct APIClient: Sendable {
    let session: URLSession
    let tokenProvider: @Sendable () -> String?
    let baseURLProvider: @Sendable () -> URL

    init(
        session: URLSession = APIClient.makeDefaultSession(),
        tokenProvider: @escaping @Sendable () -> String? = { KeychainStore.getToken() },
        baseURLProvider: @escaping @Sendable () -> URL = { APIConfiguration.baseURL }
    ) {
        self.session = session
        self.tokenProvider = tokenProvider
        self.baseURLProvider = baseURLProvider
    }

    static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 45
        config.httpAdditionalHeaders = [
            "User-Agent": "AnixartApp/10.5 (iOS; SwiftUI)"
        ]
        return URLSession(configuration: config)
    }

    func request<Response: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        query: [String: String] = [:],
        form: [String: String?] = [:],
        body: (any Encodable)? = nil,
        headers: [String: String] = [:],
        includeToken: Bool = true,
        overrideBaseURL: URL? = nil,
        validateStatus: Bool = true,
        as type: Response.Type = Response.self
    ) async throws -> Response {
        let baseURL = overrideBaseURL ?? baseURLProvider()
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard var components = URLComponents(url: baseURL.appending(path: cleanPath), resolvingAgainstBaseURL: false) else {
            throw APIError.malformedURL
        }

        var queryItems = query
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }

        if includeToken, let token = tokenProvider(), !token.isEmpty,
           !queryItems.contains(where: { $0.name == "token" }) {
            queryItems.append(URLQueryItem(name: "token", value: token))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw APIError.malformedURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let nonNilForm = form.compactMapValues { $0 }
        if !nonNilForm.isEmpty {
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let encoded = nonNilForm
                .sorted { $0.key < $1.key }
                .map { key, value in
                    "\(Self.formEscape(key))=\(Self.formEscape(value))"
                }
                .joined(separator: "&")
            request.httpBody = Data(encoded.utf8)
        } else if let body {
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder.anixart.encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unexpectedResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpStatus(http.statusCode)
        }

        do {
            let decoded = try JSONDecoder.anixart.decode(Response.self, from: data)
            if validateStatus, let status = decoded as? APIStatus, status.code != 0 {
                throw APIError.server(code: status.code)
            }
            return decoded
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.decodingFailed(error.localizedDescription)
        }
    }

    func fetchRawString(
        url: URL,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        form: [String: String] = [:]
    ) async throws -> (body: String, headers: [String: String], statusCode: Int) {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        if !form.isEmpty {
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let encoded = form
                .sorted { $0.key < $1.key }
                .map { "\(Self.formEscape($0.key))=\(Self.formEscape($0.value))" }
                .joined(separator: "&")
            request.httpBody = Data(encoded.utf8)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unexpectedResponse
        }
        let bodyText = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        var stringHeaders: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            stringHeaders[String(describing: key)] = String(describing: value)
        }
        return (bodyText, stringHeaders, http.statusCode)
    }

    func fetchRedirectLocation(url: URL, headers: [String: String] = [:]) async throws -> String? {
        let delegate = NoRedirectDelegate()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        let tempSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { tempSession.finishTasksAndInvalidate() }

        var request = URLRequest(url: url)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (_, response) = try await tempSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { return nil }
        return http.value(forHTTPHeaderField: "Location")
    }

    private static func formEscape(_ string: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }
}

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void
    init(_ value: some Encodable) { encodeValue = value.encode }
    func encode(to encoder: Encoder) throws { try encodeValue(encoder) }
}

extension JSONDecoder {
    static var anixart: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

extension JSONEncoder {
    static var anixart: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}
