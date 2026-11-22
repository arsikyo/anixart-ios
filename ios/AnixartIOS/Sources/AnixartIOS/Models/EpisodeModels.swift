import Foundation

struct VoiceoverType: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let name: String
    let icon: String?
    let episodesCount: Int?
    let viewCount: Int64?
    let isSub: Bool?
}

struct VideoSource: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let name: String
    let episodesCount: Int?
    let type: VoiceoverType?

    init(id: Int64, name: String, episodesCount: Int?, type: VoiceoverType?) {
        self.id = id
        self.name = name
        self.episodesCount = episodesCount
        self.type = type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        episodesCount = try container.decodeIfPresent(Int.self, forKey: .episodesCount)
        type = try container.decodeObjectOrIgnoreRefIfPresent(VoiceoverType.self, forKey: .type)
    }
}

struct Episode: Codable, Identifiable, Hashable, Sendable {
    let id: Int64?
    let releaseId: Int64?
    let sourceId: Int64?
    let position: Int
    let name: String?
    let url: String
    let iframe: Bool?
    let isWatched: Bool?
    let isFiller: Bool?
    let addedDate: Int64?
    let source: VideoSource?
    let release: Release?

    init(
        id: Int64?,
        position: Int,
        name: String?,
        url: String,
        iframe: Bool?,
        isWatched: Bool?,
        isFiller: Bool?,
        addedDate: Int64?,
        source: VideoSource?,
        release: Release?,
        releaseId: Int64? = nil,
        sourceId: Int64? = nil
    ) {
        self.id = id
        self.releaseId = releaseId
        self.sourceId = sourceId
        self.position = position
        self.name = name
        self.url = url
        self.iframe = iframe
        self.isWatched = isWatched
        self.isFiller = isFiller
        self.addedDate = addedDate
        self.source = source
        self.release = release
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int64.self, forKey: .id)
        releaseId = try container.decodeIfPresent(Int64.self, forKey: .releaseId)
        sourceId = try container.decodeIfPresent(Int64.self, forKey: .sourceId)
        position = try container.decode(Int.self, forKey: .position)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        url = try container.decode(String.self, forKey: .url)
        iframe = try container.decodeIfPresent(Bool.self, forKey: .iframe)
        isWatched = try container.decodeIfPresent(Bool.self, forKey: .isWatched)
        isFiller = try container.decodeIfPresent(Bool.self, forKey: .isFiller)
        addedDate = try container.decodeIfPresent(Int64.self, forKey: .addedDate)
        source = try container.decodeObjectOrIgnoreRefIfPresent(VideoSource.self, forKey: .source)
        release = try container.decodeObjectOrIgnoreRefIfPresent(Release.self, forKey: .release)
    }

    var stableId: String {
        "\(id ?? Int64(position))-\(position)-\(url)"
    }

    var displayTitle: String {
        if let name, !name.isEmpty {
            if name.localizedCaseInsensitiveContains("\(position) сер") || name == "\(position)" {
                return name
            }
            return "\(position) серия — \(name)"
        }
        return "\(position) серия"
    }
}

struct TypesResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let types: [VoiceoverType]?
}

struct SourcesResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let sources: [VideoSource]?
}

struct EpisodeResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let episodes: [Episode]?
}

struct EpisodeTargetResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let episode: Episode?
}

struct EpisodeUpdate: Decodable, Identifiable, Hashable, Sendable {
    let id: Int64?
    let lastUpdateDate: Int64?
    let lastEpisodeUpdateName: String?
    let lastEpisodeTypeUpdateName: String?
    let lastEpisodeSourceUpdateName: String?
}
