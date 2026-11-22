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

private struct ReleaseRelatedRef: Decodable {
    let id: Int64?
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

    private enum CodingKeys: String, CodingKey {
        case id, titleRu, titleOriginal, titleAlt, image, poster, year, genres, country
        case director, author, studio, description, note, grade, rating, voteCount, yourVote
        case episodesReleased, episodesTotal, duration, season, ageRating, broadcast
        case profileListStatus, isFavorite, isPlayDisabled, isViewed, isAdult
        case relatedId, related, status, category
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        titleRu = try c.decodeIfPresent(String.self, forKey: .titleRu)
        titleOriginal = try c.decodeIfPresent(String.self, forKey: .titleOriginal)
        titleAlt = try c.decodeIfPresent(String.self, forKey: .titleAlt)
        image = try c.decodeIfPresent(String.self, forKey: .image)
        poster = try c.decodeIfPresent(String.self, forKey: .poster)
        year = try c.decodeIfPresent(String.self, forKey: .year)
        genres = try c.decodeIfPresent(String.self, forKey: .genres)
        country = try c.decodeIfPresent(String.self, forKey: .country)
        director = try c.decodeIfPresent(String.self, forKey: .director)
        author = try c.decodeIfPresent(String.self, forKey: .author)
        studio = try c.decodeIfPresent(String.self, forKey: .studio)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        grade = try c.decodeIfPresent(Double.self, forKey: .grade)
        rating = try c.decodeIfPresent(Double.self, forKey: .rating)
        voteCount = try c.decodeIfPresent(Int.self, forKey: .voteCount)
        yourVote = try c.decodeIfPresent(Int.self, forKey: .yourVote)
        episodesReleased = try c.decodeIfPresent(Int.self, forKey: .episodesReleased)
        episodesTotal = try c.decodeIfPresent(Int.self, forKey: .episodesTotal)
        duration = try c.decodeIfPresent(Int.self, forKey: .duration)
        season = try c.decodeIfPresent(Int.self, forKey: .season)
        ageRating = try c.decodeIfPresent(Int.self, forKey: .ageRating)
        broadcast = try c.decodeIfPresent(Int.self, forKey: .broadcast)
        profileListStatus = try c.decodeIfPresent(Int.self, forKey: .profileListStatus)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite)
        isPlayDisabled = try c.decodeIfPresent(Bool.self, forKey: .isPlayDisabled)
        isViewed = try c.decodeIfPresent(Bool.self, forKey: .isViewed)
        isAdult = try c.decodeIfPresent(Bool.self, forKey: .isAdult)
        let directRelatedId = try c.decodeIfPresent(Int64.self, forKey: .relatedId)
        let relatedObj = try c.decodeObjectOrIgnoreRefIfPresent(ReleaseRelatedRef.self, forKey: .related)
        relatedId = directRelatedId ?? relatedObj?.id
        status = try c.decodeObjectOrIgnoreRefIfPresent(ReleaseStatusInfo.self, forKey: .status)
        category = try c.decodeObjectOrIgnoreRefIfPresent(ReleaseCategoryInfo.self, forKey: .category)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(titleRu, forKey: .titleRu)
        try c.encodeIfPresent(titleOriginal, forKey: .titleOriginal)
        try c.encodeIfPresent(titleAlt, forKey: .titleAlt)
        try c.encodeIfPresent(image, forKey: .image)
        try c.encodeIfPresent(poster, forKey: .poster)
        try c.encodeIfPresent(year, forKey: .year)
        try c.encodeIfPresent(genres, forKey: .genres)
        try c.encodeIfPresent(country, forKey: .country)
        try c.encodeIfPresent(director, forKey: .director)
        try c.encodeIfPresent(author, forKey: .author)
        try c.encodeIfPresent(studio, forKey: .studio)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(note, forKey: .note)
        try c.encodeIfPresent(grade, forKey: .grade)
        try c.encodeIfPresent(rating, forKey: .rating)
        try c.encodeIfPresent(voteCount, forKey: .voteCount)
        try c.encodeIfPresent(yourVote, forKey: .yourVote)
        try c.encodeIfPresent(episodesReleased, forKey: .episodesReleased)
        try c.encodeIfPresent(episodesTotal, forKey: .episodesTotal)
        try c.encodeIfPresent(duration, forKey: .duration)
        try c.encodeIfPresent(season, forKey: .season)
        try c.encodeIfPresent(ageRating, forKey: .ageRating)
        try c.encodeIfPresent(broadcast, forKey: .broadcast)
        try c.encodeIfPresent(profileListStatus, forKey: .profileListStatus)
        try c.encodeIfPresent(isFavorite, forKey: .isFavorite)
        try c.encodeIfPresent(isPlayDisabled, forKey: .isPlayDisabled)
        try c.encodeIfPresent(isViewed, forKey: .isViewed)
        try c.encodeIfPresent(isAdult, forKey: .isAdult)
        try c.encodeIfPresent(relatedId, forKey: .relatedId)
        try c.encodeIfPresent(status, forKey: .status)
        try c.encodeIfPresent(category, forKey: .category)
    }

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
