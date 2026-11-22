import Foundation

struct VideoStreamVariant: Identifiable, Hashable, Sendable {
    let quality: String
    let url: URL
    var id: String { "\(quality)-\(url.absoluteString)" }
}

struct VideoParseResult: Sendable {
    let variants: [VideoStreamVariant]
    let headers: [String: String]
    let useWebFallback: Bool
    let originalURL: URL
}

struct VideoParserService: Sendable {
    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    private var defaultUserAgent: String {
        let configured = APIConfiguration.sibnetUserAgent
        if !configured.isEmpty { return configured }
        return "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }

    func resolve(episodeURL rawURL: String, forceWeb: Bool = false) async -> VideoParseResult {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.hasPrefix("//") ? "https:" + trimmed : trimmed
        DebugLogger.log(.parser, "resolve start: rawURL='\(rawURL)' forceWeb=\(forceWeb)")

        guard let url = URL(string: normalized), let host = url.host?.lowercased() else {
            DebugLogger.log(.parser, "Invalid episodeURL: '\(rawURL)' -> about:blank web fallback", level: .error)
            return VideoParseResult(variants: [], headers: [:], useWebFallback: true, originalURL: URL(string: "about:blank")!)
        }

        if forceWeb {
            DebugLogger.log(.parser, "forceWeb=true -> opening \(url.absoluteString) in WKWebView")
            return VideoParseResult(variants: [], headers: [:], useWebFallback: true, originalURL: url)
        }

        if host.contains("kodik") || host.contains("aniqit") || host.contains("anivod") || host.contains("kodikres") {
            DebugLogger.log(.parser, "Matched host '\(host)' -> parseKodik")
            if let res = await parseKodik(url: url), !res.variants.isEmpty {
                DebugLogger.log(.parser, "parseKodik success: \(res.variants.map { "\($0.quality)=\($0.url.absoluteString)" }.joined(separator: ", "))")
                return res
            }
            DebugLogger.log(.parser, "parseKodik returned 0 variants -> web fallback", level: .warning)
        } else if host.contains("vk.com") || host.contains("vk.ru") || host.contains("vkvideo.") {
            DebugLogger.log(.parser, "Matched host '\(host)' -> parseVKVideo")
            if let res = await parseVKVideo(url: url), !res.variants.isEmpty {
                DebugLogger.log(.parser, "parseVKVideo success: \(res.variants.count) variants")
                return res
            }
            DebugLogger.log(.parser, "parseVKVideo returned 0 variants -> web fallback", level: .warning)
        } else if host.contains("studiomir.club") {
            DebugLogger.log(.parser, "Matched host '\(host)' -> parseStudioMir")
            if let res = await parseStudioMir(url: url), !res.variants.isEmpty { return res }
        } else if host.contains("anilibria.") || host.contains("anilib.one") || host.contains("libria.fun") {
            DebugLogger.log(.parser, "Matched host '\(host)' -> parseAniLibria")
            if let res = await parseAniLibria(url: url), !res.variants.isEmpty { return res }
        } else if host.contains("rutube.ru") {
            DebugLogger.log(.parser, "Matched host '\(host)' -> parseRuTube")
            if let res = await parseRuTube(url: url), !res.variants.isEmpty { return res }
        } else if host.contains("sibnet.ru") {
            DebugLogger.log(.parser, "Matched host '\(host)' -> parseSibnet")
            if let res = await parseSibnet(url: url), !res.variants.isEmpty { return res }
        } else if host.contains("my.mail.ru") {
            DebugLogger.log(.parser, "Matched host '\(host)' -> parseMailRu")
            if let res = await parseMailRu(url: url), !res.variants.isEmpty { return res }
        } else if host.contains("ok.ru") {
            DebugLogger.log(.parser, "Matched host '\(host)' -> parseOK")
            if let res = await parseOK(url: url), !res.variants.isEmpty { return res }
        } else if host.contains("myvi.top") {
            DebugLogger.log(.parser, "Matched host '\(host)' -> parseMyvi")
            if let res = await parseMyvi(url: url), !res.variants.isEmpty { return res }
        } else if host.contains("secvideo1.online") || host.contains("csst.online") || host.contains("sstrge.online") {
            DebugLogger.log(.parser, "Matched host '\(host)' -> parseAllvideo")
            if let res = await parseAllvideo(url: url), !res.variants.isEmpty { return res }
        } else if host.contains("sovetromantica.com") {
            DebugLogger.log(.parser, "Matched host '\(host)' -> parseSovetRomantica")
            if let res = await parseSovetRomantica(url: url), !res.variants.isEmpty { return res }
        } else if normalized.hasSuffix(".m3u8") || normalized.hasSuffix(".mp4") {
            DebugLogger.log(.parser, "Direct stream URL detected: \(url.absoluteString)")
            return VideoParseResult(
                variants: [VideoStreamVariant(quality: "Default", url: url)],
                headers: ["User-Agent": defaultUserAgent],
                useWebFallback: false,
                originalURL: url
            )
        } else {
            DebugLogger.log(.parser, "No native parser for host '\(host)' -> web fallback", level: .warning)
        }

        // Fallback во встроенный WebView-плеер, если хостинг неизвестен или прямой парсинг не вернул потоки
        DebugLogger.log(.parser, "Returning WebFallback for \(url.absoluteString)", level: .warning)
        return VideoParseResult(variants: [], headers: [:], useWebFallback: true, originalURL: url)
    }

    // MARK: - Kodik

    private func parseKodik(url: URL) async -> VideoParseResult? {
        let raw = url.absoluteString
        let parts = raw.components(separatedBy: "d=")
        let rawLinkPart = (parts.first ?? raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "//")
            .replacingOccurrences(of: "http://", with: "//")
        let domainPart: String
        if parts.count >= 2 {
            domainPart = parts[1].components(separatedBy: "&").first ?? parts[1]
        } else {
            domainPart = "anixart-app.com"
        }

        let endpointString = APIConfiguration.kodikVideoLinksURL
        guard var components = URLComponents(string: endpointString) else {
            DebugLogger.log(.parser, "Kodik: invalid endpointString '\(endpointString)'", level: .error)
            return nil
        }
        var queryItems = components.queryItems ?? []
        if !queryItems.contains(where: { $0.name == "p" }) {
            queryItems.append(URLQueryItem(name: "p", value: "56a768d08f43091901c44b54fe970049"))
        }
        queryItems.append(URLQueryItem(name: "link", value: rawLinkPart))
        queryItems.append(URLQueryItem(name: "d", value: domainPart))
        components.queryItems = queryItems

        guard let apiURL = components.url else {
            DebugLogger.log(.parser, "Kodik: failed to build apiURL", level: .error)
            return nil
        }

        let resp: (body: String, headers: [String: String], statusCode: Int)
        do {
            resp = try await client.fetchRawString(
                url: apiURL,
                headers: [
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36",
                    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
                ]
            )
        } catch {
            DebugLogger.log(.parser, "Kodik request failed: \(error.localizedDescription)", level: .error)
            return nil
        }

        guard !resp.body.isEmpty else {
            DebugLogger.log(.parser, "Kodik empty response body (HTTP \(resp.statusCode))", level: .error)
            return nil
        }

        let patterns: [(String, String)] = [
            ("1080p", "\"1080\":\\{\"[sS]rc\":\"(.*?)\""),
            ("720p", "\"720\":\\{\"[sS]rc\":\"(.*?)\""),
            ("480p", "\"480\":\\{\"[sS]rc\":\"(.*?)\""),
            ("360p", "\"360\":\\{\"[sS]rc\":\"(.*?)\"")
        ]

        var variants: [VideoStreamVariant] = []
        for (label, pattern) in patterns {
            if let matched = firstMatch(pattern, in: resp.body),
               let normalizedURL = normalizeKodikStreamURL(matched) {
                variants.append(.init(quality: label, url: normalizedURL))
            }
        }

        // JSON fallback если структура ответа отличается от плоского { "720": { "src": "..." } }
        if variants.isEmpty,
           let data = resp.body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let root = (json["links"] as? [String: Any]) ?? json
            for key in ["1080", "720", "480", "360"] {
                if let entry = root[key] as? [String: Any],
                   let src = (entry["src"] as? String) ?? (entry["Src"] as? String),
                   let normalizedURL = normalizeKodikStreamURL(src) {
                    variants.append(.init(quality: "\(key)p", url: normalizedURL))
                } else if let arrayEntry = (root[key] as? [[String: Any]])?.first,
                          let src = (arrayEntry["src"] as? String) ?? (arrayEntry["Src"] as? String),
                          let normalizedURL = normalizeKodikStreamURL(src) {
                    variants.append(.init(quality: "\(key)p", url: normalizedURL))
                }
            }
        }

        if variants.isEmpty {
            let snippet = String(resp.body.prefix(400))
            DebugLogger.log(.parser, "Kodik HTTP \(resp.statusCode) yielded 0 variants. Body prefix: \(snippet)", level: .error)
        }

        return VideoParseResult(
            variants: variants,
            headers: ["User-Agent": defaultUserAgent],
            useWebFallback: variants.isEmpty,
            originalURL: url
        )
    }

