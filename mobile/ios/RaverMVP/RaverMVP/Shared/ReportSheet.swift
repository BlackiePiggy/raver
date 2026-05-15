import SwiftUI

struct ReportSheetTarget: Identifiable, Hashable {
    let id: String
    var type: ContentReportTargetType
    var title: String
    var preview: String?
    var targetUserID: String?
    var targetUserDisplayName: String?

    var reportInputType: String {
        type.rawValue
    }
}

struct ReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let target: ReportSheetTarget
    var onCompleted: ((ContentReport, Bool) -> Void)?

    @State private var selectedReason: ContentReportReason = .spam
    @State private var detail = ""
    @State private var attachmentLinksText = ""
    @State private var shouldBlockUser = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var completedReport: ContentReport?
    @FocusState private var isDetailFocused: Bool

    private var canBlockUser: Bool {
        guard let targetUserID = target.targetUserID, !targetUserID.isEmpty else { return false }
        return targetUserID != appState.session?.user.id
    }

    var body: some View {
        NavigationStack {
            Group {
                if let completedReport {
                    successView(report: completedReport)
                } else {
                    formView
                }
            }
            .navigationTitle(LT("举报", "Report", "報告"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LT("关闭", "Close", "閉じる")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var formView: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(target.type.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(target.title)
                        .font(.headline)
                    if let preview = target.preview?.trimmingCharacters(in: .whitespacesAndNewlines), !preview.isEmpty {
                        Text(preview)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                .padding(.vertical, 4)
            }

            Section(LT("举报原因", "Reason", "報告理由")) {
                Picker(LT("举报原因", "Reason", "報告理由"), selection: $selectedReason) {
                    ForEach(ContentReportReason.allCases) { reason in
                        Text(reason.title).tag(reason)
                    }
                }
                .pickerStyle(.inline)
            }

            Section(LT("补充说明", "Details", "補足説明")) {
                TextEditor(text: $detail)
                    .frame(minHeight: 96)
                    .focused($isDetailFocused)
                    .overlay(alignment: .topLeading) {
                        if detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(LT("可选：补充截图链接、上下文或你希望审核员注意的信息。", "Optional: add screenshot links, context, or anything moderators should review.", "任意: スクリーンショットリンク、文脈、審査担当者に確認してほしい情報を追加してください。"))
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Section {
                TextEditor(text: $attachmentLinksText)
                    .frame(minHeight: 72)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .overlay(alignment: .topLeading) {
                        if attachmentLinksText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(LT("可选：每行一个截图、图片、视频或音频链接。", "Optional: one screenshot, image, video, or audio link per line.", "任意: スクリーンショット、画像、動画、音声リンクを1行に1つ入力してください。"))
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
            } header: {
                Text(LT("截图/附件", "Screenshots / Attachments", "スクリーンショット / 添付"))
            } footer: {
                Text(LT("请只提交与本次举报直接相关的证据链接。", "Only include evidence links directly related to this report.", "今回の報告に直接関係する証拠リンクのみ含めてください。"))
            }

            if canBlockUser {
                Section {
                    Toggle(isOn: $shouldBlockUser) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LT("同时拉黑此用户", "Also block this user", "このユーザーもブロック"))
                            if let name = target.targetUserDisplayName {
                                Text(name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text(LT("拉黑后，对方将更难继续通过私信或互动打扰你。", "Blocking helps prevent further unwanted messages or interactions.", "ブロックすると、相手からの不要なDMややり取りを受けにくくなります。"))
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text(LT("提交举报", "Submit Report", "報告を送信"))
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(isSubmitting)
            }
        }
    }

    private func successView(report: ContentReport) -> some View {
        VStack(spacing: 18) {
            Image(systemName: shouldBlockUser ? "checkmark.shield.fill" : "checkmark.circle.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.green)
            Text(LT("举报已提交", "Report Submitted", "報告を送信しました"))
                .font(.title3.weight(.semibold))
            Text(LT("我们会尽快审核。处理结果会以不泄露他人隐私的方式反馈给你。", "We will review it as soon as possible and share an outcome without exposing anyone else's private details.", "できるだけ早く確認します。結果は他者のプライバシーを開示しない形でお知らせします。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Text("\(LT("状态", "Status", "状態")): \(report.status)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(LT("完成", "Done", "完了")) {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @MainActor
    private func submit() async {
        guard !isSubmitting else { return }
        isDetailFocused = false
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            let report = try await appState.service.submitContentReport(
                input: ContentReportInput(
                    targetType: target.reportInputType,
                    targetId: target.id,
                    reason: selectedReason.rawValue,
                    detail: trimmedDetail.isEmpty ? nil : trimmedDetail,
                    attachments: normalizedAttachments(),
                    source: "ios_app"
                )
            )
            if shouldBlockUser, let targetUserID = target.targetUserID {
                _ = try await appState.service.blockUser(
                    userID: targetUserID,
                    input: UserBlockInput(reason: selectedReason.rawValue, note: trimmedDetail.isEmpty ? nil : trimmedDetail, source: "report_sheet")
                )
            }
            completedReport = report
            onCompleted?(report, shouldBlockUser)
        } catch {
            errorMessage = error.userFacingMessage ?? LT("提交失败，请稍后重试。", "Submit failed. Please try again.", "送信に失敗しました。もう一度お試しください。")
        }
    }

    private func normalizedAttachments() -> [ContentReportAttachmentInput]? {
        let links = attachmentLinksText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(8)
            .map { link in
                ContentReportAttachmentInput(type: attachmentType(for: link), url: link, label: nil)
            }
        return links.isEmpty ? nil : Array(links)
    }

    private func attachmentType(for link: String) -> String {
        let lowercased = link.lowercased()
        if lowercased.contains(".mp4") || lowercased.contains(".mov") || lowercased.contains("video") {
            return "video"
        }
        if lowercased.contains(".mp3") || lowercased.contains(".m4a") || lowercased.contains(".wav") || lowercased.contains("audio") {
            return "audio"
        }
        if lowercased.contains(".png") || lowercased.contains(".jpg") || lowercased.contains(".jpeg") || lowercased.contains(".webp") {
            return "image"
        }
        return "link"
    }
}
