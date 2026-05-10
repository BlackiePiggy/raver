import SwiftUI

struct SquadOfflineActivityStarterSheet: View {
    let squadID: String
    let service: SocialService
    let webService: WebFeatureService
    let onStarted: (SquadOfflineActivity) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var events: [WebEvent] = []
    @State private var selectedEventID: String?
    @State private var isLoading = true
    @State private var isStarting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            Button {
                                selectedEventID = nil
                            } label: {
                                eventChoiceRow(
                                    title: L("不绑定具体活动", "No Event"),
                                    subtitle: L("直接开启小队线下活动", "Start squad offline activity directly"),
                                    isSelected: selectedEventID == nil
                                )
                            }
                            .buttonStyle(.plain)

                            ForEach(events) { event in
                                Button {
                                    selectedEventID = event.id
                                } label: {
                                    eventChoiceRow(
                                        title: event.name,
                                        subtitle: event.summaryLocation,
                                        isSelected: selectedEventID == event.id
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let errorMessage {
                            Section {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(L("开启线下活动", "Start Offline Activity"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("取消", "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await startActivity() }
                    } label: {
                        if isStarting {
                            ProgressView()
                        } else {
                            Text(L("开启", "Start"))
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isStarting)
                }
            }
            .task {
                await loadEvents()
            }
        }
    }

    private func eventChoiceRow(title: String, subtitle: String, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
                Text(subtitle.isEmpty ? L("活动库", "Event library") : subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isSelected ? RaverTheme.accent : RaverTheme.secondaryText.opacity(0.45))
        }
        .padding(.vertical, 4)
    }

    private func loadEvents() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await webService.fetchEvents(page: 1, limit: 30, search: nil, eventType: nil, status: nil)
            events = page.items
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage ?? L("活动列表加载失败", "Failed to load events")
        }
    }

    private func startActivity() async {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        do {
            let selected = events.first { $0.id == selectedEventID }
            let created = try await service.startSquadOfflineActivity(
                squadID: squadID,
                input: StartSquadOfflineActivityInput(
                    eventID: selectedEventID,
                    title: selected?.name
                )
            )
            onStarted(created)
            dismiss()
        } catch {
            errorMessage = error.userFacingMessage ?? L("开启失败", "Failed to start")
        }
    }
}
