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
            errorMessage = L("读取图片失败，请重试", "Failed to read image. Please try again.")
        }
    }

    func save(service: WebFeatureService) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = L("名称不能为空", "Name cannot be empty.")
            return false
        }
        isSaving = true
        defer { isSaving = false }

        do {
            var finalImageURL = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            if let selectedCoverData {
                isUploadingCover = true
                defer { isUploadingCover = false }
                let upload = try await service.uploadRatingImage(
                    imageData: jpegData(from: selectedCoverData),
                    fileName: "rating-event-edit-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    ratingEventID: eventID,
                    ratingUnitID: nil,
                    usage: "event-cover"
                )
                finalImageURL = upload.url
            }
            _ = try await service.updateRatingEvent(
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
            errorMessage = L("读取图片失败，请重试", "Failed to read image. Please try again.")
        }
    }

    func save(service: WebFeatureService) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = L("名称不能为空", "Name cannot be empty.")
            return false
        }
        isSaving = true
        defer { isSaving = false }

        do {
            var finalImageURL = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            if let selectedCoverData {
                isUploadingCover = true
                defer { isUploadingCover = false }
                let upload = try await service.uploadRatingImage(
                    imageData: jpegData(from: selectedCoverData),
                    fileName: "rating-unit-edit-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    ratingEventID: nil,
                    ratingUnitID: unitID,
                    usage: "unit-cover"
                )
                finalImageURL = upload.url
            }
            _ = try await service.updateRatingUnit(
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
    private var service: WebFeatureService { appContainer.webService }

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
        SwiftUI.Form(content: {
                SwiftUI.Section(LL("编辑打分事件")) {
                    TextField(LL("名称"), text: $viewModel.name)
                        .submitLabel(.done)
                        .onSubmit {
                            dismissKeyboard()
                        }
                    TextField(LL("描述（选填）"), text: $viewModel.description, axis: .vertical)
                        .lineLimit(2...4)
                    TextField(LL("封面 URL（选填）"), text: $viewModel.imageUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            dismissKeyboard()
                        }
                    let hasSelectedCover = viewModel.selectedCoverData != nil
                    PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                        Label(hasSelectedCover ? L("更换封面图", "Replace cover") : L("从相册上传封面图", "Upload cover from Photos"), systemImage: "photo")
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
                        Text(LL("已选择本地封面图，保存时会自动上传并使用该图片。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
            })
            .raverSystemNavigation(title: LL("编辑打分事件"))
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.isSaving ? L("保存中...", "Saving...") : L("保存", "Save")) {
                        Task {
                            if await viewModel.save(service: service) {
                                onSaved()
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving || viewModel.isUploadingCover)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L("收起", "Dismiss")) {
                        dismissKeyboard()
                    }
                }
            }
            .onChange(of: selectedCoverPhoto) { _, newValue in
                Task { await viewModel.loadSelectedCoverPhoto(newValue) }
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
    private var service: WebFeatureService { appContainer.webService }

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
        SwiftUI.Form(content: {
                SwiftUI.Section(LL("编辑打分单位")) {
                    TextField(LL("名称"), text: $viewModel.name)
                        .submitLabel(.done)
                        .onSubmit {
                            dismissKeyboard()
                        }
                    TextField(LL("描述（选填）"), text: $viewModel.description, axis: .vertical)
                        .lineLimit(2...4)
                    TextField(LL("封面 URL（选填）"), text: $viewModel.imageUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            dismissKeyboard()
                        }
                    let hasSelectedCover = viewModel.selectedCoverData != nil
                    PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                        Label(hasSelectedCover ? L("更换单位图片", "Replace unit image") : L("从相册上传单位图", "Upload unit image from Photos"), systemImage: "photo")
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
                        Text(LL("已选择本地单位图，保存时会自动上传并使用该图片。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
            })
            .raverSystemNavigation(title: LL("编辑打分单位"))
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.isSaving ? L("保存中...", "Saving...") : L("保存", "Save")) {
                        Task {
                            if await viewModel.save(service: service) {
                                onSaved()
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving || viewModel.isUploadingCover)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L("收起", "Dismiss")) {
                        dismissKeyboard()
                    }
                }
            }
            .onChange(of: selectedCoverPhoto) { _, newValue in
                Task { await viewModel.loadSelectedCoverPhoto(newValue) }
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

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

}
