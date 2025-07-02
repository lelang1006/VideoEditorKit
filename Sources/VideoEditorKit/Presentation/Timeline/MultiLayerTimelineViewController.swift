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
    var isTrimInProgress: Bool = false
    
    // Flag to prevent unintended deselection during layout operations
    var isLayoutInProgress: Bool = false
    
    // Flag to prevent deselection immediately after trim operations
    var isPostTrimProtectionActive: Bool = false
    
    // Gesture state management
    var currentGestureState: GestureState = .none
    
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
    
    /// Current translation being tracked for visual feedback
    var currentTrimTranslation: CGPoint = .zero
    
    /// Helper to get current translation for visual feedback
    func handleTrimGesture_getCurrentTranslation() -> CGPoint {
        return currentTrimTranslation
    }

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
        setupCentralizedGestures() // Setup gesture management
        
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
    
    // MARK: - Reactive Timeline Generation
    
    /// Generates timeline thumbnails for the given asset
    private func generateThumbnails(for asset: AVAsset) {
        let rect = CGRect(x: 0, y: 0, width: view.bounds.width, height: 64.0)
        store.videoTimeline(for: asset, in: rect)
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] images in
                guard let self = self else { return }
                self.updateThumbnails(images)
            }.store(in: &cancellables)
    }
    
    /// Updates thumbnails for existing video items without recreating tracks
    private func updateThumbnails(_ images: [CGImage]) {
        // Update thumbnails in existing video items without disrupting track structure
        for trackIndex in 0..<tracks.count {
            for itemIndex in 0..<tracks[trackIndex].items.count {
                if let videoItem = tracks[trackIndex].items[itemIndex] as? VideoTimelineItem {
                    // Create new item with updated thumbnails
                    let updatedVideoItem = VideoTimelineItem(
                        asset: videoItem.asset,
                        thumbnails: images,
                        startTime: videoItem.startTime,
                        duration: videoItem.duration
                    )
                    tracks[trackIndex].items[itemIndex] = updatedVideoItem
                    
                    // Update the track view
                    if let trackView = trackViews[safe: trackIndex] {
                        trackView.updateItem(updatedVideoItem)
                    }
                }
            }
        }
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
    
    /// Initialize the timeline with the current store state
    func initializeTimeline() {
        updateTracksFromStore()
        generateThumbnails(for: store.originalAsset)
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
            trackView.tag = index
            
            trackViews.append(trackView)
            tracksStackView.addArrangedSubview(trackView)
            
            trackView.autoSetDimension(.height, toSize: configuration.trackHeight)
        }
        
        updateContentSize()
        
        // Preserve current selection before removing track views
        let currentSelectedItemId = selectedItem?.id
        let currentSelectedItemType = selectedItem?.trackType

        // Restore selection after track views are created
        if let selectedId = currentSelectedItemId {
            // First try to find exact ID match
            if let item = findItemById(selectedId) {
                print("📱 🔄 updateTracksView - Restoring selection by exact ID: \(selectedId)")
                selectedItem = item
                selectItem(item)
            } else if let itemType = currentSelectedItemType {
                // Fallback to type match if ID no longer exists
                print("📱 🔄 updateTracksView - Item ID not found, restoring by type: \(itemType.debugDescription)")
                restoreSelectionByType(itemType: itemType)
            }
        }

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
    
    func updateScrollViewContentOffset(fractionCompleted: Double) {
        let maxDuration = tracks.flatMap { $0.items }.map { $0.startTime + $0.duration }.max() ?? CMTime.zero
        if maxDuration.seconds > 0 {
            let targetTime = maxDuration.seconds * fractionCompleted
            let targetPixels = CGFloat(targetTime) * configuration.pixelsPerSecond
            let centerOffset = targetPixels - scrollView.contentInset.left
            let point = CGPoint(x: centerOffset, y: 0)
            
            scrollView.setContentOffset(point, animated: false)
            timeRulerView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: 0))
        }
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
        // MARK: - Store Property Bindings (Reactive Flow)
        
        // React to asset changes - this replaces setupTimelineWithAsset calls
        store.$originalAsset
            .sink { [weak self] asset in
                guard let self = self else { return }
                self.updateTracksFromStore()
                self.generateThumbnails(for: asset)
            }
            .store(in: &cancellables)
        
        // React to timeline structure changes (trim, speed, video edit)
        Publishers.CombineLatest(
            store.$trimPositions.removeDuplicates { $0.0 == $1.0 && $0.1 == $1.1 },
            store.$speed.removeDuplicates()
        )
        .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main) // Prevent rapid-fire updates
        .sink { [weak self] _, _ in
            guard let self = self else { return }
            self.updateTracksFromStore()
        }
        .store(in: &cancellables)
        
        // React to audio replacement changes
        store.$audioReplacement
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateTracksFromStore()
            }
            .store(in: &cancellables)
        
        // React to volume and mute changes (update existing audio items)
        Publishers.CombineLatest(store.$volume, store.$isMuted)
            .sink { [weak self] volume, isMuted in
                guard let self = self else { return }
                self.updateAudioProperties(volume: volume, isMuted: isMuted)
            }
            .store(in: &cancellables)
        
        // MARK: - Playhead Position Bindings
        
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
    
    @objc func themeDidChange() {
        updateTheme()
    }
}

