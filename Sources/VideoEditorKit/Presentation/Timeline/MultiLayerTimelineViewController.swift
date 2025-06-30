//
//  MultiLayerTimelineViewController.swift
//  
//
//  Created by VideoEditorKit on 28.06.25.
//

import AVFoundation
import Combine
import PureLayout
import UIKit

protocol MultiLayerTimelineDelegate: AnyObject {
    func timeline(_ timeline: MultiLayerTimelineViewController, didSelectItem item: TimelineItem)
    func timeline(_ timeline: MultiLayerTimelineViewController, didTrimItem item: TimelineItem, newStartTime: CMTime, newDuration: CMTime)
    func timeline(_ timeline: MultiLayerTimelineViewController, didAddTrackOfType type: TimelineTrackType)
}

final class MultiLayerTimelineViewController: UIViewController {

    // MARK: - Published Properties
    
    @Published var playheadPosition: CMTime = .zero
    @Published var isSeeking: Bool = false
    @Published var selectedItem: TimelineItem?
    @Published var seekerValue: Double = 0.0
    
    // Flag to prevent auto-scrolling during trim operations
    private var isTrimInProgress: Bool = false
    
    // Flag to prevent unintended deselection during layout operations
    private var isLayoutInProgress: Bool = false
    
    // Flag to prevent deselection immediately after trim operations
    private var isPostTrimProtectionActive: Bool = false
    
    // MARK: - Properties
    
    weak var delegate: MultiLayerTimelineDelegate?
    var tracks: [TimelineTrack] = [] {
        didSet {
            updateTracksView()
        }
    }
    
    lazy var scrollView: UIScrollView = makeScrollView()
    lazy var contentView: UIView = makeContentView()
    lazy var timeRulerView: TimeRulerView = makeTimeRulerView()
    private lazy var carretLayer: CALayer = makeCarretLayer()
    lazy var tracksStackView: UIStackView = makeTracksStackView()
    
    var trackViews: [TimelineTrackView] = []
    var cancellables = Set<AnyCancellable>()
    let configuration = TimelineConfiguration.default
    
    // MARK: - Store Integration (same as VideoTimelineViewController)
    
    let store: VideoEditorStore
    
    // MARK: - Init
    
    init(store: VideoEditorStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Init
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        
        // Initialize haptic feedback system - using standard iOS haptics
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update content size first to ensure proper layout
        updateContentSize()
        
        updatePlayheadPosition()
        updateCarretLayerFrame()
        
        // Apply content insets to allow full timeline scrollability
        // We need enough padding so that 00:00 appears at the absolute center of the view
        // when timeline is in its default centered position
        let viewCenter = view.bounds.width / 2
        let timelineStart = configuration.trackHeaderWidth
        let horizontal = viewCenter - timelineStart // This ensures 00:00 aligns with view center
        let contentInset = UIEdgeInsets(top: 0, left: horizontal, bottom: 0, right: horizontal)
        
        scrollView.contentInset = contentInset
        timeRulerView.setContentInset(contentInset) // Sync TimeRulerView contentInset
        

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Ensure proper initial positioning after view appears
        DispatchQueue.main.async {
            self.updateScrollViewContentOffset(fractionCompleted: 0.0)
        }
    }
    
    // MARK: - Timeline Generation (same pattern as VideoTimelineViewController)
    
    func generateTimeline(for asset: AVAsset) {
        let rect = CGRect(x: 0, y: 0, width: view.bounds.width, height: 64.0)
        store.videoTimeline(for: asset, in: rect)
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] images in
                guard let self = self else { return }
                self.setupTimelineWithAsset(asset, thumbnails: images)
            }.store(in: &cancellables)
        
        updateContentSize()
    }
}

// MARK: - Public Methods

extension MultiLayerTimelineViewController {
    
    func addTrack(type: TimelineTrackType) {
        let newTrack = TimelineTrack(type: type)
        tracks.append(newTrack)
        delegate?.timeline(self, didAddTrackOfType: type)
    }
    
