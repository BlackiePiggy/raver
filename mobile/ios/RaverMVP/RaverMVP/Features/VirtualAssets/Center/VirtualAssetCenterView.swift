import SwiftUI

@MainActor
final class VirtualAssetCenterViewModel: ObservableObject {
    @Published var inventory: [UserVirtualAsset] = []
    @Published var catalog: [VirtualAssetDefinition] = []
    @Published var equips: [UserVirtualAssetEquip] = []
    @Published var appearance: UserAssetAppearance?
    @Published var selectedType: VirtualAssetType = .avatarFrame
    @Published private(set) var phase: LoadPhase = .idle
    @Published var isRefreshing = false
    @Published var updatingAssetID: String?
    @Published var error: String?

    private let repository: VirtualAssetRepository
    private let onAppearanceChanged: () -> Void

    init(
        repository: VirtualAssetRepository,
        onAppearanceChanged: @escaping () -> Void = {}
    ) {
        self.repository = repository
        self.onAppearanceChanged = onAppearanceChanged
    }

    var selectedAssets: [VirtualAssetDefinition] {
        catalog
            .filter { $0.type == selectedType }
            .sorted { lhs, rhs in
                if owns(lhs.id) != owns(rhs.id) {
                    return owns(lhs.id)
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    var selectedEquippedIDs: [String] {
        equips.first { $0.assetType == selectedType }?.assetIDs ?? []
    }

    var selectedOwnedCount: Int {
        inventory.filter { $0.asset.type == selectedType && $0.isUsable }.count
    }

    func load() async {
        if phase == .initialLoading || isRefreshing { return }
        let hadContent = !catalog.isEmpty || !inventory.isEmpty
        phase = hadContent ? .success : .initialLoading
        isRefreshing = hadContent
        defer { isRefreshing = false }

        if !hadContent, let cached = repository.cachedMyAssets() {
            apply(cached)
            phase = .success
        }

        do {
            async let catalogTask = repository.fetchCatalog(type: nil, includeHidden: false)
            async let myAssetsTask = repository.fetchMyAssets()
            let (catalogValue, myAssets) = try await (catalogTask, myAssetsTask)
            catalog = catalogValue.filter { VirtualAssetType.supportedCases.contains($0.type) }
            apply(myAssets)
            phase = .success
            error = nil
            recordCatalogExposure()
        } catch {
            VirtualAssetTelemetry.record(event: "load_failed", surface: "center", error: error.localizedDescription)
            if catalog.isEmpty, inventory.isEmpty, let cached = repository.cachedMyAssets() {
                apply(cached)
                phase = .success
                self.error = L("当前离线，已显示上次同步的装扮库存。", "You're offline. Showing your latest synced style inventory.")
            } else if catalog.isEmpty, inventory.isEmpty {
                phase = .failure(message: error.userFacingMessage ?? L("装扮中心加载失败", "Failed to load Style Center"))
            } else {
                phase = .success
                self.error = error.userFacingMessage
            }
        }
    }

    func refresh() async {
        await load()
    }

    func owns(_ assetID: String) -> Bool {
        inventory.contains { $0.assetID == assetID && $0.isUsable }
    }

    func isEquipped(_ assetID: String) -> Bool {
        selectedEquippedIDs.contains(assetID)
    }

    func statusText(for asset: VirtualAssetDefinition) -> String {
        guard let item = inventory.first(where: { $0.assetID == asset.id }) else {
            return L("未拥有", "Not owned")
        }
        if !item.isUsable {
            return L("不可用", "Unavailable")
        }
        if let expiresAt = item.expiresAt {
            return L("限时 \(expiresAt.appLocalizedYMDText())", "Until \(expiresAt.appLocalizedYMDText())")
        }
        return L("已拥有", "Owned")
    }

    func toggleEquip(_ asset: VirtualAssetDefinition) async {
        guard owns(asset.id), updatingAssetID == nil else { return }
        updatingAssetID = asset.id
        defer { updatingAssetID = nil }

        let nextIDs: [String]
        if selectedType == .profileBadge {
            var ids = selectedEquippedIDs
            if ids.contains(asset.id) {
                ids.removeAll { $0 == asset.id }
            } else {
                ids.append(asset.id)
            }
            nextIDs = Array(ids.prefix(selectedType.maxEquippedCount))
        } else {
            nextIDs = isEquipped(asset.id) ? [] : [asset.id]
        }

        do {
            let response = try await repository.updateEquip(assetType: selectedType, assetIDs: nextIDs)
            upsertEquip(response.equip)
            appearance = response.appearance
            VirtualAssetTelemetry.record(
                event: nextIDs.isEmpty ? "unequip" : "equip",
                surface: "center",
                assetID: asset.id,
                assetType: asset.type
            )
            onAppearanceChanged()
            OperationBannerCenter.shared.success(nextIDs.isEmpty ? L("已卸下装扮", "Style removed") : L("已装备装扮", "Style equipped"))
        } catch {
            VirtualAssetTelemetry.record(
                event: "load_failed",
                surface: "center",
                assetID: asset.id,
                assetType: asset.type,
                error: error.localizedDescription
            )
            self.error = error.userFacingMessage
        }
    }

    private func apply(_ response: MyVirtualAssetsResponse) {
        inventory = response.inventory
        equips = response.equips
        appearance = response.appearance

        if catalog.isEmpty {
            catalog = response.inventory.map(\.asset)
        }
    }

    private func upsertEquip(_ equip: UserVirtualAssetEquip) {
        if let index = equips.firstIndex(where: { $0.assetType == equip.assetType }) {
            equips[index] = equip
        } else {
            equips.append(equip)
        }
    }

    private func recordCatalogExposure() {
        for asset in catalog.prefix(24) {
            VirtualAssetTelemetry.record(
                event: "preview",
                surface: "center",
                assetID: asset.id,
                assetType: asset.type
            )
        }
    }
}

struct VirtualAssetCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: VirtualAssetCenterViewModel

    init(
        repository: VirtualAssetRepository,
        onAppearanceChanged: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(
            wrappedValue: VirtualAssetCenterViewModel(
                repository: repository,
                onAppearanceChanged: onAppearanceChanged
            )
        )
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .idle, .initialLoading:
                ProfileSkeletonView()
            case .failure(let message), .offline(let message):
                ScrollView {
                    ScreenErrorCard(message: message, retryAction: {
                        Task { await viewModel.load() }
                    })
                    .padding(16)
                    .padding(.top, 40)
                }
            case .empty, .success:
                content
            }
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: L("装扮中心", "Style Center"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isRefreshing)
            }
        }
        .task {
            await viewModel.load()
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if viewModel.isRefreshing {
                    InlineLoadingBadge(title: L("正在同步装扮", "Syncing styles"))
                }

                if let appearance = viewModel.appearance {
                    VirtualAssetRenderPreviewView(appearance: appearance)
                }

                typePicker

                if viewModel.selectedAssets.isEmpty {
                    ContentUnavailableView(
                        L("暂无装扮", "No Styles"),
                        systemImage: "sparkles",
                        description: Text(L("这一类装扮还没有开放。", "This style category is not available yet."))
                    )
                    .padding(.top, 20)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.selectedAssets) { asset in
                            VirtualAssetInventoryRow(
                                asset: asset,
                                isOwned: viewModel.owns(asset.id),
                                isEquipped: viewModel.isEquipped(asset.id),
                                statusText: viewModel.statusText(for: asset),
                                isUpdating: viewModel.updatingAssetID == asset.id
                            ) {
                                Task { await viewModel.toggleEquip(asset) }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var typePicker: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L("分类", "Categories"))
                        .font(.headline)
                        .foregroundStyle(RaverTheme.primaryText)
                    Spacer()
                    Text(L("已拥有 \(viewModel.selectedOwnedCount)", "\(viewModel.selectedOwnedCount) owned"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                }

                VirtualAssetTypeSegmentedControl(selection: $viewModel.selectedType)
            }
        }
    }
}

