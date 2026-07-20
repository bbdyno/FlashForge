//
//  ReviewHeatmapView.swift
//  FlashForge
//
//  Created by bbdyno on 2/11/26.
//

import UIKit
import SnapKit

final class ReviewHeatmapView: UIView {
    private let titleLabel = UILabel()
    private let collectionView: UICollectionView
    private var dayItems: [HeatmapDay] = []
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        let layout = ReviewHeatmapFlowLayout()
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: .zero)
        configureHierarchy()
        configureStyle()
        configureLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true else {
            return
        }
        applyTheme()
        collectionView.reloadData()
    }

    func update(reviewCountByDate: [Date: Int], totalDays: Int = 140, today: Date = .now) {
        let days = max(7, totalDays)
        let startOfToday = calendar.startOfDay(for: today)

        var generated: [HeatmapDay] = []
        generated.reserveCapacity(days)

        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else {
                continue
            }
            let count = reviewCountByDate[calendar.startOfDay(for: date)] ?? 0
            generated.append(HeatmapDay(date: date, count: count))
        }

        dayItems = generated
        collectionView.reloadData()
    }

    private func configureHierarchy() {
        addSubview(titleLabel)
        addSubview(collectionView)
    }

    private func configureStyle() {
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        layer.borderWidth = 0.5
        layer.borderColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor
        backgroundColor = AppTheme.cardBackground

        titleLabel.text = FlashForgeStrings.Insights.Activity.title
        titleLabel.font = AppTypography.font(size: 17, weight: .bold, textStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.textPrimary

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.register(ReviewHeatmapCell.self, forCellWithReuseIdentifier: ReviewHeatmapCell.reuseIdentifier)

        applyTheme()
    }

    private func applyTheme() {
        layer.borderColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor
        backgroundColor = AppTheme.cardBackground
        titleLabel.textColor = AppTheme.textPrimary
    }

    private func configureLayout() {
        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(18)
        }

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(14)
            make.leading.trailing.bottom.equalToSuperview().inset(18)
            make.height.greaterThanOrEqualTo(110)
        }
    }
}

extension ReviewHeatmapView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dayItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ReviewHeatmapCell.reuseIdentifier,
            for: indexPath
        ) as? ReviewHeatmapCell else {
            return UICollectionViewCell()
        }

        let item = dayItems[indexPath.item]
        cell.configure(count: item.count)
        return cell
    }
}

private struct HeatmapDay: Hashable, Sendable {
    let date: Date
    let count: Int
}

private final class ReviewHeatmapFlowLayout: UICollectionViewLayout {
    private let rowCount = 7
    private let itemSide: CGFloat = 12
    private let spacing: CGFloat = 4

    private var cachedAttributes: [UICollectionViewLayoutAttributes] = []
    private var cachedContentSize: CGSize = .zero

    override func prepare() {
        super.prepare()

        guard let collectionView else {
            cachedAttributes.removeAll()
            cachedContentSize = .zero
            return
        }

        cachedAttributes.removeAll(keepingCapacity: true)

        let itemCount = collectionView.numberOfItems(inSection: 0)
        let itemWidth = itemSide + spacing
        let itemHeight = itemSide + spacing

        for index in 0..<itemCount {
            let row = index % rowCount
            let column = index / rowCount
            let x = CGFloat(column) * itemWidth
            let y = CGFloat(row) * itemHeight

            let frame = CGRect(x: x, y: y, width: itemSide, height: itemSide)
            let indexPath = IndexPath(item: index, section: 0)
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = frame
            cachedAttributes.append(attributes)
        }

        let columns = max(1, Int(ceil(Double(itemCount) / Double(rowCount))))
        let width = CGFloat(columns) * itemSide + CGFloat(max(0, columns - 1)) * spacing
        let height = CGFloat(rowCount) * itemSide + CGFloat(max(0, rowCount - 1)) * spacing
        cachedContentSize = CGSize(width: width, height: height)
    }

    override var collectionViewContentSize: CGSize {
        cachedContentSize
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        cachedAttributes.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.item >= 0, indexPath.item < cachedAttributes.count else {
            return nil
        }
        return cachedAttributes[indexPath.item]
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        false
    }
}

private final class ReviewHeatmapCell: UICollectionViewCell {
    static let reuseIdentifier = "ReviewHeatmapCell"
    private var lastCount = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 3
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 0.5
        contentView.layer.borderColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true else {
            return
        }
        contentView.layer.borderColor = AppTheme.resolved(AppTheme.cardBorder, for: traitCollection).cgColor
        configure(count: lastCount)
    }

    func configure(count: Int) {
        lastCount = count
        switch count {
        case ...0:
            contentView.backgroundColor = AppTheme.inputBackground
        case 1...10:
            contentView.backgroundColor = AppTheme.accent.withAlphaComponent(0.40)
        case 11...50:
            contentView.backgroundColor = AppTheme.accent.withAlphaComponent(0.68)
        default:
            contentView.backgroundColor = AppTheme.accent
        }
    }
}