    private func normalizeKodikStreamURL(_ raw: String) -> URL? {
        var cleaned = raw.replacingOccurrences(of: "\\/", with: "/")
        if !cleaned.hasPrefix("https://") && !cleaned.hasPrefix("http://") {
            cleaned = cleaned.hasPrefix("//") ? "https:\(cleaned)" : "https://\(cleaned)"
        }
        let hlsURL = cleaned.replacingOccurrences(of: ":hls:hls.m3u8", with: ":hls:manifest.m3u8")
        return URL(string: hlsURL)
    }

    // MARK: - VK Video

    private func parseVKVideo(url: URL) async -> VideoParseResult? {
        guard let params = extractVKVideoParams(from: url.absoluteString) else {
            DebugLogger.log(.parser, "VK: failed to extract video params from \(url.absoluteString)", level: .error)
            return nil
        }

        let vkUserAgent = "com.vk.vkvideo.prod/822 (iPhone, iOS 16.7.7, iPhone10,4, Scale/2.0) SAK/1.119"
        let deviceId = UUID().uuidString.uppercased()

        var tokenComponents = URLComponents(string: "https://oauth.vk.com/oauth/get_anonym_token")!
        tokenComponents.queryItems = [
            URLQueryItem(name: "client_id", value: "51552953"),
            URLQueryItem(name: "client_secret", value: "qgr0yWwXCrsxA1jnRtRX"),
            URLQueryItem(name: "device_id", value: deviceId)
        ]

        guard let tokenURL = tokenComponents.url,
              let tokenResp = try? await client.fetchRawString(
                url: tokenURL,
                headers: ["User-Agent": vkUserAgent]
              ),
              let tokenData = tokenResp.body.data(using: .utf8),
              let anon = try? JSONDecoder.anixart.decode(VKAnonymousTokenResponse.self, from: tokenData),
              let anonymousToken = anon.token,
              !anonymousToken.isEmpty else {
            DebugLogger.log(.parser, "VK: failed to fetch anonymous_token", level: .error)
            return nil
        }

        let videosParam = params.accessKey.map { "\(params.ownerId)_\(params.videoId)_\($0)" }
            ?? "\(params.ownerId)_\(params.videoId)"

        guard let videoGetURL = URL(string: "https://api.vk.com/method/video.get"),
              let videoResp = try? await client.fetchRawString(
                url: videoGetURL,
                method: .post,
                headers: ["User-Agent": vkUserAgent],
                form: [
                    "anonymous_token": anonymousToken,
                    "device_id": deviceId,
                    "lang": "en",
                    "v": "5.244",
                    "videos": videosParam
                ]
              ) else {
            DebugLogger.log(.parser, "VK: video.get request failed", level: .error)
            return nil
        }

        guard let videoData = videoResp.body.data(using: .utf8),
              let decoded = try? JSONDecoder.anixart.decode(VKVideoGetResponse.self, from: videoData),
              let files = decoded.response?.items?.first?.files else {
            DebugLogger.log(.parser, "VK: decode/empty files HTTP \(videoResp.statusCode): \(String(videoResp.body.prefix(300)))", level: .error)
            return nil
        }

        var variants: [VideoStreamVariant] = []
        for q in ["2160", "1440", "1080", "720", "480", "360"] {
            if let streamStr = files["mp4_\(q)"], !streamStr.isEmpty, let streamURL = URL(string: streamStr) {
                variants.append(.init(quality: "\(q)p", url: streamURL))
            }
        }
        if let hlsStr = files["hls"], !hlsStr.isEmpty, let hlsURL = URL(string: hlsStr) {
            variants.append(.init(quality: "Auto (HLS)", url: hlsURL))
        }

        return VideoParseResult(
            variants: variants,
            headers: ["User-Agent": vkUserAgent],
            useWebFallback: variants.isEmpty,
            originalURL: url
        )
    }

