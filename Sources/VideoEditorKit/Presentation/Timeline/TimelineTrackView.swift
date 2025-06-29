//
//  TimelineTrackView.swift
//  
//
//  Created by VideoEditorKit on 28.06.25.
//

import UIKit
import AVFoundation
import PureLayout

protocol TimelineTrackViewDelegate: AnyObject {
    func trackView(_ trackView: TimelineTrackView, didS    private func makeIconView() -> UIImageView {
        let theme = TimelineTheme.current
        let imageView = UIImageView()
        imageView.tintColor = theme.primaryTextColor
        imageView.contentMode = .scaleAspectFit
        return imageView
    }
    
    private func makeTitleLabel() -> UILabel {
        let theme = TimelineTheme.current
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = theme.primaryTextColor
        return label
    }
    
    private func makeDeleteButton() -> UIButton {
        let theme = TimelineTheme.current
        let button = UIButton()
        button.setImage(UIImage(systemName: "trash"), for: .normal)
        button.tintColor = theme.deleteButtonColor
        return button
    }lineItem)
    func trackView(_ trackView: TimelineTrackView, didTrimItem item: TimelineItem, newStartTime: CMTime, newDuration: CMTime)
    func trackView(_ trackView: TimelineTrackView, didDeleteItem item: TimelineItem)
}

class TimelineTrackView: UIView {
    
    // MARK: - Properties
    
    weak var delegate: TimelineTrackViewDelegate?
    
    private let track: TimelineTrack
    private let configuration: TimelineConfiguration
    private var itemViews: [TimelineItemView] = []
    
    private lazy var headerView: TrackHeaderView = makeHeaderView()
    private lazy var contentView: UIView = makeContentView()
    
    // MARK: - Init
    
    init(track: TimelineTrack, configuration: TimelineConfiguration) {
        self.track = track
        self.configuration = configuration
        super.init(frame: .zero)
        setupUI()
        updateItems()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Public Methods

extension TimelineTrackView {
    
    func updateItems() {
        // Remove existing item views
        itemViews.forEach { $0.removeFromSuperview() }
        itemViews.removeAll()
        
        // Add new item views
        for item in track.items {
            let itemView = TimelineItemView(item: item, configuration: configuration)
            itemView.delegate = self
            
            itemViews.append(itemView)
            contentView.addSubview(itemView)
            
            // Position the item view
            positionItemView(itemView, for: item)
        }
        
        // Animate appearance of new items
        animateItemsAppearance()
    }
    
    func updateItem(_ item: TimelineItem) {
        guard let itemView = itemViews.first(where: { $0.item.id == item.id }) else { return }
        itemView.updateItemData(item)
        positionItemView(itemView, for: item)
    }
    
    func removeItem(_ item: TimelineItem) {
        guard let index = itemViews.firstIndex(where: { $0.item.id == item.id }) else { return }
        let itemView = itemViews[index]
        
        // Use animation system for removal
        TimelineAnimationSystem.animateItemRemoval(itemView)
        itemViews.remove(at: index)
    }
    
    func selectItem(_ item: TimelineItem?) {
        itemViews.forEach { itemView in
            itemView.setSelected(itemView.item.id == item?.id)
        }
    }
    
    private func positionItemView(_ itemView: TimelineItemView, for item: TimelineItem) {
        let x = CGFloat(item.startTime.seconds) * configuration.pixelsPerSecond
        let width = CGFloat(item.duration.seconds) * configuration.pixelsPerSecond
        
        itemView.frame = CGRect(
            x: x,
            y: 0,
            width: max(width, configuration.minimumItemWidth),
            height: configuration.trackHeight
        )
    }
    
    private func animateItemsAppearance() {
        itemViews.enumerated().forEach { index, itemView in
            // Stagger the animation for a nice effect
            let delay = Double(index) * 0.05
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                TimelineAnimationSystem.animateItemAddition(itemView)
            }
        }
    }
}

// MARK: - Private Methods

private extension TimelineTrackView {
    
    func setupUI() {
        updateTheme()
        layer.cornerRadius = 4
        
        addSubview(headerView)
        addSubview(contentView)
        
        setupConstraints()
    }
    
