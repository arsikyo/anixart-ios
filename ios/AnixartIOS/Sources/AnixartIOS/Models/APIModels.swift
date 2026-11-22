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

struct TogglesResponse: Decodable, Sendable {
    let code: Int?
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

struct ReleaseVideoBanner: Codable, Hashable, Sendable {
    let name: String?
    let image: String?
    let value: String?
    let actionId: Int64?
    let isNew: Bool?

    var imageURL: URL? {
        guard let image, !image.isEmpty else { return nil }
        return URL(string: image.replacingOccurrences(of: "http://", with: "https://"))
    }
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
    let vote1Count: Int?
    let vote2Count: Int?
    let vote3Count: Int?
    let vote4Count: Int?
    let vote5Count: Int?
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
    let releaseDate: String?
    let airedOnDate: Int64?
    let favoritesCount: Int?
    let commentCount: Int?
    let collectionCount: Int?
    let watchingCount: Int?
    let planCount: Int?
    let completedCount: Int?
    let holdOnCount: Int?
    let droppedCount: Int?
    let screenshots: [String]?
    let screenshotImages: [String]?
    let videoBanners: [ReleaseVideoBanner]?
    let status: ReleaseStatusInfo?
    let category: ReleaseCategoryInfo?

    private enum CodingKeys: String, CodingKey {
        case id, titleRu, titleOriginal, titleAlt, image, poster, year, genres, country
        case director, author, studio, description, note, grade, rating, voteCount, yourVote
        case vote1Count, vote2Count, vote3Count, vote4Count, vote5Count
        case episodesReleased, episodesTotal, duration, season, ageRating, broadcast
        case profileListStatus, isFavorite, isPlayDisabled, isViewed, isAdult
        case relatedId, related, releaseDate, airedOnDate
        case favoritesCount, commentCount, commentsCount, collectionCount
        case watchingCount, planCount, completedCount, holdOnCount, droppedCount
        case screenshots, screenshotImages, videoBanners, status, category
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
        vote1Count = try c.decodeIfPresent(Int.self, forKey: .vote1Count)
        vote2Count = try c.decodeIfPresent(Int.self, forKey: .vote2Count)
        vote3Count = try c.decodeIfPresent(Int.self, forKey: .vote3Count)
        vote4Count = try c.decodeIfPresent(Int.self, forKey: .vote4Count)
        vote5Count = try c.decodeIfPresent(Int.self, forKey: .vote5Count)
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
        releaseDate = try c.decodeIfPresent(String.self, forKey: .releaseDate)
        airedOnDate = try c.decodeIfPresent(Int64.self, forKey: .airedOnDate)
        favoritesCount = try c.decodeIfPresent(Int.self, forKey: .favoritesCount)
        let cc = try c.decodeIfPresent(Int.self, forKey: .commentCount)
        let ccs = try c.decodeIfPresent(Int.self, forKey: .commentsCount)
        commentCount = cc ?? ccs
        collectionCount = try c.decodeIfPresent(Int.self, forKey: .collectionCount)
        watchingCount = try c.decodeIfPresent(Int.self, forKey: .watchingCount)
        planCount = try c.decodeIfPresent(Int.self, forKey: .planCount)
        completedCount = try c.decodeIfPresent(Int.self, forKey: .completedCount)
        holdOnCount = try c.decodeIfPresent(Int.self, forKey: .holdOnCount)
        droppedCount = try c.decodeIfPresent(Int.self, forKey: .droppedCount)
        screenshots = try c.decodeIfPresent([String].self, forKey: .screenshots)
        screenshotImages = try c.decodeIfPresent([String].self, forKey: .screenshotImages)
        videoBanners = try c.decodeIfPresent([ReleaseVideoBanner].self, forKey: .videoBanners)
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
        try c.encodeIfPresent(vote1Count, forKey: .vote1Count)
        try c.encodeIfPresent(vote2Count, forKey: .vote2Count)
        try c.encodeIfPresent(vote3Count, forKey: .vote3Count)
        try c.encodeIfPresent(vote4Count, forKey: .vote4Count)
        try c.encodeIfPresent(vote5Count, forKey: .vote5Count)
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
        try c.encodeIfPresent(releaseDate, forKey: .releaseDate)
        try c.encodeIfPresent(airedOnDate, forKey: .airedOnDate)
        try c.encodeIfPresent(favoritesCount, forKey: .favoritesCount)
        try c.encodeIfPresent(commentCount, forKey: .commentCount)
        try c.encodeIfPresent(collectionCount, forKey: .collectionCount)
        try c.encodeIfPresent(watchingCount, forKey: .watchingCount)
        try c.encodeIfPresent(planCount, forKey: .planCount)
        try c.encodeIfPresent(completedCount, forKey: .completedCount)
        try c.encodeIfPresent(holdOnCount, forKey: .holdOnCount)
        try c.encodeIfPresent(droppedCount, forKey: .droppedCount)
        try c.encodeIfPresent(screenshots, forKey: .screenshots)
        try c.encodeIfPresent(screenshotImages, forKey: .screenshotImages)
        try c.encodeIfPresent(videoBanners, forKey: .videoBanners)
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
        let file = raw.contains(".") ? raw : "\(raw).jpg"
        return URL(string: "https://s.\(APIConfiguration.staticDomain)/posters/\(file)")
    }

