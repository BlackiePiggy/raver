import SwiftUI
import UIKit

enum RaverTheme {
    static let appName = "RaveHub"
    static let background = Color(red: 0.03, green: 0.03, blue: 0.04)
    static let card = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let cardBorder = Color.white.opacity(0.1)
    static let primaryText = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let secondaryText = Color(red: 0.64, green: 0.64, blue: 0.68)
    static let accent = Color(red: 0.55, green: 0.36, blue: 0.96)

    static func brandFont(size: CGFloat) -> Font {
        if UIFont(name: "Futura-CondensedExtraBold", size: size) != nil {
            return .custom("Futura-CondensedExtraBold", size: size)
        }
        return .system(size: size, weight: .heavy, design: .rounded)
    }
}
