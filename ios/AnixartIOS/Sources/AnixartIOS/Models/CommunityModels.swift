import Foundation

struct Profile: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let login: String?
    let avatar: String?
    let status: String?
    let ratingScore: Int?
    let isBlocked: Bool?
    let isPermBanned: Bool?
    let isSponsor: Bool?
    let isVerified: Bool?
    let isOnline: Bool?
    let lastActivityTime: Int64?
    let friendCount: Int?
    let watchingCount: Int?
    let planCount: Int?
    let completedCount: Int?
    let holdOnCount: Int?
    let droppedCount: Int?
    let favoriteCount: Int?
    let commentCount: Int?
    let collectionCount: Int?
    let watchedEpisodeCount: Int?
    let watchedTime: Int64?
    let badgeName: String?
    let badgeUrl: String?
    let badgeType: Int?

    var displayName: String {
        login ?? "Профиль #\(id)"
    }

    var avatarURL: URL? {
        guard let avatar, !avatar.isEmpty else {
            return APIConfiguration.defaultAvatarURL
        }
        if avatar.hasPrefix("http") { return URL(string: avatar) }
        return URL(string: "https://s.\(APIConfiguration.staticDomain)/avatars/\(avatar)")
    }

    var badgeImageURL: URL? {
        guard let badgeUrl, !badgeUrl.isEmpty else { return nil }
        return URL(string: badgeUrl.replacingOccurrences(of: "http://", with: "https://"))
    }
}

struct ProfileResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let profile: Profile?
    let isMyProfile: Bool?
}

struct ProfileInfoResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let channelId: Int64?
    let privilegeLevel: Int64?
    let ratingScore: Int?
    let sponsorshipExpires: Int64?
    let isPermBanned: Bool?
    let isSponsor: Bool?
}

struct ProfileSocialResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let vkPage: String?
    let tgPage: String?
    let instPage: String?
    let ttPage: String?
    let discordPage: String?
}

struct ProfilePreferenceResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let channelId: Int64?
    let emailHint: String?
    let isLoginChanged: Bool?
    let isChangeLoginBanned: Bool?
    let isChangeAvatarBanned: Bool?
    let isGoogleBound: Bool?
    let isVkBound: Bool?
    let isTelegramBound: Bool?
    let isYandexBound: Bool?
    let isIncognito: Bool?
    let episodeChannelWidgetsHidden: Bool?
}

struct CollectionItem: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let title: String?
    let description: String?
    let image: String?
    let favoriteCount: Int?
    let commentCount: Int?
    let releaseCount: Int?
    let isFavorite: Bool?
    let isPrivate: Bool?
    let creator: Profile?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        image = try c.decodeIfPresent(String.self, forKey: .image)
        favoriteCount = try c.decodeIfPresent(Int.self, forKey: .favoriteCount)
        commentCount = try c.decodeIfPresent(Int.self, forKey: .commentCount)
        releaseCount = try c.decodeIfPresent(Int.self, forKey: .releaseCount)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite)
        isPrivate = try c.decodeIfPresent(Bool.self, forKey: .isPrivate)
        creator = try c.decodeObjectOrIgnoreRefIfPresent(Profile.self, forKey: .creator)
    }

    var imageURL: URL? {
        guard let image, !image.isEmpty else { return nil }
        return URL(string: image)
    }
}

struct CollectionResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let collection: CollectionItem?
    let completedCount: Int64?
    let droppedCount: Int64?
    let holdOnCount: Int64?
    let planCount: Int64?
    let watchingCount: Int64?
}

struct ReleaseComment: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let message: String?
    let timestamp: Int64?
    let isSpoiler: Bool?
    let isEdited: Bool?
    let isDeleted: Bool?
    let voteCount: Int?
    let likesCount: Int?
    let myVote: Int?
    let replyCount: Int?
    let parentCommentId: Int64?
    let isReply: Bool?
    let profile: Profile?

    private enum CodingKeys: String, CodingKey {
        case id, message, timestamp, isSpoiler, isEdited, isDeleted
        case voteCount, likesCount, vote, myVote, replyCount, parentCommentId, isReply, profile
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        timestamp = try c.decodeIfPresent(Int64.self, forKey: .timestamp)
        isSpoiler = try c.decodeIfPresent(Bool.self, forKey: .isSpoiler)
        isEdited = try c.decodeIfPresent(Bool.self, forKey: .isEdited)
        isDeleted = try c.decodeIfPresent(Bool.self, forKey: .isDeleted)
        voteCount = try c.decodeIfPresent(Int.self, forKey: .voteCount)
        likesCount = try c.decodeIfPresent(Int.self, forKey: .likesCount)
        let directVote = try c.decodeIfPresent(Int.self, forKey: .vote)
        let legacyVote = try c.decodeIfPresent(Int.self, forKey: .myVote)
        myVote = directVote ?? legacyVote
        replyCount = try c.decodeIfPresent(Int.self, forKey: .replyCount)
        parentCommentId = try c.decodeIfPresent(Int64.self, forKey: .parentCommentId)
        isReply = try c.decodeIfPresent(Bool.self, forKey: .isReply)
        profile = try c.decodeObjectOrIgnoreRefIfPresent(Profile.self, forKey: .profile)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(message, forKey: .message)
        try c.encodeIfPresent(timestamp, forKey: .timestamp)
        try c.encodeIfPresent(isSpoiler, forKey: .isSpoiler)
        try c.encodeIfPresent(isEdited, forKey: .isEdited)
        try c.encodeIfPresent(isDeleted, forKey: .isDeleted)
        try c.encodeIfPresent(voteCount, forKey: .voteCount)
        try c.encodeIfPresent(likesCount, forKey: .likesCount)
        try c.encodeIfPresent(myVote, forKey: .vote)
        try c.encodeIfPresent(replyCount, forKey: .replyCount)
        try c.encodeIfPresent(parentCommentId, forKey: .parentCommentId)
        try c.encodeIfPresent(isReply, forKey: .isReply)
        try c.encodeIfPresent(profile, forKey: .profile)
    }
}

