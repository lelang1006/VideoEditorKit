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
    var isTrimInProgress: Bool = false {
        didSet {
            // Disable/enable scroll based on trim state
            if isTrimInProgress {
                scrollHandler?.disableScroll()
            } else {
                scrollHandler?.enableScroll()
            }
        }
    }
    
    // Flag to prevent unintended deselection during layout operations
    var isLayoutInProgress: Bool = false
    
    // Flag to prevent deselection immediately after trim operations
    var isPostTrimProtectionActive: Bool = false
    
    // Gesture state management
    var currentGestureState: GestureState = .none
    
    // MARK: - Properties
    
    /// Scroll handler for managing scroll behavior
    private var scrollHandler: TimelineScrollHandler?
    
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
        
        // Initialize scroll handler FIRST
        scrollHandler = TimelineScrollHandler(timelineViewController: self)
        
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
        
        // Apply content insets to scrollView and TimeRulerView
        // We need enough padding so that 00:00 appears at the absolute center of the view
        // when timeline is in its default centered position
        let viewCenter = view.bounds.width / 2
        let timelineStart = configuration.trackHeaderWidth
        let horizontal = viewCenter - timelineStart // This ensures 00:00 aligns with view center
        let contentInset = UIEdgeInsets(top: 0, left: horizontal, bottom: 0, right: horizontal)
        
        scrollView.contentInset = contentInset
        
        // FIX: TimeRulerView needs to align with TimelineItemView positioning
        // TimelineItemView appears at screen position: horizontal + trackHeaderWidth
        // TimeRulerView 00:00 should appear at same position
        let rulerInset = UIEdgeInsets(
            top: 0,
            left: horizontal + configuration.trackHeaderWidth,  // Same total offset as TimelineItemView
            bottom: 0,
            right: horizontal
        )
        timeRulerView.setContentInset(rulerInset)
        
        // Debug insets
        print("📏 DEBUG Insets:")
        print("📏   - ViewCenter: \(viewCenter)")
        print("📏   - TimelineStart: \(timelineStart)")
        print("📏   - Horizontal: \(horizontal)")
        print("📏   - TrackHeaderWidth: \(configuration.trackHeaderWidth)")
        print("📏   - ScrollView inset: \(contentInset)")
        print("📏   - TimeRulerView inset: \(rulerInset)")
        print("📏   - TimelineItemView screen position: \(horizontal + configuration.trackHeaderWidth)")
        print("📏   - TimeRulerView 00:00 screen position: \(horizontal + configuration.trackHeaderWidth)")
        print("📏   - Both should be at ViewCenter: \(viewCenter)")
        
        // CRITICAL: Sync TimeRulerView scroll position with main scrollView immediately
        // Compensate for different content insets to achieve same effective positioning
        let compensatedOffset = scrollView.contentOffset.x - (timeRulerView.scrollView.contentInset.left - scrollView.contentInset.left)
        print("📏 🔄 [INITIAL] sync - ScrollView offset: \(scrollView.contentOffset.x), Compensated: \(compensatedOffset)")
        timeRulerView.setContentOffset(CGPoint(x: compensatedOffset, y: 0))
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
                        duration: videoItem.duration,
                        trimPositions: videoItem.trimPositions // Preserve trim positions
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
    
    func selectItem(withID id: String) {
        print("📱 🔄 MultiLayerTimelineViewController.selectItem called with ID: \(id)")
        
        // Find item by ID across all tracks
        for track in tracks {
            for item in track.items {
                if item.id == id {
                    selectItem(item)
                    return
                }
            }
        }
        
        print("📱 ⚠️ Item with ID \(id) not found in timeline")
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
        
        // Calculate proper content height based on actual tracks (without ruler)
        let tracksHeight = CGFloat(tracks.count) * configuration.trackHeight + CGFloat(max(0, tracks.count - 1)) * configuration.trackSpacing
        let contentHeight = tracksHeight // No +30 for ruler since it's outside
        
        // Set scroll view content size
        scrollView.contentSize = CGSize(width: contentWidth, height: contentHeight)
        
        // Configure directional scrolling after content size update
        scrollHandler?.forceDirectionalScrolling(for: scrollView)
        
        // Manually set content view frame to ensure it matches the content size
        // This overrides any AutoLayout constraints that might limit the width
        contentView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        
        // Debug: Print frame sizes for TimeRulerView setup
        print("📏 DEBUG TimeRulerView Setup:")
        print("📏   - View bounds: \(view.bounds)")
        print("📏   - Track header width: \(configuration.trackHeaderWidth)")
        print("📏   - Content width: \(contentWidth)")
        
        // Update TimeRulerView frame (fixed at top, outside scrollView) - FULL WIDTH
        timeRulerView.frame = CGRect(
            x: 0,  // Start at 0 for full width
            y: 0,
            width: view.bounds.width,  // Full screen width
            height: 30
        )
        
        print("📏   - TimeRulerView frame: \(timeRulerView.frame)")
        
        // Set TimeRulerView content size to match scrollView
        timeRulerView.setDuration(maxDuration, contentWidth: contentWidth)
        
        // Position TracksStackView in contentView (no Y offset since ruler is outside)
        tracksStackView.frame = CGRect(
            x: 0,
            y: 0, // Start at top since ruler is outside scrollView
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
        scrollHandler?.updatePlayheadPosition()
    }
    
    func updateTimeRuler() {
        let maxDuration = tracks.flatMap { $0.items }.map { $0.startTime + $0.duration }.max() ?? CMTime.zero
        // Pass the same content width calculation to ensure perfect sync
        let timelineContentWidth = view.bounds.width - configuration.trackHeaderWidth
        let durationWidth = CGFloat(maxDuration.seconds) * configuration.pixelsPerSecond
        let contentWidth = durationWidth + timelineContentWidth // Match updateContentSize calculation exactly
        
        // TimeRulerView setDuration method already handles content size
        timeRulerView.setDuration(maxDuration, contentWidth: contentWidth)
    }
    
    func updateCarretLayerFrame() {
        let width: CGFloat = 2.0
        // Height should start from below TimeRulerView
        let height: CGFloat = view.bounds.height - 30 // Subtract TimeRulerView height
        
        // Position playhead at the absolute center of the view
        let x = (view.bounds.width / 2) - (width / 2)
        let y: CGFloat = 30 // Start below TimeRulerView
        carretLayer.frame = CGRect(x: x, y: y, width: width, height: height)
    }
    
    func updateScrollViewContentOffset(fractionCompleted: Double) {
        scrollHandler?.updateScrollViewContentOffset(fractionCompleted: fractionCompleted)
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
        
        // Move TimeRulerView to main view (NOT inside scrollView)
        view.addSubview(timeRulerView) // ← Moved outside scrollView
        
        contentView.addSubview(tracksStackView) // Only tracks in scrollView
        view.layer.addSublayer(carretLayer)
        
        setupConstraints()
        
        // Configure scroll handler after UI setup
        if let scrollHandler = scrollHandler {
            scrollView.delegate = scrollHandler
            scrollHandler.configureDirectionalScrolling(for: scrollView)
            // Configure directional scrolling to prevent diagonal movement
            scrollHandler.forceDirectionalScrolling(for: scrollView)
        }
        
        // Listen for theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .timelineThemeDidChange,
            object: nil
        )
    }
    
    func setupConstraints() {
        // Pin TimeRulerView to full width of main view (not offset)
        timeRulerView.autoPinEdge(toSuperviewEdge: .top)
        timeRulerView.autoPinEdge(toSuperviewEdge: .leading) // No withInset
        timeRulerView.autoPinEdge(toSuperviewEdge: .trailing)
        timeRulerView.autoSetDimension(.height, toSize: 30)
        
        // Adjust scrollView to be below TimeRulerView
        scrollView.autoPinEdge(.top, to: .bottom, of: timeRulerView)
        scrollView.autoPinEdge(toSuperviewEdge: .leading)
        scrollView.autoPinEdge(toSuperviewEdge: .trailing)
        scrollView.autoPinEdge(toSuperviewEdge: .bottom)
        
        // Don't set any constraints for contentView - we'll manage it entirely with frames
        // This prevents AutoLayout from overriding our manual contentSize settings
        contentView.translatesAutoresizingMaskIntoConstraints = true
        
        // Also use frame-based layout for TracksStackView
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
        
        // React to stickers changes
        store.$stickers
            .sink { [weak self] stickers in
                guard let self = self else { return }
                print("📱 🎯 Stickers binding triggered with \(stickers.count) stickers")
                // Add a small delay to ensure the store's state is fully updated
                DispatchQueue.main.async {
                    self.updateTracksFromStore()
                }
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
        // Delegate will be set later after scroll handler is initialized
        
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
            duration: finalDuration,
            trimPositions: store.trimPositions // Truyền trim positions từ store
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
                title: "Main Audio",
                volume: volume,
                isMuted: isMuted,
                startTime: .zero,
                duration: finalDuration
            )
            audioTrack.items = [audioItem]
            newTracks.append(audioTrack)
        }
        
        // 3. Create individual sticker tracks (one track per sticker for better control)
        print("📱 🎯 Store has \(store.stickers.count) stickers")
        for (index, sticker) in store.stickers.enumerated() {
            var stickerTrack = TimelineTrack(type: .sticker)
            stickerTrack.items = [sticker] // Each sticker gets its own track
            newTracks.append(stickerTrack)
            
            print("📱 🎯 Created individual track for sticker \(index + 1): \(sticker.id)")
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
        
        // For stickers, try to find the exact same sticker by ID first
        if case .sticker = itemType, let selectedItemId = selectedItem?.id {
            print("📱 🎯 Attempting to restore specific sticker: \(selectedItemId)")
            if let foundSticker = findItemById(selectedItemId) {
                print("📱 ✅ Restored specific sticker by ID: \(selectedItemId)")
                selectedItem = foundSticker
                selectItem(foundSticker)
                return
            }
        }
        
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
    
    /// Add a new sticker with its own track for better control
    public func addStickerItem(_ sticker: StickerTimelineItem) {
        print("📱 🎯 Adding new sticker to store: \(sticker.id)")
        print("📱 🎯 Store currently has \(store.stickers.count) stickers")
        
        // Add sticker to store - this will trigger updateTracksFromStore via binding
        store.addSticker(sticker)
        
        print("📱 🎯 After adding, store has \(store.stickers.count) stickers")
        
        // Auto-select the new sticker after the tracks are updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.selectItem(sticker)
        }
        
        delegate?.timeline(self, didAddTrackOfType: .sticker)
    }
    
    /// Remove a specific sticker and its track
    public func removeStickerItem(_ sticker: StickerTimelineItem) {
        print("📱 🎯 Removing sticker from store: \(sticker.id)")
        
        // Clear selection if this was the selected item
        if selectedItem?.id == sticker.id {
            selectedItem = nil
            selectItem(nil)
        }
        
        // Remove sticker from store - this will trigger updateTracksFromStore via binding
        store.removeSticker(withId: sticker.id)
        
        print("📱 ✅ Removed sticker from store")
    }
}


