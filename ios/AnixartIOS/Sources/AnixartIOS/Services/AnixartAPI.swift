import Foundation

struct AnixartAPI: Sendable {
    let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    // MARK: - Config

    func configURLs(
        versionCode: Int = APIConfiguration.appVersionCode,
        isBeta: Bool = APIConfiguration.isBeta
    ) async throws -> ConfigURLsResponse {
        try await client.request(
            "config/urls",
            query: [
                "version_code": String(versionCode),
                "is_beta": String(isBeta)
            ],
            validateStatus: false
        )
    }

    func toggles(
        versionCode: Int = APIConfiguration.appVersionCode,
        isBeta: Bool = APIConfiguration.isBeta,
        shouldUseMirrorURLs: Bool = APIConfiguration.shouldUseMirrorURLs
    ) async throws -> TogglesResponse {
        try await client.request(
            "config/toggles",
            query: [
                "version_code": String(versionCode),
                "is_beta": String(isBeta),
                "is_api_alt": String(shouldUseMirrorURLs)
            ]
        )
    }

    // MARK: - Auth

    func signIn(login: String, password: String) async throws -> SignInResponse {
        try await client.request(
            "auth/signIn",
            method: .post,
            form: ["login": login, "password": password],
            includeToken: false
        )
    }

    func checkLogin(_ login: String) async throws -> CheckLoginResponse {
        try await client.request(
            "auth/checkLogin",
            method: .post,
            form: ["login": login],
            includeToken: false
        )
    }

    func signUp(login: String, email: String, password: String) async throws -> SignUpResponse {
        try await client.request(
            "auth/signUp",
            method: .post,
            form: ["login": login, "email": email, "password": password],
            headers: ["X-Long-Code": "1"],
            includeToken: false
        )
    }

    func verifyRegistration(
        login: String,
        email: String,
        password: String,
        hash: String,
        code: String,
        vkAccessToken: String? = nil,
        googleIdToken: String? = nil,
        telegramIdToken: String? = nil,
        yandexAccessToken: String? = nil
    ) async throws -> VerifyResponse {
        try await client.request(
            "auth/verify",
            method: .post,
            form: [
                "login": login,
                "email": email,
                "password": password,
                "vkAccessToken": vkAccessToken,
                "googleIdToken": googleIdToken,
                "telegramIdToken": telegramIdToken,
                "yandexAccessToken": yandexAccessToken,
                "hash": hash,
                "code": code
            ],
            includeToken: false
        )
    }

    func resendVerification(
        login: String,
        email: String,
        password: String,
        hash: String,
        vkAccessToken: String? = nil,
        googleIdToken: String? = nil,
        telegramIdToken: String? = nil,
        yandexAccessToken: String? = nil
    ) async throws -> ResendResponse {
        try await client.request(
            "auth/resend",
            method: .post,
            form: [
                "login": login,
                "email": email,
                "password": password,
                "vkAccessToken": vkAccessToken,
                "googleIdToken": googleIdToken,
                "telegramIdToken": telegramIdToken,
                "yandexAccessToken": yandexAccessToken,
                "hash": hash
            ],
            headers: ["X-Long-Code": "1"],
            includeToken: false
        )
    }

    func restorePassword(data: String) async throws -> RestoreResponse {
        try await client.request(
            "auth/restore",
            method: .post,
            form: ["data": data],
            headers: ["X-Long-Code": "1"],
            includeToken: false
        )
    }

    func restoreVerify(data: String, newPassword: String, hash: String, code: String) async throws -> RestoreVerifyResponse {
        try await client.request(
            "auth/restore/verify",
            method: .post,
            form: [
                "data": data,
                "password": newPassword,
                "hash": hash,
                "code": code
            ],
            includeToken: false
        )
    }

    func signInWithProvider(_ provider: AuthProvider, token: String) async throws -> OAuthSignInResponse {
        switch provider {
        case .vk:
            return try await client.request("auth/vk", method: .post, form: ["vkAccessToken": token], includeToken: false)
        case .google:
            return try await client.request("auth/google", method: .post, form: ["googleIdToken": token], includeToken: false)
        case .telegram:
            return try await client.request("auth/telegram", method: .post, form: ["telegramIdToken": token], includeToken: false)
        case .yandex:
            return try await client.request("auth/yandex", method: .post, form: ["yandexAccessToken": token], includeToken: false)
        }
    }

