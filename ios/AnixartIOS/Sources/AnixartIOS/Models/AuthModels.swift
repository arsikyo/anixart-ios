import Foundation

struct ProfileToken: Codable, Sendable {
    let id: Int64
    let token: String
}

struct SignInResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let profile: Profile?
    let profileToken: ProfileToken?
}

struct CheckLoginResponse: Decodable, APIStatus, Sendable {
    let code: Int
}

struct SignUpResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let hash: String?
    let codeTimestampExpires: Int64?
    let codeTimeLeft: Int64?
    let codeLength: Int?
    let suggestedLogins: [String]?
}

struct VerifyResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let profile: Profile?
    let profileToken: ProfileToken?
    let suggestedLogins: [String]?
}

struct ResendResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let hash: String?
    let codeTimestampExpires: Int64?
    let codeTimeLeft: Int64?
    let codeLength: Int?
}

struct RestoreResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let hash: String?
    let codeTimestampExpires: Int64?
    let codeTimeLeft: Int64?
    let codeLength: Int?
}

struct RestoreVerifyResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let profile: Profile?
    let profileToken: ProfileToken?
    let attemptsLeft: Int?
}

struct RestoreResendResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let hash: String?
    let codeTimestampExpires: Int64?
    let codeTimeLeft: Int64?
    let codeLength: Int?
}

struct OAuthSignInResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let profile: Profile?
    let profileToken: ProfileToken?
    let hash: String?
    let email: String?
    let codeTimestampExpires: Int64?
    let codeTimeLeft: Int64?
    let codeLength: Int?
    let suggestedLogins: [String]?
}

enum AuthProvider: String, CaseIterable, Identifiable, Sendable {
    case vk
    case telegram
    case yandex
    case google

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vk: return "VK ID"
        case .telegram: return "Telegram"
        case .yandex: return "Яндекс ID"
        case .google: return "Google"
        }
    }

    var systemImage: String {
        switch self {
        case .vk: return "person.crop.circle.badge.checkmark"
        case .telegram: return "paperplane.fill"
        case .yandex: return "y.circle.fill"
        case .google: return "g.circle.fill"
        }
    }
}
