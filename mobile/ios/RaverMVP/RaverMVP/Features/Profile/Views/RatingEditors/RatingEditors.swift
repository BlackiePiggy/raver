import SwiftUI
import PhotosUI
import UIKit

@MainActor
final class RatingEventEditorViewModel: ObservableObject {
    let eventID: String

    @Published var name: String
    @Published var description: String
    @Published var imageUrl: String
    @Published var selectedCoverData: Data?
    @Published var isSaving = false
    @Published var isUploadingCover = false
    @Published var errorMessage: String?

    init(event: WebRatingEvent) {
        eventID = event.id
        name = event.name
        description = event.description ?? ""
        imageUrl = event.imageUrl ?? ""
    }

    func loadSelectedCoverPhoto(_ item: PhotosPickerItem?) async {
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

    func save(repository: RatingRepository) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = LT("名称不能为空", "Name cannot be empty.", "名前を入力してください。")
            return false
        }
        isSaving = true
        defer { isSaving = false }

        do {
            var finalImageURL = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            if let selectedCoverData {
                isUploadingCover = true
                defer { isUploadingCover = false }
                let upload = try await repository.uploadRatingImage(
                    imageData: jpegData(from: selectedCoverData),
                    fileName: "rating-event-edit-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    ratingEventID: eventID,
                    ratingUnitID: nil,
                    usage: "event-cover"
                )
                finalImageURL = upload.url
            }
            _ = try await repository.updateRatingEvent(
                id: eventID,
                input: UpdateRatingEventInput(
                    name: trimmedName,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    imageUrl: finalImageURL
                )
            )
            return true
        } catch {
            errorMessage = error.userFacingMessage
            return false
        }
    }

    private func jpegData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.9) else {
            return data
        }
        return jpeg
    }
}

@MainActor
final class RatingUnitEditorViewModel: ObservableObject {
    let unitID: String

    @Published var name: String
    @Published var description: String
    @Published var imageUrl: String
    @Published var selectedCoverData: Data?
    @Published var isSaving = false
    @Published var isUploadingCover = false
    @Published var errorMessage: String?

    init(unit: WebRatingUnit) {
        unitID = unit.id
        name = unit.name
        description = unit.description ?? ""
        imageUrl = unit.imageUrl ?? ""
    }

    func loadSelectedCoverPhoto(_ item: PhotosPickerItem?) async {
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

    func save(repository: RatingRepository) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = LT("名称不能为空", "Name cannot be empty.", "名前を入力してください。")
            return false
        }
        isSaving = true
        defer { isSaving = false }

        do {
            var finalImageURL = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            if let selectedCoverData {
                isUploadingCover = true
                defer { isUploadingCover = false }
                let upload = try await repository.uploadRatingImage(
                    imageData: jpegData(from: selectedCoverData),
                    fileName: "rating-unit-edit-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    ratingEventID: nil,
                    ratingUnitID: unitID,
                    usage: "unit-cover"
                )
                finalImageURL = upload.url
            }
            _ = try await repository.updateRatingUnit(
                id: unitID,
                input: UpdateRatingUnitInput(
                    name: trimmedName,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    imageUrl: finalImageURL
                )
            )
            return true
        } catch {
            errorMessage = error.userFacingMessage
            return false
        }
    }

    private func jpegData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.9) else {
            return data
        }
        return jpeg
    }
}

