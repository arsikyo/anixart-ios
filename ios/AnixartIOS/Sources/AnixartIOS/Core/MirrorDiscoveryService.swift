import Foundation

struct MirrorDiscoveryResult: Sendable {
    let urls: [String]
    let shouldUseMirrorURLs: Bool
    let toggles: TogglesResponse?
    let configURLs: ConfigURLsResponse?
}

struct MirrorDiscoveryService: Sendable {
    private let client: APIClient

    init(client: APIClient? = nil) {
        if let client {
            self.client = client
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 7
            config.timeoutIntervalForResource = 12
            config.httpAdditionalHeaders = [
                "User-Agent": "AnixartApp/10.5 (iOS; SwiftUI)"
            ]
            self.client = APIClient(session: URLSession(configuration: config))
        }
    }

    /// Повторяет цепочку ChainedNetFetcher из Android:
    /// 1) config/urls с текущего или базового адреса
    /// 2) GitHub Pages fallback (https://anixhelper.github.io/pages/urls.json)
    /// 3) config/toggles для получения актуальных флагов, статического домена и парсерных настроек
    func syncConfiguration() async -> MirrorDiscoveryResult {
        var collectedURLs: [String] = []
        var configResponse: ConfigURLsResponse?
        var workingBaseURL: URL?

        let candidates = Array(NSOrderedSet(array: [
            APIConfiguration.baseURL.absoluteString,
            APIConfiguration.fallbackMirrorURL.absoluteString,
            APIConfiguration.primaryBaseURL.absoluteString
        ]).compactMap { $0 as? String })

        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if let resp: ConfigURLsResponse = try? await client.request(
                "config/urls",
                query: [
                    "version_code": String(APIConfiguration.appVersionCode),
                    "is_beta": String(APIConfiguration.isBeta)
                ],
                overrideBaseURL: url,
                validateStatus: false
            ) {
                configResponse = resp
                workingBaseURL = url
                collectedURLs.append(contentsOf: resp.apiUrls)
                APIConfiguration.shouldUseMirrorURLs = resp.shouldUseMirrorUrls
                if let staticDomain = resp.staticDomain, !staticDomain.isEmpty {
                    APIConfiguration.staticDomain = staticDomain
                }
                if url.absoluteString != APIConfiguration.baseURL.absoluteString {
                    try? APIConfiguration.setBaseURL(url.absoluteString)
                    DebugLogger.log(.app, "Switched active baseURL to working mirror: \(url.absoluteString)")
                }
                break
            }
        }

        if collectedURLs.isEmpty, let ghUrls = await fetchGitHubPagesMirrors() {
            collectedURLs.append(contentsOf: ghUrls)
        }

        if collectedURLs.isEmpty {
            collectedURLs = [
                APIConfiguration.fallbackMirrorURL.absoluteString,
                APIConfiguration.primaryBaseURL.absoluteString
            ]
        }

        let uniqueURLs = Array(NSOrderedSet(array: collectedURLs).compactMap { $0 as? String })
        APIConfiguration.cachedMirrors = uniqueURLs

        if configResponse == nil, let first = uniqueURLs.first {
            try? APIConfiguration.setBaseURL(first)
        }

        let toggles: TogglesResponse? = try? await client.request(
            "config/toggles",
            query: [
                "version_code": String(APIConfiguration.appVersionCode),
                "is_beta": String(APIConfiguration.isBeta),
                "is_api_alt": String(APIConfiguration.shouldUseMirrorURLs)
            ],
            overrideBaseURL: workingBaseURL,
            validateStatus: false
        )

        if let toggles {
            if let staticDomain = toggles.staticDomain, !staticDomain.isEmpty {
                APIConfiguration.staticDomain = staticDomain
            }
            if let ua = toggles.sibnetUserAgent, !ua.isEmpty {
                APIConfiguration.sibnetUserAgent = ua
            }
            if let randUA = toggles.sibnetRandUserAgent {
                APIConfiguration.sibnetRandUserAgent = randUA
            }
            if let kodikURL = toggles.kodikVideoLinksUrl, !kodikURL.isEmpty {
                APIConfiguration.kodikVideoLinksURL = kodikURL
            }
            if let iframeURL = toggles.iframeEmbedUrl, !iframeURL.isEmpty {
                APIConfiguration.iframeEmbedURL = iframeURL
            }
        }

        return MirrorDiscoveryResult(
            urls: uniqueURLs,
            shouldUseMirrorURLs: configResponse?.shouldUseMirrorUrls ?? APIConfiguration.shouldUseMirrorURLs,
            toggles: toggles,
            configURLs: configResponse
        )
    }

    private func fetchGitHubPagesMirrors() async -> [String]? {
        guard let raw = try? await client.fetchRawString(url: APIConfiguration.githubPagesMirrorsURL),
              let data = raw.body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        let country = (Locale.current.region?.identifier ?? "default").lowercased()

        if let dict = json as? [String: Any] {
            if let regionEntry = dict[country] as? [String], !regionEntry.isEmpty {
                return regionEntry
            }
            if let defaultEntry = dict["default"] as? [String], !defaultEntry.isEmpty {
                return defaultEntry
            }
            if let apiUrls = dict["api_urls"] as? [String], !apiUrls.isEmpty {
                return apiUrls
            }
            if let urls = dict["urls"] as? [String], !urls.isEmpty {
                return urls
            }
        } else if let list = json as? [String], !list.isEmpty {
            return list
        }
        return nil
    }
}