    private func extractVKVideoParams(from rawURL: String) -> (ownerId: String, videoId: String, accessKey: String?)? {
        let decoded = rawURL.removingPercentEncoding ?? rawURL
        if decoded.contains("video_ext.php") {
            guard let oid = firstMatch("[?&]oid=(-?\\d+)", in: decoded),
                  let vid = firstMatch("[?&]id=(\\d+)", in: decoded) else {
                return nil
            }
            let hash = firstMatch("[?&]hash=([a-f0-9]+)", in: decoded)
            return (oid, vid, hash)
        }

        if let groups = allGroups("(?:video|clip)(-?\\d+)_(\\d+)(?:_([a-f0-9]+))?", in: decoded),
           let owner = groups[safe: 1],
           let vid = groups[safe: 2] {
            return (owner, vid, groups[safe: 3])
        }

        if let zParam = firstMatch("[?&]z=([^&]+)", in: decoded),
           let groups = allGroups("(?:video|clip)(-?\\d+)_(\\d+)(?:_([a-f0-9]+))?", in: zParam),
           let owner = groups[safe: 1],
           let vid = groups[safe: 2] {
            return (owner, vid, groups[safe: 3])
        }

        return nil
    }

    // MARK: - StudioMir

    private func parseStudioMir(url: URL) async -> VideoParseResult? {
        guard let ani = firstMatch("[?&]ani=(\\d+)", in: url.absoluteString),
              let epStr = firstMatch("[&?]ep=(\\d+)", in: url.absoluteString),
              let ep = Int(epStr),
              let apiURL = URL(string: "https://api.studiomir.club/api?ani=\(ani)&apikey=80b2d3e9c4ff27eb2e924c4d38f7daec") else {
            DebugLogger.log(.parser, "StudioMir: invalid params in \(url.absoluteString)", level: .error)
            return nil
        }

        guard let resp = try? await client.fetchRawString(url: apiURL, headers: ["User-Agent": defaultUserAgent]),
              let data = resp.body.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([StudioMirItem].self, from: data),
              let episodes = decoded.first?.players?.tsm else {
            DebugLogger.log(.parser, "StudioMir: failed to decode response", level: .error)
            return nil
        }

        let matching = episodes.filter { $0.episode == ep }
        let selected = matching.first(where: { $0.type == "TV" })
            ?? matching.first(where: { $0.type != "TR" })
            ?? matching.first
        guard let target = selected else {
            DebugLogger.log(.parser, "StudioMir: no episode \(ep) found", level: .warning)
            return nil
        }

        var variants: [VideoStreamVariant] = []
        if let u = target.hls?.hls2160.flatMap(URL.init(string:)) { variants.append(.init(quality: "2160p", url: u)) }
        if let u = target.hls?.hls1080.flatMap(URL.init(string:)) { variants.append(.init(quality: "1080p", url: u)) }
        if let u = target.hls?.hls720.flatMap(URL.init(string:)) { variants.append(.init(quality: "720p", url: u)) }
        if variants.isEmpty, let def = target.url.flatMap(URL.init(string:)) {
            variants.append(.init(quality: "Default", url: def))
        }
        DebugLogger.log(.parser, "StudioMir: \(variants.count) variants")
        return VideoParseResult(variants: variants, headers: ["User-Agent": defaultUserAgent], useWebFallback: variants.isEmpty, originalURL: url)
    }

