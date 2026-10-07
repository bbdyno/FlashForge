import SwiftUI
import UIKit

enum WidgetTheme {
    // Mirrors AppTheme's Colour Field palette; the widget target cannot import it.
    static let background = dynamicColor(
        light: UIColor(red: 0.984, green: 0.973, blue: 0.945, alpha: 1),
        dark: UIColor(red: 0.086, green: 0.082, blue: 0.075, alpha: 1)
    )
    static let surface = dynamicColor(
        light: UIColor(red: 1.000, green: 0.992, blue: 0.973, alpha: 1),
        dark: UIColor(red: 0.129, green: 0.122, blue: 0.110, alpha: 1)
    )
    static let border = dynamicColor(
        light: UIColor(red: 0.086, green: 0.082, blue: 0.075, alpha: 1),
        dark: UIColor(red: 0.945, green: 0.922, blue: 0.867, alpha: 1)
    )
    static let textPrimary = dynamicColor(
        light: UIColor(red: 0.086, green: 0.082, blue: 0.075, alpha: 1),
        dark: UIColor(red: 0.965, green: 0.945, blue: 0.902, alpha: 1)
    )
    static let textSecondary = dynamicColor(
        light: UIColor(red: 0.420, green: 0.400, blue: 0.369, alpha: 1),
        dark: UIColor(red: 0.659, green: 0.631, blue: 0.584, alpha: 1)
    )
    static let accent = dynamicColor(
        light: UIColor(red: 0.086, green: 0.082, blue: 0.075, alpha: 1),
        dark: UIColor(red: 0.878, green: 0.933, blue: 0.612, alpha: 1)
    )
    static let accentSoft = dynamicColor(
        light: UIColor(red: 0.878, green: 0.933, blue: 0.612, alpha: 1),
        dark: UIColor(red: 0.184, green: 0.212, blue: 0.094, alpha: 1)
    )
    static let success = dynamicColor(
        light: UIColor(red: 0.184, green: 0.420, blue: 0.310, alpha: 1),
        dark: UIColor(red: 0.710, green: 0.839, blue: 0.478, alpha: 1)
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
