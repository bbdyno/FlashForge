//
//  WalkthroughArtworkView.swift
//  FlashForge
//
//  Hand-drawn vector artwork for onboarding. The illustrations are rendered
//  from paths so they remain crisp, theme-aware, and independent of generated
//  or stock imagery.

import UIKit

enum WalkthroughArtworkKind {
    case memory
    case study
    case privacy
}

final class WalkthroughArtworkView: UIView {
    private let kind: WalkthroughArtworkKind

    init(kind: WalkthroughArtworkKind) {
        self.kind = kind
        super.init(frame: .zero)
        isOpaque = false
        contentMode = .redraw
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true else {
            return
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        drawCanvas(in: rect)

        switch kind {
        case .memory:
            drawMemory(in: rect)
        case .study:
            drawStudy(in: rect)
        case .privacy:
            drawPrivacy(in: rect)
        }

        context.restoreGState()
    }

    private var primary: UIColor {
        AppTheme.resolved(AppTheme.textPrimary, for: traitCollection)
    }

    private var secondary: UIColor {
        AppTheme.resolved(AppTheme.textSecondary, for: traitCollection)
    }

    private var surface: UIColor {
        AppTheme.resolved(AppTheme.cardBackground, for: traitCollection)
    }

    private var input: UIColor {
        AppTheme.resolved(AppTheme.inputBackground, for: traitCollection)
    }

    private var border: UIColor {
        AppTheme.resolved(AppTheme.cardBorder, for: traitCollection)
    }

    private var accent: UIColor {
        AppTheme.resolved(AppTheme.accent, for: traitCollection)
    }

    private func drawCanvas(in rect: CGRect) {
        let canvas = UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 24)
        surface.setFill()
        canvas.fill()
        border.setStroke()
        canvas.lineWidth = 1
        canvas.stroke()
    }

    private func drawMemory(in rect: CGRect) {
        let width = min(rect.width * 0.60, 210)
        let height = width * 0.70
        let origin = CGPoint(x: rect.midX - width / 2, y: rect.midY - height / 2 + 8)

        for index in stride(from: 2, through: 0, by: -1) {
            let offset = CGFloat(index) * 13
            let cardRect = CGRect(
                x: origin.x + offset,
                y: origin.y - offset,
                width: width,
                height: height
            )
            let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 18)
            (index == 0 ? surface : input).setFill()
            path.fill()
            (index == 0 ? accent : border).setStroke()
            path.lineWidth = index == 0 ? 2 : 1
            path.stroke()
        }

        let lineY = origin.y + height * 0.42
        drawLine(from: CGPoint(x: origin.x + 24, y: lineY),
                 to: CGPoint(x: origin.x + width - 24, y: lineY),
                 color: primary,
                 width: 3)
        drawLine(from: CGPoint(x: origin.x + 24, y: lineY + 20),
                 to: CGPoint(x: origin.x + width * 0.64, y: lineY + 20),
                 color: secondary,
                 width: 2)