    func signUpWithProvider(_ provider: AuthProvider, login: String, email: String, token: String) async throws -> OAuthSignInResponse {
        let headers = ["X-Long-Code": "1"]
        switch provider {
        case .vk:
            return try await client.request("auth/vk", method: .post, form: ["login": login, "email": email, "vkAccessToken": token], headers: headers, includeToken: false)
        case .google:
            return try await client.request("auth/google", method: .post, form: ["login": login, "email": email, "googleIdToken": token], headers: headers, includeToken: false)
        case .telegram:
            return try await client.request("auth/telegram", method: .post, form: ["login": login, "email": email, "telegramIdToken": token], headers: headers, includeToken: false)
        case .yandex:
            return try await client.request("auth/yandex", method: .post, form: ["login": login, "email": email, "yandexAccessToken": token], headers: headers, includeToken: false)
        }
    }

    // MARK: - Discover & Schedule

    func watching(page: Int = 0) async throws -> PageableResponse<Release> {
        try await client.request("discover/watching/\(page)", method: .post)
    }

    func recommendations(page: Int = 0, previousPage: Int = -1) async throws -> PageableResponse<Release> {
        try await client.request(
            "discover/recommendations/\(page)",
            method: .post,
            query: ["previous_page": String(previousPage)]
        )
    }

    func discussing() async throws -> PageableResponse<Release> {
        try await client.request("discover/discussing", method: .post)
    }

    func interesting() async throws -> PageableResponse<InterestingItem> {
        try await client.request("discover/interesting", method: .post, includeToken: false)
    }

    func schedule() async throws -> ScheduleResponse {
        try await client.request("schedule", includeToken: false)
    }

    // MARK: - Releases

    func release(id: Int64, extendedMode: Bool = true) async throws -> Release {
        let response: ReleaseResponse = try await client.request(
            "release/\(id)",
            query: ["extended_mode": String(extendedMode)]
        )
        guard let release = response.release else { throw APIError.unexpectedResponse }
        return release
    }

    func randomRelease(extendedMode: Bool = true) async throws -> Release {
        let response: ReleaseResponse = try await client.request(
            "release/random",
            query: ["extended_mode": String(extendedMode)]
        )
        guard let release = response.release else { throw APIError.unexpectedResponse }
        return release
    }

    func related(relatedId: Int64, page: Int = 0) async throws -> PageableResponse<Release> {
        try await client.request(
            "related/\(relatedId)/\(page)",
            headers: ["API-Version": "1"]
        )
    }

    func voteRelease(id: Int64, vote: Int) async throws -> BaseResponse {
        try await client.request("release/vote/add/\(id)/\(vote)")
    }

    func deleteVoteRelease(id: Int64) async throws -> BaseResponse {
        try await client.request("release/vote/delete/\(id)")
    }

    func releaseVideos(releaseId: Int64) async throws -> ReleaseVideosResponse {
        try await client.request("video/release/\(releaseId)")
    }

    func releaseStreamingPlatforms(releaseId: Int64) async throws -> PageableResponse<ReleaseStreamingPlatform> {
        try await client.request("release/streaming/platform/\(releaseId)", includeToken: false)
    }

    func reportReasons() async throws -> [ReportReason] {
        let resp: ReportReasonsResponse = try await client.request("report/reasons/release")
        return resp.content ?? resp.reasons ?? []
    }

    func reportRelease(releaseId: Int64, reasonId: Int64, message: String) async throws -> BaseResponse {
        try await client.request(
            "report/release/\(releaseId)",
            method: .post,
            body: ReportRequest(reason: reasonId, message: message)
        )
    }

    // MARK: - Search & Filter

    func searchReleases(query: String, page: Int = 0, searchBy: Int = 0) async throws -> [Release] {
        let response: ReleaseSearchResponse = try await client.request(
            "search/releases/\(page)",
            method: .post,
            body: SearchRequest(query: query, searchBy: searchBy),
            headers: ["API-Version": "1"]
        )
        return response.releases ?? response.content ?? []
    }

