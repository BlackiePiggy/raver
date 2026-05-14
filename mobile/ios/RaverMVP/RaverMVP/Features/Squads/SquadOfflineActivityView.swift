import MapKit
import SwiftUI

private enum SquadOfflineMapFocusMode: CaseIterable {
    case smartCluster
    case allMembers
    case eventVenue

    var icon: String {
        switch self {
        case .smartCluster: return "person.3.sequence.fill"
        case .allMembers: return "arrow.up.left.and.arrow.down.right"
        case .eventVenue: return "tent.2.fill"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .smartCluster: return L("聚焦大多数成员", "Focus Main Cluster")
        case .allMembers: return L("显示所有成员", "Show All Members")
        case .eventVenue: return L("移动到活动场地", "Move to Event Venue")
        }
    }
}

struct SquadOfflineActivityView: View {
    let squadID: String
    let activityRepository: SquadActivityRepository
    let locationRepository: LocationSyncRepository

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationUploader = SquadOfflineActivityLocationUploader()
    @State private var activity: SquadOfflineActivity?
    @State private var camera: MapCameraPosition = .automatic
    @State private var isLoading = true
    @State private var isJoining = false
    @State private var isEnding = false
    @State private var isUpdatingPresenceStatus = false
    @State private var removingParticipantID: String?
    @State private var isPanelExpanded = false
    @State private var mapFocusMode: SquadOfflineMapFocusMode = .smartCluster
    @State private var panelDragOffset: CGFloat = 0
    @State private var shouldPreserveCameraOnNextActivityRefresh = false
    @State private var lastHandledAutomaticUploadAt: Date?
    @State private var configuredLocationUploadKey: String?
    @State private var errorMessage: String?
    @State private var showEndConfirm = false
    @State private var showCreatorLeaveConfirm = false
    @State private var showInviteSheet = false
    @State private var participantToRemove: SquadOfflineActivityParticipant?
    @State private var now = Date()

    private var isEndedActivity: Bool {
        activity?.isEnded == true
    }

