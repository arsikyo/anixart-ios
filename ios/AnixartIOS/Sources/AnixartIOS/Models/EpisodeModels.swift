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
}

struct Episode: Codable, Identifiable, Hashable, Sendable {
    let id: Int64?
    let position: Int
    let name: String?
    let url: String
    let iframe: Bool?
    let isWatched: Bool?
    let isFiller: Bool?
    let addedDate: Int64?
    let source: VideoSource?
    let release: Release?

    var stableId: String {
        "\(id ?? Int64(position))-\(position)-\(url)"
    }

    var displayTitle: String {
        if let name, !name.isEmpty {
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