    func searchCollections(query: String, page: Int = 0) async throws -> PageableResponse<CollectionItem> {
        try await client.request(
            "search/collections/\(page)",
            method: .post,
            body: SearchRequest(query: query)
        )
    }

    func searchProfiles(query: String, page: Int = 0) async throws -> PageableResponse<Profile> {
        try await client.request(
            "search/profiles/\(page)",
            method: .post,
            body: SearchRequest(query: query)
        )
    }

    func filterReleases(page: Int = 0, filter: FilterRequest, extendedMode: Bool = true) async throws -> PageableResponse<Release> {
        try await client.request(
            "filter/\(page)",
            method: .post,
            query: ["extended_mode": String(extendedMode)],
            body: filter
        )
    }

    // MARK: - Episodes & History

    func episodeTypes(releaseId: Int64) async throws -> [VoiceoverType] {
        let resp: TypesResponse = try await client.request("episode/\(releaseId)")
        return resp.types ?? []
    }

    func episodeSources(releaseId: Int64, typeId: Int64) async throws -> [VideoSource] {
        let resp: SourcesResponse = try await client.request("episode/\(releaseId)/\(typeId)", includeToken: false)
        return resp.sources ?? []
    }

    func episodes(releaseId: Int64, typeId: Int64, sourceId: Int64, sort: Int = 0) async throws -> [Episode] {
        let resp: EpisodeResponse = try await client.request(
            "episode/\(releaseId)/\(typeId)/\(sourceId)",
            query: ["sort": String(sort)]
        )
        return resp.episodes ?? []
    }

    func episodeUpdates(releaseId: Int64, page: Int = 0) async throws -> PageableResponse<EpisodeUpdateItem> {
        try await client.request("episode/updates/\(releaseId)/\(page)", includeToken: false)
    }

    func markEpisodeWatched(releaseId: Int64, sourceId: Int64, position: Int) async throws -> BaseResponse {
        try await client.request("episode/watch/\(releaseId)/\(sourceId)/\(position)", method: .post)
    }

    func markEpisodeUnwatched(releaseId: Int64, sourceId: Int64, position: Int) async throws -> BaseResponse {
        try await client.request("episode/unwatch/\(releaseId)/\(sourceId)/\(position)", method: .post)
    }

    func addToHistory(releaseId: Int64, sourceId: Int64, position: Int) async throws -> BaseResponse {
        try await client.request("history/add/\(releaseId)/\(sourceId)/\(position)")
    }

    func history(page: Int = 0) async throws -> PageableResponse<Release> {
        try await client.request("history/\(page)")
    }

    func deleteFromHistory(releaseId: Int64) async throws -> BaseResponse {
        try await client.request("history/delete/\(releaseId)")
    }

    // MARK: - Bookmarks, Favorites & Collections

    func favorites(page: Int = 0, sort: Int? = nil) async throws -> PageableResponse<Release> {
        var query: [String: String] = [:]
        if let sort { query["sort"] = String(sort) }
        return try await client.request("favorite/all/\(page)", query: query)
    }

    func addFavorite(releaseId: Int64) async throws -> BaseResponse {
        try await client.request("favorite/add/\(releaseId)")
    }

    func deleteFavorite(releaseId: Int64) async throws -> BaseResponse {
        try await client.request("favorite/delete/\(releaseId)")
    }

    func profileList(status: BookmarkStatus, page: Int = 0, sort: Int? = nil) async throws -> PageableResponse<Release> {
        var query: [String: String] = [:]
        if let sort { query["sort"] = String(sort) }
        return try await client.request("profile/list/all/\(status.rawValue)/\(page)", query: query)
    }

    func addToProfileList(status: BookmarkStatus, releaseId: Int64) async throws -> BaseResponse {
        try await client.request("profile/list/add/\(status.rawValue)/\(releaseId)")
    }

    func deleteFromProfileList(status: BookmarkStatus, releaseId: Int64) async throws -> BaseResponse {
        try await client.request("profile/list/delete/\(status.rawValue)/\(releaseId)")
    }

