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

    func appLocalizedYMDText() -> String {
        Self.appDateFormatter(zhFormat: "yyyy年M月d日", enFormat: "MMM d, yyyy")
            .string(from: self)
    }

    func appLocalizedYMDText(in timeZone: TimeZone) -> String {
        Self.appDateFormatter(zhFormat: "yyyy年M月d日", enFormat: "MMM d, yyyy", timeZone: timeZone)
            .string(from: self)
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

        if Self.appDateLanguage == .en {
            if calendar.isDate(startDay, inSameDayAs: endDay) {
                return self.appLocalizedYMDText(in: timeZone)
            }
            return "\(self.appLocalizedYMDText(in: timeZone)) - \(endDate.appLocalizedYMDText(in: timeZone))"
        }

        let startYear = calendar.component(.year, from: startDay)
        let startMonth = calendar.component(.month, from: startDay)
        let startDayOfMonth = calendar.component(.day, from: startDay)
        let endYear = calendar.component(.year, from: endDay)
        let endMonth = calendar.component(.month, from: endDay)
        let endDayOfMonth = calendar.component(.day, from: endDay)

        if startYear == endYear, startMonth == endMonth {
            if startDayOfMonth == endDayOfMonth {
                return "\(startYear)年\(startMonth)月\(startDayOfMonth)日"
            }
            return "\(startYear)年\(startMonth)月\(startDayOfMonth)日-\(endDayOfMonth)日"
        }

        if startYear == endYear {
            return "\(startYear)年\(startMonth)月\(startDayOfMonth)日-\(endMonth)月\(endDayOfMonth)日"
        }

        return "\(startYear)年\(startMonth)月\(startDayOfMonth)日-\(endYear)年\(endMonth)月\(endDayOfMonth)日"
    }

    func appLocalizedYMDHMText() -> String {
        Self.appDateFormatter(zhFormat: "yyyy年M月d日 HH:mm", enFormat: "MMM d, yyyy HH:mm", jaFormat: "yyyy年M月d日 HH:mm")
            .string(from: self)
    }

    func appLocalizedMDText() -> String {
        Self.appDateFormatter(zhFormat: "M月d日", enFormat: "MMM d")
            .string(from: self)
    }

    func appLocalizedYMText() -> String {
        Self.appDateFormatter(zhFormat: "yyyy年M月", enFormat: "MMMM yyyy", jaFormat: "yyyy年M月")
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