    func addItem(_ item: TimelineItem, to trackIndex: Int) {
        guard trackIndex < tracks.count else { return }
        tracks[trackIndex].items.append(item)
        updateTracksView()
        
        // Animate to the new item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let trackView = self.trackViews[safe: trackIndex] {
                trackView.selectItem(item)
            }
        }
    }
    
    func removeItem(_ item: TimelineItem) {
        for (trackIndex, track) in tracks.enumerated() {
            if let itemIndex = track.items.firstIndex(where: { $0.id == item.id }) {
                tracks[trackIndex].items.remove(at: itemIndex)
                
                // Animate removal
                if let trackView = trackViews[safe: trackIndex] {
                    trackView.removeItem(item)
                }
                break
            }
        }
    }
    
    func updateItem(_ item: TimelineItem) {
        // Check if this is the currently selected item
        let wasSelected = selectedItem?.id == item.id
        
        // Set layout flag to protect selection during updates
        isLayoutInProgress = true
        
        for (trackIndex, var track) in tracks.enumerated() {
            if let itemIndex = track.items.firstIndex(where: { $0.id == item.id }) {
                tracks[trackIndex].items[itemIndex] = item
                
                // Update track view
                if let trackView = trackViews[safe: trackIndex] {
                    trackView.updateItem(item)
                }
                break
            }
        }
        updateContentSize()
        
        // Clear layout flag
        isLayoutInProgress = false
        
        // If this item was selected, update the selectedItem and ensure it stays selected
        if wasSelected {
            selectedItem = item
            print("📱 🔄 Item was selected, ensuring it remains selected after update")
            
            // Ensure selection is maintained in track views immediately
            selectItem(item)
        }
    }
    
    func selectItem(_ item: TimelineItem?) {
        print("📱 🔄 MultiLayerTimelineViewController.selectItem called with item ID: \(item?.id ?? "nil")")
        
        // Don't clear selection during layout operations unless explicitly setting a new item
        if isLayoutInProgress && item == nil && selectedItem != nil {
            print("📱 🚫 Preventing deselection during layout operation")
            return
        }
        
        // Don't clear selection during post-trim protection period unless explicitly setting a new item
        if isPostTrimProtectionActive && item == nil && selectedItem != nil {
            print("📱 🚫 Preventing deselection during post-trim protection period")
            return
        }
        
        selectedItem = item
        
        // Update selection in all track views
        trackViews.forEach { trackView in
            trackView.selectItem(item)
        }
    }
    
    func setPlayheadPosition(_ time: CMTime) {
        playheadPosition = time
        updatePlayheadPosition()
    }
}

// MARK: - Methods

extension MultiLayerTimelineViewController {
    
    func updateTracksView() {
        // Remove existing track views
        trackViews.forEach { $0.removeFromSuperview() }
        trackViews.removeAll()
        
        // Add new track views
        for (index, track) in tracks.enumerated() {
            let trackView = TimelineTrackView(track: track, configuration: configuration)
            trackView.delegate = self
            trackView.tag = index
            
            trackViews.append(trackView)
            tracksStackView.addArrangedSubview(trackView)
            
            trackView.autoSetDimension(.height, toSize: configuration.trackHeight)
        }
        
        updateContentSize()
    }
    
    func updateContentSize() {
        let maxDuration = tracks.flatMap { $0.items }.map { $0.startTime + $0.duration }.max() ?? CMTime.zero
        
        // Calculate content width properly:
        // - Timeline content width (excluding track header)
        let timelineContentWidth = view.bounds.width - configuration.trackHeaderWidth
        // - Duration converted to pixels 
        let durationWidth = CGFloat(maxDuration.seconds) * configuration.pixelsPerSecond
        // - Add full timeline width padding at the end to ensure we can scroll to the very end
        // This allows the last second of video to be scrolled to the center of the screen
        let contentWidth = durationWidth + timelineContentWidth
        
        // Calculate proper content height based on actual tracks
        let tracksHeight = CGFloat(tracks.count) * configuration.trackHeight + CGFloat(max(0, tracks.count - 1)) * configuration.trackSpacing
        let contentHeight = tracksHeight + 30 // +30 for ruler height
        
        // Set scroll view content size
        scrollView.contentSize = CGSize(width: contentWidth, height: contentHeight)
        
        // Manually set content view frame to ensure it matches the content size
        // This overrides any AutoLayout constraints that might limit the width
        contentView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        
        // Manually position TimeRulerView and TracksStackView since contentView uses frame-based layout
        timeRulerView.frame = CGRect(
            x: configuration.trackHeaderWidth,
            y: 0,
            width: contentWidth - configuration.trackHeaderWidth,
            height: 30
        )
        
        let tracksY: CGFloat = 30 // Below the time ruler
        tracksStackView.frame = CGRect(
            x: 0,
            y: tracksY,
            width: contentWidth,
            height: tracksHeight
        )
        
        // Force scroll view to recognize the new content size
        // Set layout flag to prevent deselection during scroll view updates
        isLayoutInProgress = true
        DispatchQueue.main.async {
            self.scrollView.setNeedsLayout()
            self.scrollView.layoutIfNeeded()
            self.isLayoutInProgress = false
        }
        
        // Update time ruler when content size changes
        updateTimeRuler()
    }
    