    func collections(page: Int = 0, previousPage: Int = -1, whereValue: Int = 1, sort: Int = 0) async throws -> PageableResponse<CollectionItem> {
        try await client.request(
            "collection/all/\(page)",
            query: [
                "previous_page": String(previousPage),
                "where": String(whereValue),
                "sort": String(sort)
            ]
        )
    }

    func collectionDetail(id: Int64) async throws -> CollectionResponse {
        try await client.request("collection/\(id)")
    }

    func collectionReleases(id: Int64, page: Int = 0) async throws -> PageableResponse<Release> {
        try await client.request("collection/\(id)/releases/\(page)")
    }

    func favoriteCollections(page: Int = 0) async throws -> PageableResponse<CollectionItem> {
        try await client.request("collectionFavorite/all/\(page)")
    }

    func releaseCollections(releaseId: Int64, page: Int = 0) async throws -> PageableResponse<CollectionItem> {
        try await client.request("collection/all/release/\(releaseId)/\(page)")
    }

    func myCollectionsForRelease(releaseId: Int64, page: Int = 0) async throws -> PageableResponse<CollectionItem> {
        try await client.request("collectionMy/release/\(releaseId)/\(page)")
    }

    func myCollections(page: Int = 0) async throws -> PageableResponse<CollectionItem> {
        try await client.request("collectionMy/all/\(page)")
    }

    func addReleaseToCollection(collectionId: Int64, releaseId: Int64) async throws -> BaseResponse {
        try await client.request("collectionMy/release/add/\(collectionId)/\(releaseId)")
    }

    func removeReleaseFromCollection(collectionId: Int64, releaseId: Int64) async throws -> BaseResponse {
        try await client.request("collectionMy/release/delete/\(collectionId)/\(releaseId)")
    }

    // MARK: - Comments

    func releaseComments(releaseId: Int64, page: Int = 0, sort: Int = 1) async throws -> PageableResponse<ReleaseComment> {
        try await client.request(
            "release/comment/all/\(releaseId)/\(page)",
            query: ["sort": String(sort)]
        )
    }

    func releaseCommentReplies(commentId: Int64, page: Int = 0) async throws -> PageableResponse<ReleaseComment> {
        try await client.request("release/comment/replies/\(commentId)/\(page)")
    }

    func addReleaseComment(releaseId: Int64, message: String, spoiler: Bool = false, parentCommentId: Int64? = nil, replyToProfileId: Int64? = nil) async throws -> ReleaseCommentAddResponse {
        try await client.request(
            "release/comment/add/\(releaseId)",
            method: .post,
            body: CommentAddRequest(
                parentCommentId: parentCommentId,
                replyToProfileId: replyToProfileId,
                message: message,
                spoiler: spoiler
            )
        )
    }

    func voteReleaseComment(commentId: Int64, vote: Int) async throws -> BaseResponse {
        try await client.request("release/comment/vote/\(commentId)/\(vote)")
    }

    func deleteReleaseComment(commentId: Int64) async throws -> BaseResponse {
        try await client.request("release/comment/delete/\(commentId)")
    }

    // MARK: - Profile & Notifications

    func profileInfo() async throws -> ProfileInfoResponse {
        try await client.request("profile/info")
    }

    func profile(id: Int64) async throws -> ProfileResponse {
        try await client.request("profile/\(id)")
    }

    func profileSocial(id: Int64) async throws -> ProfileSocialResponse {
        try await client.request("profile/social/\(id)")
    }

    func profilePreferences() async throws -> ProfilePreferenceResponse {
        try await client.request("profile/preference/my")
    }

    func friends(profileId: Int64, page: Int = 0) async throws -> PageableResponse<Profile> {
        try await client.request("profile/friend/all/\(profileId)/\(page)")
    }

    func notifications(page: Int = 0) async throws -> PageableResponse<ProfileNotification> {
        try await client.request("notification/all/\(page)")
    }

    func notificationCount() async throws -> NotificationCountResponse {
        try await client.request("notification/count")
    }

    func markNotificationsRead() async throws -> BaseResponse {
        try await client.request("notification/read")
    }
}
