import SwiftUI

@MainActor
final class MyPublishesViewModel: ObservableObject {
    @Published var publishes = MyPublishes(djSets: [], events: [], ratingEvents: [], ratingUnits: [])
    @Published var newsPublishes: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: WebFeatureService
    private let socialService: SocialService

    init(service: WebFeatureService, socialService: SocialService) {
        self.service = service
        self.socialService = socialService
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let publishesTask = service.fetchMyPublishes()
            async let newsTask = loadMyNewsPublishes()
            publishes = try await publishesTask
            newsPublishes = try await newsTask
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func deleteSet(id: String) async {
        do {
            try await service.deleteDJSet(id: id)
            publishes.djSets.removeAll { $0.id == id }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func deleteEvent(id: String) async {
        do {
            try await service.deleteEvent(id: id)
            publishes.events.removeAll { $0.id == id }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func deleteRatingEvent(id: String) async {
        do {
            try await service.deleteRatingEvent(id: id)
            publishes.ratingEvents.removeAll { $0.id == id }
            publishes.ratingUnits.removeAll { $0.eventId == id }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func deleteRatingUnit(id: String) async {
        do {
            try await service.deleteRatingUnit(id: id)
            publishes.ratingUnits.removeAll { $0.id == id }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func loadMyNewsPublishes() async throws -> [Post] {
        let profile = try await socialService.fetchMyProfile()
        var cursor: String?
        var rounds = 0
        var merged: [Post] = []
        var seen: Set<String> = []

        repeat {
            let page = try await socialService.fetchPostsByUser(userID: profile.id, cursor: cursor)
            for post in page.posts where post.isRaverNews && !seen.contains(post.id) {
                seen.insert(post.id)
                merged.append(post)
            }
            cursor = page.nextCursor
            rounds += 1
        } while cursor != nil && rounds < 6

        return merged.sorted { $0.createdAt > $1.createdAt }
    }
}

struct MyPublishesView: View {
    @Environment(\.appPush) private var appPush
    @Environment(\.profilePush) private var profilePush
    @StateObject private var viewModel: MyPublishesViewModel
    @State private var selectedTab = 0

    init(service: WebFeatureService, socialService: SocialService) {
        _viewModel = StateObject(
            wrappedValue: MyPublishesViewModel(
                service: service,
                socialService: socialService
            )
        )
    }

    var body: some View {
        List {
            Picker(LL("发布类型"), selection: $selectedTab) {
                Text(L("Sets", "Sets")).tag(0)
                Text(L("活动", "Events")).tag(1)
                Text(LL("打分")).tag(2)
                Text(LL("资讯")).tag(3)
            }
            .pickerStyle(.segmented)

            if selectedTab == 0 {
                if viewModel.publishes.djSets.isEmpty, !viewModel.isLoading {
                    ContentUnavailableView(LL("暂无发布 Set"), systemImage: "waveform")
                        .listRowBackground(Color.clear)
                }

                ForEach(viewModel.publishes.djSets) { set in
                    Button {
                        appPush(.discover(.setDetail(setID: set.id)))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(set.title)
                                .font(.headline)
                            Text(L("\(set.trackCount) 首曲目", "\(set.trackCount) tracks"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text(set.createdAt.appLocalizedYMDHMText())
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button {
                            profilePush(.editSet(setID: set.id))
                        } label: {
                            Label(LL("编辑"), systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            Task { await viewModel.deleteSet(id: set.id) }
                        } label: {
                            Label(LL("删除"), systemImage: "trash")
                        }
                    }
                }
            } else if selectedTab == 1 {
                if viewModel.publishes.events.isEmpty, !viewModel.isLoading {
                    ContentUnavailableView(LL("暂无发布活动"), systemImage: "calendar")
                        .listRowBackground(Color.clear)
                }

                ForEach(viewModel.publishes.events) { event in
                    Button {
                        appPush(.eventDetail(eventID: event.id))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.name)
                                .font(.headline)
                            Text(event.startDate.appLocalizedYMDText())
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text([event.city, event.country].compactMap { $0 }.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text(event.createdAt.appLocalizedYMDHMText())
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions {
                        Button {
                            profilePush(.editEvent(eventID: event.id))
                        } label: {
                            Label(LL("编辑"), systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            Task { await viewModel.deleteEvent(id: event.id) }
                        } label: {
                            Label(LL("删除"), systemImage: "trash")
                        }
                    }
                }
            } else if selectedTab == 2 {
                if viewModel.publishes.ratingEvents.isEmpty, viewModel.publishes.ratingUnits.isEmpty, !viewModel.isLoading {
                    ContentUnavailableView(LL("暂无发布打分"), systemImage: "star.leadinghalf.filled")
                        .listRowBackground(Color.clear)
                }

                if !viewModel.publishes.ratingEvents.isEmpty {
                    Section(LL("我发布的打分事件")) {
                        ForEach(viewModel.publishes.ratingEvents) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.name)
                                    .font(.headline)
                                Text(L("\(event.unitCount) 个打分单位", "\(event.unitCount) rating units"))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                Text(event.createdAt.appLocalizedYMDHMText())
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            .padding(.vertical, 4)
                            .swipeActions {
                                Button {
                                    profilePush(.editRatingEvent(eventID: event.id))
                                } label: {
                                    Label(LL("编辑"), systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    Task { await viewModel.deleteRatingEvent(id: event.id) }
                                } label: {
                                    Label(LL("删除"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                if !viewModel.publishes.ratingUnits.isEmpty {
                    Section(LL("我发布的打分单位")) {
                        ForEach(viewModel.publishes.ratingUnits) { unit in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(unit.name)
                                    .font(.headline)
                                Text(L("所属事件：\(unit.eventName)", "Event: \(unit.eventName)"))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                Text(unit.createdAt.appLocalizedYMDHMText())
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            .padding(.vertical, 4)
                            .swipeActions {
                                Button {
                                    profilePush(.editRatingUnit(unitID: unit.id))
                                } label: {
                                    Label(LL("编辑"), systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    Task { await viewModel.deleteRatingUnit(id: unit.id) }
                                } label: {
                                    Label(LL("删除"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            } else {
                if viewModel.newsPublishes.isEmpty, !viewModel.isLoading {
                    ContentUnavailableView(LL("暂无发布资讯"), systemImage: "newspaper")
                        .listRowBackground(Color.clear)
                }

                ForEach(viewModel.newsPublishes) { post in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.raverNewsTitle)
                            .font(.headline)
                            .lineLimit(2)
                        Text(post.raverNewsSource)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                        Text(post.createdAt.appLocalizedYMDHMText())
                            .font(.caption2)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L("我的发布", "My Posts"))
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
