import Foundation

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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var raver: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
