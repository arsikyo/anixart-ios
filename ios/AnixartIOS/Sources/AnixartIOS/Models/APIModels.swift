import Foundation

protocol APIStatus: Sendable {
    var code: Int { get }
}

struct BaseResponse: Decodable, APIStatus, Sendable {
    let code: Int
}

struct PageableResponse<Item: Decodable & Sendable>: Decodable, APIStatus, Sendable {
    let code: Int
    let content: [Item]
    let totalCount: Int64?
    let totalPageCount: Int?
    let currentPage: Int?
}

struct ReleaseResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let release: Release?
}

struct ReleaseSearchResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let releases: [Release]?
    let content: [Release]?
}

struct ScheduleResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let monday: [Release]?
    let tuesday: [Release]?
    let wednesday: [Release]?
    let thursday: [Release]?
    let friday: [Release]?
    let saturday: [Release]?
    let sunday: [Release]?
}

struct ConfigURLsResponse: Decodable, Sendable {
    let code: Int?
    let apiUrls: [String]
    let editorUrl: String?
    let staticDomain: String?
    let shouldUseMirrorUrls: Bool
    let googleAuthAvailable: Bool
    let telegramAuthAvailable: Bool
    let vkAuthAvailable: Bool
    let yandexAuthAvailable: Bool
    let consentRequired: Bool?
}

struct TogglesResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let whatsNew: String?
    let downloadLink: String?
    let baseUrl: String?
    let iframeEmbedUrl: String?
    let kodikAdIframeUrl: String?
    let kodikVideoLinksUrl: String?
    let sibnetUserAgent: String?
    let sibnetRandUserAgent: Bool?
    let torlookUrl: String?
    let editorUrl: String?
    let staticDomain: String?
    let googleAuthAvailable: Bool?
    let telegramAuthAvailable: Bool?
    let vkAuthAvailable: Bool?
    let yandexAuthAvailable: Bool?
    let impMessageEnabled: Bool?
    let impMessageText: String?
    let impMessageLink: String?
    let snowfall: Bool?
}

struct AnixPlayerConfigResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let lastVersionCode: Int64?
    let whatsNew: String?
    let downloadLinks: [String: String]?
}

struct ReleaseStatusInfo: Codable, Hashable, Sendable {
    let id: Int64?
    let name: String?
}

struct ReleaseCategoryInfo: Codable, Hashable, Sendable {
    let id: Int64?
    let name: String?
}

struct Release: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let titleRu: String?
    let titleOriginal: String?
    let titleAlt: String?
    let image: String?
    let poster: String?
    let year: String?
    let genres: String?
    let country: String?
    let director: String?
    let author: String?
    let studio: String?
    let description: String?
    let note: String?
    let grade: Double?
    let rating: Double?
    let voteCount: Int?
    let yourVote: Int?
    let episodesReleased: Int?
    let episodesTotal: Int?
    let duration: Int?
    let season: Int?
    let ageRating: Int?
    let broadcast: Int?
    let profileListStatus: Int?
    let isFavorite: Bool?
    let isPlayDisabled: Bool?
    let isViewed: Bool?
    let isAdult: Bool?
    let relatedId: Int64?
    let status: ReleaseStatusInfo?
    let category: ReleaseCategoryInfo?

    var displayTitle: String {
        if let ru = titleRu, !ru.isEmpty { return ru }
        if let orig = titleOriginal, !orig.isEmpty { return orig }
        if let alt = titleAlt, !alt.isEmpty { return alt }
        return "Без названия"
    }

    var subtitleTitle: String? {
        if let orig = titleOriginal, !orig.isEmpty, orig != displayTitle { return orig }
        return titleAlt
    }

    var imageURL: URL? {
        guard let raw = image ?? poster, !raw.isEmpty else { return nil }
        if raw.hasPrefix("http") { return URL(string: raw) }
        return URL(string: "https://s.\(APIConfiguration.staticDomain)/posters/\(raw)")
    }

    var episodeText: String? {
        guard episodesReleased != nil || episodesTotal != nil else { return nil }
        let released = episodesReleased.map(String.init) ?? "?"
        let total = episodesTotal.map(String.init) ?? "?"
        return "\(released) / \(total) эп."
    }
}

struct InterestingItem: Decodable, Identifiable, Hashable, Sendable {
    let id: Int64
    let title: String?
    let description: String?
    let image: String?
    let type: Int?
    let action: String?

    var imageURL: URL? {
        guard let image, !image.isEmpty else { return nil }
        return URL(string: image)
    }
}

struct SearchRequest: Encodable, Sendable {
    let query: String
    let searchBy: Int

    init(query: String, searchBy: Int = 0) {
        self.query = query
        self.searchBy = searchBy
    }
}

struct FilterRequest: Encodable, Sendable {
    var categoryId: Int64?
    var country: String?
    var startYear: Int?
    var endYear: Int?
    var episodeDurationFrom: Int?
    var episodeDurationTo: Int?
    var episodesFrom: Int?
    var episodesTo: Int?
    var genres: [String] = []
    var genresMode: Int?
    var isGenresExcludeModeEnabled: Bool = false
    var profileListExclusions: [Int] = []
    var season: Int?
    var sort: Int? = 0
    var source: String?
    var statusId: Int64?
    var studio: String?
    var types: [Int64] = []
    var ageRatings: [Int] = []
}

enum BookmarkStatus: Int, CaseIterable, Identifiable, Sendable {
    case watching = 1
    case planned = 2
    case completed = 3
    case onHold = 4
    case dropped = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .watching: return "Смотрю"
        case .planned: return "В планах"
        case .completed: return "Просмотрено"
        case .onHold: return "Отложено"
        case .dropped: return "Брошено"
        }
    }

    var systemImage: String {
        switch self {
        case .watching: return "play.circle"
        case .planned: return "calendar.badge.plus"
        case .completed: return "checkmark.circle"
        case .onHold: return "pause.circle"
        case .dropped: return "xmark.circle"
        }
    }
}