    func setupConstraints() {
        headerView.autoPinEdge(toSuperviewEdge: .left)
        headerView.autoPinEdge(toSuperviewEdge: .top)
        headerView.autoPinEdge(toSuperviewEdge: .bottom)
        headerView.autoSetDimension(.width, toSize: 120)
        
        contentView.autoPinEdge(.left, to: .right, of: headerView)
        contentView.autoPinEdge(toSuperviewEdge: .top)
        contentView.autoPinEdge(toSuperviewEdge: .bottom)
        contentView.autoPinEdge(toSuperviewEdge: .right)
    }
}

// MARK: - Factory Methods

private extension TimelineTrackView {
    
    func makeHeaderView() -> TrackHeaderView {
        return TrackHeaderView(track: track)
    }
    
    func makeContentView() -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
}

// MARK: - TimelineItemViewDelegate

extension TimelineTrackView: TimelineItemViewDelegate {
    
    func itemView(_ itemView: TimelineItemView, didSelectItem item: TimelineItem) {
        delegate?.trackView(self, didSelectItem: item)
    }
    
    func itemView(_ itemView: TimelineItemView, didTrimItem item: TimelineItem, newStartTime: CMTime, newDuration: CMTime) {
        delegate?.trackView(self, didTrimItem: item, newStartTime: newStartTime, newDuration: newDuration)
    }
    
    func itemView(_ itemView: TimelineItemView, didDeleteItem item: TimelineItem) {
        delegate?.trackView(self, didDeleteItem: item)
    }
}

// MARK: - TrackHeaderView

class TrackHeaderView: UIView {
    
    private let track: TimelineTrack
    private lazy var iconView: UIImageView = makeIconView()
    private lazy var titleLabel: UILabel = makeTitleLabel()
    private lazy var deleteButton: UIButton = makeDeleteButton()
    
    init(track: TimelineTrack) {
        self.track = track
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        updateTheme()
        
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(deleteButton)
        
        setupConstraints()
        updateContent()
    }
    
    private func setupConstraints() {
        iconView.autoPinEdge(toSuperviewEdge: .left, withInset: 8)
        iconView.autoAlignAxis(toSuperviewAxis: .horizontal)
        iconView.autoSetDimensions(to: CGSize(width: 20, height: 20))
        
        titleLabel.autoPinEdge(.left, to: .right, of: iconView, withOffset: 8)
        titleLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        deleteButton.autoPinEdge(toSuperviewEdge: .right, withInset: 8)
        deleteButton.autoAlignAxis(toSuperviewAxis: .horizontal)
        deleteButton.autoSetDimensions(to: CGSize(width: 24, height: 24))
    }
    
    private func updateContent() {
        switch track.type {
        case .video:
            iconView.image = UIImage(systemName: "video.fill")
            titleLabel.text = "Video"
        case .audio(let subtype):
            iconView.image = UIImage(systemName: "speaker.wave.2.fill")
            switch subtype {
            case .original:
                titleLabel.text = "Original Audio"
            case .replacement:
                titleLabel.text = "Audio Track"
            case .voiceover:
                titleLabel.text = "Voiceover"
            }
        case .text:
            iconView.image = UIImage(systemName: "text.bubble.fill")
            titleLabel.text = "Text"
        case .sticker:
            iconView.image = UIImage(systemName: "star.fill")
            titleLabel.text = "Stickers"
        }
    }
    
    private func makeIconView() -> UIImageView {
        let imageView = UIImageView()
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }
    
    private func makeTitleLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        return label
    }
    
    private func makeDeleteButton() -> UIButton {
        let button = UIButton()
        button.setImage(UIImage(systemName: "trash"), for: .normal)
        button.tintColor = .red
        return button
    }
}

// MARK: - TrackHeaderView Theme Support

extension TrackHeaderView: TimelineThemeAware {
    
    public func updateTheme() {
        let theme = TimelineTheme.current
        backgroundColor = theme.trackHeaderBackgroundColor
        iconView.tintColor = theme.primaryTextColor
        titleLabel.textColor = theme.primaryTextColor
        deleteButton.tintColor = theme.deleteButtonColor
    }
}

// MARK: - TimelineThemeAware

extension TimelineTrackView: TimelineThemeAware {
    
    public func updateTheme() {
        let theme = TimelineTheme.current
        backgroundColor = theme.trackBackgroundColor
        
        // Update header view theme
        headerView.updateTheme()
        
        // Update all item views
        itemViews.forEach { $0.updateTheme() }
    }
}
