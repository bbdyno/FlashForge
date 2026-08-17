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

    // Soft Editorial: parchment in light mode, obsidian in dark mode, and one
    // warm copper accent. The palette stays tactile without turning the UI into
    // a retro terminal or a collection of glossy cards.
    static let backgroundTop = dynamic(
        UIColor(red: 0.949, green: 0.933, blue: 0.902, alpha: 1),
        UIColor(red: 0.043, green: 0.047, blue: 0.051, alpha: 1)
    )
    static let backgroundMid = dynamic(
        UIColor(red: 0.949, green: 0.933, blue: 0.902, alpha: 1),
        UIColor(red: 0.043, green: 0.047, blue: 0.051, alpha: 1)
    )
    static let backgroundBottom = dynamic(
        UIColor(red: 0.949, green: 0.933, blue: 0.902, alpha: 1),
        UIColor(red: 0.043, green: 0.047, blue: 0.051, alpha: 1)
    )

    static let cardBackground = dynamic(
        UIColor(red: 0.985, green: 0.973, blue: 0.945, alpha: 1),
        UIColor(red: 0.078, green: 0.082, blue: 0.086, alpha: 1)
    )
    static let cardBorder = dynamic(
        UIColor(red: 0.808, green: 0.776, blue: 0.718, alpha: 1),
        UIColor(red: 0.190, green: 0.190, blue: 0.184, alpha: 1)
    )
    static let textPrimary = dynamic(
        UIColor(red: 0.090, green: 0.086, blue: 0.078, alpha: 1),
        UIColor(red: 0.945, green: 0.922, blue: 0.875, alpha: 1)
    )
    static let textSecondary = dynamic(
        UIColor(red: 0.390, green: 0.370, blue: 0.335, alpha: 1),
        UIColor(red: 0.635, green: 0.608, blue: 0.558, alpha: 1)
    )

    // Study cards stay paper-like in both modes. In dark mode this creates the
    // deliberate editorial contrast used by the approved concept instead of
    // turning every surface into another dark panel.
    static let studyPaper = UIColor(red: 0.957, green: 0.925, blue: 0.855, alpha: 1)
    static let studyPaperSecondary = UIColor(red: 0.875, green: 0.831, blue: 0.748, alpha: 1)
    static let studyPaperTertiary = UIColor(red: 0.792, green: 0.745, blue: 0.663, alpha: 1)
    static let studyInk = UIColor(red: 0.075, green: 0.071, blue: 0.064, alpha: 1)
    static let studyMuted = UIColor(red: 0.337, green: 0.310, blue: 0.270, alpha: 1)
    static let studyLine = UIColor(red: 0.720, green: 0.667, blue: 0.580, alpha: 1)

    static let ink = dynamic(
        UIColor(red: 0.090, green: 0.086, blue: 0.078, alpha: 1),
        UIColor(red: 0.945, green: 0.922, blue: 0.875, alpha: 1)
    )
    static let inkSurface = dynamic(
        UIColor(red: 0.090, green: 0.086, blue: 0.078, alpha: 1),
        UIColor(red: 0.145, green: 0.137, blue: 0.126, alpha: 1)
    )
    static let onInk = UIColor(red: 0.965, green: 0.945, blue: 0.905, alpha: 1)
    static let accent = dynamic(
        UIColor(red: 0.680, green: 0.298, blue: 0.180, alpha: 1),
        UIColor(red: 0.855, green: 0.424, blue: 0.267, alpha: 1)
    )
    static let accentSoft = dynamic(
        UIColor(red: 0.938, green: 0.855, blue: 0.790, alpha: 1),
        UIColor(red: 0.190, green: 0.118, blue: 0.090, alpha: 1)
    )
    static let accentTeal = dynamic(
        UIColor(red: 0.220, green: 0.430, blue: 0.350, alpha: 1),
        UIColor(red: 0.405, green: 0.675, blue: 0.555, alpha: 1)
    )
    static let tealSoft = dynamic(
        UIColor(red: 0.888, green: 0.895, blue: 0.850, alpha: 1),
        UIColor(red: 0.090, green: 0.122, blue: 0.110, alpha: 1)
    )
    static let infoBlue = dynamic(
        UIColor(red: 0.285, green: 0.355, blue: 0.500, alpha: 1),
        UIColor(red: 0.480, green: 0.590, blue: 0.770, alpha: 1)
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
        UIColor(red: 0.900, green: 0.875, blue: 0.825, alpha: 1),
        UIColor(red: 0.105, green: 0.110, blue: 0.114, alpha: 1)
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
        UIColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 0.10),
        UIColor.black.withAlphaComponent(0.38)
    )
    static let tabBarBackground = dynamic(
        UIColor(red: 0.965, green: 0.945, blue: 0.905, alpha: 0.98),
        UIColor(red: 0.047, green: 0.051, blue: 0.055, alpha: 0.98)
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

    @MainActor
    static func styleSurface(_ view: UIView, radius: CGFloat = 18, shadow: Bool = false) {
        view.backgroundColor = cardBackground
        view.layer.cornerRadius = radius
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1.0 / UIScreen.main.scale
        view.layer.borderColor = resolved(cardBorder, for: view.traitCollection).cgColor
        guard shadow else { return }
        view.layer.shadowColor = resolved(shadowColor, for: view.traitCollection).cgColor
        view.layer.shadowOpacity = 0.05
        view.layer.shadowRadius = 18
        view.layer.shadowOffset = CGSize(width: 0, height: 10)
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

    @MainActor
    static func applyTracking(_ tracking: CGFloat, to label: UILabel) {
        guard let text = label.text else { return }
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [.kern: tracking]
        )
    }
}
