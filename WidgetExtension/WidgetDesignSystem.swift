import SwiftUI
import UIKit

enum WidgetTheme {
    static let background = dynamicColor(
        light: UIColor(red: 0.965, green: 0.965, blue: 0.945, alpha: 1),
        dark: UIColor(red: 0.065, green: 0.069, blue: 0.078, alpha: 1)
    )
    static let surface = dynamicColor(
        light: UIColor(red: 1.00, green: 1.00, blue: 0.995, alpha: 1),
        dark: UIColor(red: 0.105, green: 0.110, blue: 0.122, alpha: 1)
    )
    static let border = dynamicColor(
        light: UIColor(red: 0.875, green: 0.875, blue: 0.845, alpha: 1),
        dark: UIColor(red: 0.175, green: 0.183, blue: 0.202, alpha: 1)
    )
    static let textPrimary = dynamicColor(
        light: UIColor(red: 0.09, green: 0.095, blue: 0.105, alpha: 1),
        dark: UIColor(red: 0.955, green: 0.955, blue: 0.935, alpha: 1)
    )
    static let textSecondary = dynamicColor(
        light: UIColor(red: 0.40, green: 0.405, blue: 0.43, alpha: 1),
        dark: UIColor(red: 0.61, green: 0.62, blue: 0.65, alpha: 1)
    )
    static let accent = dynamicColor(
        light: UIColor(red: 0.35, green: 0.31, blue: 0.82, alpha: 1),
        dark: UIColor(red: 0.50, green: 0.47, blue: 0.95, alpha: 1)
    )
    static let accentSoft = dynamicColor(
        light: UIColor(red: 0.925, green: 0.915, blue: 0.985, alpha: 1),
        dark: UIColor(red: 0.16, green: 0.145, blue: 0.265, alpha: 1)
    )
    static let success = dynamicColor(
        light: UIColor(red: 0.20, green: 0.46, blue: 0.38, alpha: 1),
        dark: UIColor(red: 0.39, green: 0.71, blue: 0.60, alpha: 1)
    )

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}

enum WidgetTypography {
    enum Weight: String {
        case regular = "Manrope-Regular"
        case medium = "Manrope-Medium"
        case semibold = "Manrope-SemiBold"
        case bold = "Manrope-Bold"
    }

    static func font(
        size: CGFloat,
        weight: Weight = .regular,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: textStyle)
    }
}
