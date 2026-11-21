import SwiftUI

struct ReleasePosterCard: View {
    let release: Release

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: release.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Color.secondary.opacity(0.2)
                        .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
                default:
                    Color.secondary.opacity(0.15)
                }
            }
            .frame(width: 136, height: 196)
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

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: release.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Color.secondary.opacity(0.2)
                }
            }
            .frame(width: 72, height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 5) {
                Text(release.displayTitle)
                    .font(.headline)
                    .lineLimit(2)

                if let genres = release.genres, !genres.isEmpty {
                    Text(genres)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 10) {
                    if let year = release.year, !year.isEmpty {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let ep = release.episodeText {
                        Text(ep)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let grade = release.grade, grade > 0 {
                        Label(grade.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
