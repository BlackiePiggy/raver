import SwiftUI
import UIKit

enum RaverTheme {
    static let appName = "RaveHub"
    static let background = dynamicColor(
        light: UIColor(red: 0.97, green: 0.97, blue: 0.985, alpha: 1),
        dark: UIColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 1)
    )
    static let card = dynamicColor(
        light: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
        dark: UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
    )
    static let cardBorder = dynamicColor(
        light: UIColor.black.withAlphaComponent(0.08),
        dark: UIColor.white.withAlphaComponent(0.10)
    )
    static let primaryText = dynamicColor(
        light: UIColor(red: 0.10, green: 0.10, blue: 0.13, alpha: 1),
        dark: UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)
    )
    static let secondaryText = dynamicColor(
        light: UIColor(red: 0.42, green: 0.44, blue: 0.50, alpha: 1),
        dark: UIColor(red: 0.64, green: 0.64, blue: 0.68, alpha: 1)
    )
    static let accent = dynamicColor(
        light: UIColor(red: 0.42, green: 0.26, blue: 0.86, alpha: 1),
        dark: UIColor(red: 0.55, green: 0.36, blue: 0.96, alpha: 1)
    )
    static let tabBarChromeStart = dynamicColor(
        light: UIColor(red: 0.98, green: 0.98, blue: 1.0, alpha: 0.86),
        dark: UIColor(red: 0.10, green: 0.08, blue: 0.16, alpha: 0.20)
    )
    static let tabBarChromeEnd = dynamicColor(
        light: UIColor(red: 0.93, green: 0.91, blue: 0.99, alpha: 0.82),
        dark: UIColor(red: 0.15, green: 0.10, blue: 0.25, alpha: 0.20)
    )
    static let tabBarSelectionStart = dynamicColor(
        light: UIColor(red: 0.49, green: 0.36, blue: 0.95, alpha: 0.92),
        dark: UIColor(red: 0.52, green: 0.40, blue: 0.98, alpha: 0.62)
    )
    static let tabBarSelectionEnd = dynamicColor(
        light: UIColor(red: 0.38, green: 0.27, blue: 0.88, alpha: 0.88),
        dark: UIColor(red: 0.42, green: 0.29, blue: 0.90, alpha: 0.56)
    )
    static let tabBarStrokeLeading = dynamicColor(
        light: UIColor.white.withAlphaComponent(0.88),
        dark: UIColor.white.withAlphaComponent(0.24)
    )
    static let tabBarStrokeTrailing = dynamicColor(
        light: UIColor(red: 0.72, green: 0.62, blue: 1.0, alpha: 0.18),
        dark: UIColor(red: 0.72, green: 0.62, blue: 1.0, alpha: 0.28)
    )
    static let tabBarSelectionStroke = dynamicColor(
        light: UIColor.white.withAlphaComponent(0.46),
        dark: UIColor.white.withAlphaComponent(0.18)
    )
    static let tabBarShadowPrimary = dynamicColor(
        light: UIColor.black.withAlphaComponent(0.10),
        dark: UIColor.black.withAlphaComponent(0.46)
    )
    static let tabBarShadowAccent = dynamicColor(
        light: UIColor(red: 0.43, green: 0.30, blue: 0.92, alpha: 0.10),
        dark: UIColor(red: 0.43, green: 0.30, blue: 0.92, alpha: 0.24)
    )

    static func brandFont(size: CGFloat) -> Font {
        if UIFont(name: "Futura-CondensedExtraBold", size: size) != nil {
            return .custom("Futura-CondensedExtraBold", size: size)
        }
        return .system(size: size, weight: .heavy, design: .rounded)
    }

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(
            UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}