// MARK: - Reactive Track Management

extension MultiLayerTimelineViewController {
    
    /// Single method to update tracks from store state - replaces setupTimelineWithAsset
    private func updateTracksFromStore() {
        let asset = store.originalAsset
        let trimPositions = store.trimPositions
        let speed = store.speed
        let audioReplacement = store.audioReplacement
        let volume = store.volume
        let isMuted = store.isMuted
                
        // Calculate durations based on trim and speed
        let originalDuration = asset.duration
        let trimmedDuration = CMTime(
            seconds: originalDuration.seconds * (trimPositions.1 - trimPositions.0),
            preferredTimescale: originalDuration.timescale
        )
        let finalDuration = CMTime(
            seconds: trimmedDuration.seconds / speed,
            preferredTimescale: trimmedDuration.timescale
        )
        
        // Create new tracks array
        var newTracks: [TimelineTrack] = []
        
        // 1. Create main video track
        var videoTrack = TimelineTrack(type: .video)
        let videoItem = VideoTimelineItem(
            asset: asset,
            thumbnails: [], // Thumbnails are updated separately via generateThumbnails
            startTime: .zero,
            duration: finalDuration
        )
        videoTrack.items = [videoItem]
        newTracks.append(videoTrack)
        
        // 2. Create audio track(s)
        if let audioReplacement = audioReplacement {
            // Audio replacement track
            var audioTrack = TimelineTrack(type: .audio(.replacement))
            let audioItem = AudioTimelineItem(
                trackType: .audio(.replacement),
                asset: audioReplacement.asset,
                waveform: [], // Could be enhanced later
                title: audioReplacement.title ?? "Replacement Audio",
                volume: volume,
                isMuted: isMuted,
                startTime: .zero,
                duration: finalDuration
            )
            audioTrack.items = [audioItem]
            newTracks.append(audioTrack)
        } else if asset.tracks(withMediaType: .audio).count > 0 {
            // Original audio track
            var audioTrack = TimelineTrack(type: .audio(.original))
            let audioItem = AudioTimelineItem(
                trackType: .audio(.original),
                asset: asset,
                waveform: [], // Could be enhanced later
                title: "Main Audio",
                volume: volume,
                isMuted: isMuted,
                startTime: .zero,
                duration: finalDuration
            )
            audioTrack.items = [audioItem]
            newTracks.append(audioTrack)
        }
        
        // Update tracks (this triggers updateTracksView via didSet)
        self.tracks = newTracks

        // Preserve current selection by type BEFORE updating tracks
        var selectedItemType: TimelineTrackType?
        if let currentSelected = selectedItem {
            selectedItemType = currentSelected.trackType
            print("📱 🔄 updateTracksFromStore - Preserving selection type: \(selectedItemType?.debugDescription ?? "nil")")
        }

        // Restore selection using saved type - do this IMMEDIATELY, not async
        if let itemType = selectedItemType {
            print("📱 🔄 updateTracksFromStore - Restoring selection IMMEDIATELY for type: \(itemType.debugDescription)")
            self.restoreSelectionByType(itemType: itemType)
        }
        
        // Reset scroll position to beginning
        DispatchQueue.main.async {
            self.updateScrollViewContentOffset(fractionCompleted: 0.0)
        }
    }
    
