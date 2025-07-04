//
//  TimelineTrackView.swift
//  
//
//  Created by VideoEditorKit on 28.06.25.
//

import UIKit
import AVFoundation
import PureLayout



final class TimelineTrackView: UIView {
    
    // MARK: - Properties
    
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
            
            itemViews.append(itemView)
            contentView.addSubview(itemView)
            
            // Position the item view
            positionItemView(itemView, for: item)
        }
        
        // Items appear immediately without animation
    }
    
    func updateItem(_ item: TimelineItem) {
        guard let itemView = itemViews.first(where: { $0.item.id == item.id }) else { return }
        
        // Preserve selection state during update
        let wasSelected = itemView.itemIsSelected
        print("📱 🔄 TimelineTrackView.updateItem - preserving selection: \(wasSelected)")
        
        itemView.updateItemData(item)
        
        // Position immediately, then restore selection
        positionItemView(itemView, for: item)
        
        // Restore selection immediately if it was previously selected
        if wasSelected {
            print("📱 🔄 TimelineTrackView.updateItem - restoring selection immediately")
            itemView.setSelected(true)
        }
    }
    
    func removeItem(_ item: TimelineItem) {
        guard let index = itemViews.firstIndex(where: { $0.item.id == item.id }) else { return }
        let itemView = itemViews[index]
        
        // Remove immediately without animation
        itemView.removeFromSuperview()
        itemViews.remove(at: index)
    }
    
    func selectItem(_ item: TimelineItem?) {
        print("📱 🔄 TimelineTrackView.selectItem called with item ID: \(item?.id ?? "nil")")
        itemViews.forEach { itemView in
            let shouldBeSelected = itemView.item.id == item?.id
            print("📱 🔄 Item \(itemView.item.id) should be selected: \(shouldBeSelected)")
            itemView.setSelected(shouldBeSelected)
        }
    }
    
    private func positionItemView(_ itemView: TimelineItemView, for item: TimelineItem) {
        // Calculate position relative to timeline start (not relative to view bounds)
        let x = CGFloat(item.startTime.seconds) * configuration.pixelsPerSecond
        let width = CGFloat(item.duration.seconds) * configuration.pixelsPerSecond
        
        let finalFrame = CGRect(
            x: x,
            y: 0,
            width: max(width, configuration.minimumItemWidth),
            height: configuration.trackHeight
        )
        
        print("📍 Positioning item: startTime=\(item.startTime.seconds)s, x=\(x), width=\(width)")
        print("   Final frame: \(finalFrame)")
        print("   (Note: x=0 means item starts at timeline 00:00, which is correct for newly imported media)")
        
        itemView.frame = finalFrame
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
        headerView.autoSetDimension(.width, toSize: configuration.trackHeaderWidth)
        
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
        backgroundColor = .clear // Track header background is transparent  
        // No title label to update since it's hidden
    }
}

// MARK: - TimelineThemeAware

extension TimelineTrackView: TimelineThemeAware {
    
    public func updateTheme() {
        // Update header view theme
        headerView.updateTheme()
        
        // Update all item views
        itemViews.forEach { $0.updateTheme() }
    }
}