    private var viewerRouteCoordinates: [CLLocationCoordinate2D] {
        (activity?.viewerRoute ?? []).map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    private var currentParticipant: SquadOfflineActivityParticipant? {
        guard let currentUserID = appState.session?.user.id else { return nil }
        return activity?.activeParticipants.first(where: { $0.id == currentUserID })
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer
                .ignoresSafeArea()

            topChrome

            bottomChrome
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadActivity()
        }
        .onDisappear {
            locationUploader.stop()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
        .onChange(of: activity) { previous, next in
            configureLocationUpload(for: next)
            if shouldPreserveCameraOnNextActivityRefresh {
                shouldPreserveCameraOnNextActivityRefresh = false
                return
            }
            if shouldUpdateCamera(from: previous, to: next) {
                updateCamera(for: next)
            }
        }
        .onChange(of: mapFocusMode) { _, _ in
            updateCamera(for: activity)
        }
        .onChange(of: locationUploader.lastUploadAt) { _, uploadAt in
            guard let uploadAt else { return }
            Task {
                await refreshAfterAutomaticLocationUpload(uploadAt)
            }
        }
        .confirmationDialog(
            L("结束线下活动？", "End Offline Activity?"),
            isPresented: $showEndConfirm,
            titleVisibility: .visible
        ) {
            Button(L("结束活动", "End Activity"), role: .destructive) {
                if let activity {
                    Task { await endActivity(activity) }
                }
            }
            Button(L("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(L("结束后会在群聊中自动生成活动卡片，并写入历史活动记录。", "A summary card will be posted to chat and saved to activity history."))
        }
        .confirmationDialog(
            L("你是活动创建者", "You Created This Activity"),
            isPresented: $showCreatorLeaveConfirm,
            titleVisibility: .visible
        ) {
            Button(L("结束活动", "End Activity"), role: .destructive) {
                if let activity {
                    Task { await endActivity(activity) }
                }
            }
            Button(L("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(L("创建者不能直接退出，需要结束本次线下活动。", "The creator cannot leave directly. End this offline activity instead."))
        }
        .confirmationDialog(
            L("移除队友？", "Remove Teammate?"),
            isPresented: Binding(
                get: { participantToRemove != nil },
                set: { if !$0 { participantToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L("移出活动", "Remove from Activity"), role: .destructive) {
                if let participant = participantToRemove, let activity {
                    Task { await removeParticipant(participant, from: activity) }
                }
            }
            Button(L("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(participantToRemove.map { L("将 \($0.displayName) 移出本次线下活动。", "Remove \($0.displayName) from this offline activity.") } ?? "")
        }
        .sheet(isPresented: $showInviteSheet) {
            SquadOfflineActivityInviteSheet(
                squadID: squadID,
                existingMemberIDs: Set(activity?.participants.map(\.id) ?? []),
                repository: activityRepository,
                currentUserID: appState.session?.user.id ?? ""
            )
        }
    }

    private var mapLayer: some View {
        Map(position: $camera) {
            if let activity {
                if activity.isEnded {
                    let routeCoordinates = viewerRouteCoordinates
                    if routeCoordinates.count >= 2 {
                        MapPolyline(coordinates: routeCoordinates)
                            .stroke(RaverTheme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                    if let first = routeCoordinates.first {
                        Annotation(
                            L("起点", "Start"),
                            coordinate: first,
                            anchor: .center
                        ) {
                            SquadOfflineRouteEndpointBadge(systemImage: "play.fill", color: .green)
                        }
                    }
                    if let last = routeCoordinates.last {
                        Annotation(
                            L("终点", "End"),
                            coordinate: last,
                            anchor: .center
                        ) {
                            SquadOfflineRouteEndpointBadge(systemImage: "flag.checkered", color: RaverTheme.accent)
                        }
                    }
                } else {
                    ForEach(activity.activeParticipants) { participant in
                        if let location = participant.latestLocation {
                            Annotation(
                                "",
                                coordinate: CLLocationCoordinate2D(
                                    latitude: location.latitude,
                                    longitude: location.longitude
                                ),
                                anchor: .bottom
                            ) {
                                SquadOfflineMapAvatar(participant: participant)
                            }
                        }
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .including([.publicTransport, .restroom, .park])))
        .overlay {
            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }
        }
    }

    private var topChrome: some View {
        ZStack(alignment: .topLeading) {
            Button {
                if !router.path.isEmpty {
                    router.pop()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.45), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            mapControlStack
                .padding(.trailing, 12)
                .padding(.top, 54)
        }
    }

    private var mapControlStack: some View {
        VStack(spacing: 8) {
            Button {
                Task { await centerOnMyLocation() }
            } label: {
                mapControlIcon("scope", isSelected: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("我的定位", "My Location"))

            ForEach(SquadOfflineMapFocusMode.allCases, id: \.self) { mode in
                Button {
                    mapFocusMode = mode
                } label: {
                    mapControlIcon(mode.icon, isSelected: mapFocusMode == mode)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.accessibilityTitle)
            }
        }
    }

    private func mapControlIcon(_ systemName: String, isSelected: Bool) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isSelected ? .black : .white)
            .frame(width: 38, height: 38)
            .background(isSelected ? Color.white : Color.black.opacity(0.55), in: Circle())
            .contentShape(Circle())
    }

    private var bottomChrome: some View {
        VStack(alignment: .leading, spacing: 8) {
            presenceStatusToggles
                .padding(.horizontal, 26)
            bottomPanel
        }
    }

    @ViewBuilder
    private var presenceStatusToggles: some View {
        if let activity, activity.isJoined, !activity.isEnded, let participant = currentParticipant {
            HStack(spacing: 8) {
                presenceToggleButton(
                    imageName: "SquadRestroomStatusIcon",
                    title: L("厕所", "Restroom"),
                    selectedColor: .green,
                    selectedForegroundColor: .white,
                    isSelected: participant.isInRestroom == true
                ) {
                    Task {
                        await updatePresenceStatus(
                            isInRestroom: !(participant.isInRestroom == true),
                            isBuyingDrink: participant.isBuyingDrink == true
                        )
                    }
                }

                presenceToggleButton(
                    imageName: "SquadBuyingDrinkStatusIcon",
                    title: L("买酒", "Buying Drinks"),
                    selectedColor: .yellow,
                    selectedForegroundColor: .black,
                    isSelected: participant.isBuyingDrink == true
                ) {
                    Task {
                        await updatePresenceStatus(
                            isInRestroom: participant.isInRestroom == true,
                            isBuyingDrink: !(participant.isBuyingDrink == true)
                        )
                    }
                }
            }
        }
    }

    private func presenceToggleButton(
        imageName: String,
        title: String,
        selectedColor: Color,
        selectedForegroundColor: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(isSelected ? selectedForegroundColor : .white)
                .frame(width: 24, height: 24)
                .frame(width: 42, height: 42)
                .background(isSelected ? selectedColor : Color.black.opacity(0.66), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(isSelected ? 0.0 : 0.18), lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isUpdatingPresenceStatus)
        .accessibilityLabel(title)
    }

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 58, height: 5)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        isPanelExpanded.toggle()
                    }
                }

            if let activity {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(activity.displayTitle ?? L("我的队伍", "My Squad"))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .fixedSize(horizontal: false, vertical: true)
                        if let venueText = venueText(for: activity) {
                            HStack(alignment: .center, spacing: 6) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .frame(width: 14, height: 14)
                                Text(venueText)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.54))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                        if activity.isEnded {
                            Label(L("本次线下活动已结束", "This offline activity has ended"), systemImage: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.green.opacity(0.88))
                        } else {
                            Text(L("\(activity.participantCount) 人正在活动中", "\(activity.participantCount) active"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.62))
                        }
                    }

                    Spacer(minLength: 6)

                    if activity.isEnded {
                        EmptyView()
                    } else if activity.isJoined {
                        Button {
                            if activity.isCreatedByMe {
                                showCreatorLeaveConfirm = true
                            } else {
                                Task { await leaveActivity(activity) }
                            }
                        } label: {
                            Image(systemName: "figure.walk.departure")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 44, height: 44)
                        }
                        .foregroundStyle(.white)
                        .background(Color.black.opacity(0.92), in: Circle())
                        .buttonStyle(.plain)
                        .accessibilityLabel(L("退出活动", "Leave Activity"))
                    } else {
                        Button {
                            Task { await joinActivity(activity) }
                        } label: {
                            if isJoining {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Label(L("加入", "Join"), systemImage: "location.fill")
                            }
                        }
                        .buttonStyle(SquadOfflinePrimaryButtonStyle())
                        .disabled(isJoining)
                    }
                }

                if activity.isEnded {
                    endedSummaryPanel(activity)
                } else {
                    participantStrip(activity, expanded: isPanelExpanded)

                    Divider()
                        .overlay(Color.white.opacity(0.18))

                    HStack(spacing: 24) {
                        infoBlock(title: L("创建", "Created"), value: activity.startedAt.formatted(date: .numeric, time: .shortened))
                        infoBlock(title: L("时长", "Duration"), value: durationText(from: activity.startedAt, to: now))
                        Spacer()
                        panelActionButtons(activity)
                    }

                    if isPanelExpanded {
                        expandedPanelContent(activity)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.red.opacity(0.92))
                    } else if activity.isJoined {
                        Text(L("定位会约每 5 分钟同步一次，用于活动轨迹与后续总结。", "Location syncs about every 5 minutes for routes and summaries."))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, isPanelExpanded ? 34 : 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: isPanelExpanded ? 430 : nil, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.78))
                .ignoresSafeArea(edges: .bottom)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 0)
        .offset(y: max(0, panelDragOffset))
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    panelDragOffset = value.translation.height
                }
                .onEnded { value in
                    let shouldExpand = value.translation.height < -36
                    let shouldCollapse = value.translation.height > 36
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        if shouldExpand { isPanelExpanded = true }
                        if shouldCollapse { isPanelExpanded = false }
                        panelDragOffset = 0
                    }
                }
        )
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: isPanelExpanded)
    }

    private func participantStrip(_ activity: SquadOfflineActivity, expanded: Bool) -> some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: expanded ? 12 : 10) {
                    ForEach(activity.activeParticipants) { participant in
                        VStack(spacing: 5) {
                            SquadOfflineAvatarView(participant: participant, size: expanded ? 40 : 34)
                            Text(participant.displayName)
                                .font(.system(size: expanded ? 11 : 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.76))
                                .lineLimit(1)
                                .frame(width: expanded ? 52 : 44)
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 8) {
                if activity.canManage {
                    Button {
                        isPanelExpanded = true
                    } label: {
                        Image(systemName: "person.crop.circle.badge.minus")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .foregroundStyle(.white)
                    .background(Color.white.opacity(0.12), in: Circle())
                    .accessibilityLabel(L("移除队友", "Remove Teammate"))
                }

                Button {
                    showInviteSheet = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .foregroundStyle(.white)
                .background(Color.white.opacity(0.12), in: Circle())
                .accessibilityLabel(L("邀请队友", "Invite Teammate"))
            }
        }
    }

    private func endedSummaryPanel(_ activity: SquadOfflineActivity) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
                .overlay(Color.white.opacity(0.18))

            HStack(spacing: 18) {
                summaryMetric(
                    title: L("开始", "Started"),
                    value: activity.startedAt.formatted(date: .numeric, time: .shortened),
                    icon: "calendar"
                )
                summaryMetric(
                    title: L("时长", "Duration"),
                    value: durationText(from: activity.startedAt, to: activity.endedAt ?? now),
                    icon: "clock"
                )
            }

            HStack(spacing: 18) {
                summaryMetric(
                    title: L("参与人次", "Participants"),
                    value: L("\(activity.participantCount) 人", "\(activity.participantCount) people"),
                    icon: "person.2"
                )
                summaryMetric(
                    title: L("轨迹点", "Route Points"),
                    value: L("\(activity.viewerRoute?.count ?? 0) 个", "\(activity.viewerRoute?.count ?? 0) points"),
                    icon: "point.topleft.down.curvedto.point.bottomright.up"
                )
            }

            HStack(spacing: 18) {
                summaryMetric(
                    title: L("厕所", "Restroom"),
                    value: L("\(activity.viewerSummary?.restroomCount ?? 0) 次", "\(activity.viewerSummary?.restroomCount ?? 0) times"),
                    icon: "toilet.fill"
                )
                summaryMetric(
                    title: L("买东西", "Buying"),
                    value: L("\(activity.viewerSummary?.buyingDrinkCount ?? 0) 次", "\(activity.viewerSummary?.buyingDrinkCount ?? 0) times"),
                    icon: "mug.fill"
                )
            }

            if let endedAt = activity.endedAt {
                Label(
                    L("结束于 \(endedAt.formatted(date: .numeric, time: .shortened))", "Ended at \(endedAt.formatted(date: .numeric, time: .shortened))"),
                    systemImage: "checkmark.seal.fill"
                )
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.green.opacity(0.86))
            }

            Text(L("你的活动轨迹已生成，后续可在这里接入 AI 总结同行伙伴、停留区域和舞台动线。", "Your route has been generated. AI summaries can later cover companions, linger zones, and stage movement."))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func summaryMetric(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RaverTheme.accent)
                .frame(width: 22, height: 22)
                .background(Color.white.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.38))
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func panelActionButtons(_ activity: SquadOfflineActivity) -> some View {
        HStack(spacing: 10) {
            if activity.isJoined {
                Button {
                    Task { await manuallyUploadLocation(activity) }
                } label: {
                    if locationUploader.isUploading {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                }
                .foregroundStyle(.white)
                .background(Color.white.opacity(0.12), in: Circle())
                .accessibilityLabel(L("手动更新定位", "Update Location Manually"))
            }

            if activity.canManage {
                Button {
                    showEndConfirm = true
                } label: {
                    if isEnding {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                }
                .foregroundStyle(.white)
                .background(Color.red.opacity(0.82), in: Circle())
                .disabled(isEnding)
                .accessibilityLabel(L("结束活动", "End Activity"))
            }
        }
    }

    private func expandedPanelContent(_ activity: SquadOfflineActivity) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label(
                    locationUploader.lastUploadAt.map {
                        L("上次同步 \($0.formatted(date: .omitted, time: .shortened))", "Last synced \($0.formatted(date: .omitted, time: .shortened))")
                    } ?? L("尚未同步定位", "Location not synced yet"),
                    systemImage: "clock"
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L("参与成员", "Participants"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.86))

                ForEach(activity.activeParticipants) { participant in
                    HStack(spacing: 10) {
                        SquadOfflineAvatarView(participant: participant, size: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(participant.displayName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.82))
                                    .lineLimit(1)
                                participantStatusChips(participant)
                                Spacer(minLength: 0)
                            }
                            .frame(height: 20, alignment: .center)
                            Text(participant.latestLocation.map {
                                L("定位 \($0.capturedAt.formatted(date: .omitted, time: .shortened))", "Located \($0.capturedAt.formatted(date: .omitted, time: .shortened))")
                            } ?? L("暂无定位", "No location yet"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.42))
                        }
                        Spacer()
                        if activity.canManage && participant.id != activity.createdBy?.id {
                            removeParticipantButton(participant)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func participantStatusChips(_ participant: SquadOfflineActivityParticipant) -> some View {
        let chips = participantPresenceChips(participant)
        if !chips.isEmpty {
            HStack(spacing: 6) {
                ForEach(chips, id: \.title) { chip in
                    HStack(spacing: 3) {
                        Image(chip.imageName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 11, height: 11)
                        Text(chip.title)
                    }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(chip.foregroundColor)
                        .padding(.horizontal, 6)
                        .frame(height: 20)
                        .background(chip.backgroundColor, in: Capsule())
                        .lineLimit(1)
                        .accessibilityLabel(chip.title)
                }
            }
        }
    }

    private func participantPresenceChips(_ participant: SquadOfflineActivityParticipant) -> [(title: String, imageName: String, backgroundColor: Color, foregroundColor: Color)] {
        var chips: [(title: String, imageName: String, backgroundColor: Color, foregroundColor: Color)] = []
        if participant.isInRestroom == true {
            chips.append((L("厕所", "Restroom"), "SquadRestroomStatusIcon", .green.opacity(0.88), .white))
        }
        if participant.isBuyingDrink == true {
            chips.append((L("买东西", "Buying"), "SquadBuyingDrinkStatusIcon", .yellow.opacity(0.9), .black.opacity(0.86)))
        }
        return chips
    }

    private func removeParticipantButton(_ participant: SquadOfflineActivityParticipant) -> some View {
        Button {
            participantToRemove = participant
        } label: {
            if removingParticipantID == participant.id {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                    .frame(width: 34, height: 34)
            } else {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
        }
        .foregroundStyle(.red.opacity(0.95))
        .buttonStyle(.plain)
        .disabled(removingParticipantID != nil)
        .accessibilityLabel(L("移除 \(participant.displayName)", "Remove \(participant.displayName)"))
    }

    private func infoBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.38))
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.76))
        }
    }

    private func venueText(for activity: SquadOfflineActivity) -> String? {
        let addressText = activity.eventAddressText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !addressText.isEmpty {
            return addressText
        }
        let venue = activity.eventVenueName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let address = activity.eventVenueAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let city = activity.eventCity?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !venue.isEmpty && !address.isEmpty {
            return "\(venue) · \(address)"
        }
        if !address.isEmpty {
            return address
        }
        if !venue.isEmpty && !city.isEmpty {
            return "\(venue) · \(city)"
        }
        if !venue.isEmpty {
            return venue
        }
        if !city.isEmpty {
            return city
        }
        return nil
    }

    private func loadActivity() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if let current = try await activityRepository.fetchCurrentSquadOfflineActivity(squadID: squadID) {
                activity = current
            } else {
                activity = try await activityRepository.fetchSquadOfflineActivityHistory(squadID: squadID).first
            }
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage ?? L("活动加载失败", "Failed to load activity")
        }
    }

    private func joinActivity(_ activity: SquadOfflineActivity) async {
        guard !isJoining else { return }
        isJoining = true
        defer { isJoining = false }
        do {
            self.activity = try await activityRepository.joinSquadOfflineActivity(squadID: squadID, activityID: activity.id)
            _ = await locationUploader.uploadNow(repository: locationRepository, squadID: squadID, activityID: activity.id)
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage ?? L("加入失败", "Failed to join")
        }
    }

    private func manuallyUploadLocation(_ activity: SquadOfflineActivity) async {
        guard activity.isJoined else { return }
        let didUpload = await locationUploader.uploadNow(repository: locationRepository, squadID: squadID, activityID: activity.id)
        if didUpload {
            shouldPreserveCameraOnNextActivityRefresh = true
            await loadActivity()
        } else {
            errorMessage = locationUploader.errorMessage ?? L("定位更新失败", "Failed to update location")
        }
    }

    private func centerOnMyLocation() async {
        guard let activity else { return }
        if centerOnJoinedUserLocation(in: activity) {
            return
        }

        guard activity.isJoined else {
            updateCamera(for: activity)
            return
        }

        let didUpload = await locationUploader.uploadNow(repository: locationRepository, squadID: squadID, activityID: activity.id)
        if didUpload {
            await loadActivity()
            _ = centerOnJoinedUserLocation(in: self.activity)
        } else {
            errorMessage = locationUploader.errorMessage ?? L("定位更新失败", "Failed to update location")
        }
    }

    private func refreshAfterAutomaticLocationUpload(_ uploadAt: Date) async {
        guard lastHandledAutomaticUploadAt != uploadAt,
              let activity,
              activity.isJoined,
              !activity.isEnded,
              !centerOnJoinedUserLocation(in: activity) else {
            return
        }
        lastHandledAutomaticUploadAt = uploadAt
        await loadActivity()
        _ = centerOnJoinedUserLocation(in: self.activity)
    }

    @discardableResult
    private func centerOnJoinedUserLocation(in activity: SquadOfflineActivity?) -> Bool {
        let currentUserID = appState.session?.user.id
        guard let activity,
              let participant = activity.activeParticipants.first(where: { $0.id == currentUserID }),
              let location = participant.latestLocation else {
            return false
        }
        camera = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
            )
        )
        return true
    }

    private func leaveActivity(_ activity: SquadOfflineActivity) async {
        do {
            self.activity = try await activityRepository.leaveSquadOfflineActivity(squadID: squadID, activityID: activity.id)
            locationUploader.stop()
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage ?? L("退出失败", "Failed to leave")
        }
    }

    private func endActivity(_ activity: SquadOfflineActivity) async {
        guard !isEnding else { return }
        isEnding = true
        defer { isEnding = false }
        do {
            let endedActivity = try await activityRepository.endSquadOfflineActivity(squadID: squadID, activityID: activity.id)
            locationUploader.stop()
            self.activity = endedActivity
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage ?? L("结束活动失败", "Failed to end activity")
        }
    }

    private func removeParticipant(_ participant: SquadOfflineActivityParticipant, from activity: SquadOfflineActivity) async {
        guard removingParticipantID == nil else { return }
        removingParticipantID = participant.id
        defer {
            removingParticipantID = nil
            participantToRemove = nil
        }
        do {
            self.activity = try await activityRepository.removeSquadOfflineActivityParticipant(
                squadID: squadID,
                activityID: activity.id,
                participantUserID: participant.id
            )
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage ?? L("移除队友失败", "Failed to remove teammate")
        }
    }

    private func updatePresenceStatus(isInRestroom: Bool, isBuyingDrink: Bool) async {
        guard let activity, activity.isJoined, !activity.isEnded, !isUpdatingPresenceStatus else { return }
        isUpdatingPresenceStatus = true
        defer { isUpdatingPresenceStatus = false }
        do {
            shouldPreserveCameraOnNextActivityRefresh = true
            self.activity = try await activityRepository.updateSquadOfflineActivityStatus(
                squadID: squadID,
                activityID: activity.id,
                input: SquadOfflineActivityStatusInput(
                    isInRestroom: isInRestroom,
                    isBuyingDrink: isBuyingDrink
                )
            )
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage ?? L("状态更新失败", "Failed to update status")
        }
    }

    private func configureLocationUpload(for activity: SquadOfflineActivity?) {
        guard let activity, activity.isJoined, !activity.isEnded else {
            locationUploader.stop()
            configuredLocationUploadKey = nil
            return
        }
        let uploadKey = "\(activity.id):\(activity.uploadIntervalSeconds)"
        guard configuredLocationUploadKey != uploadKey else { return }
        configuredLocationUploadKey = uploadKey
        locationUploader.start(
            repository: locationRepository,
            squadID: squadID,
            activityID: activity.id,
            intervalSeconds: activity.uploadIntervalSeconds
        )
    }

    private func shouldUpdateCamera(from previous: SquadOfflineActivity?, to next: SquadOfflineActivity?) -> Bool {
        cameraSignature(for: previous) != cameraSignature(for: next)
    }

    private func cameraSignature(for activity: SquadOfflineActivity?) -> String {
        guard let activity else { return "none" }
        let participantSignature = activity.activeParticipants
            .map { participant -> String in
                if let location = participant.latestLocation {
                    return "\(participant.id):\(location.latitude):\(location.longitude):\(location.capturedAt.timeIntervalSince1970)"
                }
                return "\(participant.id):no-location"
            }
            .sorted()
            .joined(separator: "|")
        let eventSignature = activity.eventCoordinate.map { "\($0.latitude):\($0.longitude)" } ?? "no-event"
        let routeSignature = (activity.viewerRoute ?? [])
            .map { "\($0.latitude):\($0.longitude):\($0.capturedAt.timeIntervalSince1970)" }
            .joined(separator: "|")
        return [
            activity.id,
            activity.status,
            activity.endedAt?.timeIntervalSince1970.description ?? "active",
            eventSignature,
            participantSignature,
            routeSignature,
        ].joined(separator: "#")
    }

    private func updateCamera(for activity: SquadOfflineActivity?) {
        guard let activity else { return }
        if activity.isEnded, let region = region(for: viewerRouteCoordinates) {
            camera = .region(region)
            return
        }
        let participantCoordinates = activity.activeParticipants.compactMap { participant -> CLLocationCoordinate2D? in
            guard let location = participant.latestLocation else { return nil }
            return CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        }

        switch mapFocusMode {
        case .smartCluster:
            if let region = clusteredRegion(for: participantCoordinates) {
                camera = .region(region)
                return
            }
        case .allMembers:
            if let region = region(for: participantCoordinates) {
                camera = .region(region)
                return
            }
        case .eventVenue:
            if let eventCoordinate = activity.eventCoordinate {
                camera = .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: eventCoordinate.latitude, longitude: eventCoordinate.longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                    )
                )
                return
            }
        }

        if let region = clusteredRegion(for: participantCoordinates) {
            camera = .region(region)
            return
        }

        if let eventCoordinate = activity.eventCoordinate {
            camera = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: eventCoordinate.latitude, longitude: eventCoordinate.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                )
            )
            return
        }

        camera = .automatic
    }

    private func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }
        guard coordinates.count > 1 else {
            return MKCoordinateRegion(
                center: first,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }

        let lats = coordinates.map(\.latitude)
        let lngs = coordinates.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(), let minLng = lngs.min(), let maxLng = lngs.max() else {
            return nil
        }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: max(0.006, (maxLat - minLat) * 1.6),
                longitudeDelta: max(0.006, (maxLng - minLng) * 1.6)
            )
        )
    }

    private func clusteredRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }
        guard coordinates.count > 1 else {
            return MKCoordinateRegion(
                center: first,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }

        let locations = coordinates.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        var bestCluster = locations
        for candidate in locations {
            let nearby = locations.filter { $0.distance(from: candidate) <= 1_500 }
            if nearby.count > bestCluster.count / 2 || nearby.count > bestCluster.count {
                bestCluster = nearby
            }
        }

        let useCluster = bestCluster.count >= max(2, Int(Double(locations.count) * 0.6))
        let selected = useCluster ? bestCluster : locations
        let lats = selected.map(\.coordinate.latitude)
        let lngs = selected.map(\.coordinate.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(), let minLng = lngs.min(), let maxLng = lngs.max() else {
            return nil
        }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.006, (maxLat - minLat) * 1.8),
            longitudeDelta: max(0.006, (maxLng - minLng) * 1.8)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private func durationText(from start: Date, to end: Date) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(start)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return L("\(hours) 小时 \(minutes) 分钟", "\(hours)h \(minutes)m")
        }
        if minutes > 0 {
            return L("\(minutes) 分钟", "\(minutes)m")
        }
        return L("<1 分钟", "<1m")
    }
}

