import SwiftUI

struct ReleasePosterCard: View {
    let release: Release

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.secondary.opacity(0.15)
                .frame(width: 136, height: 196)
                .overlay {
                    AsyncImage(url: release.imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        default:
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topTrailing) {
                    if let grade = release.grade, grade > 0 {
                        Label(grade.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(6)
                    }
                }

            Text(release.displayTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .frame(width: 136, alignment: .leading)

            if let ep = release.episodeText {
                Text(ep)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ReleaseRow: View {
    let release: Release

    private var bookmarkBadge: String? {
        guard let raw = release.profileListStatus,
              let status = BookmarkStatus(rawValue: raw) else {
            return nil
        }
        return status.title.lowercased()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Color.secondary.opacity(0.16)
                .frame(width: 98, height: 138)
                .overlay {
                    AsyncImage(url: release.imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        default:
                            EmptyView()
                        }
                    }
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottom) {
                    if let bookmarkBadge {
                        Text(bookmarkBadge)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                            .background(Color.purple.opacity(0.75))
                            .clipShape(
                                UnevenRoundedRectangle(
                                    bottomLeadingRadius: 12,
                                    bottomTrailingRadius: 12
                                )
                            )
                    }
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(release.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 5) {
                    if let ep = release.compactEpisodeText {
                        Text(ep)
                    }

                    if !release.isAnnouncement, let grade = release.grade, grade > 0 {
                        if release.compactEpisodeText != nil {
                            Text("•")
                        }
                        HStack(spacing: 2) {
                            Text(grade.formatted(.number.precision(.fractionLength(1))))
                            Image(systemName: "star.fill")
                                .font(.caption2)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let datePill = release.announcementDateText {
                    Text(datePill)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                let desc = release.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                Text(desc.isEmpty ? "Описание не указано" : desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