        let orbitRect = CGRect(x: rect.midX - 118, y: rect.midY - 104, width: 236, height: 208)
        let orbit = UIBezierPath(ovalIn: orbitRect)
        border.withAlphaComponent(0.7).setStroke()
        orbit.lineWidth = 1
        orbit.setLineDash([5, 8], count: 2, phase: 0)
        orbit.stroke()
        drawDot(at: CGPoint(x: orbitRect.maxX - 14, y: orbitRect.midY - 50), radius: 7, color: accent)
        drawDot(at: CGPoint(x: orbitRect.minX + 24, y: orbitRect.maxY - 42), radius: 4, color: secondary)
    }

    private func drawStudy(in rect: CGRect) {
        let cardWidth = min(rect.width * 0.62, 220)
        let cardHeight = cardWidth * 0.82
        let backRect = CGRect(
            x: rect.midX - cardWidth / 2 + 18,
            y: rect.midY - cardHeight / 2 - 18,
            width: cardWidth,
            height: cardHeight
        )
        let frontRect = backRect.offsetBy(dx: -36, dy: 30)

        let back = UIBezierPath(roundedRect: backRect, cornerRadius: 20)
        input.setFill()
        back.fill()
        border.setStroke()
        back.lineWidth = 1
        back.stroke()

        let front = UIBezierPath(roundedRect: frontRect, cornerRadius: 20)
        surface.setFill()
        front.fill()
        accent.setStroke()
        front.lineWidth = 2
        front.stroke()

        drawLine(from: CGPoint(x: frontRect.minX + 26, y: frontRect.midY - 24),
                 to: CGPoint(x: frontRect.maxX - 26, y: frontRect.midY - 24),
                 color: primary,
                 width: 3)
        drawLine(from: CGPoint(x: frontRect.minX + 26, y: frontRect.midY),
                 to: CGPoint(x: frontRect.maxX - 56, y: frontRect.midY),
                 color: secondary,
                 width: 2)

        let ratingsY = frontRect.maxY - 30
        let colors = [AppTheme.gradeAgain, AppTheme.gradeHard, AppTheme.gradeGood, AppTheme.gradeEasy]
        for (index, color) in colors.enumerated() {
            let x = frontRect.minX + 34 + CGFloat(index) * 38
            drawDot(
                at: CGPoint(x: x, y: ratingsY),
                radius: 7,
                color: AppTheme.resolved(color, for: traitCollection)
            )
        }

        let arrowStart = CGPoint(x: backRect.maxX - 58, y: backRect.minY + 34)
        drawLine(from: arrowStart, to: CGPoint(x: arrowStart.x + 26, y: arrowStart.y), color: accent, width: 2)
        drawLine(from: CGPoint(x: arrowStart.x + 18, y: arrowStart.y - 7),
                 to: CGPoint(x: arrowStart.x + 26, y: arrowStart.y),
                 color: accent,
                 width: 2)
        drawLine(from: CGPoint(x: arrowStart.x + 18, y: arrowStart.y + 7),
                 to: CGPoint(x: arrowStart.x + 26, y: arrowStart.y),
                 color: accent,
                 width: 2)
    }

    private func drawPrivacy(in rect: CGRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY - 4)
        let shield = UIBezierPath()
        shield.move(to: CGPoint(x: center.x, y: center.y - 102))
        shield.addCurve(
            to: CGPoint(x: center.x + 86, y: center.y - 58),
            controlPoint1: CGPoint(x: center.x + 32, y: center.y - 90),
            controlPoint2: CGPoint(x: center.x + 62, y: center.y - 76)
        )
        shield.addLine(to: CGPoint(x: center.x + 72, y: center.y + 42))
        shield.addCurve(
            to: CGPoint(x: center.x, y: center.y + 104),
            controlPoint1: CGPoint(x: center.x + 62, y: center.y + 76),
            controlPoint2: CGPoint(x: center.x + 28, y: center.y + 96)
        )
        shield.addCurve(
            to: CGPoint(x: center.x - 72, y: center.y + 42),
            controlPoint1: CGPoint(x: center.x - 28, y: center.y + 96),
            controlPoint2: CGPoint(x: center.x - 62, y: center.y + 76)
        )
        shield.addLine(to: CGPoint(x: center.x - 86, y: center.y - 58))
        shield.addCurve(
            to: CGPoint(x: center.x, y: center.y - 102),
            controlPoint1: CGPoint(x: center.x - 62, y: center.y - 76),
            controlPoint2: CGPoint(x: center.x - 32, y: center.y - 90)
        )
        shield.close()
        input.setFill()
        shield.fill()
        accent.setStroke()
        shield.lineWidth = 2
        shield.stroke()

        let fileRect = CGRect(x: center.x - 54, y: center.y - 46, width: 108, height: 92)
        let file = UIBezierPath(roundedRect: fileRect, cornerRadius: 15)
        surface.setFill()
        file.fill()
        border.setStroke()
        file.lineWidth = 1
        file.stroke()

        drawLine(from: CGPoint(x: fileRect.minX + 20, y: fileRect.minY + 30),
                 to: CGPoint(x: fileRect.maxX - 20, y: fileRect.minY + 30),
                 color: primary,
                 width: 3)
        drawLine(from: CGPoint(x: fileRect.minX + 20, y: fileRect.minY + 52),
                 to: CGPoint(x: fileRect.maxX - 40, y: fileRect.minY + 52),
                 color: secondary,
                 width: 2)
        drawDot(at: CGPoint(x: center.x, y: center.y + 78), radius: 7, color: accent)
    }

    private func drawLine(from start: CGPoint, to end: CGPoint, color: UIColor, width: CGFloat) {
        let line = UIBezierPath()
        line.move(to: start)
        line.addLine(to: end)
        color.setStroke()
        line.lineWidth = width
        line.lineCapStyle = .round
        line.stroke()
    }

    private func drawDot(at point: CGPoint, radius: CGFloat, color: UIColor) {
        let dot = UIBezierPath(
            ovalIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        )
        color.setFill()
        dot.fill()
    }
}