    func updatePlayheadPosition() {
        updateCarretLayerFrame()
        
        // Calculate scroll position to center current time under the playhead
        let currentTime = store.playheadProgress
        
        if currentTime.seconds >= 0 {
            // Convert current time to pixels
            let currentTimePixels = CGFloat(currentTime.seconds) * configuration.pixelsPerSecond
            // Calculate offset to center this time position under the fixed playhead
            let centerOffset = currentTimePixels - scrollView.contentInset.left
            let point = CGPoint(x: centerOffset, y: 0)
            
            // Update main timeline scroll
            scrollView.setContentOffset(point, animated: false)
            
            // Sync time ruler scroll position (both have same contentInset now)
            timeRulerView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: 0))
        }
    }
    
    func updateTimeRuler() {
        let maxDuration = tracks.flatMap { $0.items }.map { $0.startTime + $0.duration }.max() ?? CMTime.zero
        // Pass the same content width calculation to ensure perfect sync
        let timelineContentWidth = view.bounds.width - configuration.trackHeaderWidth
        let durationWidth = CGFloat(maxDuration.seconds) * configuration.pixelsPerSecond
        let contentWidth = durationWidth + timelineContentWidth // Match updateContentSize calculation exactly
        
        timeRulerView.setDuration(maxDuration, contentWidth: contentWidth)
    }
    
    func updateCarretLayerFrame() {
        let width: CGFloat = 2.0
        let height: CGFloat = view.bounds.height
        
        // Position playhead at the absolute center of the entire view
        // This ensures both playhead and 00:00 appear at the visual center
        let x = (view.bounds.width / 2) - (width / 2)
        let y: CGFloat = 0
        carretLayer.frame = CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - UI Setup

extension MultiLayerTimelineViewController {
    
    func setupUI() {
        // Set light theme as default
        TimelineThemeManager.shared.setTheme(.light)
        updateTheme()
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(timeRulerView)
        contentView.addSubview(tracksStackView)
        view.layer.addSublayer(carretLayer)
        
        setupConstraints()
        
        // Listen for theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .timelineThemeDidChange,
            object: nil
        )
    }
    
    func setupConstraints() {
        scrollView.autoPinEdgesToSuperviewEdges()
        
        // Don't set any constraints for contentView - we'll manage it entirely with frames
        // This prevents AutoLayout from overriding our manual contentSize settings
        contentView.translatesAutoresizingMaskIntoConstraints = true
        
        // Also use frame-based layout for TimeRulerView and TracksStackView
        timeRulerView.translatesAutoresizingMaskIntoConstraints = true
        tracksStackView.translatesAutoresizingMaskIntoConstraints = true
    }
    
    func setupBindings() {
        // Store bindings (same pattern as VideoTimelineViewController)
        store.$playheadProgress
            .sink { [weak self] playheadProgress in
                guard let self = self else { return }
                // Prevent auto-scrolling during trim operations to avoid unwanted timeline jumps
                if !self.isSeeking && !self.isTrimInProgress {
                    self.playheadPosition = playheadProgress
                    self.updatePlayheadPosition()
                }
            }
            .store(in: &cancellables)
        
        $seekerValue
            .assign(to: \.currentSeekingValue, weakly: store)
            .store(in: &cancellables)

        $isSeeking
            .assign(to: \.isSeeking, weakly: store)
            .store(in: &cancellables)
    }
}

