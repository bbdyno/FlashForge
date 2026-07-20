//
//  AppDesignSystem.swift
//  FlashForge
//

import UIKit

enum AppTheme {
    private static func dynamic(_ light: UIColor, _ dark: UIColor) -> UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        }
    }

    // Editorial Mono: quiet neutral surfaces with one restrained indigo accent.
    static let backgroundTop = dynamic(
        UIColor(red: 0.965, green: 0.965, blue: 0.945, alpha: 1),
        UIColor(red: 0.065, green: 0.069, blue: 0.078, alpha: 1)
    )
    static let backgroundMid = dynamic(
        UIColor(red: 0.965, green: 0.965, blue: 0.945, alpha: 1),
        UIColor(red: 0.065, green: 0.069, blue: 0.078, alpha: 1)
    )
    static let backgroundBottom = dynamic(
        UIColor(red: 0.965, green: 0.965, blue: 0.945, alpha: 1),
        UIColor(red: 0.065, green: 0.069, blue: 0.078, alpha: 1)
    )

    static let cardBackground = dynamic(
        UIColor(red: 1.00, green: 1.00, blue: 0.995, alpha: 1),
        UIColor(red: 0.105, green: 0.110, blue: 0.122, alpha: 1)
    )
    static let cardBorder = dynamic(
        UIColor(red: 0.875, green: 0.875, blue: 0.845, alpha: 1),
        UIColor(red: 0.175, green: 0.183, blue: 0.202, alpha: 1)
    )
    static let textPrimary = dynamic(
        UIColor(red: 0.09, green: 0.095, blue: 0.105, alpha: 1),
        UIColor(red: 0.955, green: 0.955, blue: 0.935, alpha: 1)
    )
    static let textSecondary = dynamic(
        UIColor(red: 0.40, green: 0.405, blue: 0.43, alpha: 1),
        UIColor(red: 0.61, green: 0.62, blue: 0.65, alpha: 1)
    )

    static let ink = dynamic(
        UIColor(red: 0.09, green: 0.095, blue: 0.105, alpha: 1),
        UIColor(red: 0.955, green: 0.955, blue: 0.935, alpha: 1)
    )
    static let inkSurface = dynamic(
        UIColor(red: 0.09, green: 0.095, blue: 0.105, alpha: 1),
        UIColor(red: 0.17, green: 0.18, blue: 0.20, alpha: 1)
    )
    static let onInk = UIColor(red: 0.985, green: 0.985, blue: 0.97, alpha: 1)
    static let accent = dynamic(
        UIColor(red: 0.35, green: 0.31, blue: 0.82, alpha: 1),
        UIColor(red: 0.50, green: 0.47, blue: 0.95, alpha: 1)
    )
    static let accentSoft = dynamic(
        UIColor(red: 0.925, green: 0.915, blue: 0.985, alpha: 1),
        UIColor(red: 0.16, green: 0.145, blue: 0.265, alpha: 1)
    )
    static let accentTeal = dynamic(
        UIColor(red: 0.20, green: 0.46, blue: 0.38, alpha: 1),
        UIColor(red: 0.39, green: 0.71, blue: 0.60, alpha: 1)
    )
    static let tealSoft = dynamic(
        UIColor(red: 0.925, green: 0.930, blue: 0.915, alpha: 1),
        UIColor(red: 0.135, green: 0.145, blue: 0.150, alpha: 1)
    )
    static let infoBlue = dynamic(
        UIColor(red: 0.35, green: 0.31, blue: 0.82, alpha: 1),
        UIColor(red: 0.50, green: 0.47, blue: 0.95, alpha: 1)
    )
    static let dangerRed = dynamic(.systemRed, UIColor(red: 1, green: 0.38, blue: 0.37, alpha: 1))

    static let gradeAgain = dynamic(
        UIColor(red: 0.78, green: 0.20, blue: 0.18, alpha: 1),
        UIColor(red: 0.92, green: 0.32, blue: 0.29, alpha: 1)
    )
    static let gradeHard = dynamic(
        UIColor(red: 0.83, green: 0.44, blue: 0.08, alpha: 1),
        UIColor(red: 0.94, green: 0.56, blue: 0.18, alpha: 1)
    )
    static let gradeGood = dynamic(
        UIColor(red: 0.12, green: 0.43, blue: 0.68, alpha: 1),
        UIColor(red: 0.30, green: 0.61, blue: 0.87, alpha: 1)
    )
    static let gradeEasy = dynamic(
        UIColor(red: 0.08, green: 0.50, blue: 0.38, alpha: 1),
        UIColor(red: 0.23, green: 0.69, blue: 0.54, alpha: 1)
    )

    static let inputBackground = dynamic(
        UIColor(red: 0.925, green: 0.925, blue: 0.90, alpha: 1),
        UIColor(red: 0.135, green: 0.14, blue: 0.155, alpha: 1)
    )
    static let glassBorder = cardBorder
    static let glassFill = cardBackground
    static let glassHighlightStart = dynamic(
        UIColor.white.withAlphaComponent(0.18),
        UIColor.white.withAlphaComponent(0.025)
    )
    static let glassHighlightMid = UIColor.clear
    static let badgeBackground = accentSoft
    static let badgeBorder = accent.withAlphaComponent(0.28)
    static let shadowColor = dynamic(
        UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 0.12),
        UIColor.black.withAlphaComponent(0.30)
    )
    static let tabBarBackground = dynamic(
        UIColor(red: 0.985, green: 0.985, blue: 0.97, alpha: 0.98),
        UIColor(red: 0.075, green: 0.079, blue: 0.089, alpha: 0.98)
    )

    static func resolved(_ color: UIColor, for traitCollection: UITraitCollection) -> UIColor {
        color.resolvedColor(with: traitCollection)
    }

    static func buttonFill(from tint: UIColor, for traitCollection: UITraitCollection) -> UIColor {
        resolved(tint, for: traitCollection)
    }

    static func applyGradient(to layer: CAGradientLayer, traitCollection: UITraitCollection? = nil) {
        let traits = traitCollection ?? UITraitCollection.current
        layer.colors = [
            resolved(backgroundTop, for: traits).cgColor,
            resolved(backgroundMid, for: traits).cgColor,
            resolved(backgroundBottom, for: traits).cgColor
        ]
        layer.locations = [0, 0.48, 1]
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 0, y: 1)
    }

    static func styleSurface(_ view: UIView, radius: CGFloat = 18, shadow: Bool = false) {
        view.backgroundColor = cardBackground
        view.layer.cornerRadius = radius
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 0.5
        view.layer.borderColor = resolved(cardBorder, for: view.traitCollection).cgColor
        guard shadow else { return }
        view.layer.shadowColor = resolved(shadowColor, for: view.traitCollection).cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowRadius = 16
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
    }

    @MainActor
    static func makeNavigationAppearance() -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = backgroundTop
        appearance.shadowColor = cardBorder.withAlphaComponent(0.45)
        appearance.titleTextAttributes = [
            .foregroundColor: textPrimary,
            .font: AppTypography.font(size: 17, weight: .semibold, textStyle: .headline)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: textPrimary,
            .font: AppTypography.font(size: 32, weight: .bold, textStyle: .largeTitle)
        ]
        return appearance
    }
}

