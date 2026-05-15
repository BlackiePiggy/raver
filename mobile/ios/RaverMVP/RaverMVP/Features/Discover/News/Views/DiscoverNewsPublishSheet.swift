import SwiftUI
import PhotosUI
import UIKit

struct DiscoverNewsPublishSheet: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.dismiss) private var dismiss

    let onSubmit: (DiscoverNewsDraft) async throws -> Void

    @State private var category: DiscoverNewsCategory = .festival
    @State private var sourceName = ""
    @State private var title = ""
    @State private var summary = ""
    @State private var bodyText = ""
    @State private var linkText = ""
    @State private var coverURL = ""
    @State private var selectedCoverPhoto: PhotosPickerItem?
    @State private var selectedCoverData: Data?
    @State private var isSubmitting = false
    @State private var isUploadingCover = false
    @State private var errorMessage: String?
    @State private var boundDjIDs: [String] = []
    @State private var boundBrandIDs: [String] = []
    @State private var boundEventIDs: [String] = []
    @State private var boundDjNameByID: [String: String] = [:]
    @State private var boundBrandNameByID: [String: String] = [:]
    @State private var boundEventNameByID: [String: String] = [:]
    @State private var djSearchText = ""
    @State private var brandSearchText = ""
    @State private var eventSearchText = ""
    @State private var djSearchResults: [WebDJ] = []
    @State private var brandSearchResults: [WebLearnFestival] = []
    @State private var eventSearchResults: [WebEvent] = []
    @State private var isSearchingDJs = false
    @State private var isSearchingBrands = false
    @State private var isSearchingEvents = false

    private var repository: DiscoverNewsRepository {
        appContainer.discoverNewsRepository
    }

    var body: some View {
        Form {
            Section(LT("基础信息", "基础信息", "基本情報")) {
                Picker(LT("分类", "分类", "カテゴリ"), selection: $category) {
                    ForEach(DiscoverNewsCategory.allCases.filter { $0 != .all }) { item in
                        Text(item.title).tag(item)
                    }
                }

                TextField(LT("来源名称", "来源名称", "ソース名"), text: $sourceName)
                TextField(LT("资讯标题", "资讯标题", "ニュースタイトル"), text: $title)
                TextField(LT("资讯摘要（选填）", "资讯摘要（选填）", "ニュース概要（任意）"), text: $summary, axis: .vertical)
                    .lineLimit(2...4)
                TextField(LT("正文（选填）", "正文（选填）", "本文（任意）"), text: $bodyText, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section(LT("封面图", "封面图", "カバー画像")) {
                TextField(LT("封面图 URL（选填）", "封面图 URL（选填）", "カバー画像URL（任意）"), text: $coverURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                    Label(
                        selectedCoverData == nil
                            ? LT("从相册上传封面图", "Upload cover from Photos", "写真からカバー画像をアップロード")
                            : LT("更换封面图", "Replace cover", "カバー画像を変更"),
                        systemImage: "photo"
                    )
                }

                if let selectedCoverData,
                   let preview = UIImage(data: selectedCoverData) {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            Section(LT("外链（选填）", "外链（选填）", "外部リンク（任意）")) {
                TextField(LT("原文链接", "原文链接", "原文リンク"), text: $linkText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section(LT("关联实体（选填）", "关联实体（选填）", "関連エンティティ（任意）")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TextField(LT("搜索 DJ", "搜索 DJ", "DJを検索"), text: $djSearchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button(LT("搜索", "搜索", "検索")) {
                            Task { await searchBindingDJs() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(djSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearchingDJs)
                    }

                    if !boundDjIDs.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(boundDjIDs, id: \.self) { id in
                                HStack(spacing: 8) {
                                    Text(boundDjNameByID[id] ?? id)
                                        .font(.caption)
                                        .foregroundStyle(RaverTheme.primaryText)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Button {
                                        boundDjIDs.removeAll { $0 == id }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(RaverTheme.secondaryText)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(RaverTheme.card, in: Capsule())
                            }
                        }
                    }

                    if isSearchingDJs {
                        ProgressView(LT("搜索 DJ 中...", "搜索 DJ 中...", "DJを検索中..."))
                            .font(.caption)
                    } else if !djSearchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(djSearchResults.prefix(8))) { dj in
                                Button {
                                    toggleBoundDJ(dj)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: boundDjIDs.contains(dj.id) ? "checkmark.circle.fill" : "plus.circle")
                                            .foregroundStyle(boundDjIDs.contains(dj.id) ? RaverTheme.accent : RaverTheme.secondaryText)
                                        Text(dj.name)
                                            .font(.caption)
                                            .foregroundStyle(RaverTheme.primaryText)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TextField(LT("搜索电音节 Brand", "搜索电音节 Brand", "フェスBrandを検索"), text: $brandSearchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button(LT("搜索", "搜索", "検索")) {
                            Task { await searchBindingBrands() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(brandSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearchingBrands)
                    }

                    if !boundBrandIDs.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(boundBrandIDs, id: \.self) { id in
                                HStack(spacing: 8) {
                                    Text(boundBrandNameByID[id] ?? id)
                                        .font(.caption)
                                        .foregroundStyle(RaverTheme.primaryText)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Button {
                                        boundBrandIDs.removeAll { $0 == id }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(RaverTheme.secondaryText)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(RaverTheme.card, in: Capsule())
                            }
                        }
                    }

                    if isSearchingBrands {
                        ProgressView(LT("搜索 Brand 中...", "搜索 Brand 中...", "Brandを検索中..."))
                            .font(.caption)
                    } else if !brandSearchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(brandSearchResults.prefix(8))) { brand in
                                Button {
                                    toggleBoundBrand(brand)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: boundBrandIDs.contains(brand.id) ? "checkmark.circle.fill" : "plus.circle")
                                            .foregroundStyle(boundBrandIDs.contains(brand.id) ? RaverTheme.accent : RaverTheme.secondaryText)
                                        Text(brand.name)
                                            .font(.caption)
                                            .foregroundStyle(RaverTheme.primaryText)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TextField(LT("搜索活动 Event", "搜索活动 Event", "イベントを検索"), text: $eventSearchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button(LT("搜索", "搜索", "検索")) {
                            Task { await searchBindingEvents() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(eventSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearchingEvents)
                    }

                    if !boundEventIDs.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(boundEventIDs, id: \.self) { id in
                                HStack(spacing: 8) {
                                    Text(boundEventNameByID[id] ?? id)
                                        .font(.caption)
                                        .foregroundStyle(RaverTheme.primaryText)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Button {
                                        boundEventIDs.removeAll { $0 == id }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(RaverTheme.secondaryText)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(RaverTheme.card, in: Capsule())
                            }
                        }
                    }

                    if isSearchingEvents {
                        ProgressView(LT("搜索活动中...", "搜索活动中...", "イベントを検索中..."))
                            .font(.caption)
                    } else if !eventSearchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(eventSearchResults.prefix(8))) { event in
                                Button {
                                    toggleBoundEvent(event)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: boundEventIDs.contains(event.id) ? "checkmark.circle.fill" : "plus.circle")
                                            .foregroundStyle(boundEventIDs.contains(event.id) ? RaverTheme.accent : RaverTheme.secondaryText)
                                        Text(event.name)
                                            .font(.caption)
                                            .foregroundStyle(RaverTheme.primaryText)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            if let errorMessage {
                Section {
                    FormStatusMessage(message: errorMessage)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
        }
        .raverSystemNavigation(title: LT("发布资讯", "发布资讯", "ニュースを公開"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSubmitting ? LT("发布中...", "Publishing...", "公開中...") : LT("发布", "Publish", "公開")) {
                    Task { await submit() }
                }
                .disabled(!canSubmit)
            }
        }
        .onChange(of: selectedCoverPhoto) { _, newValue in
            Task { await loadSelectedCoverPhoto(newValue) }
        }
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSubmitting
            && !isUploadingCover
    }

    @MainActor
    private func submit() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSource = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedSource.isEmpty else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            var finalCoverURL = coverURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if let selectedCoverData {
                isUploadingCover = true
                defer { isUploadingCover = false }
                finalCoverURL = try await repository.uploadNewsCoverImage(
                    imageData: jpegData(from: selectedCoverData),
                    fileName: "news-cover-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg"
                )
            }

            try await onSubmit(
                DiscoverNewsDraft(
                    category: category,
                    source: trimmedSource,
                    title: trimmedTitle,
                    summary: trimmedSummary,
                    body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
                    link: linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : linkText.trimmingCharacters(in: .whitespacesAndNewlines),
                    coverImageURL: finalCoverURL.isEmpty ? nil : finalCoverURL,
                    boundDjIDs: boundDjIDs,
                    boundBrandIDs: boundBrandIDs,
                    boundEventIDs: boundEventIDs
                )
            )

            dismiss()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    @MainActor
    private func loadSelectedCoverPhoto(_ item: PhotosPickerItem?) async {
        guard let item else {
            selectedCoverData = nil
            return
        }
        do {
            selectedCoverData = try await item.loadTransferable(type: Data.self)
        } catch {
            selectedCoverData = nil
            errorMessage = LT("读取图片失败，请重试", "Failed to read image. Please try again.", "画像を読み込めませんでした。もう一度お試しください。")
        }
    }

    private func jpegData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.9) else {
            return data
        }
        return jpeg
    }

    private func toggleBoundDJ(_ dj: WebDJ) {
        boundDjNameByID[dj.id] = dj.name
        if let index = boundDjIDs.firstIndex(of: dj.id) {
            boundDjIDs.remove(at: index)
        } else {
            boundDjIDs.append(dj.id)
        }
    }

    private func toggleBoundBrand(_ brand: WebLearnFestival) {
        boundBrandNameByID[brand.id] = brand.name
        if let index = boundBrandIDs.firstIndex(of: brand.id) {
            boundBrandIDs.remove(at: index)
        } else {
            boundBrandIDs.append(brand.id)
        }
    }

    private func toggleBoundEvent(_ event: WebEvent) {
        boundEventNameByID[event.id] = event.name
        if let index = boundEventIDs.firstIndex(of: event.id) {
            boundEventIDs.remove(at: index)
        } else {
            boundEventIDs.append(event.id)
        }
    }

    @MainActor
    private func searchBindingDJs() async {
        let keyword = djSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            djSearchResults = []
            return
        }
        isSearchingDJs = true
        defer { isSearchingDJs = false }
        do {
            let items = try await repository.searchDJs(query: keyword, limit: 20)
            djSearchResults = items
            for item in items {
                boundDjNameByID[item.id] = item.name
            }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    @MainActor
    private func searchBindingBrands() async {
        let keyword = brandSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            brandSearchResults = []
            return
        }
        isSearchingBrands = true
        defer { isSearchingBrands = false }
        do {
            let items = try await repository.fetchLearnFestivals(search: keyword)
            brandSearchResults = items
            for item in items {
                boundBrandNameByID[item.id] = item.name
            }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    @MainActor
    private func searchBindingEvents() async {
        let keyword = eventSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            eventSearchResults = []
            return
        }
        isSearchingEvents = true
        defer { isSearchingEvents = false }
        do {
            let items = try await repository.searchEvents(query: keyword, limit: 20)
            eventSearchResults = items
            for item in items {
                boundEventNameByID[item.id] = item.name
            }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}
