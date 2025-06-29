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
    func trackView(_ trackView: TimelineTrackView, didSelectItem item: TimelineItem)
    func trackView(_ trackView: TimelineTrackView, didTrimItem item: TimelineItem, newStartTime: CMTime, newDuration: CMTime)
}

final class TimelineTrackView: UIView {
    
    // MARK: - Properties
    
    weak var delegate: TimelineTrackViewDelegate?
    
    let track: TimelineTrack
    let configuration: TimelineConfiguration
    var itemViews: [TimelineItemView] = []
    
    lazy var headerView: TrackHeaderView = makeHeaderView()
    lazy var contentView: UIView = makeContentView()
    
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
}

// MARK: - TrackHeaderView

class TrackHeaderView: UIView {
    
    private let track: TimelineTrack
    
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
        
        // titleLabel is hidden - not added to view hierarchy
        
        setupConstraints()
        updateContent()
    }
    
    private func setupConstraints() {
        // No constraints needed since titleLabel is hidden
    }
    
    private func updateContent() {
        // Track header content is hidden
        // No title text will be displayed
    }
}

// MARK: - TrackHeaderView Theme Support

extension TrackHeaderView: TimelineThemeAware {
    
    public func updateTheme() {
        let theme = TimelineTheme.current
        backgroundColor = theme.trackHeaderBackgroundColor
        // No title label to update since it's hidden
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