private struct VirtualAssetTypeSegmentedControl: View {
    @Binding var selection: VirtualAssetType

    var body: some View {
        HStack(spacing: 8) {
            ForEach(VirtualAssetType.supportedCases) { type in
                Button {
                    selection = type
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: type.centerIconName)
                            .font(.system(size: 15, weight: .semibold))
                        Text(type.centerTitle)
                            .font(.caption2.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .foregroundStyle(selection == type ? Color.white : RaverTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selection == type ? RaverTheme.accent : RaverTheme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(selection == type ? Color.clear : RaverTheme.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct VirtualAssetInventoryRow: View {
    let asset: VirtualAssetDefinition
    let isOwned: Bool
    let isEquipped: Bool
    let statusText: String
    let isUpdating: Bool
    let onToggle: () -> Void

    var body: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 12) {
                preview

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(asset.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineLimit(1)

                        if isEquipped {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(RaverTheme.accent)
                        }
                    }

                    if let description = asset.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .lineLimit(2)
                    }

                    Text(statusText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isOwned ? RaverTheme.accent : RaverTheme.secondaryText)
                }

                Spacer(minLength: 8)

                Button(action: onToggle) {
                    if isUpdating {
                        ProgressView()
                    } else {
                        Text(buttonTitle)
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isOwned || isUpdating)
                .controlSize(.small)
            }
        }
    }

    private var buttonTitle: String {
        if !isOwned { return L("预览", "Preview") }
        return isEquipped ? L("卸下", "Remove") : L("装备", "Equip")
    }

    @ViewBuilder
    private var preview: some View {
        switch asset.type {
        case .avatarFrame:
            VirtualAssetAvatarView(size: 44, avatarFrame: asset) {
                AvatarPlaceholderView(size: 44, backgroundColor: RaverTheme.card)
            }
        case .profileBadge:
            VirtualAssetBadgeView(asset: asset, compact: true, showTitle: false)
                .frame(width: 54, height: 54)
        case .chatBubbleSkin:
            VirtualAssetChatBubbleContainer(asset: asset, isMine: true) { style in
                Text("Hi")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(style.textColor))
            }
            .frame(width: 62, height: 42)
        case .titleMedal:
            VirtualAssetTitleMedalView(asset: asset, compact: true, maxWidth: 74)
                .frame(width: 78, height: 34, alignment: .leading)
        case .unknown:
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(RaverTheme.accent)
                .frame(width: 54, height: 54)
        }
    }
}

private extension VirtualAssetType {
    var centerTitle: String {
        switch self {
        case .avatarFrame:
            return L("头像框", "Frames")
        case .profileBadge:
            return L("徽章", "Badges")
        case .chatBubbleSkin:
            return L("气泡", "Bubbles")
        case .titleMedal:
            return L("称号", "Titles")
        case .unknown(let value):
            return value
        }
    }

    var centerIconName: String {
        switch self {
        case .avatarFrame:
            return "person.crop.circle"
        case .profileBadge:
            return "seal"
        case .chatBubbleSkin:
            return "bubble.left.and.bubble.right"
        case .titleMedal:
            return "tag"
        case .unknown:
            return "sparkles"
        }
    }
}
