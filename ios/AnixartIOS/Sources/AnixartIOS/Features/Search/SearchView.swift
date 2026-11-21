import SwiftUI

private enum SearchScope: String, CaseIterable, Identifiable {
    case releases = "Релизы"
    case collections = "Коллекции"
    case profiles = "Профили"
    var id: String { rawValue }
}

struct SearchView: View {
    @State private var query = ""
    @State private var scope: SearchScope = .releases
    @State private var releases: [Release] = []
    @State private var collections: [CollectionItem] = []
    @State private var profiles: [Profile] = []
    @State private var filter = FilterRequest()
    @State private var showFilterSheet = false
    @State private var isFilteredMode = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = AnixartAPI()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Категория", selection: $scope) {
                    ForEach(SearchScope.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                List {
                    switch scope {
                    case .releases:
                        ForEach(releases) { release in
                            NavigationLink(value: release) {
                                ReleaseRow(release: release)
                            }
                        }
                    case .collections:
                        ForEach(collections) { col in
                            NavigationLink(value: col) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(col.title ?? "Коллекция #\(col.id)").font(.headline)
                                    if let desc = col.description, !desc.isEmpty {
                                        Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                }
                            }
                        }
                    case .profiles:
                        ForEach(profiles) { profile in
                            NavigationLink(value: profile) {
                                HStack(spacing: 12) {
                                    AsyncImage(url: profile.avatarURL) { phase in
                                        switch phase {
                                        case .success(let image): image.resizable().scaledToFill()
                                        default: Color.secondary.opacity(0.2)
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(profile.displayName).font(.headline)
                                        if let status = profile.status, !status.isEmpty {
                                            Text(status).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if isLoading {
                        ProgressView("Поиск...")
                    } else if isCurrentScopeEmpty {
                        ContentUnavailableView(
                            isFilteredMode ? "Ничего не найдено по фильтру" : "Введите запрос для поиска",
                            systemImage: "magnifyingglass"
                        )
                    }
                }
            }
            .navigationTitle("Поиск")
            .searchable(text: $query, prompt: "Название, коллекция или ник")
            .onSubmit(of: .search) {
                isFilteredMode = false
                Task { await performSearch() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilterSheet = true
                    } label: {
                        Label("Фильтр", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheetView(filter: $filter) {
                    scope = .releases
                    isFilteredMode = true
                    Task { await applyFilter() }
                }
            }
            .navigationDestination(for: Release.self) { ReleaseDetailView(release: $0) }
            .navigationDestination(for: CollectionItem.self) { CollectionDetailView(collection: $0) }
            .navigationDestination(for: Profile.self) { OtherProfileView(profileID: $0.id) }
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

    private var isCurrentScopeEmpty: Bool {
        switch scope {
        case .releases: return releases.isEmpty
        case .collections: return collections.isEmpty
        case .profiles: return profiles.isEmpty
        }
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            switch scope {
            case .releases:
                releases = try await api.searchReleases(query: trimmed, page: 0)
            case .collections:
                collections = try await api.searchCollections(query: trimmed, page: 0).content
            case .profiles:
                profiles = try await api.searchProfiles(query: trimmed, page: 0).content
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyFilter() async {
        isLoading = true
        defer { isLoading = false }
        do {
            releases = try await api.filterReleases(page: 0, filter: filter).content
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct FilterSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: FilterRequest
    let onApply: () -> Void

    @State private var startYearText = ""
    @State private var endYearText = ""
    @State private var genresText = ""
    @State private var studioText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Сортировка") {
                    Picker("Сортировать по", selection: Binding(
                        get: { filter.sort ?? 0 },
                        set: { filter.sort = $0 }
                    )) {
                        Text("По дате обновления").tag(0)
                        Text("По рейтингу").tag(1)
                        Text("По популярности").tag(2)
                        Text("По году").tag(3)
                    }
                }

                Section("Годы и студия") {
                    TextField("Год от (например 2020)", text: $startYearText)
                        .keyboardType(.numberPad)
                    TextField("Год до (например 2026)", text: $endYearText)
                        .keyboardType(.numberPad)
                    TextField("Студия (опционально)", text: $studioText)
                }

                Section("Жанры") {
                    TextField("Через запятую (например экшен, комедия)", text: $genresText)
                    Toggle("Исключить выбранные жанры", isOn: $filter.isGenresExcludeModeEnabled)
                }

                Section {
                    Button("Сбросить фильтр", role: .destructive) {
                        filter = FilterRequest()
                        startYearText = ""
                        endYearText = ""
                        genresText = ""
                        studioText = ""
                    }
                }
            }
            .navigationTitle("Фильтр релизов")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Применить") {
                        filter.startYear = Int(startYearText)
                        filter.endYear = Int(endYearText)
                        filter.studio = studioText.isEmpty ? nil : studioText
                        filter.genres = genresText
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        dismiss()
                        onApply()
                    }
                }
            }
            .onAppear {
                startYearText = filter.startYear.map(String.init) ?? ""
                endYearText = filter.endYear.map(String.init) ?? ""
                studioText = filter.studio ?? ""
                genresText = filter.genres.joined(separator: ", ")
            }
        }
    }
}