    var episodeText: String? {
        guard episodesReleased != nil || episodesTotal != nil else { return nil }
        let released = episodesReleased.map(String.init) ?? "?"
        let total = episodesTotal.map(String.init) ?? "?"
        return "\(released) / \(total) эп."
    }

    var isAnnouncement: Bool {
        status?.id == 3 || status?.name?.localizedCaseInsensitiveContains("анонс") == true
    }

    var compactEpisodeText: String? {
        if isAnnouncement {
            if let total = episodesTotal, total > 0 {
                return "Анонс  \(total) эп"
            }
            return "Анонс  ? эп"
        }
        if let released = episodesReleased, let total = episodesTotal {
            if released == total && total > 0 {
                return "\(total) эп"
            }
            return "\(released) из \(total) эп"
        }
        if let released = episodesReleased {
            return "\(released) из ? эп"
        }
        if let total = episodesTotal {
            return "\(total) эп"
        }
        return nil
    }

    var ageRatingText: String? {
        switch ageRating {
        case 1: return "0+"
        case 2: return "6+"
        case 3: return "12+"
        case 4: return "16+"
        case 5: return "18+"
        default:
            return (isAdult == true) ? "18+" : nil
        }
    }

    var countryFlagEmoji: String {
        let lower = (country ?? "").lowercased()
        if lower.contains("япон") { return "🇯🇵" }
        if lower.contains("кита") { return "🇨🇳" }
        if lower.contains("коре") { return "🇰🇷" }
        if lower.contains("сша") || lower.contains("америк") { return "🇺🇸" }
        if lower.contains("росс") { return "🇷🇺" }
        if lower.contains("франц") { return "🇫🇷" }
        if lower.contains("велик") || lower.contains("англ") { return "🇬🇧" }
        return "🌐"
    }

    var seasonName: String? {
        switch season {
        case 1: return "зима"
        case 2: return "весна"
        case 3: return "лето"
        case 4: return "осень"
        default: return nil
        }
    }

    var countrySeasonYearText: String? {
        var parts: [String] = []
        if let country, !country.isEmpty {
            parts.append(country)
        }
        var timeParts: [String] = []
        if let seasonName {
            timeParts.append(seasonName)
        }
        if let year, !year.isEmpty {
            timeParts.append("\(year) г.")
        }
        if !timeParts.isEmpty {
            parts.append(timeParts.joined(separator: " "))
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    var episodeStatsText: String? {
        let epPart: String?
        if let released = episodesReleased, let total = episodesTotal {
            if released == total && total > 0 {
                epPart = "\(total) эп."
            } else {
                epPart = "\(released) из \(total) эп."
            }
        } else if let released = episodesReleased {
            epPart = "\(released) эп."
        } else if let total = episodesTotal {
            epPart = "\(total) эп."
        } else {
            epPart = nil
        }

        if let epPart, let duration, duration > 0 {
            return "\(epPart) по ~\(duration) мин."
        }
        if let epPart { return epPart }
        if let duration, duration > 0 {
            return "Длительность ~\(duration) мин."
        }
        return nil
    }

    var typeAndStatusText: String? {
        let cat = category?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let st = status?.name?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let items = [cat, st].compactMap { ($0?.isEmpty == false) ? $0 : nil }
        return items.isEmpty ? nil : items.joined(separator: ", ")
    }

    var creditsText: String? {
        var items: [String] = []
        if let studio, !studio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("Студия \(studio)")
        }
        if let author, !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("автор \(author)")
        }
        if let director, !director.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("режиссёр \(director)")
        }
        return items.isEmpty ? nil : items.joined(separator: ", ")
    }

    var genreTags: [String] {
        guard let genres, !genres.isEmpty else { return [] }
        return genres
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var screenshotURLs: [URL] {
        if let screenshotImages, !screenshotImages.isEmpty {
            return screenshotImages.compactMap { URL(string: $0) }
        }
        if let screenshots, !screenshots.isEmpty {
            return screenshots.compactMap { key in
                if key.hasPrefix("http") { return URL(string: key) }
                return URL(string: "https://s.\(APIConfiguration.staticDomain)/screenshots/\(key).jpg")
            }
        }
        return []
    }

    var voteBreakdown: [(stars: Int, count: Int)] {
        [
            (5, vote5Count ?? 0),
            (4, vote4Count ?? 0),
            (3, vote3Count ?? 0),
            (2, vote2Count ?? 0),
            (1, vote1Count ?? 0)
        ]
    }

    var listStatsTotal: Int {
        (watchingCount ?? 0)
            + (planCount ?? 0)
            + (completedCount ?? 0)
            + (holdOnCount ?? 0)
            + (droppedCount ?? 0)
    }

    var announcementDateText: String? {
        guard isAnnouncement else { return nil }
        if let raw = releaseDate?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return raw
        }
        if let ts = airedOnDate, ts > 0 {
            let date = Date(timeIntervalSince1970: TimeInterval(ts))
            return Self.announcementFormatter.string(from: date)
        }
        if let year = year?.trimmingCharacters(in: .whitespacesAndNewlines), !year.isEmpty {
            return "\(year) г."
        }
        return "скоро"
    }

    private static let announcementFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM yyyy 'г.'"
        return f
    }()
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