struct RatingEventEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    private var ratingRepository: RatingRepository { appContainer.ratingRepository }

    let event: WebRatingEvent
    let onSaved: () -> Void

    @State private var selectedCoverPhoto: PhotosPickerItem?
    @StateObject private var viewModel: RatingEventEditorViewModel

    init(event: WebRatingEvent, onSaved: @escaping () -> Void) {
        self.event = event
        self.onSaved = onSaved
        _viewModel = StateObject(wrappedValue: RatingEventEditorViewModel(event: event))
    }

    var body: some View {
        Form {
                Section(LT("编辑打分事件", "Edit Rating Event", "評価イベントを編集")) {
                    TextField(LT("名称", "Name", "名称"), text: $viewModel.name)
                        .submitLabel(.done)
                        .onSubmit {
                            dismissKeyboard()
                        }
                    TextField(LT("描述（选填）", "Description (optional)", "説明（任意）"), text: $viewModel.description, axis: .vertical)
                        .lineLimit(2...4)
                    TextField(LT("封面 URL（选填）", "Cover URL (optional)", "カバーURL（任意）"), text: $viewModel.imageUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            dismissKeyboard()
                        }
                    let hasSelectedCover = viewModel.selectedCoverData != nil
                    PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                        Label(hasSelectedCover ? LT("更换封面图", "Replace cover", "カバー画像を変更") : LT("从相册上传封面图", "Upload cover from Photos", "写真からカバー画像をアップロード"), systemImage: "photo")
                    }
                    if let selectedCoverData = viewModel.selectedCoverData,
                       let preview = UIImage(data: selectedCoverData) {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    if viewModel.selectedCoverData != nil {
                        Text(LT("已选择本地封面图，保存时会自动上传并使用该图片。", "A local cover image is selected. It will be uploaded and used when you save.", "ローカルカバー画像を選択済みです。保存時に自動アップロードして使用します。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
            }
            .raverSystemNavigation(title: LT("编辑打分事件", "Edit Rating Event", "評価イベントを編集"))
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.isSaving ? LT("保存中...", "Saving...", "保存中...") : LT("保存", "Save", "保存")) {
                        Task {
                            if await viewModel.save(repository: ratingRepository) {
                                onSaved()
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving || viewModel.isUploadingCover)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(LT("收起", "Dismiss", "閉じる")) {
                        dismissKeyboard()
                    }
                }
            }
            .onChange(of: selectedCoverPhoto) { _, newValue in
                Task { await viewModel.loadSelectedCoverPhoto(newValue) }
            }
            .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button(LT("确定", "OK", "OK"), role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

}

struct RatingUnitEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    private var ratingRepository: RatingRepository { appContainer.ratingRepository }

    let unit: WebRatingUnit
    let onSaved: () -> Void

    @State private var selectedCoverPhoto: PhotosPickerItem?
    @StateObject private var viewModel: RatingUnitEditorViewModel

    init(unit: WebRatingUnit, onSaved: @escaping () -> Void) {
        self.unit = unit
        self.onSaved = onSaved
        _viewModel = StateObject(wrappedValue: RatingUnitEditorViewModel(unit: unit))
    }

    var body: some View {
        Form {
                Section(LT("编辑打分单位", "Edit Rating Unit", "評価ユニットを編集")) {
                    TextField(LT("名称", "Name", "名称"), text: $viewModel.name)
                        .submitLabel(.done)
                        .onSubmit {
                            dismissKeyboard()
                        }
                    TextField(LT("描述（选填）", "Description (optional)", "説明（任意）"), text: $viewModel.description, axis: .vertical)
                        .lineLimit(2...4)
                    TextField(LT("封面 URL（选填）", "Cover URL (optional)", "カバーURL（任意）"), text: $viewModel.imageUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            dismissKeyboard()
                        }
                    let hasSelectedCover = viewModel.selectedCoverData != nil
                    PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                        Label(hasSelectedCover ? LT("更换单位图片", "Replace unit image", "ユニット画像を変更") : LT("从相册上传单位图", "Upload unit image from Photos", "写真からユニット画像をアップロード"), systemImage: "photo")
                    }
                    if let selectedCoverData = viewModel.selectedCoverData,
                       let preview = UIImage(data: selectedCoverData) {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    if viewModel.selectedCoverData != nil {
                        Text(LT("已选择本地单位图，保存时会自动上传并使用该图片。", "A local unit image is selected. It will be uploaded and used when you save.", "ローカルユニット画像を選択済みです。保存時に自動アップロードして使用します。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
            }
            .raverSystemNavigation(title: LT("编辑打分单位", "Edit Rating Unit", "評価ユニットを編集"))
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.isSaving ? LT("保存中...", "Saving...", "保存中...") : LT("保存", "Save", "保存")) {
                        Task {
                            if await viewModel.save(repository: ratingRepository) {
                                onSaved()
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving || viewModel.isUploadingCover)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(LT("收起", "Dismiss", "閉じる")) {
                        dismissKeyboard()
                    }
                }
            }
            .onChange(of: selectedCoverPhoto) { _, newValue in
                Task { await viewModel.loadSelectedCoverPhoto(newValue) }
            }
            .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button(LT("确定", "OK", "OK"), role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

}