    // MARK: - AniLibria

    private func parseAniLibria(url: URL) async -> VideoParseResult? {
        guard let match = allGroups("id=(\\d+)&ep=(\\d+)", in: url.absoluteString),
              let releaseId = match[safe: 1],
              let epStr = match[safe: 2],
              let ep = Int(epStr),
              let apiURL = URL(string: "https://anilibria.top/api/v1/anime/releases/\(releaseId)") else {
            DebugLogger.log(.parser, "AniLibria: invalid params in \(url.absoluteString)", level: .error)
            return nil
        }

        guard let resp = try? await client.fetchRawString(url: apiURL, headers: ["User-Agent": defaultUserAgent]),
              let data = resp.body.data(using: .utf8),
              let release = try? JSONDecoder.anixart.decode(AniLibriaRelease.self, from: data),
              let episode = release.episodes?.first(where: { $0.ordinal == ep }) else {
            DebugLogger.log(.parser, "AniLibria: failed to fetch/find episode \(ep)", level: .error)
            return nil
        }

        var variants: [VideoStreamVariant] = []
        if let u = episode.hls1080.flatMap(URL.init(string:)) { variants.append(.init(quality: "1080p", url: u)) }
        if let u = episode.hls720.flatMap(URL.init(string:)) { variants.append(.init(quality: "720p", url: u)) }
        if let u = episode.hls480.flatMap(URL.init(string:)) { variants.append(.init(quality: "480p", url: u)) }
        DebugLogger.log(.parser, "AniLibria: \(variants.count) variants")
        return VideoParseResult(variants: variants, headers: ["User-Agent": defaultUserAgent], useWebFallback: variants.isEmpty, originalURL: url)
    }