// MARK: - Factory Methods

extension MultiLayerTimelineViewController {
    
    func makeScrollView() -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        return scrollView
    }
    
    func makeContentView() -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
    func makeTimeRulerView() -> TimeRulerView {
        let rulerView = TimeRulerView(configuration: configuration)
        rulerView.isHidden = false
        rulerView.alpha = 1.0
        rulerView.clipsToBounds = false
        return rulerView
    }
    
    func makeCarretLayer() -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = #colorLiteral(red: 0.1137254902, green: 0.1137254902, blue: 0.1215686275, alpha: 1).cgColor
        layer.cornerRadius = 1.0
        return layer
    }
    
    func makeTracksStackView() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = configuration.trackSpacing
        stackView.alignment = .fill
        stackView.distribution = .fill
        return stackView
    }
}

// MARK: - UIScrollViewDelegate

extension MultiLayerTimelineViewController: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isSeeking = true
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isSeeking = false
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            isSeeking = false
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Update time ruler scroll position to sync with timeline
        timeRulerView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: 0))
        
        // Calculate current time based on scroll position
        if isSeeking {
            // Convert scroll position back to time
            let scrollOffsetWithInset = scrollView.contentOffset.x + scrollView.contentInset.left
            let timeSeconds = Double(scrollOffsetWithInset) / Double(configuration.pixelsPerSecond)
            let newTime = CMTime(seconds: max(timeSeconds, 0), preferredTimescale: configuration.timeScale)
            playheadPosition = newTime
        }
        
        // Update seeker value for store integration
        let maxDuration = tracks.flatMap { $0.items }.map { $0.startTime + $0.duration }.max() ?? CMTime.zero
        if maxDuration.seconds > 0 {
            let currentTimeSeconds = Double(scrollView.contentOffset.x + scrollView.contentInset.left) / Double(configuration.pixelsPerSecond)
            seekerValue = currentTimeSeconds / maxDuration.seconds
        }
    }
}

// MARK: - TimelineTrackViewDelegate

extension MultiLayerTimelineViewController: TimelineTrackViewDelegate {
    
    func trackView(_ trackView: TimelineTrackView, didSelectItem item: TimelineItem) {
        selectItem(item)
        delegate?.timeline(self, didSelectItem: item)
    }
    
