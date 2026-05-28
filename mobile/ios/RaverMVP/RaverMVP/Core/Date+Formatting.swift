import Foundation

struct EventDiscreteDateRange: Hashable, Identifiable {
    let id: String
    let weekIndex: Int
    let label: String?
    let startDate: Date
    let endDate: Date
}

func localizedEventWeekTitle(_ weekIndex: Int) -> String {
    LT("第 \(weekIndex) 周", "Week \(weekIndex)", "第\(weekIndex)週")
}

func localizedEventDayCountText(dayCount: Int) -> String {
    let count = max(dayCount, 1)
    return LT("共\(count)日", "\(count) days total", "全\(count)日")
}

func eventDiscreteDateSummaryDateLines(
    ranges: [EventDiscreteDateRange],
    fallbackStartDate: Date,
    fallbackEndDate: Date,
    timeZone: TimeZone
) -> [String] {
    guard !ranges.isEmpty else {
        return [
            Date.appLocalizedCompactDateRangeText(
                startDate: fallbackStartDate,
                endDate: fallbackEndDate,
                timeZone: timeZone,
                includeTimeZone: false
            )
        ]
    }

    return ranges.map { range in
        let prefix = ranges.count > 1 ? (range.label?.nilIfBlank ?? localizedEventWeekTitle(range.weekIndex)) : nil
        let summary = Date.appLocalizedCompactDateRangeText(
            startDate: range.startDate,
            endDate: range.endDate,
            timeZone: timeZone,
            includeTimeZone: false
        )
        if let prefix {
            return "\(prefix) · \(summary)"
        }
        return summary
    }
}

func eventDiscreteDateSummaryDisplayLines(
    dateLines: [String],
    dayCountText: String,
    timeZoneLabel: String? = nil
) -> [String] {
    let trimmedTimeZoneLabel = timeZoneLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let normalizedDateLines = dateLines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    guard let first = normalizedDateLines.first else {
        return dayCountText.isEmpty ? [] : [dayCountText]
    }

    if normalizedDateLines.count == 1 {
        var segments = [first]
        if !dayCountText.isEmpty {
            segments.append(dayCountText)
        }
        if !trimmedTimeZoneLabel.isEmpty {
            segments.append(trimmedTimeZoneLabel)
        }
        return [segments.joined(separator: " · ")]
    }

    let decoratedDateLines = normalizedDateLines.map { line in
        guard !trimmedTimeZoneLabel.isEmpty else { return line }
        return "\(line) · \(trimmedTimeZoneLabel)"
    }

    return dayCountText.isEmpty ? decoratedDateLines : decoratedDateLines + [dayCountText]
}

func eventDiscreteDateSummaryDisplayText(
    dateLines: [String],
    dayCountText: String,
    timeZone: TimeZone? = nil,
    separator: String = "\n"
) -> String {
    eventDiscreteDateSummaryDisplayLines(
        dateLines: dateLines,
        dayCountText: dayCountText,
        timeZoneLabel: timeZone.map(Date.appLocalizedTimeZoneLabel)
    ).joined(separator: separator)
}

private enum AppFormattingLocale {
    static var current: Locale {
        Locale(identifier: AppLanguagePreference.current.effectiveLanguage.localeIdentifier)
    }
}

extension Date {
    private static var appDateLanguage: AppLanguage {
        AppLanguagePreference.current.effectiveLanguage
    }