    /// Updates audio properties for existing audio items without recreating tracks
    private func updateAudioProperties(volume: Float, isMuted: Bool) {
        var needsUpdate = false
        
        for trackIndex in 0..<tracks.count {
            for itemIndex in 0..<tracks[trackIndex].items.count {
                if let audioItem = tracks[trackIndex].items[itemIndex] as? AudioTimelineItem {
                    if audioItem.volume != volume || audioItem.isMuted != isMuted {
                        // Create new audio item with updated properties
                        let updatedAudioItem = AudioTimelineItem(
                            trackType: audioItem.trackType,
                            asset: audioItem.asset,
                            waveform: audioItem.waveform,
                            title: audioItem.title,
                            volume: volume,
                            isMuted: isMuted,
                            startTime: audioItem.startTime,
                            duration: audioItem.duration
                        )
                        tracks[trackIndex].items[itemIndex] = updatedAudioItem
                        needsUpdate = true
                        
                        // Update the track view
                        if let trackView = trackViews[safe: trackIndex] {
                            trackView.updateItem(updatedAudioItem)
                        }
                    }
                }
            }
        }
        
        if needsUpdate {
            updateContentSize()
        }
    }
    
    /// Restores selection by finding item of the same type as the previously selected item
    private func restoreSelection(itemId: String) {
        print("📱 🔄 Check Restored selection by exact ID match: \(itemId)")
        // First try to find exact ID match (for preserved items)
        for track in tracks {
            if let item = track.items.first(where: { $0.id == itemId }) {
                print("📱 🔄 Restored selection by exact ID match: \(itemId)")
                selectedItem = item
                selectItem(item)
                return
            }
        }
        
        // If no exact match, try to select item of the same type at the same position
        // This handles cases where items are recreated but should maintain logical selection
        if let previousItem: any TimelineItem = selectedItem {
            for track in tracks {
                for item in track.items {
                    if type(of: item) == type(of: previousItem) {
                        print("📱 🔄 Restored selection by type match: \(type(of: item))")
                        selectedItem = item
                        selectItem(item)
                        return
                    }
                }
            }
        }
        
        print("📱 ⚠️ Could not restore selection for item ID: \(itemId)")
    }
}

// MARK: - Selection Helper Methods

extension MultiLayerTimelineViewController {
    
    /// Find an item by ID across all tracks
    private func findItemById(_ itemId: String) -> TimelineItem? {
        for track in tracks {
            if let item = track.items.first(where: { $0.id == itemId }) {
                return item
            }
        }
        return nil
    }

        /// Restores selection by finding first item of matching type
    private func restoreSelectionByType(itemType: TimelineTrackType) {
        print("📱 🔄 Attempting to restore selection by type: \(itemType.debugDescription)")
        
        // Find first item of matching type
        for track in tracks {
            for item in track.items {
                if itemTypesMatch(item.trackType, itemType) {
                    print("📱 ✅ Restored selection by type match: \(itemType.debugDescription)")
                    selectedItem = item
                    selectItem(item)
                    
                    // Also ensure the selection is immediately propagated to track views
                    DispatchQueue.main.async {
                        print("📱 🔄 Re-enforcing selection for item: \(item.id)")
                        self.trackViews.forEach { trackView in
                            trackView.selectItem(item)
                        }
                    }
                    return
                }
            }
        }
        
        print("📱 ⚠️ Could not restore selection for type: \(itemType.debugDescription)")
    }
    
    /// Helper method to check if two track types match (handling enum cases)
    private func itemTypesMatch(_ type1: TimelineTrackType, _ type2: TimelineTrackType) -> Bool {
        switch (type1, type2) {
        case (.video, .video):
            return true
        case (.audio(let subtype1), .audio(let subtype2)):
            return subtype1 == subtype2
        case (.text, .text):
            return true
        case (.sticker, .sticker):
            return true
        default:
            return false
        }
    }
    

}
