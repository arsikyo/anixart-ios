import SwiftUI

private enum DiscoverSection: String, CaseIterable, Identifiable {
    case schedule = "Расписание"
    case collections = "Коллекции"
    case history = "История"
    var id: String { rawValue }
}

private enum WeekdayTab: Int, CaseIterable, Identifiable {
    case monday = 0, tuesday, wednesday, thursday, friday, saturday, sunday
    var id: Int { rawValue }

    var shortTitle: String {
        switch self {
        case .monday: return "Пн"
        case .tuesday: return "Вт"
        case .wednesday: return "Ср"
        case .thursday: return "Чт"
        case .friday: return "Пт"
        case .saturday: return "Сб"
        case .sunday: return "Вс"
        }
    }
}

struct DiscoverView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var section: DiscoverSection = .schedule
    @State private var selectedDay: WeekdayTab = .monday
    @State private var schedule: ScheduleResponse?
    @State private var collections: [CollectionItem] = []
    @State private var history: [Release] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = AnixartAPI()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Раздел", selection: $section) {
                    ForEach(DiscoverSection.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch section {
                case .schedule:
                    scheduleContent
                case .collections:
                    collectionsContent
                case .history:
                    historyContent
                }
            }
            .navigationTitle("Обзор")
            .navigationDestination(for: Release.self) { ReleaseDetailView(release: $0) }
            .navigationDestination(for: CollectionItem.self) { CollectionDetailView(collection: $0) }
            .task(id: section) {
                await loadCurrentSection()
            }
            .alert("Ошибка", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var scheduleContent: some View {
        VStack(spacing: 0) {
            Picker("День недели", selection: $selectedDay) {
                ForEach(WeekdayTab.allCases) { day in
                    Text(day.shortTitle).tag(day)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            let items = releases(for: selectedDay)
            List(items) { release in
                NavigationLink(value: release) {
                    ReleaseRow(release: release)
                }
            }
            .listStyle(.plain)
            .overlay {
                if isLoading && schedule == nil {
                    ProgressView("Загрузка расписания...")
                } else if items.isEmpty {
                    ContentUnavailableView("Нет релизов в этот день", systemImage: "calendar")
                }
            }
            .refreshable {
                await loadSchedule()
            }
        }
    }

    private var collectionsContent: some View {
        List(collections) { col in
            NavigationLink(value: col) {
                HStack(spacing: 12) {
                    AsyncImage(url: col.imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Color.secondary.opacity(0.2)
                        }
                    }
                    .frame(width: 84, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(col.title ?? "Коллекция #\(col.id)")
                            .font(.headline)
                            .lineLimit(1)
                        if let desc = col.description, !desc.isEmpty {
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        if let count = col.releaseCount {
                            Text("Релизов: \(count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if isLoading && collections.isEmpty {
                ProgressView("Загрузка коллекций...")
            } else if collections.isEmpty {
                ContentUnavailableView("Коллекции не найдены", systemImage: "square.stack.3d.up")
            }
        }
        .refreshable {
            await loadCollections()
        }
    }

    private var historyContent: some View {
        Group {
            if !session.isAuthenticated {
                ContentUnavailableView(
                    "Требуется вход",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Войдите в аккаунт, чтобы видеть историю просмотра.")
                )
            } else {
                List {
                    ForEach(history) { release in
                        NavigationLink(value: release) {
                            ReleaseRow(release: release)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Удалить", role: .destructive) {
                                Task { await removeFromHistory(release) }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if isLoading && history.isEmpty {
                        ProgressView("Загрузка истории...")
                    } else if history.isEmpty {
                        ContentUnavailableView("История пуста", systemImage: "clock")
                    }
                }
                .refreshable {
                    await loadHistory()
                }
            }
        }
    }

    private func releases(for day: WeekdayTab) -> [Release] {
        guard let schedule else { return [] }
        switch day {
        case .monday: return schedule.monday ?? []
        case .tuesday: return schedule.tuesday ?? []
        case .wednesday: return schedule.wednesday ?? []
        case .thursday: return schedule.thursday ?? []
        case .friday: return schedule.friday ?? []
        case .saturday: return schedule.saturday ?? []
        case .sunday: return schedule.sunday ?? []
        }
    }

    private func loadCurrentSection() async {
        switch section {
        case .schedule:
            if schedule == nil { await loadSchedule() }
        case .collections:
            if collections.isEmpty { await loadCollections() }
        case .history:
            if session.isAuthenticated { await loadHistory() }
        }
    }

    private func loadSchedule() async {
        isLoading = true
        defer { isLoading = false }
        do {
            schedule = try await api.schedule()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadCollections() async {
        isLoading = true
        defer { isLoading = false }
        do {
            collections = try await api.collections(page: 0).content
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadHistory() async {
        isLoading = true
        defer { isLoading = false }
        do {
            history = try await api.history(page: 0).content
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeFromHistory(_ release: Release) async {
        do {
            _ = try await api.deleteFromHistory(releaseId: release.id)
            history.removeAll { $0.id == release.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CollectionDetailView: View {
    let collection: CollectionItem
    @State private var detail: CollectionResponse?
    @State private var releases: [Release] = []
    @State private var errorMessage: String?

    private let api = AnixartAPI()

    var body: some View {
        List {
            Section {
                if let desc = detail?.collection?.description ?? collection.description, !desc.isEmpty {
                    Text(desc).font(.subheadline)
                }
                if let creator = detail?.collection?.creator ?? collection.creator {
                    Text("Автор: \(creator.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Релизы") {
                ForEach(releases) { release in
                    NavigationLink(value: release) {
                        ReleaseRow(release: release)
                    }
                }
            }
        }
        .navigationTitle(collection.title ?? "Коллекция")
        .task {
            do {
                detail = try await api.collectionDetail(id: collection.id)
                releases = try await api.collectionReleases(id: collection.id, page: 0).content
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }
}
