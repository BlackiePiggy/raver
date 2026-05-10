import MapKit
import SwiftUI

struct SquadOfflineActivityHistoryView: View {
    let squadID: String
    let service: SocialService

    @State private var activities: [SquadOfflineActivity] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(L("加载历史活动中...", "Loading activity history..."))
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            } else if activities.isEmpty {
                ContentUnavailableView(
                    L("暂无历史活动", "No Historical Activities"),
                    systemImage: "clock.arrow.circlepath",
                    description: Text(L("结束线下活动后会自动出现在这里。", "Ended offline activities will appear here automatically."))
                )
            } else {
                Section {
                    ForEach(activities) { activity in
                        NavigationLink {
                            SquadOfflineActivityHistoryDetailView(activity: activity)
                        } label: {
                            SquadOfflineActivityHistoryRow(activity: activity)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .raverSystemNavigation(title: L("历史活动记录", "Activity History"))
        .refreshable {
            await loadHistory()
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
            await loadHistory()
        }
    }

    @MainActor
    private func loadHistory() async {
        isLoading = true
        defer { isLoading = false }
        do {
            activities = try await service.fetchSquadOfflineActivityHistory(squadID: squadID)
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage ?? L("历史活动加载失败", "Failed to load activity history")
        }
    }
}

private struct SquadOfflineActivityHistoryRow: View {
    let activity: SquadOfflineActivity

    var body: some View {
        HStack(spacing: 12) {
            cover

            VStack(alignment: .leading, spacing: 6) {
                Text(activity.displayTitle ?? L("线下活动", "Offline Activity"))
                    .font(.headline)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(durationText(activity.durationSeconds), systemImage: "clock")
                    Label(L("\(activity.participantCount) 人次", "\(activity.participantCount) participants"), systemImage: "person.2")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(RaverTheme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var cover: some View {
        if let resolved = AppConfig.resolvedURLString(activity.eventCoverImageURL),
           !resolved.isEmpty {
            ImageLoaderView(urlString: resolved)
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(RaverTheme.accent.opacity(0.16))
                .frame(width: 54, height: 54)
                .overlay(
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(RaverTheme.accent)
                )
        }
    }

    private var subtitle: String {
        let started = activity.startedAt.formatted(date: .numeric, time: .shortened)
        if let creator = activity.createdBy?.displayName.nilIfBlank {
            return L("\(creator) 创建 · \(started)", "Created by \(creator) · \(started)")
        }
        return started
    }

    private func durationText(_ seconds: Int) -> String {
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

private struct SquadOfflineActivityHistoryDetailView: View {
    let activity: SquadOfflineActivity

    @State private var camera: MapCameraPosition = .automatic

    private var routeCoordinates: [CLLocationCoordinate2D] {
        (activity.viewerRoute ?? []).map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                routeMap

                VStack(alignment: .leading, spacing: 12) {
                    Text(activity.displayTitle ?? L("线下活动", "Offline Activity"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(2)

                    if let venueText {
                        Label(venueText, systemImage: "mappin.and.ellipse")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                .padding(.horizontal, 16)

                summaryGrid
                    .padding(.horizontal, 16)

                routeSummary
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
        }
        .background(RaverTheme.background.ignoresSafeArea())
        .raverSystemNavigation(title: L("活动详情", "Activity Detail"))
        .onAppear {
            updateCamera()
        }
    }

    private var routeMap: some View {
        Map(position: $camera) {
            if routeCoordinates.count >= 2 {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(RaverTheme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            if let first = routeCoordinates.first {
                Annotation(L("起点", "Start"), coordinate: first, anchor: .center) {
                    routeEndpointBadge(systemImage: "play.fill", color: .green)
                }
            }
            if let last = routeCoordinates.last {
                Annotation(L("终点", "End"), coordinate: last, anchor: .center) {
                    routeEndpointBadge(systemImage: "flag.checkered", color: RaverTheme.accent)
                }
            }
        }
        .frame(height: 280)
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .including([.publicTransport, .restroom, .park])))
        .overlay {
            if routeCoordinates.isEmpty {
                ContentUnavailableView(
                    L("暂无你的轨迹", "No Route Yet"),
                    systemImage: "location.slash",
                    description: Text(L("加入并上传定位后，历史活动会展示你的个人轨迹。", "After joining and uploading location, your personal route appears here."))
                )
                .background(.thinMaterial)
            }
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            summaryCard(title: L("创建时间", "Created"), value: activity.startedAt.formatted(date: .numeric, time: .shortened), icon: "calendar")
            summaryCard(title: L("活动时长", "Duration"), value: durationText(activity.durationSeconds), icon: "clock")
            summaryCard(title: L("参与人次", "Participants"), value: L("\(activity.participantCount) 人", "\(activity.participantCount) people"), icon: "person.2")
            summaryCard(title: L("轨迹点", "Route Points"), value: L("\(activity.viewerRoute?.count ?? 0) 个", "\(activity.viewerRoute?.count ?? 0) points"), icon: "point.topleft.down.curvedto.point.bottomright.up")
            summaryCard(title: L("厕所", "Restroom"), value: L("\(activity.viewerSummary?.restroomCount ?? 0) 次", "\(activity.viewerSummary?.restroomCount ?? 0) times"), icon: "toilet.fill")
            summaryCard(title: L("买东西", "Buying"), value: L("\(activity.viewerSummary?.buyingDrinkCount ?? 0) 次", "\(activity.viewerSummary?.buyingDrinkCount ?? 0) times"), icon: "mug.fill")
        }
    }

    private var routeSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L("本次活动总结", "Activity Summary"), systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(RaverTheme.primaryText)

            Text(L("你的轨迹数据已保留在本次历史活动中。后续可以在这里接入 AI，总结同行成员、最长同处对象、舞台停留和临时状态记录。", "Your route data is saved with this activity. AI can later summarize companions, longest co-presence, stage stays, and temporary status records here."))
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var venueText: String? {
        let addressText = activity.eventAddressText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !addressText.isEmpty { return addressText }
        let venue = activity.eventVenueName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let address = activity.eventVenueAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let city = activity.eventCity?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !venue.isEmpty && !address.isEmpty { return "\(venue) · \(address)" }
        if !address.isEmpty { return address }
        if !venue.isEmpty && !city.isEmpty { return "\(venue) · \(city)" }
        if !venue.isEmpty { return venue }
        if !city.isEmpty { return city }
        return nil
    }

    private func summaryCard(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RaverTheme.accent)
                .frame(width: 28, height: 28)
                .background(RaverTheme.accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func routeEndpointBadge(systemImage: String, color: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color, in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.88), lineWidth: 2))
            .shadow(color: .black.opacity(0.22), radius: 6, x: 0, y: 3)
    }

    private func updateCamera() {
        guard let region = region(for: routeCoordinates) else {
            camera = .automatic
            return
        }
        camera = .region(region)
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

    private func durationText(_ seconds: Int) -> String {
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
