import SwiftUI

enum CommentSortOrder: Int, CaseIterable, Identifiable {
    case newest = 1
    case oldest = 2
    case popular = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .newest: return "Сначала новые"
        case .oldest: return "Сначала старые"
        case .popular: return "Популярные"
        }
    }
}

struct ReleaseCommentRow: View {
    let comment: ReleaseComment
    let isOwnComment: Bool
    let onReply: () -> Void
    let onVote: (Int) -> Void
    let onDelete: () -> Void

    @State private var revealSpoiler = false

    private var score: Int {
        comment.voteCount ?? 0
    }

    private var scoreColor: Color {
        if score > 0 { return BookmarkStatus.watching.color }
        if score < 0 { return AnixartFormat.accentRed }
        return .secondary
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Color.secondary.opacity(0.18)
                .frame(width: 36, height: 36)
                .overlay {
                    AsyncImage(url: comment.profile?.avatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: "person.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .clipped()
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(comment.profile?.displayName ?? "Пользователь")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let badgeURL = comment.profile?.badgeImageURL {
                        AsyncImage(url: badgeURL) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFit()
                            }
                        }
                        .frame(width: 16, height: 16)
                    }

                    if let ts = comment.timestamp, ts > 0 {
                        Text(AnixartFormat.commentDate(timestamp: ts))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if comment.isEdited == true {
                        Image(systemName: "pencil")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isOwnComment {
                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if comment.isDeleted == true {
                    Text("Комментарий удалён")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .italic()
                } else if comment.isSpoiler == true && !revealSpoiler {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            revealSpoiler = true
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text("Комментарий может содержать спойлер.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Нажмите, чтобы прочитать")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(Color.secondary.opacity(0.11))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(comment.message ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Button("Ответить", action: onReply)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)

                    Spacer()

                    HStack(spacing: 14) {
                        Button {
                            onVote(1)
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(comment.myVote == 1 || comment.myVote == -1 ? AnixartFormat.accentRed : .secondary)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Text("\(score)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(scoreColor)
                            .monospacedDigit()

                        Button {
                            onVote(2)
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(comment.myVote == 2 ? BookmarkStatus.watching.color : .secondary)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
    }
}

struct CommentComposerBar: View {
    @Binding var text: String
    @Binding var isSpoiler: Bool
    let replyingTo: ReleaseComment?
    let isSending: Bool
    let onCancelReply: () -> Void
    let onShowRules: () -> Void
    let onSend: () -> Void

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let replyingTo {
                HStack(spacing: 6) {
                    Text("Ответ для \(replyingTo.profile?.displayName ?? "пользователя")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: onCancelReply) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("Ваш комментарий", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .font(.body)

            HStack(spacing: 8) {
                Button {
                    isSpoiler.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSpoiler ? "eye.slash.fill" : "eye.slash")
                        Text("Спойлер")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSpoiler ? AnixartFormat.accentRed : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(isSpoiler ? AnixartFormat.accentRed.opacity(0.14) : Color(.systemBackground))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(isSpoiler ? AnixartFormat.accentRed : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button(action: onShowRules) {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                        Text("Правила")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(.systemBackground))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onSend) {
                    Group {
                        if isSending {
                            ProgressView()
                                .tint(.white)
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.subheadline.weight(.bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(canSend ? AnixartFormat.accentRed : Color.secondary.opacity(0.35))
                    .clipShape(Circle())
                }
                .disabled(!canSend)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
    }
}

@MainActor
struct ReleaseCommentsView: View {
    @ObservedObject private var session = SessionStore.shared

    let release: Release
    let initialTotalCount: Int

    @State private var comments: [ReleaseComment] = []
    @State private var totalCount: Int = 0
    @State private var sortOrder: CommentSortOrder = .newest
    @State private var page = 0
    @State private var hasMore = false
    @State private var isLoading = false
    @State private var newCommentText = ""
    @State private var isSpoiler = false
    @State private var replyingTo: ReleaseComment?
    @State private var isSending = false
    @State private var showRules = false
    @State private var alertMessage: String?

    private let api = AnixartAPI()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                Divider()

                HStack {
                    Text("\(totalCount) всего")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Menu {
                        ForEach(CommentSortOrder.allCases) { option in
                            Button {
                                guard sortOrder != option else { return }
                                sortOrder = option
                            } label: {
                                HStack {
                                    Text(option.title)
                                    if sortOrder == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease")
                            Text(sortOrder.title)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

                if isLoading && comments.isEmpty {
                    ProgressView("Загрузка комментариев...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if comments.isEmpty {
                    ContentUnavailableView("Комментариев пока нет", systemImage: "bubble.left.and.bubble.right")
                        .padding(.top, 50)
                } else {
                    ForEach(Array(comments.enumerated()), id: \.element.id) { idx, comment in
                        ReleaseCommentRow(
                            comment: comment,
                            isOwnComment: comment.profile?.id == session.currentProfile?.id,
                            onReply: { replyingTo = comment },
                            onVote: { vote in Task { await voteComment(comment, vote: vote) } },
                            onDelete: { Task { await deleteComment(comment) } }
                        )
                        .padding(.horizontal, 16)
                        .onAppear {
                            if idx >= comments.count - 4, hasMore, !isLoading {
                                Task { await load(page: page + 1, append: true) }
                            }
                        }
                    }

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
            }
            .padding(.bottom, 16)
        }
        .navigationTitle("Комментарии")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                CommentComposerBar(
                    text: $newCommentText,
                    isSpoiler: $isSpoiler,
                    replyingTo: replyingTo,
                    isSending: isSending,
                    onCancelReply: { replyingTo = nil },
                    onShowRules: { showRules = true },
                    onSend: { Task { await submitComment() } }
                )
            }
        }
        .task(id: sortOrder) {
            await load(page: 0, append: false)
        }
        .alert("Правила комментариев", isPresented: $showRules) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Уважайте других участников, не оскорбляйте пользователей и скрывайте сюжетные повороты под тегом «Спойлер».")
        }
        .alert("Сообщение", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func load(page targetPage: Int, append: Bool) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await api.releaseComments(releaseId: release.id, page: targetPage, sort: sortOrder.rawValue)
            if append {
                var seen = Set(comments.map(\.id))
                let unique = resp.content.filter { seen.insert($0.id).inserted }
                comments.append(contentsOf: unique)
            } else {
                comments = resp.content
            }
            if let total = resp.totalCount {
                totalCount = Int(total)
            } else if totalCount == 0 {
                totalCount = max(initialTotalCount, comments.count)
            }
            page = targetPage
            let totalPages = resp.totalPageCount ?? 1
            hasMore = (targetPage + 1) < totalPages
        } catch {
            if !append {
                alertMessage = error.localizedDescription
            }
        }
    }

    private func submitComment() async {
        guard session.isAuthenticated else {
            alertMessage = "Войдите в аккаунт, чтобы оставлять комментарии."
            return
        }
        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true
        defer { isSending = false }
        do {
            let resp = try await api.addReleaseComment(
                releaseId: release.id,
                message: trimmed,
                spoiler: isSpoiler,
                parentCommentId: replyingTo?.id,
                replyToProfileId: replyingTo?.profile?.id
            )
            newCommentText = ""
            isSpoiler = false
            replyingTo = nil
            if let comment = resp.comment, sortOrder == .newest {
                comments.insert(comment, at: 0)
                totalCount += 1
            } else {
                await load(page: 0, append: false)
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func voteComment(_ comment: ReleaseComment, vote: Int) async {
        guard session.isAuthenticated else {
            alertMessage = "Войдите в аккаунт, чтобы оценивать комментарии."
            return
        }
        do {
            _ = try await api.voteReleaseComment(commentId: comment.id, vote: vote)
            await load(page: 0, append: false)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func deleteComment(_ comment: ReleaseComment) async {
        guard session.isAuthenticated else { return }
        do {
            _ = try await api.deleteReleaseComment(commentId: comment.id)
            comments.removeAll { $0.id == comment.id }
            totalCount = max(0, totalCount - 1)
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
