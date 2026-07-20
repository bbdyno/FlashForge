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

    // Calm Forge: warm paper, deep ink, and a single ember action color.
    static let backgroundTop = dynamic(
        UIColor(red: 0.97, green: 0.95, blue: 0.91, alpha: 1),
        UIColor(red: 0.055, green: 0.075, blue: 0.11, alpha: 1)
    )
    static let backgroundMid = dynamic(
        UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1),
        UIColor(red: 0.065, green: 0.09, blue: 0.13, alpha: 1)
    )
    static let backgroundBottom = dynamic(
        UIColor(red: 0.94, green: 0.92, blue: 0.88, alpha: 1),
        UIColor(red: 0.075, green: 0.105, blue: 0.15, alpha: 1)
    )

    static let cardBackground = dynamic(
        UIColor(red: 1.00, green: 0.995, blue: 0.98, alpha: 1),
        UIColor(red: 0.09, green: 0.125, blue: 0.18, alpha: 1)
    )
    static let cardBorder = dynamic(
        UIColor(red: 0.83, green: 0.80, blue: 0.74, alpha: 1),
        UIColor(red: 0.23, green: 0.28, blue: 0.36, alpha: 1)
    )
    static let textPrimary = dynamic(
        UIColor(red: 0.075, green: 0.105, blue: 0.17, alpha: 1),
        UIColor(red: 0.965, green: 0.95, blue: 0.91, alpha: 1)
    )
    static let textSecondary = dynamic(
        UIColor(red: 0.36, green: 0.38, blue: 0.41, alpha: 1),
        UIColor(red: 0.68, green: 0.71, blue: 0.76, alpha: 1)
    )

    static let ink = dynamic(
        UIColor(red: 0.075, green: 0.12, blue: 0.22, alpha: 1),
        UIColor(red: 0.965, green: 0.95, blue: 0.91, alpha: 1)
    )
    static let inkSurface = dynamic(
        UIColor(red: 0.075, green: 0.12, blue: 0.22, alpha: 1),
        UIColor(red: 0.12, green: 0.17, blue: 0.25, alpha: 1)
    )
    static let onInk = UIColor(red: 0.985, green: 0.97, blue: 0.93, alpha: 1)
    static let accent = dynamic(
        UIColor(red: 0.95, green: 0.29, blue: 0.18, alpha: 1),
        UIColor(red: 1.00, green: 0.40, blue: 0.28, alpha: 1)
    )
    static let accentSoft = dynamic(
        UIColor(red: 1.00, green: 0.88, blue: 0.82, alpha: 1),
        UIColor(red: 0.28, green: 0.13, blue: 0.12, alpha: 1)
    )
    static let accentTeal = dynamic(
        UIColor(red: 0.05, green: 0.55, blue: 0.54, alpha: 1),
        UIColor(red: 0.25, green: 0.76, blue: 0.73, alpha: 1)
    )
    static let tealSoft = dynamic(
        UIColor(red: 0.83, green: 0.94, blue: 0.91, alpha: 1),
        UIColor(red: 0.08, green: 0.25, blue: 0.26, alpha: 1)
    )
    static let infoBlue = dynamic(
        UIColor(red: 0.22, green: 0.38, blue: 0.68, alpha: 1),
        UIColor(red: 0.45, green: 0.61, blue: 0.92, alpha: 1)
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
        UIColor(red: 0.92, green: 0.90, blue: 0.85, alpha: 1),
        UIColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1)
    )
    static let glassBorder = cardBorder
    static let glassFill = cardBackground
    static let glassHighlightStart = dynamic(
        UIColor.white.withAlphaComponent(0.72),
        UIColor.white.withAlphaComponent(0.06)
    )
    static let glassHighlightMid = UIColor.clear
    static let badgeBackground = accentSoft
    static let badgeBorder = accent.withAlphaComponent(0.28)
    static let shadowColor = dynamic(
        UIColor(red: 0.08, green: 0.10, blue: 0.13, alpha: 0.18),
        UIColor.black.withAlphaComponent(0.45)
    )
    static let tabBarBackground = dynamic(
        UIColor(red: 0.99, green: 0.98, blue: 0.95, alpha: 0.96),
        UIColor(red: 0.07, green: 0.095, blue: 0.14, alpha: 0.96)
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
        layer.startPoint = CGPoint(x: 0.08, y: 0)
        layer.endPoint = CGPoint(x: 0.92, y: 1)
    }

    static func styleSurface(_ view: UIView, radius: CGFloat = 20, shadow: Bool = false) {
        view.backgroundColor = cardBackground
        view.layer.cornerRadius = radius
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1
        view.layer.borderColor = resolved(cardBorder, for: view.traitCollection).cgColor
        guard shadow else { return }
        view.layer.shadowColor = resolved(shadowColor, for: view.traitCollection).cgColor
        view.layer.shadowOpacity = 0.12
        view.layer.shadowRadius = 22
        view.layer.shadowOffset = CGSize(width: 0, height: 12)
    }

    @MainActor
    static func makeNavigationAppearance() -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = backgroundTop
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: textPrimary,
            .font: AppTypography.font(size: 17, weight: .semibold, textStyle: .headline)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: textPrimary,
            .font: AppTypography.font(size: 34, weight: .bold, textStyle: .largeTitle)
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