enum AppTypography {
    enum Weight {
        case regular
        case medium
        case semibold
        case bold

        fileprivate var postScriptName: String {
            switch self {
            case .regular:
                return "Manrope-Regular"
            case .medium:
                return "Manrope-Medium"
            case .semibold:
                return "Manrope-SemiBold"
            case .bold:
                return "Manrope-Bold"
            }
        }

        fileprivate var systemWeight: UIFont.Weight {
            switch self {
            case .regular:
                return .regular
            case .medium:
                return .medium
            case .semibold:
                return .semibold
            case .bold:
                return .bold
            }
        }
    }

    static func font(
        size: CGFloat,
        weight: Weight = .regular,
        textStyle: UIFont.TextStyle = .body,
        maximumPointSize: CGFloat? = nil
    ) -> UIFont {
        let base = UIFont(name: weight.postScriptName, size: size)
            ?? UIFont.systemFont(ofSize: size, weight: weight.systemWeight)
        let metrics = UIFontMetrics(forTextStyle: textStyle)
        if let maximumPointSize {
            return metrics.scaledFont(for: base, maximumPointSize: maximumPointSize)
        }
        return metrics.scaledFont(for: base)
    }

    static func applyTracking(_ tracking: CGFloat, to label: UILabel) {
        guard let text = label.text else { return }
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [.kern: tracking]
        )
    }
}