    func trackView(_ trackView: TimelineTrackView, didTrimItem item: TimelineItem, newStartTime: CMTime, newDuration: CMTime) {
        print("📱 🎬 MultiLayerTimelineViewController.trackView(_:didTrimItem:...) called")
        
        // Set trim flag to prevent auto-scrolling during store update
        isTrimInProgress = true
        
        // Validate the new placement
        var updatedItem = item
        updatedItem.startTime = newStartTime
        updatedItem.duration = newDuration
        
        let validationResult = TimelineInteractionSystem.validateItemPlacement(updatedItem)
        
        if !validationResult.isValid {
            // Show validation error without animation
            // Could show alert or other feedback instead of shake
            isTrimInProgress = false // Reset flag on error
            return
        }
        
        // Find the track this item belongs to
        guard let trackIndex = tracks.firstIndex(where: { track in
            track.items.contains { $0.id == item.id }
        }) else { 
            isTrimInProgress = false // Reset flag on error
            return 
        }
        
        // Check for collisions
        let collisions = TimelineInteractionSystem.detectCollisions(
            for: updatedItem,
            in: tracks[trackIndex],
            excluding: item
        )
        
        if !collisions.isEmpty {
            // Find a valid position
            let validStartTime = TimelineInteractionSystem.findValidPosition(
                for: updatedItem,
                in: tracks[trackIndex],
                preferredStartTime: newStartTime
            )
            updatedItem.startTime = validStartTime
        }
        
        updateItem(updatedItem)
        delegate?.timeline(self, didTrimItem: updatedItem, newStartTime: updatedItem.startTime, newDuration: updatedItem.duration)
        
        // Ensure the trimmed item remains selected
        print("📱 🔄 Trim completed, ensuring item remains selected")
        selectedItem = updatedItem
        selectItem(updatedItem)
        
        // Store the selected item ID for re-selection after potential data reloads
        let selectedItemId = updatedItem.id
        
        // Activate post-trim protection to prevent immediate deselection
        isPostTrimProtectionActive = true
        
        // Update store to sync with rest of app (delayed to avoid interference with selection)
        if let videoItem = updatedItem as? VideoTimelineItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let totalDuration = videoItem.asset.duration.seconds
                let trimStartRatio = updatedItem.startTime.seconds / totalDuration
                let trimEndRatio = (updatedItem.startTime.seconds + updatedItem.duration.seconds) / totalDuration
                
                print("📹 Store update - Video trim: start=\(trimStartRatio), end=\(trimEndRatio)")
                self.store.trimPositions = (trimStartRatio, trimEndRatio)
                
                // Re-select item after store update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.selectItemById(selectedItemId)
                }
            }
        }
        
        // Reset protection after operation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.isTrimInProgress = false
            self.isPostTrimProtectionActive = false
            print("📱 🔄 Trim operation completed")
            
            // Final selection check
            self.selectItemById(selectedItemId)
        }
    }
    
    @objc func themeDidChange() {
        updateTheme()
    }
    
    private func selectItemById(_ itemId: String) {
        print("📱 🔄 Searching for item with ID: \(itemId)")
        
        // Find the item by ID across all tracks
        for track in tracks {
            if let item = track.items.first(where: { $0.id == itemId }) {
                print("📱 🔄 Found item by ID, re-selecting")
                selectedItem = item
                selectItem(item)
                return
            }
        }
        
        print("📱 ⚠️ Could not find item with ID \(itemId) for re-selection")
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - TimelineThemeAware

extension MultiLayerTimelineViewController: TimelineThemeAware {
    
    func updateTheme() {
        let theme = TimelineTheme.current
        
        view.backgroundColor = theme.backgroundColor
        scrollView.backgroundColor = theme.contentBackgroundColor
        contentView.backgroundColor = theme.contentBackgroundColor
        
        // Update time ruler
        timeRulerView.updateTheme()
        
        // Update all track views
        trackViews.forEach { $0.updateTheme() }
    }
}

// MARK: - Timeline Setup

extension MultiLayerTimelineViewController {
    
    func setupTimelineWithAsset(_ asset: AVAsset, thumbnails: [CGImage] = []) {
        let duration = asset.duration
        
        // First priority: Check if current selected item matches the type we need
        var existingVideoItem: VideoTimelineItem?
        var existingAudioItem: AudioTimelineItem?
        
        // If we have a selected video item, use it (regardless of asset reference)
        if let selectedVideoItem = selectedItem as? VideoTimelineItem {
            existingVideoItem = selectedVideoItem
            print("📹 Using selected video item for preservation: ID=\(selectedVideoItem.id)")
        }
        
        // If we have a selected audio item, use it (regardless of asset reference)  
        if let selectedAudioItem = selectedItem as? AudioTimelineItem {
            existingAudioItem = selectedAudioItem
            print("📹 Using selected audio item for preservation")
        }
        
        // Second priority: Check existing tracks for asset match (fallback)
        if existingVideoItem == nil || existingAudioItem == nil {
            for track in tracks {
                for item in track.items {
                    if existingVideoItem == nil, let videoItem = item as? VideoTimelineItem, videoItem.asset === asset {
                        existingVideoItem = videoItem
                        print("📹 Found existing video item by asset reference: ID=\(videoItem.id)")
                    }
                    if existingAudioItem == nil, let audioItem = item as? AudioTimelineItem, audioItem.asset === asset {
                        existingAudioItem = audioItem
                        print("📹 Found existing audio item by asset reference")
                    }
                }
            }
        }
        
        // Create a main video track, preserving existing item if available
        var videoTrack = TimelineTrack(type: .video)
        let videoItem: VideoTimelineItem
        
        if let existing = existingVideoItem {
            // Update thumbnails but preserve trim data AND ID
            // Reset startTime to 0 since this is a regenerated timeline (video should start from beginning)
            videoItem = VideoTimelineItem(
                id: existing.id,           // Preserve ID for selection tracking
                asset: asset,
                thumbnails: thumbnails,
                startTime: .zero,          // Reset to start from timeline beginning
                duration: existing.duration     // Preserve trimmed duration
            )
            print("📹 Preserving existing video item: ID=\(existing.id), startTime=0.0s (reset), duration=\(existing.duration.seconds)s")
        } else {
            // Create new item with full duration
            videoItem = VideoTimelineItem(
                asset: asset,
                thumbnails: thumbnails,
                startTime: .zero,
                duration: duration
            )
            print("📹 Creating new video item with full duration, ID=\(videoItem.id)")
        }
        
        videoTrack.items = [videoItem]
        
        // Create an audio track if audio exists, preserving existing item if available
        var newTracks = [videoTrack]
        if asset.tracks(withMediaType: .audio).count > 0 {
            var audioTrack = TimelineTrack(type: .audio(.original))
            let audioItem: AudioTimelineItem
            
            if let existing = existingAudioItem {
                // Preserve existing audio item trim data but reset startTime
                audioItem = AudioTimelineItem(
                    trackType: .audio(.original),
                    asset: asset,
                    waveform: existing.waveform,
                    title: existing.title,
                    volume: existing.volume,
                    isMuted: existing.isMuted,
                    startTime: .zero,           // Reset to start from timeline beginning
                    duration: existing.duration     // Preserve trimmed duration
                )
                print("📹 Preserving existing audio item: startTime=0.0s (reset), duration=\(existing.duration.seconds)s")
            } else {
                // Create new item with full duration
                audioItem = AudioTimelineItem(
                    trackType: .audio(.original),
                    asset: asset,
                    waveform: [], // Empty waveform for now, could be enhanced later
                    title: "Main Audio",
                    volume: 1.0,
                    isMuted: false,
                    startTime: .zero,
                    duration: duration
                )
                print("📹 Creating new audio item with full duration")
            }
            
            audioTrack.items = [audioItem]
            newTracks.append(audioTrack)
        }
        
        // Update the timeline with tracks
        self.tracks = newTracks
        
        // Re-apply selection if we preserved an existing item
        if let existing = existingVideoItem, selectedItem?.id == existing.id {
            print("📹 Re-selecting preserved video item with ID: \(existing.id)")
            // Find the newly created item with the same ID and re-select it
            DispatchQueue.main.async {
                self.selectItemById(existing.id)
            }
        } else if let existing = existingAudioItem, selectedItem?.id == existing.id {
            print("📹 Re-selecting preserved audio item with ID: \(existing.id)")
            // Find the newly created item with the same ID and re-select it  
            DispatchQueue.main.async {
                self.selectItemById(existing.id)
            }
        }
        
        // Reset scroll position to beginning (like VideoTimelineViewController)
        DispatchQueue.main.async {
            self.updateScrollViewContentOffset(fractionCompleted: 0.0)
        }
    }
    
    private func updateScrollViewContentOffset(fractionCompleted: Double) {
        // For initial positioning (fractionCompleted = 0), center the timeline like VideoTimelineViewController
        if fractionCompleted == 0.0 {
            // Center position: scroll so that time 0 appears at center of screen
            // This should align items at startTime=0 with the center playhead
            let centerX = -scrollView.contentInset.left
            let point = CGPoint(x: centerX, y: 0)
            
            scrollView.setContentOffset(point, animated: false)
        } else {
            // Normal calculation for playback position
            let maxDuration = tracks.flatMap { $0.items }.map { $0.startTime + $0.duration }.max() ?? CMTime.zero
            
            if maxDuration.seconds > 0 {
                // Calculate the timeline position based on current playback time
                let currentTimePixels = CGFloat(store.playheadProgress.seconds) * configuration.pixelsPerSecond
                // Offset to center the current time under the playhead
                let centerOffset = currentTimePixels - scrollView.contentInset.left
                let point = CGPoint(x: centerOffset, y: 0)
                
                scrollView.setContentOffset(point, animated: false)
            }
        }
        
        // Sync time ruler (both have same contentInset)
        timeRulerView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: 0))
    }
}
