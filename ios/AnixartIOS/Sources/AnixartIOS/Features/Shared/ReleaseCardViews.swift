import SwiftUI

extension BookmarkStatus {
    var color: Color {
        switch self {
        case .watching:
            return Color(red: 0.40, green: 0.73, blue: 0.42) // #66BB6A
        case .planned:
            return Color(red: 0.73, green: 0.41, blue: 0.78) // #BA68C8
        case .completed:
            return Color(red: 0.36, green: 0.42, blue: 0.75) // #5C6BC0
        case .onHold:
            return Color(red: 0.98, green: 0.80, blue: 0.28) // #FCCB47
        case .dropped:
            return Color(red: 1.00, green: 0.32, blue: 0.32) // #FF5252
        }
    }

    var pillForegroundColor: Color {
        switch self {
        case .onHold:
            return Color(red: 0.75, green: 0.56, blue: 0.05)
        default:
            return color
        }
    }
}

enum AnixartFormat {
    static let accentRed = Color(red: 0.94, green: 0.27, blue: 0.36)

    static func spaced(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func compactViews(_ value: Int64) -> String {
        if value >= 1_000_000 {
            let m = Double(value) / 1_000_000.0
            return m >= 10 ? "\(Int(m))M" : String(format: "%.1fM", m).replacingOccurrences(of: ".0", with: "")
        }
        if value >= 1_000 {
            let k = Double(value) / 1_000.0
            return k >= 10 ? "\(Int(k))K" : String(format: "%.1fK", k).replacingOccurrences(of: ".0", with: "")
        }
        return "\(value)"
    }

    static func pluralEpisodes(_ count: Int) -> String {
        let mod100 = abs(count) % 100
        let mod10 = abs(count) % 10
        if mod100 >= 11 && mod100 <= 14 { return "\(count) эпизодов" }
        switch mod10 {
        case 1: return "\(count) эпизод"
        case 2, 3, 4: return "\(count) эпизода"
        default: return "\(count) эпизодов"
        }
    }

    static func pluralVotes(_ count: Int) -> String {
        let mod100 = abs(count) % 100
        let mod10 = abs(count) % 10
        let word: String
        if mod100 >= 11 && mod100 <= 14 {
            word = "голосов"
        } else {
            switch mod10 {
            case 1: word = "голос"
            case 2, 3, 4: word = "голоса"
            default: word = "голосов"
            }
        }
        return "\(spaced(count)) \(word)"
    }

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM yyyy 'в' HH:mm"
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM 'в' HH:mm"
        return f
    }()

    static func fullDateTime(timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return dateTimeFormatter.string(from: date)
    }

    static func commentDate(timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let cal = Calendar.current
        if cal.component(.year, from: date) == cal.component(.year, from: Date()) {
            return shortDateFormatter.string(from: date)
        }
        return dateTimeFormatter.string(from: date)
    }
}

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

    private var bookmarkStatus: BookmarkStatus? {
        guard let raw = release.profileListStatus else { return nil }
        return BookmarkStatus(rawValue: raw)
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
                    if let bookmarkStatus {
                        Text(bookmarkStatus.title.lowercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(bookmarkStatus == .onHold ? .black.opacity(0.85) : .white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                            .background(bookmarkStatus.color.opacity(0.88))
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