private struct SquadOfflineMapAvatar: View {
    let participant: SquadOfflineActivityParticipant

    var body: some View {
        VStack(spacing: 3) {
            Text(participant.displayName)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .foregroundStyle(.white)
                .background(Color.black.opacity(0.58), in: Capsule())
            SquadOfflineAvatarView(participant: participant, size: 34)
                .shadow(color: .black.opacity(0.28), radius: 7, x: 0, y: 3)
        }
    }
}

private struct SquadOfflineRouteEndpointBadge: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color, in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.88), lineWidth: 2))
            .shadow(color: .black.opacity(0.22), radius: 6, x: 0, y: 3)
    }
}

private struct SquadOfflineAvatarView: View {
    let participant: SquadOfflineActivityParticipant
    let size: CGFloat

    var body: some View {
        ZStack {
            if let resolved = AppConfig.resolvedURLString(participant.avatarURL),
               !resolved.isEmpty {
                ImageLoaderView(urlString: resolved)
            } else {
                Circle()
                    .fill(RaverTheme.accent)
                    .overlay(
                        Text(String(participant.displayName.prefix(1)).uppercased())
                            .font(.system(size: size * 0.38, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.84), lineWidth: 2))
    }
}

private struct SquadOfflinePrimaryButtonStyle: ButtonStyle {
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background((isDestructive ? Color.black : RaverTheme.accent).opacity(configuration.isPressed ? 0.72 : 1), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(isDestructive ? 0.14 : 0), lineWidth: 1))
    }
}

