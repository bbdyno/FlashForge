import UIKit
import SnapKit

final class AppearanceOptionControl: UIControl {
    let appearance: AppAppearance

    private let previewView: AppearancePreviewView
    private let titleLabel = UILabel()
    private let selectionMark = UIView()

    override var isSelected: Bool {
        didSet { updateSelection() }
    }

    init(appearance: AppAppearance, title: String) {
        self.appearance = appearance
        previewView = AppearancePreviewView(appearance: appearance)
        super.init(frame: .zero)

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = title

        addSubview(previewView)
        addSubview(titleLabel)
        addSubview(selectionMark)

        titleLabel.text = title
        titleLabel.font = AppTypography.font(size: 13, weight: .semibold, textStyle: .subheadline)
        titleLabel.textAlignment = .center

        selectionMark.layer.cornerRadius = 2
        selectionMark.isUserInteractionEnabled = false

        previewView.isUserInteractionEnabled = false
        titleLabel.isUserInteractionEnabled = false

        previewView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().inset(4)
            make.height.equalTo(70)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(previewView.snp.bottom).offset(9)
            make.leading.trailing.equalToSuperview()
        }
        selectionMark.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(7)
            make.centerX.equalToSuperview()
            make.width.equalTo(18)
            make.height.equalTo(4)
            make.bottom.equalToSuperview()
        }

        updateSelection()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateSelection() {
        previewView.isSelected = isSelected
        titleLabel.textColor = isSelected ? AppTheme.textPrimary : AppTheme.textSecondary
        selectionMark.backgroundColor = isSelected ? AppTheme.accent : .clear
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}

private final class AppearancePreviewView: UIView {
    let appearance: AppAppearance

    var isSelected = false {
        didSet { setNeedsDisplay() }
    }

    init(appearance: AppAppearance) {
        self.appearance = appearance
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        let bounds = rect.insetBy(dx: 1.5, dy: 1.5)
        let radius: CGFloat = 13
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: radius)
        path.addClip()

        switch appearance {
        case .system:
            AppTheme.studyPaper.setFill()
            path.fill()
            AppTheme.backgroundTop.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).setFill()
            let darkHalf = UIBezierPath()
            darkHalf.move(to: CGPoint(x: bounds.maxX, y: bounds.minY))
            darkHalf.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
            darkHalf.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
            darkHalf.close()
            darkHalf.fill()
        case .light:
            AppTheme.studyPaper.setFill()
            path.fill()
        case .dark:
            AppTheme.backgroundTop.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).setFill()
            path.fill()
        }

        UIColor.white.withAlphaComponent(appearance == .dark ? 0.07 : 0.34).setStroke()
        let innerLine = UIBezierPath()
        innerLine.move(to: CGPoint(x: bounds.minX + 12, y: bounds.minY + 15))
        innerLine.addLine(to: CGPoint(x: bounds.maxX - 12, y: bounds.minY + 15))
        innerLine.lineWidth = 2
        innerLine.stroke()

        let borderColor = isSelected ? AppTheme.accent : AppTheme.cardBorder
        borderColor.setStroke()
        path.lineWidth = isSelected ? 2.5 : 1
        path.stroke()
    }
}
