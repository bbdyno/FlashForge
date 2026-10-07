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

    private static func hex(_ value: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    // Colour Field: flat paper, one ink for every outline and label, and a
    // small set of pastel fields that carry the colour. Nothing is tinted,
    // blurred or softly shadowed.
    static let outlineWidth: CGFloat = 1.5

    static let lilac = hex(0xE6D6FA)
    static let lime = hex(0xE0EE9C)
    static let peach = hex(0xFFD0B0)
    static let sky = hex(0xCDE4F7)
    static let butter = hex(0xF6E3A1)
    static let tomato = hex(0xE8553A)
    static let fieldColors = [lilac, lime, peach, sky, butter]

    static let backgroundTop = dynamic(hex(0xFBF8F1), hex(0x161513))
    static let backgroundMid = backgroundTop
    static let backgroundBottom = backgroundTop

    static let cardBackground = dynamic(hex(0xFFFDF8), hex(0x211F1C))
    static let cardBorder = dynamic(hex(0x161513), hex(0xF1EBDD))
    static let textPrimary = dynamic(hex(0x161513), hex(0xF6F1E6))
    static let textSecondary = dynamic(hex(0x6B665E), hex(0xA8A195))

    // Study cards and colour fields look the same in both modes, so anything
    // drawn on them uses these fixed inks rather than the dynamic text colours.
    static let studyPaper = hex(0xFFFDF8)
    static let studyPaperSecondary = peach
    static let studyPaperTertiary = lime
    static let studyInk = hex(0x161513)
    static let studyMuted = hex(0x6B665E)
    static let studyLine = hex(0x161513)

    static let ink = textPrimary
    static let inkSurface = dynamic(hex(0x161513), hex(0x2B2823))
    static let onInk = hex(0xFFFDF8)
    // The one filled control on a screen: ink on paper, lime on the dark canvas.
    static let emphasisFill = dynamic(hex(0x161513), lime)
    static let onEmphasis = dynamic(hex(0xFFFDF8), hex(0x161513))
    static let accent = dynamic(hex(0xD9472B), hex(0xF0694D))
    static let accentSoft = dynamic(peach, hex(0x4A2A1E))
    static let accentTeal = dynamic(hex(0x2F6B4F), hex(0xB5D67A))
    static let tealSoft = dynamic(lime, hex(0x2F3618))
    static let infoBlue = dynamic(hex(0x2F5F8A), hex(0x8DBBE6))
    static let dangerRed = dynamic(hex(0xC8321C), hex(0xFF6A5B))

    static let gradeAgain = dynamic(hex(0xC8321C), hex(0xEB524A))
    static let gradeHard = dynamic(hex(0xD47014), hex(0xF08F2E))
    static let gradeGood = dynamic(hex(0x1F6EAD), hex(0x4D9CDE))
    static let gradeEasy = dynamic(hex(0x148061), hex(0x3BB08A))

    static let inputBackground = dynamic(hex(0xF1ECE1), hex(0x26231F))
    static let glassBorder = cardBorder
    static let glassFill = cardBackground
    static let glassHighlightStart = UIColor.clear
    static let glassHighlightMid = UIColor.clear
    static let badgeBackground = accentSoft
    static let badgeBorder = cardBorder
    static let shadowColor = cardBorder
    static let tabBarBackground = backgroundTop

    // Deck colours are derived, not stored: each deck hashes to a field colour,
    // and a deck that would repeat its neighbour's colour takes the next one.
    // Pass decks in the order the Library lists them.
    static func fieldColors(for orderedIDs: [UUID]) -> [UUID: UIColor] {
        var result: [UUID: UIColor] = [:]
        var previousIndex: Int?
        for id in orderedIDs {
            let seed = withUnsafeBytes(of: id.uuid) { $0.reduce(0) { ($0 &* 31) &+ Int($1) } }
            var index = abs(seed) % fieldColors.count
            if index == previousIndex {
                index = (index + 1) % fieldColors.count
            }
            result[id] = fieldColors[index]
            previousIndex = index
        }
        return result
    }

    static func canvasColor(for field: UIColor?) -> UIColor {
        guard let field else {
            return backgroundTop
        }
        return dynamic(field, hex(0x161513))
    }

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
        view.layer.borderWidth = outlineWidth
        view.layer.borderColor = resolved(cardBorder, for: view.traitCollection).cgColor
        guard shadow else { return }
        applyHardShadow(to: view)
    }

    @MainActor
    static func applyHardShadow(to view: UIView, offset: CGFloat = 3) {
        view.layer.shadowColor = resolved(shadowColor, for: view.traitCollection).cgColor
        view.layer.shadowOpacity = 1
        view.layer.shadowRadius = 0
        view.layer.shadowOffset = CGSize(width: offset, height: offset)
    }

    @MainActor
    static func styleOutline(_ view: UIView, radius: CGFloat, color: UIColor = cardBorder) {
        view.layer.cornerRadius = radius
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = outlineWidth
        view.layer.borderColor = resolved(color, for: view.traitCollection).cgColor
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
            .font: AppTypography.display(size: 34, textStyle: .largeTitle)
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

    // Newsreader for Latin and numerals, falling back to Noto Serif KR for
    // Hangul so mixed-language titles stay in one serif voice.
    static func display(
        size: CGFloat,
        textStyle: UIFont.TextStyle = .title1,
        maximumPointSize: CGFloat? = nil
    ) -> UIFont {
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: "NewsreaderDisplay-Medium",
            .cascadeList: [UIFontDescriptor(fontAttributes: [.name: "NotoSerifKR-SemiBold"])]
        ])
        let base = UIFont(descriptor: descriptor, size: size)
        let metrics = UIFontMetrics(forTextStyle: textStyle)
        if let maximumPointSize {
            return metrics.scaledFont(for: base, maximumPointSize: maximumPointSize)
        }
        return metrics.scaledFont(for: base)
    }

    static func displayItalic(size: CGFloat, textStyle: UIFont.TextStyle = .subheadline) -> UIFont {
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: "NewsreaderText-Italic",
            .cascadeList: [UIFontDescriptor(fontAttributes: [.name: "NotoSerifKR-SemiBold"])]
        ])
        let base = UIFont(descriptor: descriptor, size: size)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
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

// Phosphor icons (MIT). The catalog stores them as 256pt vectors, so they are
// redrawn at the requested point size and tinted like SF Symbols.
enum AppIcon {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(_ name: String, size: CGFloat = 20) -> UIImage? {
        let key = "\(name)@\(size)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let source = UIImage(named: "Icons/\(name)") else {
            return nil
        }
        let target = CGSize(width: size, height: size)
        let image = UIGraphicsImageRenderer(size: target).image { _ in
            source.draw(in: CGRect(origin: .zero, size: target))
        }
        .withRenderingMode(.alwaysTemplate)
        cache.setObject(image, forKey: key)
        return image
    }
}