private struct SquadOfflineActivityInviteSheet: View {
    @Environment(\.dismiss) private var dismiss

    let squadID: String
    let existingMemberIDs: Set<String>
    let repository: SquadActivityRepository
    let currentUserID: String

    @State private var friends: [UserSummary] = []
    @State private var selectedUserIDs = Set<String>()
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var availableFriends: [UserSummary] {
        friends.filter { !existingMemberIDs.contains($0.id) && $0.id != currentUserID }
    }

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text(L("加载好友中...", "Loading friends..."))
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                } else if availableFriends.isEmpty {
                    ContentUnavailableView(
                        L("暂无可邀请好友", "No Friends Available"),
                        systemImage: "person.2.slash",
                        description: Text(L("当前没有可邀请进入小队的好友。", "There are no friends available to invite into this squad."))
                    )
                } else {
                    Section {
                        ForEach(availableFriends) { friend in
                            Button {
                                toggleSelection(friend.id)
                            } label: {
                                HStack(spacing: 10) {
                                    inviteeAvatar(friend, size: 36)
                                    Text(friend.displayName)
                                        .foregroundStyle(Color.primary)
                                    Spacer(minLength: 0)
                                    Image(systemName: selectedUserIDs.contains(friend.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedUserIDs.contains(friend.id) ? RaverTheme.accent : RaverTheme.secondaryText)
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        }
                    } footer: {
                        Text(L("邀请好友加入小队后，对方可从群聊顶部胶囊进入并加入线下活动。", "After friends join the squad, they can enter from the chat banner and join the offline activity."))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L("邀请队友", "Invite Teammates"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("取消", "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("发送", "Send")) {
                        Task { await sendInvites() }
                    }
                    .disabled(selectedUserIDs.isEmpty || isSubmitting || isLoading)
                }
            }
            .alert(L("操作失败", "Operation Failed"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(L("确定", "OK"), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .task {
                await loadFriends()
            }
            .overlay {
                if isSubmitting {
                    ProgressView(LL("邀请中..."))
                }
            }
        }
    }

    private func toggleSelection(_ userID: String) {
        if selectedUserIDs.contains(userID) {
            selectedUserIDs.remove(userID)
        } else {
            selectedUserIDs.insert(userID)
        }
    }

    @MainActor
    private func loadFriends() async {
        guard !currentUserID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            friends = try await repository.fetchFriends(userID: currentUserID, cursor: nil).users
        } catch {
            errorMessage = error.userFacingMessage ?? L("加载好友失败", "Failed to load friends")
        }
    }

    @MainActor
    private func sendInvites() async {
        guard !selectedUserIDs.isEmpty else { return }
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            for userID in selectedUserIDs {
                try await repository.inviteUserToSquad(squadID: squadID, inviteeUserID: userID)
            }
            dismiss()
        } catch {
            errorMessage = error.userFacingMessage ?? L("发送邀请失败", "Failed to send invite")
        }
    }

    @ViewBuilder
    private func inviteeAvatar(_ user: UserSummary, size: CGFloat) -> some View {
        if let resolved = AppConfig.resolvedURLString(user.avatarURL),
           (resolved.hasPrefix("http://") || resolved.hasPrefix("https://")) {
            ImageLoaderView(urlString: resolved)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            AvatarPlaceholderView(size: size)
        }
    }
}