    // MARK: - RuTube

    private func parseRuTube(url: URL) async -> VideoParseResult? {
        let videoId = url.pathComponents.last(where: { !$0.isEmpty && $0 != "embed" })
        guard let videoId,
              let apiURL = URL(string: "https://rutube.ru/api/play/options/\(videoId)/?no_404=true&referer&pver=v2") else {
            return nil
        }

        guard let resp = try? await client.fetchRawString(url: apiURL, headers: [
            "User-Agent": defaultUserAgent,
            "Referer": "https://rutube.ru/"
        ]),
              let data = resp.body.data(using: .utf8),
              let options = try? JSONDecoder.anixart.decode(RuTubePlayOptions.self, from: data),
              let m3u8String = options.videoBalancer?.m3u8,
              let masterURL = URL(string: m3u8String) else {
            return nil
        }

        var variants: [VideoStreamVariant] = []
        if let playlist = try? await client.fetchRawString(url: masterURL, headers: ["User-Agent": defaultUserAgent]) {
            let lines = playlist.body.components(separatedBy: .newlines)
            for idx in lines.indices where lines[idx].hasPrefix("#EXT-X-STREAM-INF:") {
                let nextIdx = idx + 1
                guard nextIdx < lines.count else { continue }
                let streamLine = lines[nextIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !streamLine.isEmpty, !streamLine.hasPrefix("#"),
                      let streamURL = URL(string: streamLine, relativeTo: masterURL)?.absoluteURL else { continue }

                if let res = allGroups("RESOLUTION=(\\d+)x(\\d+)", in: lines[idx]),
                   let w = Int(res[safe: 1] ?? "0"),
                   let h = Int(res[safe: 2] ?? "0") {
                    let maxDim = max(w, h)
                    let label = maxDim >= 3840 ? "2160p"
                        : maxDim >= 2560 ? "1440p"
                        : maxDim >= 1920 ? "1080p"
                        : maxDim >= 1280 ? "720p"
                        : maxDim >= 854 ? "480p" : "360p"
                    variants.append(.init(quality: label, url: streamURL))
                }
            }
        }
        if variants.isEmpty {
            variants.append(.init(quality: "Auto (HLS)", url: masterURL))
        }
        return VideoParseResult(variants: variants, headers: ["Referer": "https://rutube.ru/", "User-Agent": defaultUserAgent], useWebFallback: false, originalURL: url)
    }

    // MARK: - Sibnet

    private func parseSibnet(url: URL) async -> VideoParseResult? {
        guard let html = try? await client.fetchRawString(url: url, headers: ["User-Agent": defaultUserAgent]),
              let path = firstMatch("src:\\s*\"(.*?)\"", in: html.body),
              let redirectURL = URL(string: "https://video.sibnet.ru\(path)") else {
            DebugLogger.log(.parser, "Sibnet: failed to extract src from HTML", level: .error)
            return nil
        }

        let headers = ["Referer": url.absoluteString, "User-Agent": defaultUserAgent]
        guard let location = try? await client.fetchRedirectLocation(url: redirectURL, headers: headers) else {
            DebugLogger.log(.parser, "Sibnet: no redirect location, using \(redirectURL.absoluteString)", level: .warning)
            return VideoParseResult(variants: [.init(quality: "Default", url: redirectURL)], headers: headers, useWebFallback: false, originalURL: url)
        }

        let firstFinal = location.hasPrefix("http") ? location : "https:\(location)"
        var finalURLString = firstFinal
        if let u1 = URL(string: firstFinal),
           let secondLoc = try? await client.fetchRedirectLocation(url: u1, headers: ["User-Agent": defaultUserAgent]) {
            finalURLString = secondLoc.replacingOccurrences(of: ":443", with: "")
        }

        guard let finalURL = URL(string: finalURLString) else {
            DebugLogger.log(.parser, "Sibnet: invalid finalURL '\(finalURLString)'", level: .error)
            return nil
        }
        DebugLogger.log(.parser, "Sibnet resolved: \(finalURL.absoluteString)")
        return VideoParseResult(variants: [.init(quality: "Default", url: finalURL)], headers: headers, useWebFallback: false, originalURL: url)
    }

    // MARK: - Mail.ru

    private func parseMailRu(url: URL) async -> VideoParseResult? {
        guard let id = firstMatch("embed/([0-9]*)", in: url.absoluteString),
              let metaURL = URL(string: "https://my.mail.ru/+/video/meta/\(id)"),
              let resp = try? await client.fetchRawString(url: metaURL, headers: ["User-Agent": defaultUserAgent]),
              let data = resp.body.data(using: .utf8),
              let meta = try? JSONDecoder().decode(MailRuMeta.self, from: data) else {
            return nil
        }

        let setCookie = resp.headers.first { $0.key.caseInsensitiveCompare("Set-Cookie") == .orderedSame }?.value
        var assetHeaders: [String: String] = ["User-Agent": defaultUserAgent]
        if let setCookie, !setCookie.isEmpty {
            assetHeaders["Cookie"] = setCookie
        }

        var variants: [VideoStreamVariant] = []
        for video in meta.videos ?? [] {
            let fullString = video.url.hasPrefix("http") ? video.url : "https:\(video.url)"
            guard let vURL = URL(string: fullString) else { continue }
            if video.key.contains("1080") { variants.append(.init(quality: "1080p", url: vURL)) }
            else if video.key.contains("720") { variants.append(.init(quality: "720p", url: vURL)) }
            else if video.key.contains("480") { variants.append(.init(quality: "480p", url: vURL)) }
            else if video.key.contains("360") { variants.append(.init(quality: "360p", url: vURL)) }
        }
        variants.sort { qualityRank($0.quality) > qualityRank($1.quality) }
        return VideoParseResult(variants: variants, headers: assetHeaders, useWebFallback: variants.isEmpty, originalURL: url)
    }

    // MARK: - OK.ru / Myvi / Allvideo / SovetRomantica

    private func parseOK(url: URL) async -> VideoParseResult? {
        guard let html = try? await client.fetchRawString(url: url, headers: ["User-Agent": defaultUserAgent]),
              let rawAttr = firstMatch("data-options=\"(.*?)\"", in: html.body) else { return nil }
        let unescaped = rawAttr
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
        guard unescaped.contains("\"provider\":\"UPLOADED_ODKL\""),
              !unescaped.contains("\"is_live\":true") else { return nil }

        let pairs = allMatches("\"name\":\"(\\w+)\".*?\"url\":\"(.*?)\"", in: unescaped)
        var variants: [VideoStreamVariant] = []
        for pair in pairs {
            guard let name = pair[safe: 1], let raw = pair[safe: 2] else { continue }
            let cleanURL = raw.replacingOccurrences(of: "\\u0026", with: "&")
            guard cleanURL.hasPrefix("http"), !cleanURL.contains("disallowed"), let vURL = URL(string: cleanURL) else { continue }
            let label = switch name {
            case "full": "1080p"
            case "hd": "720p"
            case "sd": "480p"
            case "low": "360p"
            default: name
            }
            variants.append(.init(quality: label, url: vURL))
        }
        variants.sort { qualityRank($0.quality) > qualityRank($1.quality) }
        return VideoParseResult(variants: variants, headers: ["User-Agent": defaultUserAgent], useWebFallback: variants.isEmpty, originalURL: url)
    }

    private func parseMyvi(url: URL) async -> VideoParseResult? {
        guard let html = try? await client.fetchRawString(url: url, headers: ["User-Agent": defaultUserAgent]),
              let encoded = firstMatch("CreatePlayer\\(\"v=(.*?)\\\\u0026", in: html.body),
              let decoded = encoded.removingPercentEncoding,
              let finalURL = URL(string: decoded) else {
            return nil
        }
        return VideoParseResult(variants: [.init(quality: "Default", url: finalURL)], headers: ["User-Agent": defaultUserAgent], useWebFallback: false, originalURL: url)
    }

    private func parseAllvideo(url: URL) async -> VideoParseResult? {
        guard let html = try? await client.fetchRawString(url: url, headers: ["User-Agent": defaultUserAgent]),
              let filePayload = firstMatch("file:\"(.*?)\"", in: html.body) else {
            return nil
        }
        let matches = allMatches("\\[([0-9]*p)](.*?)(,|$)", in: filePayload)
        var variants: [VideoStreamVariant] = []
        for match in matches {
            if let q = match[safe: 1], let u = match[safe: 2], let vURL = URL(string: u) {
                variants.append(.init(quality: q, url: vURL))
            }
        }
        if variants.isEmpty, let fallback = URL(string: filePayload) {
            variants.append(.init(quality: "Default", url: fallback))
        }
        variants.sort { qualityRank($0.quality) > qualityRank($1.quality) }
        return VideoParseResult(variants: variants, headers: ["User-Agent": defaultUserAgent], useWebFallback: variants.isEmpty, originalURL: url)
    }

    private func parseSovetRomantica(url: URL) async -> VideoParseResult? {
        guard let html = try? await client.fetchRawString(url: url, headers: ["User-Agent": defaultUserAgent]),
              let m3u8 = firstMatch("\"file\":\"(.*?)\"", in: html.body),
              let vURL = URL(string: m3u8) else {
            return nil
        }
        return VideoParseResult(variants: [.init(quality: "Auto (HLS)", url: vURL)], headers: ["User-Agent": defaultUserAgent], useWebFallback: false, originalURL: url)
    }

    // MARK: - Helpers

    private func qualityRank(_ quality: String) -> Int {
        switch quality {
        case "2160p": return 2160
        case "1440p": return 1440
        case "1080p": return 1080
        case "720p": return 720
        case "480p": return 480
        case "360p": return 360
        default: return 100
        }
    }

    private func firstMatch(_ pattern: String, in text: String) -> String? {
        allGroups(pattern, in: text)?[safe: 1]
    }

    private func allGroups(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (0..<match.numberOfRanges).compactMap { idx in
            guard let r = Range(match.range(at: idx), in: text) else { return nil }
            return String(text[r])
        }
    }

    private func allMatches(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).map { match in
            (0..<match.numberOfRanges).compactMap { idx in
                guard let r = Range(match.range(at: idx), in: text) else { return nil }
                return String(text[r])
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Parser DTOs

private struct StudioMirItem: Decodable {
    let players: StudioMirPlayers?
}
private struct StudioMirPlayers: Decodable {
    let tsm: [StudioMirEpisode]?
}
private struct StudioMirEpisode: Decodable {
    let episode: Int?
    let type: String?
    let url: String?
    let hls: StudioMirHLS?
}
private struct StudioMirHLS: Decodable {
    let hls720: String?
    let hls1080: String?
    let hls2160: String?
    enum CodingKeys: String, CodingKey {
        case hls720 = "720"
        case hls1080 = "1080"
        case hls2160 = "2160"
    }
}

private struct AniLibriaRelease: Decodable {
    let episodes: [AniLibriaEpisode]?
}
private struct AniLibriaEpisode: Decodable {
    let ordinal: Int?
    let hls480: String?
    let hls720: String?
    let hls1080: String?
}

private struct RuTubePlayOptions: Decodable {
    let videoBalancer: RuTubeBalancer?
}
private struct RuTubeBalancer: Decodable {
    let m3u8: String?
}

private struct MailRuMeta: Decodable {
    let videos: [MailRuVideo]?
}
private struct MailRuVideo: Decodable {
    let key: String
    let url: String
}

private struct VKAnonymousTokenResponse: Decodable {
    let token: String?
    let expiredAt: Int64?
    let error: String?
    let errorDescription: String?
}

private struct VKVideoGetResponse: Decodable {
    let response: VKVideoResponse?
}

private struct VKVideoResponse: Decodable {
    let items: [VKVideoItem]?
}

private struct VKVideoItem: Decodable {
    let files: [String: String]?
}

