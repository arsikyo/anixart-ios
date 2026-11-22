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
    let myVote: Int?
    let replyCount: Int?
    let profile: Profile?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        timestamp = try c.decodeIfPresent(Int64.self, forKey: .timestamp)
        isSpoiler = try c.decodeIfPresent(Bool.self, forKey: .isSpoiler)
        isEdited = try c.decodeIfPresent(Bool.self, forKey: .isEdited)
        isDeleted = try c.decodeIfPresent(Bool.self, forKey: .isDeleted)
        voteCount = try c.decodeIfPresent(Int.self, forKey: .voteCount)
        myVote = try c.decodeIfPresent(Int.self, forKey: .myVote)
        replyCount = try c.decodeIfPresent(Int.self, forKey: .replyCount)
        profile = try c.decodeObjectOrIgnoreRefIfPresent(Profile.self, forKey: .profile)
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