struct CommentAddRequest: Encodable, Sendable {
    let parentCommentId: Int64?
    let replyToProfileId: Int64?
    let message: String
    let spoiler: Bool
}

struct ReleaseCommentAddResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let comment: ReleaseComment?
}

struct ProfileNotification: Decodable, Identifiable, Hashable, Sendable {
    let id: Int64
    let timestamp: Int64?
    let type: String?
    let message: String?
    let isNew: Bool?
    let release: Release?
    let byProfile: Profile?

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, type, message, isNew, release, byProfile
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        timestamp = try c.decodeIfPresent(Int64.self, forKey: .timestamp)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        isNew = try c.decodeIfPresent(Bool.self, forKey: .isNew)
        release = try c.decodeObjectOrIgnoreRefIfPresent(Release.self, forKey: .release)
        byProfile = try c.decodeObjectOrIgnoreRefIfPresent(Profile.self, forKey: .byProfile)
    }
}

struct NotificationCountResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let count: Int64?
}

struct ReportReason: Decodable, Identifiable, Hashable, Sendable {
    let id: Int64
    let name: String?
}

struct ReportReasonsResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let content: [ReportReason]?
    let reasons: [ReportReason]?
}

struct ReportRequest: Encodable, Sendable {
    let reason: Int64
    let message: String
}

struct ReleaseStreamingPlatform: Decodable, Identifiable, Hashable, Sendable {
    let id: Int64
    let name: String?
    let icon: String?
    let url: String?

    var iconURL: URL? {
        guard let icon, !icon.isEmpty else { return nil }
        return URL(string: icon.replacingOccurrences(of: "http://", with: "https://"))
    }

    var targetURL: URL? {
        guard let url, !url.isEmpty else { return nil }
        return URL(string: url)
    }
}

struct ReleaseVideoHosting: Codable, Hashable, Sendable {
    let id: Int64?
    let name: String?
    let icon: String?

    var iconURL: URL? {
        guard let icon, !icon.isEmpty else { return nil }
        return URL(string: icon.replacingOccurrences(of: "http://", with: "https://"))
    }
}

struct ReleaseVideoCategory: Codable, Hashable, Sendable {
    let id: Int64?
    let name: String?
}

struct ReleaseVideoItem: Decodable, Identifiable, Hashable, Sendable {
    let id: Int64
    let title: String?
    let image: String?
    let url: String?
    let playerUrl: String?
    let timestamp: Int64?
    let favoritesCount: Int?
    let isFavorite: Bool?
    let hosting: ReleaseVideoHosting?
    let category: ReleaseVideoCategory?
    let profile: Profile?

    private enum CodingKeys: String, CodingKey {
        case id, title, image, url, playerUrl, timestamp, favoritesCount, isFavorite, hosting, category, profile
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        image = try c.decodeIfPresent(String.self, forKey: .image)
        url = try c.decodeIfPresent(String.self, forKey: .url)
        playerUrl = try c.decodeIfPresent(String.self, forKey: .playerUrl)
        timestamp = try c.decodeIfPresent(Int64.self, forKey: .timestamp)
        favoritesCount = try c.decodeIfPresent(Int.self, forKey: .favoritesCount)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite)
        hosting = try c.decodeObjectOrIgnoreRefIfPresent(ReleaseVideoHosting.self, forKey: .hosting)
        category = try c.decodeObjectOrIgnoreRefIfPresent(ReleaseVideoCategory.self, forKey: .category)
        profile = try c.decodeObjectOrIgnoreRefIfPresent(Profile.self, forKey: .profile)
    }

    var thumbnailURL: URL? {
        guard let image, !image.isEmpty else { return nil }
        return URL(string: image.replacingOccurrences(of: "http://", with: "https://"))
    }

    var playableURL: URL? {
        let raw = (playerUrl?.isEmpty == false ? playerUrl : url) ?? ""
        guard !raw.isEmpty else { return nil }
        return URL(string: raw.replacingOccurrences(of: "http://", with: "https://"))
    }
}

struct ReleaseVideoBlock: Decodable, Identifiable, Hashable, Sendable {
    let category: ReleaseVideoCategory?
    let videos: [ReleaseVideoItem]?

    var id: Int64 {
        category?.id ?? Int64((category?.name ?? "").hashValue)
    }
}

struct ReleaseVideosResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let blocks: [ReleaseVideoBlock]?
    let streamingPlatforms: [ReleaseStreamingPlatform]?
    let lastVideos: [ReleaseVideoItem]?
    let canAppeal: Bool?
}

struct EpisodeUpdateItem: Decodable, Identifiable, Hashable, Sendable {
    let lastEpisodeUpdateDate: Int64?
    let lastEpisodeUpdateName: String?
    let lastEpisodeSourceUpdateId: Int64?
    let lastEpisodeSourceUpdateName: String?
    let lastEpisodeTypeUpdateId: Int64?
    let lastEpisodeTypeUpdateName: String?

    var id: String {
        "\(lastEpisodeUpdateDate ?? 0)-\(lastEpisodeUpdateName ?? "")-\(lastEpisodeTypeUpdateId ?? 0)-\(lastEpisodeSourceUpdateId ?? 0)"
    }
}
