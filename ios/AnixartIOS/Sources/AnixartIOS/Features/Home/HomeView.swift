import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var watching: [Release] = []
    @State private var recommendations: [Release] = []
    @State private var discussing: [Release] = []
    @State private var interesting: [InterestingItem] = []
    @State private var randomRelease: Release?
    @State private var isRandomPresented = false
    @State private var currentRecPage = 0
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = AnixartAPI()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if let impText = session.toggles?.impMessageText,
                       session.toggles?.impMessageEnabled == true,
                       !impText.isEmpty {
                        Text(impText)
                            .font(.footnote)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.orange.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    }

                    if !interesting.isEmpty {
                        interestingCarousel
                    }

                    if !watching.isEmpty {
                        releaseCarousel(title: "Сейчас смотрят", releases: watching)
                    }

                    if !discussing.isEmpty {
                        releaseCarousel(title: "Обсуждаемое", releases: discussing)
                    }

                    if !recommendations.isEmpty {
                        recommendationsGrid
                    } else if !isLoading {
                        ContentUnavailableView(
                            "Лента пуста",
                            systemImage: "sparkles.tv",
                            description: Text("Нажмите «Обновить» или проверьте адрес API в настройках.")
                        )
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Главная")
            .navigationDestination(for: Release.self) { ReleaseDetailView(release: $0) }
            .navigationDestination(isPresented: $isRandomPresented) {
                if let randomRelease {
                    ReleaseDetailView(release: randomRelease)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await openRandomRelease() }
                    } label: {
                        Label("Случайное", systemImage: "dice")
                    }
                }
            }
            .refreshable {
                await loadAll(reset: true)
            }
            .task {
                if watching.isEmpty && recommendations.isEmpty {
                    await loadAll(reset: true)
                }
            }
            .alert("Ошибка загрузки", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var interestingCarousel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Интересное")
                .font(.title3.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(interesting) { item in
                        ZStack(alignment: .bottomLeading) {
                            AsyncImage(url: item.imageURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    Color.secondary.opacity(0.2)
                                }
                            }
                            .frame(width: 280, height: 150)
                            .clipped()

                            LinearGradient(
                                colors: [.clear, .black.opacity(0.8)],
                                startPoint: .center,
                                endPoint: .bottom
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title ?? "")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                if let desc = item.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.85))
                                        .lineLimit(2)
                                }
                            }
                            .padding(12)
                        }
                        .frame(width: 280, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func releaseCarousel(title: String, releases: [Release]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(releases) { release in
                        NavigationLink(value: release) {
                            ReleasePosterCard(release: release)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var recommendationsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Рекомендации")
                .font(.title3.bold())
                .padding(.horizontal)

            LazyVStack(spacing: 10) {
                ForEach(recommendations) { release in
                    NavigationLink(value: release) {
                        ReleaseRow(release: release)
                            .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }

                Button("Загрузить ещё") {
                    Task { await loadMoreRecommendations() }
                }
                .buttonStyle(.bordered)
                .padding(.top, 6)
            }
        }
    }

    private func loadAll(reset: Bool) async {
        isLoading = true
        defer { isLoading = false }

        async let interestingTask = try? api.interesting()
        async let watchingTask = try? api.watching(page: 0)
        async let discussingTask = try? api.discussing()
        async let recsTask = try? api.recommendations(page: 0, previousPage: -1)

        if let intResp = await interestingTask { interesting = intResp.content }
        if let watchResp = await watchingTask { watching = watchResp.content }
        if let discResp = await discussingTask { discussing = discResp.content }
        if let recResp = await recsTask {
            recommendations = recResp.content
            currentRecPage = 0
        }

        if watching.isEmpty && recommendations.isEmpty && discussing.isEmpty {
            do {
                let fallback = try await api.randomRelease()
                recommendations = [fallback]
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadMoreRecommendations() async {
        let nextPage = currentRecPage + 1
        do {
            let resp = try await api.recommendations(page: nextPage, previousPage: currentRecPage)
            recommendations.append(contentsOf: resp.content)
            currentRecPage = nextPage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openRandomRelease() async {
        do {
            randomRelease = try await api.randomRelease()
            isRandomPresented = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