    private static func appDateFormatter(zhFormat: String, enFormat: String, jaFormat: String? = nil, timeZone: TimeZone = .current) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appDateLanguage.localeIdentifier)
        formatter.timeZone = timeZone
        switch appDateLanguage {
        case .zh, .system:
            formatter.dateFormat = zhFormat
        case .en:
            formatter.dateFormat = enFormat
        case .ja:
            formatter.dateFormat = jaFormat ?? zhFormat
        }
        return formatter
    }

    private static func appTimeZoneLabel(_ timeZone: TimeZone = .current) -> String {
        switch timeZone.identifier {
        case "Asia/Shanghai":
            return LT("北京时间", "Asia/Shanghai", "北京時間")
        case "Asia/Tokyo":
            return LT("东京时间", "Tokyo time", "東京時間")
        case "Asia/Hong_Kong":
            return LT("香港时间", "Hong Kong time", "香港時間")
        case "Asia/Taipei":
            return LT("台北时间", "Taipei time", "台北時間")
        case "Asia/Macau":
            return LT("澳门时间", "Macau time", "マカオ時間")
        case "America/Los_Angeles":
            return LT("洛杉矶时间", "Los Angeles time", "ロサンゼルス時間")
        case "America/New_York":
            return LT("纽约时间", "New York time", "ニューヨーク時間")
        case "America/Chicago":
            return LT("芝加哥时间", "Chicago time", "シカゴ時間")
        case "America/Mexico_City":
            return LT("墨西哥城时间", "Mexico City time", "メキシコシティ時間")
        case "America/Sao_Paulo":
            return LT("圣保罗时间", "Sao Paulo time", "サンパウロ時間")
        case "America/Santiago":
            return LT("圣地亚哥时间", "Santiago time", "サンティアゴ時間")
        case "America/Argentina/Buenos_Aires":
            return LT("布宜诺斯艾利斯时间", "Buenos Aires time", "ブエノスアイレス時間")
        case "Australia/Melbourne":
            return LT("墨尔本时间", "Melbourne time", "メルボルン時間")
        case "Australia/Brisbane":
            return LT("布里斯班时间", "Brisbane time", "ブリスベン時間")
        case "Europe/Berlin":
            return LT("柏林时间", "Berlin time", "ベルリン時間")
        case "Europe/Madrid":
            return LT("马德里时间", "Madrid time", "マドリード時間")
        case "Pacific/Auckland":
            return LT("奥克兰时间", "Auckland time", "オークランド時間")
        default:
            if timeZone.identifier == "UTC" {
                return "UTC"
            }
            if let cityName = timeZone.identifier.split(separator: "/").last {
                let readableName = cityName.replacingOccurrences(of: "_", with: " ")
                return LT("\(readableName)时间", "\(readableName) time", "\(readableName)時間")
            }
            return timeZone.identifier
        }
    }

    static func appLocalizedTimeZoneLabel(_ timeZone: TimeZone = .current) -> String {
        appTimeZoneLabel(timeZone)
    }

    private func appLocalizedYMDTextRaw(in timeZone: TimeZone = .current) -> String {
        Self.appDateFormatter(zhFormat: "yyyy年M月d日", enFormat: "MMM d, yyyy", timeZone: timeZone)
            .string(from: self)
    }

    func appLocalizedYMDText() -> String {
        "\(appLocalizedYMDTextRaw()) · \(Self.appTimeZoneLabel())"
    }

    func appLocalizedYMDText(in timeZone: TimeZone) -> String {
        "\(appLocalizedYMDTextRaw(in: timeZone)) · \(Self.appTimeZoneLabel(timeZone))"
    }

    func appLocalizedDateRangeText(to endDate: Date) -> String {
        appLocalizedDateRangeText(to: endDate, timeZone: .current)
    }

    func appLocalizedDateRangeText(to endDate: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startDay = calendar.startOfDay(for: self)
        let endDay = calendar.startOfDay(for: endDate)

        guard endDay >= startDay else {
            return self.appLocalizedYMDText(in: timeZone)
        }

        let suffix = " · \(Self.appTimeZoneLabel(timeZone))"

        if Self.appDateLanguage == .en {
            if calendar.isDate(startDay, inSameDayAs: endDay) {
                return self.appLocalizedYMDText(in: timeZone)
            }
            return "\(self.appLocalizedYMDTextRaw(in: timeZone)) - \(endDate.appLocalizedYMDTextRaw(in: timeZone))\(suffix)"
        }

        let startYear = calendar.component(.year, from: startDay)
        let startMonth = calendar.component(.month, from: startDay)
        let startDayOfMonth = calendar.component(.day, from: startDay)
        let endYear = calendar.component(.year, from: endDay)
        let endMonth = calendar.component(.month, from: endDay)
        let endDayOfMonth = calendar.component(.day, from: endDay)

        if startYear == endYear, startMonth == endMonth {
            if startDayOfMonth == endDayOfMonth {
                return "\(startYear)年\(startMonth)月\(startDayOfMonth)日\(suffix)"
            }
            return "\(startYear)年\(startMonth)月\(startDayOfMonth)日-\(endDayOfMonth)日\(suffix)"
        }

        if startYear == endYear {
            return "\(startYear)年\(startMonth)月\(startDayOfMonth)日-\(endMonth)月\(endDayOfMonth)日\(suffix)"
        }

        return "\(startYear)年\(startMonth)月\(startDayOfMonth)日-\(endYear)年\(endMonth)月\(endDayOfMonth)日\(suffix)"
    }

    static func appLocalizedCompactDateRangeText(
        startDate: Date,
        endDate: Date,
        timeZone: TimeZone,
        includeTimeZone: Bool = false
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        let suffix = includeTimeZone ? " · \(Self.appTimeZoneLabel(timeZone))" : ""

        guard endDay >= startDay else {
            return startDay.appLocalizedYMDTextRaw(in: timeZone) + suffix
        }

        if calendar.isDate(startDay, inSameDayAs: endDay) {
            return startDay.appLocalizedYMDTextRaw(in: timeZone) + suffix
        }

        let startYear = calendar.component(.year, from: startDay)
        let startMonth = calendar.component(.month, from: startDay)
        let startDayOfMonth = calendar.component(.day, from: startDay)
        let endYear = calendar.component(.year, from: endDay)
        let endMonth = calendar.component(.month, from: endDay)
        let endDayOfMonth = calendar.component(.day, from: endDay)

        switch appDateLanguage {
        case .zh, .system, .ja:
            let compact: String
            if startYear != endYear {
                compact = "\(startYear)年\(startMonth)月\(startDayOfMonth)日-\(endYear)年\(endMonth)月\(endDayOfMonth)日"
            } else if startMonth != endMonth {
                compact = "\(startYear)年\(startMonth)月\(startDayOfMonth)日-\(endMonth)月\(endDayOfMonth)日"
            } else {
                compact = "\(startYear)年\(startMonth)月\(startDayOfMonth)日-\(endDayOfMonth)日"
            }
            return compact + suffix
        case .en:
            let startFormatter = Self.appDateFormatter(
                zhFormat: "yyyy年M月d日",
                enFormat: "MMM d, yyyy",
                jaFormat: "yyyy年M月d日",
                timeZone: timeZone
            )
            let sameYearFormatter = Self.appDateFormatter(
                zhFormat: "M月d日",
                enFormat: "MMM d",
                jaFormat: "M月d日",
                timeZone: timeZone
            )
            let sameMonthFormatter = Self.appDateFormatter(
                zhFormat: "d日",
                enFormat: "d",
                jaFormat: "d日",
                timeZone: timeZone
            )

            let compact: String
            if startYear != endYear {
                compact = "\(startFormatter.string(from: startDay)) - \(startFormatter.string(from: endDay))"
            } else if startMonth != endMonth {
                compact = "\(startFormatter.string(from: startDay)) - \(sameYearFormatter.string(from: endDay))"
            } else {
                compact = "\(startFormatter.string(from: startDay)) - \(sameMonthFormatter.string(from: endDay))"
            }
            return compact + suffix
        }
    }

    func appLocalizedYMDHMText() -> String {
        "\(Self.appDateFormatter(zhFormat: "yyyy年M月d日 HH:mm", enFormat: "MMM d, yyyy HH:mm", jaFormat: "yyyy年M月d日 HH:mm").string(from: self)) · \(Self.appTimeZoneLabel())"
    }

    func appLocalizedMDText() -> String {
        Self.appDateFormatter(zhFormat: "M月d日", enFormat: "MMM d")
            .string(from: self)
    }

    func appLocalizedYMText() -> String {
        Self.appDateFormatter(zhFormat: "yyyy年M月", enFormat: "MMMM yyyy", jaFormat: "yyyy年M月")
            .string(from: self)
    }

    func appLocalizedYMText(in timeZone: TimeZone) -> String {
        Self.appDateFormatter(zhFormat: "yyyy年M月", enFormat: "MMMM yyyy", jaFormat: "yyyy年M月", timeZone: timeZone)
            .string(from: self)
    }

    func appLocalizedYMDWeekdayText() -> String {
        Self.appDateFormatter(zhFormat: "yyyy年M月d日 EEE", enFormat: "EEE, MMM d, yyyy", jaFormat: "yyyy年M月d日 EEE")
            .string(from: self)
    }

    func appLocalizedMonthBadgeText() -> String {
        if Self.appDateLanguage == .en {
            return Self.appDateFormatter(zhFormat: "M月", enFormat: "MMM")
                .string(from: self)
                .uppercased()
        }
        return Self.appDateFormatter(zhFormat: "M月", enFormat: "MMM")
            .string(from: self)
    }

    func appLocalizedMonthBadgeText(in timeZone: TimeZone) -> String {
        if Self.appDateLanguage == .en {
            return Self.appDateFormatter(zhFormat: "M月", enFormat: "MMM", timeZone: timeZone)
                .string(from: self)
                .uppercased()
        }
        return Self.appDateFormatter(zhFormat: "M月", enFormat: "MMM", timeZone: timeZone)
            .string(from: self)
    }

    var feedTimeText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: AppLanguagePreference.current.effectiveLanguage.localeIdentifier)
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var chatTimeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
}

