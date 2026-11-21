import Foundation

struct MirrorDiscoveryResult: Sendable {
    let urls: [String]
    let shouldUseMirrorURLs: Bool
    let toggles: TogglesResponse?
    let configURLs: ConfigURLsResponse?
}

struct MirrorDiscoveryService: Sendable {
    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    /// Повторяет цепочку ChainedNetFetcher из Android:
    /// 1) config/urls с текущего или базового адреса
    /// 2) GitHub Pages fallback (https://anixhelper.github.io/pages/urls.json)
    /// 3) config/toggles для получения актуальных флагов, статического домена и парсерных настроек
    func syncConfiguration() async -> MirrorDiscoveryResult {
        var collectedURLs: [String] = []
        var configResponse: ConfigURLsResponse?

        let candidates = Array(NSOrderedSet(array: [
            APIConfiguration.baseURL.absoluteString,
            APIConfiguration.primaryBaseURL.absoluteString,
            APIConfiguration.fallbackMirrorURL.absoluteString
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
                collectedURLs.append(contentsOf: resp.apiUrls)
                APIConfiguration.shouldUseMirrorURLs = resp.shouldUseMirrorUrls
                if let staticDomain = resp.staticDomain, !staticDomain.isEmpty {
                    APIConfiguration.staticDomain = staticDomain
                }
                break
            }
        }

        if collectedURLs.isEmpty, let ghUrls = await fetchGitHubPagesMirrors() {
            collectedURLs.append(contentsOf: ghUrls)
        }

        if collectedURLs.isEmpty {
            collectedURLs = [
                APIConfiguration.primaryBaseURL.absoluteString,
                APIConfiguration.fallbackMirrorURL.absoluteString
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
