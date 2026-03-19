import SwiftUI

struct MyCheckinsView: View {
    private let service = AppEnvironment.makeWebService()

    @State private var filter = "all"
    @State private var page = 1
    @State private var totalPages = 1
    @State private var items: [WebCheckin] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Picker("筛选", selection: $filter) {
                Text("全部").tag("all")
                Text("活动").tag("event")
                Text("DJ").tag("dj")
            }
            .pickerStyle(.segmented)

            if items.isEmpty, !isLoading {
                VStack(spacing: 10) {
                    ContentUnavailableView("还没有打卡", systemImage: "checkmark.seal")
                    Text("去 发现 页参与活动或 DJ 打卡")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.type == "event" ? "活动打卡" : "DJ 打卡")
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)

                    if let event = item.event {
                        Text(event.name)
                            .font(.headline)
                    }
                    if let dj = item.dj {
                        Text(dj.name)
                            .font(.headline)
                    }

                    if let note = item.note, !note.isEmpty {
                        Text(note)
                    }

                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
                .padding(.vertical, 4)
                .swipeActions {
                    Button(role: .destructive) {
                        Task { await delete(item.id) }
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }

            if page < totalPages {
                Button("加载更多") {
                    Task { await loadMore() }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("我的打卡")
        .task {
            await reload()
        }
        .onChange(of: filter) { _, _ in
            Task { await reload() }
        }
        .refreshable {
            await reload()
        }
        .alert("提示", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func reload() async {
        page = 1
        totalPages = 1
        items = []
        await loadMore(reset: true)
    }

    private func loadMore(reset: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let type: String? = filter == "all" ? nil : filter
            let result = try await service.fetchMyCheckins(page: page, limit: 20, type: type)
            if reset {
                items = result.items
            } else {
                items.append(contentsOf: result.items)
            }
            totalPages = result.pagination?.totalPages ?? 1
            page += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ id: String) async {
        do {
            try await service.deleteCheckin(id: id)
            items.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct MyPublishesView: View {
    private let service = AppEnvironment.makeWebService()

    @State private var selectedTab = 0
    @State private var publishes = MyPublishes(djSets: [], events: [])
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var editingEvent: WebEvent?
    @State private var editingSet: WebDJSet?

    var body: some View {
        List {
            Picker("发布类型", selection: $selectedTab) {
                Text("Sets").tag(0)
                Text("活动").tag(1)
            }
            .pickerStyle(.segmented)

            if selectedTab == 0 {
                if publishes.djSets.isEmpty, !isLoading {
                    ContentUnavailableView("暂无发布 Set", systemImage: "waveform")
                        .listRowBackground(Color.clear)
                }

                ForEach(publishes.djSets) { set in
                    NavigationLink {
                        DJSetDetailView(setID: set.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(set.title)
                                .font(.headline)
                            Text("\(set.trackCount) tracks")
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text(set.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions {
                        Button {
                            Task { await prepareEditSet(id: set.id) }
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            Task { await deleteSet(id: set.id) }
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            } else {
                if publishes.events.isEmpty, !isLoading {
                    ContentUnavailableView("暂无发布活动", systemImage: "calendar")
                        .listRowBackground(Color.clear)
                }

                ForEach(publishes.events) { event in
                    NavigationLink {
                        EventDetailView(eventID: event.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.name)
                                .font(.headline)
                            Text(event.startDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text([event.city, event.country].compactMap { $0 }.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions {
                        Button {
                            Task { await prepareEditEvent(id: event.id) }
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            Task { await deleteEvent(id: event.id) }
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("我的发布")
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
        .sheet(item: $editingEvent) { event in
            EventEditorView(mode: .edit(event)) {
                Task { await load() }
            }
        }
        .sheet(item: $editingSet) { set in
            DJSetEditorView(mode: .edit(set)) {
                Task { await load() }
            }
        }
        .alert("提示", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            publishes = try await service.fetchMyPublishes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prepareEditEvent(id: String) async {
        do {
            editingEvent = try await service.fetchEvent(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prepareEditSet(id: String) async {
        do {
            editingSet = try await service.fetchDJSet(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSet(id: String) async {
        do {
            try await service.deleteDJSet(id: id)
            publishes.djSets.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteEvent(id: String) async {
        do {
            try await service.deleteEvent(id: id)
            publishes.events.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
