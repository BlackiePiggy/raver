import SwiftUI

struct EventUploadFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: EventUploadFlowViewModel
    @State private var showLocationPicker = false
    @State private var showExitConfirmation = false

    init(
        mode: EventUploadMode = .create,
        event: WebEvent? = nil,
        userID: String = "current",
        webService: WebFeatureService = AppEnvironment.sharedWebService,
        onSaved: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: EventUploadFlowViewModel(
            mode: mode,
            event: event,
            userID: userID,
            webService: webService,
            onSaved: onSaved
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let success = viewModel.submitSuccess {
                successView(success)
            } else {
                EventUploadProgressHeader(currentStep: viewModel.draft.currentStep)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        content
                    }
                    .padding(20)
                }
                EventUploadBottomBar(
                    canGoBack: viewModel.draft.currentStep.previous != nil,
                    isFinalStep: viewModel.draft.currentStep == .review,
                    isBusy: viewModel.isSubmitting,
                    onBack: viewModel.goBack,
                    onNext: viewModel.advance
                )
            }
        }
        .background(RaverTheme.background.ignoresSafeArea())
        .raverSystemNavigation(title: LT("上传活动", "Upload Event", "イベントをアップロード"))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if viewModel.draft.dirty && viewModel.submitSuccess == nil {
                        showExitConfirmation = true
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
        .onAppear {
            viewModel.setDismissAction { dismiss() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                viewModel.saveDraft(immediate: true)
            }
        }
        .onDisappear {
            if viewModel.submitSuccess == nil {
                viewModel.saveDraft(immediate: true)
            }
            viewModel.markAbandonedIfNeeded()
        }
        .sheet(isPresented: $showLocationPicker) {
            EventLocationPickerSheet(
                initialLatitude: viewModel.draft.latitude,
                initialLongitude: viewModel.draft.longitude,
                initialAddress: viewModel.draft.pickedMapAddress
            ) { result in
                viewModel.applyLocationPickerResult(result)
            }
        }
        .alert(LT("继续上次草稿？", "Continue Draft?", "前回の下書きを続けますか？"), isPresented: $viewModel.shouldConfirmRestoredCreateDraft) {
            Button(LT("重新开始", "Start Over", "最初から"), role: .destructive) {
                viewModel.restartCreateDraft()
            }
            Button(LT("继续草稿", "Continue", "続ける"), role: .cancel) {
                viewModel.continueRestoredDraft()
            }
        } message: {
            Text(LT("已恢复上次未提交的新建活动草稿。", "Your previous unsent event draft was restored.", "未送信のイベント下書きを復元しました。"))
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { viewModel.statusMessage != nil },
            set: { if !$0 { viewModel.statusMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.statusMessage ?? "")
        }
        .confirmationDialog(
            LT("保留草稿？", "Keep Draft?", "下書きを残しますか？"),
            isPresented: $showExitConfirmation,
            titleVisibility: .visible
        ) {
            Button(LT("保存草稿并离开", "Save Draft & Leave", "下書きを保存して離れる")) {
                viewModel.saveDraftAndClose()
            }
            Button(LT("放弃草稿", "Discard Draft", "下書きを破棄"), role: .destructive) {
                viewModel.discardDraftAndClose()
            }
            Button(LT("继续编辑", "Keep Editing", "編集を続ける"), role: .cancel) {}
        } message: {
            Text(LT("未提交的内容会保存在本地草稿中。", "Unsubmitted changes can be kept as a local draft.", "未送信の内容はローカル下書きとして保存できます。"))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.draft.currentStep {
        case .media:
            mediaStep
        case .basic:
            basicStep
        case .time:
            timeStep
        case .location:
            locationStep
        case .lineup:
            lineupStep
        case .review:
            reviewStep
        }
    }

    private var mediaStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                viewModel.tapAIPlaceholder()
            } label: {
                Label(LT("AI 智能识别", "AI Recognition", "AI認識"), systemImage: "sparkles")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(
                            colors: [.pink, .purple, .blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.55), lineWidth: 1)
                    )
                    .shadow(color: RaverTheme.accent.opacity(0.25), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)

            ForEach(EventUploadImageZone.allCases) { zone in
                EventUploadImageZoneCard(
                    zone: zone,
                    images: viewModel.draft.imageZones[zone] ?? [],
                    isRequired: zone == .poster,
                    onPicked: { items in
                        await viewModel.addPickedImages(zone: zone, items: items)
                    },
                    onReplace: { imageID, item in
                        await viewModel.replaceImage(zone: zone, imageID: imageID, item: item)
                    },
                    onDelete: { imageID in
                        viewModel.removeImage(zone: zone, imageID: imageID)
                    },
                    onMove: { imageID, direction in
                        viewModel.moveImage(zone: zone, imageID: imageID, direction: direction)
                    }
                )
            }
        }
    }

    private var basicStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                LT("基础信息", "Basics", "基本情報"),
                subtitle: LT("先把用户判断活动是否值得去的核心信息填清楚。", "Start with the essentials people need to understand the event.", "イベントを理解するための基本情報を入力します。")
            )

            uploadTextField(
                title: LT("活动名称", "Event Name", "イベント名"),
                text: localizedBinding(\.name),
                isRequired: true
            )

            VStack(alignment: .leading, spacing: 8) {
                fieldTitle(LT("活动类型", "Event Type", "イベント種別"), isRequired: false)
                Picker(EventTypeOption.pickerPrompt, selection: eventTypeBinding) {
                    Text(EventTypeOption.pickerPrompt).tag("")
                    ForEach(EventTypeOption.allCases, id: \.rawValue) { option in
                        Text(EventTypeOption.displayTitle(for: option.rawValue)).tag(option.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .tint(RaverTheme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(fieldBackground)
            }

            uploadTextField(
                title: LT("简介", "Description", "概要"),
                text: localizedBinding(\.description),
                axis: .vertical
            )

            HStack(spacing: 12) {
                uploadTextField(
                    title: LT("城市", "City", "都市"),
                    text: localizedBinding(\.city),
                    isRequired: true
                )
                uploadTextField(
                    title: LT("国家", "Country", "国"),
                    text: localizedBinding(\.country),
                    isRequired: true
                )
            }

            uploadTextField(
                title: LT("详细地址", "Detailed Address", "詳細住所"),
                text: localizedBinding(\.detailAddress),
                isRequired: true,
                axis: .vertical
            )

            Text(preferredLanguageHint)
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
        }
    }

    private var timeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                LT("时间与时区", "Time & Time Zone", "時間とタイムゾーン"),
                subtitle: LT("支持单日、多日和多 Week，跨天时间表默认按凌晨 6 点切日。", "Supports single-day, multi-day, and multi-week events. Overnight timetable rollover defaults to 6 AM.", "1日、複数日、複数Weekに対応します。深夜越えの切替は標準で朝6時です。")
            )

            VStack(alignment: .leading, spacing: 8) {
                fieldTitle(LT("活动跨度", "Schedule Mode", "開催期間"), isRequired: false)
                HStack(spacing: 8) {
                    ForEach(EventUploadScheduleMode.allCases) { mode in
                        Button {
                            viewModel.updateScheduleMode(mode)
                        } label: {
                            Text(mode.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(viewModel.draft.scheduleMode == mode ? .white : RaverTheme.primaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    viewModel.draft.scheduleMode == mode ? RaverTheme.accent : RaverTheme.card,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(RaverTheme.cardBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            DatePicker(
                LT("开始日期", "Start Date", "開始日"),
                selection: dateBinding(\.startDate),
                displayedComponents: [.date]
            )
            .datePickerStyle(.compact)
            .tint(RaverTheme.accent)
            .padding(12)
            .background(fieldBackground)

            DatePicker(
                LT("结束日期", "End Date", "終了日"),
                selection: dateBinding(\.endDate),
                displayedComponents: [.date]
            )
            .datePickerStyle(.compact)
            .tint(RaverTheme.accent)
            .padding(12)
            .background(fieldBackground)

            timeZoneSearchSection

            timeZonePreviewSection

            Stepper(value: dayRolloverBinding, in: 0...12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LT("跨天切日时间", "Overnight Rollover", "日付切替時刻"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text(LT("凌晨 \(viewModel.draft.dayRolloverHour):00 前仍算前一日", "Before \(viewModel.draft.dayRolloverHour):00 counts as the previous event day", "\(viewModel.draft.dayRolloverHour):00 前は前日の扱い"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                }
            }
            .tint(RaverTheme.accent)
            .padding(12)
            .background(fieldBackground)

            if viewModel.draft.endDate < viewModel.draft.startDate {
                Text(LT("结束日期不能早于开始日期。", "End date cannot be earlier than start date.", "終了日は開始日より前にできません。"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
    }

    private var locationStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                LT("地点", "Location", "場所"),
                subtitle: LT("城市、国家和详细地址已在基础信息中作为必填项；坐标可选。", "City, country, and detailed address are required in Basics. Coordinates are optional.", "都市、国、詳細住所は基本情報で必須です。座標は任意です。")
            )

            Button {
                showLocationPicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "map")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(LT("从地图选择位置", "Pick on Map", "地図で選択"))
                            .font(.subheadline.weight(.bold))
                        Text(LT("搜索场地、拖动地图或使用当前位置。", "Search venues, drag the map, or use current location.", "会場検索、地図移動、現在地を利用できます。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(RaverTheme.secondaryText)
                }
                .foregroundStyle(RaverTheme.primaryText)
                .padding(14)
                .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(RaverTheme.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                fieldTitle(LT("位置摘要", "Location Summary", "場所の概要"), isRequired: false)
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.locationSummary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    if let coordinateSummary = viewModel.coordinateSummary {
                        Text(coordinateSummary)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(fieldBackground)
            }

            HStack(spacing: 12) {
                uploadTextField(
                    title: LT("纬度（可选）", "Latitude (Optional)", "緯度（任意）"),
                    text: coordinateBinding(\.latitude)
                )
                uploadTextField(
                    title: LT("经度（可选）", "Longitude (Optional)", "経度（任意）"),
                    text: coordinateBinding(\.longitude)
                )
            }
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                LT("票务、预览与提交", "Tickets, Review & Submit", "チケット・確認・送信"),
                subtitle: LT("首版只保留简单票价和购票链接；提交链路会在后续接入管理员直发/普通用户审核。", "First version keeps simple pricing and ticket URL. Final submit wiring comes next.", "初版は簡単な価格とチケットURLのみです。送信接続は次に実装します。")
            )

            HStack(spacing: 12) {
                uploadTextField(
                    title: LT("最低价", "Min Price", "最低価格"),
                    text: ticketBinding(\.priceMin)
                )
                uploadTextField(
                    title: LT("最高价", "Max Price", "最高価格"),
                    text: ticketBinding(\.priceMax)
                )
            }

            HStack(spacing: 12) {
                uploadTextField(
                    title: LT("币种", "Currency", "通貨"),
                    text: ticketBinding(\.currency)
                )
                uploadTextField(
                    title: LT("购票链接", "Ticket URL", "チケットURL"),
                    text: ticketBinding(\.ticketURL)
                )
            }

            reviewCard(
                title: LT("媒体", "Media", "メディア"),
                rows: EventUploadImageZone.allCases.map { zone in
                    "\(zone.title): \(viewModel.draft.imageZones[zone]?.count ?? 0)"
                }
            )

            reviewCard(
                title: LT("基础", "Basics", "基本"),
                rows: [
                    viewModel.draft.name.primaryValue(preferredLanguage: viewModel.draft.preferredLanguage),
                    EventTypeOption.displayText(for: viewModel.draft.eventType, fallbackWhenEmpty: false),
                    viewModel.locationSummary,
                ].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            )

            reviewCard(
                title: LT("时间", "Time", "時間"),
                rows: [
                    viewModel.draft.scheduleMode.title,
                    viewModel.reviewDateRange,
                    viewModel.draft.timeZoneIdentifier,
                    LT("跨天切日：\(viewModel.draft.dayRolloverHour):00", "Rollover: \(viewModel.draft.dayRolloverHour):00", "日付切替：\(viewModel.draft.dayRolloverHour):00"),
                ]
            )

            reviewCard(
                title: LT("阵容", "Lineup", "ラインナップ"),
                rows: viewModel.draft.lineupSlots.map { slot in
                    let name = EventLineupActCodec.composeName(type: slot.actType, performerNames: slot.performerNames)
                    let stage = slot.stageName.trimmingCharacters(in: .whitespacesAndNewlines)
                    return stage.isEmpty ? name : "\(name) · \(stage)"
                }
            )
        }
    }

    private var lineupStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                LT("阵容与时间表", "Lineup & Timetable", "ラインナップとタイムテーブル"),
                subtitle: LT("没有阵容可以直接跳过；先维护舞台，后续演出时间会挂到对应舞台。", "You can skip lineup for now. Stages are prepared first for later timetable slots.", "ラインナップがなければスキップできます。まずステージを準備します。")
            )

            Button {
                viewModel.addStage()
            } label: {
                Label(LT("添加舞台", "Add Stage", "ステージを追加"), systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RaverTheme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            if viewModel.draft.stageEntries.isEmpty {
                Text(LT("尚未添加舞台。没有阵容或时间表时可以继续下一步。", "No stages yet. You can continue if lineup or timetable is not available.", "ステージ未追加です。ラインナップやタイムテーブルがなければ次へ進めます。"))
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(viewModel.draft.stageEntries.enumerated()), id: \.offset) { index, _ in
                        HStack(spacing: 10) {
                            TextField(
                                LT("舞台 \(index + 1)", "Stage \(index + 1)", "ステージ \(index + 1)"),
                                text: stageBinding(index)
                            )
                            .font(.body)
                            .foregroundStyle(RaverTheme.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .background(fieldBackground)

                            Button {
                                viewModel.removeStage(at: index)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.red)
                                    .frame(width: 38, height: 38)
                                    .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            VStack(spacing: 4) {
                                Button {
                                    viewModel.moveStage(at: index, direction: -1)
                                } label: {
                                    Image(systemName: "chevron.up")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(RaverTheme.secondaryText)
                                        .frame(width: 30, height: 18)
                                }
                                .buttonStyle(.plain)
                                .disabled(index == 0)

                                Button {
                                    viewModel.moveStage(at: index, direction: 1)
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(RaverTheme.secondaryText)
                                        .frame(width: 30, height: 18)
                                }
                                .buttonStyle(.plain)
                                .disabled(index == viewModel.draft.stageEntries.count - 1)
                            }
                        }
                    }
                }
            }

            Button {
                viewModel.addLineupSlot()
            } label: {
                Label(LT("添加演出", "Add Act", "出演を追加"), systemImage: "music.mic")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RaverTheme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            if !viewModel.draft.lineupSlots.isEmpty {
                VStack(spacing: 12) {
                    ForEach(viewModel.draft.lineupSlots) { slot in
                        lineupSlotEditor(slot)
                    }
                }
            }

            Button {
                viewModel.tapLineupImportPlaceholder()
            } label: {
                Label(LT("阵容图识别入口", "Lineup Image Import", "ラインナップ画像認識"), systemImage: "sparkles")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(RaverTheme.cardBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func lineupSlotEditor(_ slot: EventUploadLineupSlotDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(EventLineupActCodec.composeName(type: slot.actType, performerNames: slot.performerNames).isEmpty ? LT("未命名演出", "Untitled Act", "未命名の出演") : EventLineupActCodec.composeName(type: slot.actType, performerNames: slot.performerNames))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
                Spacer()
                Button {
                    viewModel.removeLineupSlot(id: slot.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.red)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }

            Picker(LT("演出形式", "Act Type", "出演形式"), selection: lineupActTypeBinding(slot.id)) {
                ForEach(EventLineupActType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)

            ForEach(0..<slot.actType.performerCount, id: \.self) { index in
                uploadTextField(
                    title: slot.actType == .solo ? LT("DJ 名称", "DJ Name", "DJ名") : LT("DJ \(index + 1)", "DJ \(index + 1)", "DJ \(index + 1)"),
                    text: lineupPerformerBinding(slot.id, performerIndex: index),
                    isRequired: true
                )
                lineupDJSearchSection(slot, performerIndex: index)
            }

            if !viewModel.draft.stageEntries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    fieldTitle(LT("舞台", "Stage", "ステージ"), isRequired: true)
                    Picker(LT("舞台", "Stage", "ステージ"), selection: lineupStageBinding(slot.id)) {
                        Text(LT("选择舞台", "Choose Stage", "ステージを選択")).tag("")
                        ForEach(viewModel.draft.stageEntries, id: \.self) { stage in
                            Text(stage).tag(stage)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(RaverTheme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(fieldBackground)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldTitle(LT("演出日", "Event Day", "出演日"), isRequired: false)
                Picker(LT("演出日", "Event Day", "出演日"), selection: lineupDayBinding(slot.id)) {
                    ForEach(lineupDayOptions) { option in
                        Text(option.title).tag(option.dayIndex)
                    }
                }
                .pickerStyle(.menu)
                .tint(RaverTheme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(fieldBackground)
            }

            Toggle(isOn: lineupTimedBinding(slot.id)) {
                Text(LT("填写演出时间", "Set Time", "時間を設定"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
            }
            .tint(RaverTheme.accent)

            if slot.startTime != nil || slot.endTime != nil {
                HStack(spacing: 12) {
                    DatePicker(
                        LT("开始", "Start", "開始"),
                        selection: lineupTimeBinding(slot.id, keyPath: \.startTime),
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .tint(RaverTheme.accent)

                    DatePicker(
                        LT("结束", "End", "終了"),
                        selection: lineupTimeBinding(slot.id, keyPath: \.endTime),
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .tint(RaverTheme.accent)
                }
                Text(LT("结束时间不晚于开始时间时，会按次日结束保存。", "If the end time is not later than the start time, it is saved as ending the next day.", "終了時刻が開始時刻以前の場合、翌日終了として保存します。"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
        .padding(14)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private func lineupDJSearchSection(_ slot: EventUploadLineupSlotDraft, performerIndex: Int) -> some View {
        let key = viewModel.djSearchKey(slotID: slot.id, performerIndex: performerIndex)
        let isSearching = viewModel.searchingDJKeys.contains(key)
        let selectedDJID = slot.performerDJIDs.indices.contains(performerIndex) ? slot.performerDJIDs[performerIndex] : nil
        let results = viewModel.djSearchResults[key] ?? []

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    Task { await viewModel.searchLineupDJ(slotID: slot.id, performerIndex: performerIndex) }
                } label: {
                    Label(
                        isSearching ? LT("搜索中", "Searching", "検索中") : LT("绑定 DJ 库", "Bind DJ", "DJを紐付け"),
                        systemImage: "magnifyingglass"
                    )
                    .font(.caption.weight(.bold))
                }
                .buttonStyle(.bordered)
                .disabled(isSearching)

                if selectedDJID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    Label(LT("已绑定", "Bound", "紐付け済み"), systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                    Button {
                        viewModel.clearLineupDJBinding(slotID: slot.id, performerIndex: performerIndex)
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.plain)
                }
            }

            if !results.isEmpty {
                VStack(spacing: 6) {
                    ForEach(results.prefix(8)) { dj in
                        Button {
                            viewModel.applyLineupDJ(dj, slotID: slot.id, performerIndex: performerIndex)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "music.mic.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(RaverTheme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dj.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(RaverTheme.primaryText)
                                    Text(dj.country ?? dj.slug ?? dj.id)
                                        .font(.caption2)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func reviewCard(title: String, rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(RaverTheme.primaryText)
            ForEach(rows.isEmpty ? [LT("未填写", "Not set", "未入力")] : rows, id: \.self) { row in
                Text(row)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(RaverTheme.primaryText)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
        }
    }

    private func successView(_ success: EventUploadSubmitSuccess) -> some View {
        VStack(spacing: 22) {
            Spacer(minLength: 40)

            ZStack {
                Circle()
                    .fill(RaverTheme.accent.opacity(0.14))
                    .frame(width: 92, height: 92)
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(RaverTheme.accent, in: Circle())
            }

            VStack(spacing: 10) {
                Text(success.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .multilineTextAlignment(.center)
                Text(success.message)
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 10) {
                Button {
                    viewModel.closeAfterSuccess()
                } label: {
                    Text(LT("返回活动页", "Back to Events", "イベントページへ戻る"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RaverTheme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Text(LT("之后也可以在我的发布里查看和管理。", "You can review and manage this later from My Posts.", "後からマイ投稿で確認・管理できます。"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }

    private var timeZoneSearchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            fieldTitle(LT("城市时区", "City Time Zone", "都市タイムゾーン"), isRequired: true)
            TextField(
                LT("输入城市或城市+州/国家", "Enter city or city + state/country", "都市または都市+州/国を入力"),
                text: timeZoneSearchBinding
            )
            .font(.body)
            .foregroundStyle(RaverTheme.primaryText)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(fieldBackground)

            HStack(spacing: 10) {
                Button {
                    Task { await viewModel.searchEventTimeZones() }
                } label: {
                    Label(
                        viewModel.isSearchingTimeZones ? LT("搜索中", "Searching", "検索中") : LT("搜索城市时区", "Search Time Zone", "タイムゾーン検索"),
                        systemImage: "magnifyingglass"
                    )
                    .font(.caption.weight(.bold))
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isSearchingTimeZones)

                Button {
                    viewModel.clearTimeZoneSelection()
                } label: {
                    Label(LT("清空", "Clear", "クリア"), systemImage: "xmark.circle")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.bordered)
            }

            Text(timeZoneSummary)
                .font(.caption)
                .foregroundStyle(viewModel.draft.selectedTimeZoneLookup == nil ? RaverTheme.secondaryText : .green)

            if !viewModel.timeZoneSearchResults.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.timeZoneSearchResults.prefix(8)) { item in
                        Button {
                            viewModel.applyTimeZoneSelection(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                Text(item.timezone)
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var timeZonePreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldTitle(LT("时区预览", "Time Zone Preview", "タイムゾーンプレビュー"), isRequired: false)
            VStack(alignment: .leading, spacing: 6) {
                Text(LT("活动城市", "Event City", "イベント都市"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                Text(formattedDateRange(timeZone: TimeZone(identifier: viewModel.draft.timeZoneIdentifier) ?? .current))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)

                Text(LT("当前设备", "Current Device", "現在の端末"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(.top, 2)
                Text(formattedDateRange(timeZone: .current))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(fieldBackground)
        }
    }

    private func formattedDateRange(timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(formatter.string(from: viewModel.draft.startDate)) - \(formatter.string(from: viewModel.draft.endDate)) · \(timeZone.identifier)"
    }

    private func uploadTextField(
        title: String,
        text: Binding<String>,
        isRequired: Bool = false,
        axis: Axis = .horizontal
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldTitle(title, isRequired: isRequired)
            TextField(title, text: text, axis: axis)
                .font(.body)
                .foregroundStyle(RaverTheme.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(axis == .vertical ? 5 : 1)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(fieldBackground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldTitle(_ title: String, isRequired: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            if isRequired {
                Text("*")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
            }
        }
    }

    private var fieldBackground: some ShapeStyle {
        RaverTheme.card
    }

    private var preferredLanguageHint: String {
        switch viewModel.draft.preferredLanguage {
        case .zh:
            return LT("当前按系统语言写入中文字段，其他语言暂不要求补齐。", "Currently writing to Chinese fields based on system language. Other languages are optional for now.", "システム言語に基づき中国語フィールドへ保存します。他言語の補完は現時点では不要です。")
        case .en:
            return LT("当前按系统语言写入英文字段，其他语言暂不要求补齐。", "Currently writing to English fields based on system language. Other languages are optional for now.", "システム言語に基づき英語フィールドへ保存します。他言語の補完は現時点では不要です。")
        case .ja:
            return LT("当前按系统语言写入日文字段，其他语言暂不要求补齐。", "Currently writing to Japanese fields based on system language. Other languages are optional for now.", "システム言語に基づき日本語フィールドへ保存します。他言語の補完は現時点では不要です。")
        }
    }

    private func localizedBinding(_ keyPath: WritableKeyPath<EventUploadDraft, EventUploadLocalizedFields>) -> Binding<String> {
        Binding {
            viewModel.draft[keyPath: keyPath].currentValue(preferredLanguage: viewModel.draft.preferredLanguage)
        } set: { value in
            viewModel.updateLocalizedField(keyPath, value: value)
        }
    }

    private var eventTypeBinding: Binding<String> {
        Binding {
            viewModel.draft.eventType
        } set: { value in
            viewModel.updateEventType(value)
        }
    }

    private func dateBinding(_ keyPath: WritableKeyPath<EventUploadDraft, Date>) -> Binding<Date> {
        Binding {
            viewModel.draft[keyPath: keyPath]
        } set: { value in
            viewModel.updateDate(keyPath, value: value)
        }
    }

    private var timeZoneSearchBinding: Binding<String> {
        Binding {
            viewModel.draft.timeZoneSearchQuery
        } set: { value in
            viewModel.updateTimeZoneSearchQuery(value)
        }
    }

    private var timeZoneSummary: String {
        if let item = viewModel.draft.selectedTimeZoneLookup {
            return LT("已确认：\(item.label)", "Confirmed: \(item.label)", "確認済み：\(item.label)")
        }
        if !viewModel.draft.timeZoneIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           case .edit = viewModel.draft.mode {
            return LT("当前活动时区：\(viewModel.draft.timeZoneIdentifier)。如需修改，请搜索城市并确认。", "Current event timezone: \(viewModel.draft.timeZoneIdentifier). Search a city to change it.", "現在のタイムゾーン：\(viewModel.draft.timeZoneIdentifier)。変更するには都市を検索してください。")
        }
        return LT("未确认活动城市时区", "No city timezone confirmed", "都市タイムゾーン未確認")
    }

    private var dayRolloverBinding: Binding<Int> {
        Binding {
            viewModel.draft.dayRolloverHour
        } set: { value in
            viewModel.updateDayRolloverHour(value)
        }
    }

    private func coordinateBinding(_ keyPath: WritableKeyPath<EventUploadDraft, Double?>) -> Binding<String> {
        Binding {
            viewModel.draft[keyPath: keyPath].map { String($0) } ?? ""
        } set: { value in
            viewModel.updateCoordinate(keyPath, rawValue: value)
        }
    }

    private func ticketBinding(_ keyPath: WritableKeyPath<EventUploadTicketDraft, String>) -> Binding<String> {
        Binding {
            viewModel.draft.ticket[keyPath: keyPath]
        } set: { value in
            viewModel.updateTicketField(keyPath, value: value)
        }
    }

    private func stageBinding(_ index: Int) -> Binding<String> {
        Binding {
            guard viewModel.draft.stageEntries.indices.contains(index) else { return "" }
            return viewModel.draft.stageEntries[index]
        } set: { value in
            viewModel.updateStage(at: index, value: value)
        }
    }

    private func lineupActTypeBinding(_ slotID: UUID) -> Binding<EventLineupActType> {
        Binding {
            viewModel.draft.lineupSlots.first(where: { $0.id == slotID })?.actType ?? .solo
        } set: { value in
            viewModel.updateLineupSlot(id: slotID) { slot in
                slot.actType = value
            }
        }
    }

    private func lineupPerformerBinding(_ slotID: UUID, performerIndex: Int) -> Binding<String> {
        Binding {
            guard let slot = viewModel.draft.lineupSlots.first(where: { $0.id == slotID }),
                  slot.performerNames.indices.contains(performerIndex) else { return "" }
            return slot.performerNames[performerIndex]
        } set: { value in
            viewModel.updateLineupSlot(id: slotID) { slot in
                while slot.performerNames.count <= performerIndex {
                    slot.performerNames.append("")
                }
                slot.performerNames[performerIndex] = value
            }
        }
    }

    private func lineupStageBinding(_ slotID: UUID) -> Binding<String> {
        Binding {
            viewModel.draft.lineupSlots.first(where: { $0.id == slotID })?.stageName ?? ""
        } set: { value in
            viewModel.updateLineupSlot(id: slotID) { slot in
                slot.stageName = value
            }
        }
    }

    private func lineupDayBinding(_ slotID: UUID) -> Binding<Int> {
        Binding {
            viewModel.draft.lineupSlots.first(where: { $0.id == slotID })?.dayIndex ?? 1
        } set: { value in
            viewModel.updateLineupSlot(id: slotID) { slot in
                slot.dayIndex = value
                slot.startTime = alignLineupDate(slot.startTime, toDayIndex: value)
                slot.endTime = alignLineupDate(slot.endTime, toDayIndex: value)
            }
        }
    }

    private func lineupTimedBinding(_ slotID: UUID) -> Binding<Bool> {
        Binding {
            guard let slot = viewModel.draft.lineupSlots.first(where: { $0.id == slotID }) else { return false }
            return slot.startTime != nil || slot.endTime != nil
        } set: { value in
            viewModel.setLineupSlotTimed(id: slotID, isTimed: value)
        }
    }

    private func lineupTimeBinding(_ slotID: UUID, keyPath: WritableKeyPath<EventUploadLineupSlotDraft, Date?>) -> Binding<Date> {
        Binding {
            viewModel.draft.lineupSlots.first(where: { $0.id == slotID })?[keyPath: keyPath] ?? Date()
        } set: { value in
            viewModel.updateLineupSlot(id: slotID) { slot in
                slot[keyPath: keyPath] = alignLineupClock(value, toDayIndex: slot.dayIndex)
            }
        }
    }

    private var lineupDayOptions: [EventUploadDayOption] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: viewModel.draft.timeZoneIdentifier) ?? .current
        let startDay = calendar.startOfDay(for: viewModel.draft.startDate)
        let endDay = max(viewModel.draft.endDate, viewModel.draft.startDate)
        let dayCount = min(max((calendar.dateComponents([.day], from: startDay, to: calendar.startOfDay(for: endDay)).day ?? 0) + 1, 1), 60)
        return (0..<dayCount).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: startDay) ?? startDay
            let title: String
            if viewModel.draft.scheduleMode == .multiWeek {
                title = LT("Week \(offset / 7 + 1) · Day \(offset % 7 + 1)", "Week \(offset / 7 + 1) · Day \(offset % 7 + 1)", "Week \(offset / 7 + 1) · Day \(offset % 7 + 1)")
            } else {
                title = LT("Day \(offset + 1)", "Day \(offset + 1)", "Day \(offset + 1)")
            }
            return EventUploadDayOption(dayIndex: offset + 1, title: title, date: date)
        }
    }

    private func alignLineupClock(_ value: Date, toDayIndex dayIndex: Int) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: viewModel.draft.timeZoneIdentifier) ?? .current
        let components = calendar.dateComponents([.hour, .minute], from: value)
        let baseDay = calendar.date(byAdding: .day, value: max(dayIndex - 1, 0), to: calendar.startOfDay(for: viewModel.draft.startDate)) ?? viewModel.draft.startDate
        return calendar.date(bySettingHour: components.hour ?? 0, minute: components.minute ?? 0, second: 0, of: baseDay) ?? value
    }

    private func alignLineupDate(_ value: Date?, toDayIndex dayIndex: Int) -> Date? {
        guard let value else { return nil }
        return alignLineupClock(value, toDayIndex: dayIndex)
    }

    private func placeholderStep(title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(RaverTheme.primaryText)
            Text(LT("这一页的详细控件会在后续实现中接入。", "Detailed controls for this step will be wired up next.", "このステップの詳細コントロールは次に実装します。"))
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }
}

private struct EventUploadDayOption: Identifiable, Hashable {
    var id: Int { dayIndex }
    let dayIndex: Int
    let title: String
    let date: Date
}
