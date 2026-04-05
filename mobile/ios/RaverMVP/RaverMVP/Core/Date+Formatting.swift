import Foundation

extension Date {
    private static var appDateLanguageIsEnglish: Bool {
        AppLanguagePreference.current.effectiveLanguage == .en
    }

    private static func appDateFormatter(zhFormat: String, enFormat: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = appDateLanguageIsEnglish
            ? Locale(identifier: "en_US_POSIX")
            : Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = .current
        formatter.dateFormat = appDateLanguageIsEnglish ? enFormat : zhFormat
        return formatter
    }

    func appLocalizedYMDText() -> String {
        Self.appDateFormatter(zhFormat: "yyyy年M月d日", enFormat: "MMM d, yyyy")
            .string(from: self)
    }

    func appLocalizedDateRangeText(to endDate: Date) -> String {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: self)
        let endDay = calendar.startOfDay(for: endDate)

        guard endDay >= startDay else {
            return self.appLocalizedYMDText()
        }

        if Self.appDateLanguageIsEnglish {
            if calendar.isDate(startDay, inSameDayAs: endDay) {
                return self.appLocalizedYMDText()
            }
            return "\(self.appLocalizedYMDText()) - \(endDate.appLocalizedYMDText())"
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
        Self.appDateFormatter(zhFormat: "yyyy年M月d日 HH:mm", enFormat: "MMM d, yyyy HH:mm")
            .string(from: self)
    }

    func appLocalizedMDText() -> String {
        Self.appDateFormatter(zhFormat: "M月d日", enFormat: "MMM d")
            .string(from: self)
    }

    func appLocalizedYMText() -> String {
        Self.appDateFormatter(zhFormat: "yyyy年M月", enFormat: "MMMM yyyy")
            .string(from: self)
    }

    func appLocalizedYMDWeekdayText() -> String {
        Self.appDateFormatter(zhFormat: "yyyy年M月d日 EEE", enFormat: "EEE, MMM d, yyyy")
            .string(from: self)
    }

    func appLocalizedMonthBadgeText() -> String {
        if Self.appDateLanguageIsEnglish {
            return Self.appDateFormatter(zhFormat: "M月", enFormat: "MMM")
                .string(from: self)
                .uppercased()
        }
        return Self.appDateFormatter(zhFormat: "M月", enFormat: "MMM")
            .string(from: self)
    }

    var feedTimeText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var chatTimeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
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