extension BinaryInteger {
    func appLocalizedNumberText() -> String {
        Double(self).appLocalizedNumberText(maximumFractionDigits: 0)
    }
}

extension BinaryFloatingPoint {
    func appLocalizedNumberText(
        minimumFractionDigits: Int = 0,
        maximumFractionDigits: Int = 2
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = AppFormattingLocale.current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: Double(self))) ?? String(Double(self))
    }

    func appLocalizedCurrencyText(
        currencyCode: String?,
        minimumFractionDigits: Int = 0,
        maximumFractionDigits: Int = 2
    ) -> String {
        let normalizedCurrency = currencyCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .nilIfEmpty
            ?? "CNY"
        let formatter = NumberFormatter()
        formatter.locale = AppFormattingLocale.current
        formatter.numberStyle = .currency
        formatter.currencyCode = normalizedCurrency
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: Double(self)))
            ?? "\(normalizedCurrency) \(appLocalizedNumberText(minimumFractionDigits: minimumFractionDigits, maximumFractionDigits: maximumFractionDigits))"
    }
}

extension JSONDecoder {
    static var raver: JSONDecoder {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        fractional.timeZone = TimeZone(secondsFromGMT: 0)

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        plain.timeZone = TimeZone(secondsFromGMT: 0)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let parsed = fractional.date(from: raw) ?? plain.date(from: raw) {
                return parsed
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(raw)"
            )
        }
        return decoder
    }
}

extension JSONEncoder {
    static var raver: JSONEncoder {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        fractional.timeZone = TimeZone(secondsFromGMT: 0)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(fractional.string(from: date))
        }
        return encoder
    }
}

extension Date {
    func eventArchiveDateText(in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }

    func normalizedEventArchiveDate(in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: self)
        return calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: components.year,
            month: components.month,
            day: components.day,
            hour: 12,
            minute: 0,
            second: 0
        )) ?? self
    }

    static func eventArchiveDate(from text: String, timeZone: TimeZone) -> Date? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let match = normalized.wholeMatch(of: /(\d{4})-(\d{2})-(\d{2})/)
        guard let match else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: Int(match.1),
            month: Int(match.2),
            day: Int(match.3),
            hour: 12,
            minute: 0,
            second: 0
        ))
    }
}
