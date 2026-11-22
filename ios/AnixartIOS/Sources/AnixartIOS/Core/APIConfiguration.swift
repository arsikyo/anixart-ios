import Foundation

enum APIConfiguration {
    static let appVersionCode = 26101718
    static let isBeta = false

    static let primaryBaseURL = URL(string: "https://api-s.anixsekai.com/")!
    static let fallbackMirrorURL = URL(string: "https://api.anixsekai.com/")!
    static let githubPagesMirrorsURL = URL(string: "https://anixhelper.github.io/pages/urls.json")!

    private static let baseURLKey = "anixart.api.baseURL"
    private static let cachedMirrorsKey = "anixart.api.mirrors"
    private static let shouldUseMirrorKey = "anixart.api.useMirror"
    private static let staticDomainKey = "anixart.api.staticDomain"
    private static let sibnetUserAgentKey = "anixart.parser.sibnetUA"
    private static let sibnetRandUAKey = "anixart.parser.sibnetRandUA"
    private static let kodikVideoLinksKey = "anixart.parser.kodikVideoLinksURL"
    private static let iframeEmbedURLKey = "anixart.parser.iframeEmbedURL"
    static let defaultKodikVideoLinksURL = "https://kodikplayer.com/get-video-info"
    static let defaultIframeEmbedURL = "https://anixmirai.com/iframe?url="

    static var baseURL: URL {
        guard let raw = UserDefaults.standard.string(forKey: baseURLKey),
              let url = URL(string: raw) else {
            return primaryBaseURL
        }
        return url
    }

    static var cachedMirrors: [String] {
        get {
            let stored = UserDefaults.standard.stringArray(forKey: cachedMirrorsKey) ?? []
            return stored.isEmpty ? [primaryBaseURL.absoluteString, fallbackMirrorURL.absoluteString] : stored
        }
        set {
            UserDefaults.standard.set(newValue, forKey: cachedMirrorsKey)
        }
    }

    static var shouldUseMirrorURLs: Bool {
        get { UserDefaults.standard.bool(forKey: shouldUseMirrorKey) }
        set { UserDefaults.standard.set(newValue, forKey: shouldUseMirrorKey) }
    }

    static var staticDomain: String {
        get { UserDefaults.standard.string(forKey: staticDomainKey) ?? "anixsekai.com" }
        set { UserDefaults.standard.set(newValue, forKey: staticDomainKey) }
    }

    static var sibnetUserAgent: String {
        get { UserDefaults.standard.string(forKey: sibnetUserAgentKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: sibnetUserAgentKey) }
    }

    static var sibnetRandUserAgent: Bool {
        get { UserDefaults.standard.bool(forKey: sibnetRandUAKey) }
        set { UserDefaults.standard.set(newValue, forKey: sibnetRandUAKey) }
    }

    static var kodikVideoLinksURL: String {
        get {
            let stored = UserDefaults.standard.string(forKey: kodikVideoLinksKey) ?? ""
            return stored.isEmpty ? defaultKodikVideoLinksURL : stored
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kodikVideoLinksKey)
        }
    }

    static var iframeEmbedURL: String {
        get {
            let stored = UserDefaults.standard.string(forKey: iframeEmbedURLKey) ?? ""
            return stored.isEmpty ? defaultIframeEmbedURL : stored
        }
        set {
            UserDefaults.standard.set(newValue, forKey: iframeEmbedURLKey)
        }
    }

    static var defaultAvatarURL: URL? {
        URL(string: "https://s.\(staticDomain)/avatars/no_avatar.jpg")
    }

    static func normalizeAndValidate(_ rawValue: String) throws -> URL {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              components.scheme == "https",
              components.host != nil else {
            throw APIError.invalidBaseURL
        }
        if !components.path.hasSuffix("/") {
            components.path += "/"
        }
        guard let url = components.url else {
            throw APIError.invalidBaseURL
        }
        return url
    }

    static func setBaseURL(_ rawValue: String) throws {
        let url = try normalizeAndValidate(rawValue)
        UserDefaults.standard.set(url.absoluteString, forKey: baseURLKey)
    }

    static func resetToDefault() {
        UserDefaults.standard.set(primaryBaseURL.absoluteString, forKey: baseURLKey)
    }
}
