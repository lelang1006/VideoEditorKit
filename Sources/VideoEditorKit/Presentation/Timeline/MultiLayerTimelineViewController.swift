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
        
        // Initialize haptic feedback system
        TimelineHapticFeedback.prepareGenerators()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePlayheadPosition()
        updateCarretLayerFrame()
        
        // Apply content insets like VideoTimelineViewController
        let horizontal = view.bounds.width / 2
        scrollView.contentInset = UIEdgeInsets(top: 0, left: horizontal, bottom: 0, right: horizontal)
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
    }
    
    func selectItem(_ item: TimelineItem?) {
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
        let contentWidth = CGFloat(maxDuration.seconds) * configuration.pixelsPerSecond + view.bounds.width
        
        scrollView.contentSize = CGSize(
            width: contentWidth,
            height: CGFloat(tracks.count) * (configuration.trackHeight + configuration.trackSpacing)
        )
        
        // Update time ruler when content size changes
        updateTimeRuler()
    }
    
    func updatePlayheadPosition() {
        updateCarretLayerFrame()
        
        // Update time ruler scroll position to sync with timeline
        timeRulerView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: 0))
    }
    
    func updateTimeRuler() {
        let maxDuration = tracks.flatMap { $0.items }.map { $0.startTime + $0.duration }.max() ?? CMTime.zero
        timeRulerView.setDuration(maxDuration)
    }
    
    func updateCarretLayerFrame() {
        let width: CGFloat = 2.0
        let height: CGFloat = view.bounds.height
        let x = view.bounds.midX - width / 2
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
        
        contentView.autoPinEdgesToSuperviewEdges()
        contentView.autoMatch(.width, to: .width, of: view, withOffset: 0, relation: .greaterThanOrEqual)
        
        timeRulerView.autoPinEdge(toSuperviewEdge: .top)
        timeRulerView.autoPinEdge(toSuperviewEdge: .left)
        timeRulerView.autoPinEdge(toSuperviewEdge: .right)
        timeRulerView.autoSetDimension(.height, toSize: 30)
        
        tracksStackView.autoPinEdge(.top, to: .bottom, of: timeRulerView)
        tracksStackView.autoPinEdge(toSuperviewEdge: .left)
        tracksStackView.autoPinEdge(toSuperviewEdge: .right)
        tracksStackView.autoPinEdge(toSuperviewEdge: .bottom)
    }
    
    func setupBindings() {
        // Store bindings (same as VideoTimelineViewController)
        store.$playheadProgress
            .sink { [weak self] playheadProgress in
                guard let self = self else { return }
                if !self.isSeeking {
                    self.playheadPosition = playheadProgress
                }
            }
            .store(in: &cancellables)
        
        $seekerValue
            .assign(to: \.currentSeekingValue, weakly: store)
            .store(in: &cancellables)

        $isSeeking
            .assign(to: \.isSeeking, weakly: store)
            .store(in: &cancellables)
        
        // Timeline-specific bindings
        $playheadPosition
            .sink { [weak self] _ in
                self?.updatePlayheadPosition()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Factory Methods

extension MultiLayerTimelineViewController {
    
    func makeScrollView() -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.delegate = self
        return scrollView
    }
    
    func makeContentView() -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
    func makeTimeRulerView() -> TimeRulerView {
        return TimeRulerView(configuration: configuration)
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
        // Update seeker value (same as VideoTimelineViewController)
        seekerValue = Double((scrollView.contentOffset.x + (scrollView.contentSize.width / 2)) / scrollView.contentSize.width)
        
        // Update playhead position for visual feedback
        if isSeeking {
            let newTime = CMTime(
                seconds: Double(scrollView.contentOffset.x) / Double(configuration.pixelsPerSecond),
                preferredTimescale: configuration.timeScale
            )
            playheadPosition = newTime
        }
        
        // Update time ruler scroll position to sync with timeline
        timeRulerView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: 0))
    }
}

// MARK: - TimelineTrackViewDelegate

extension MultiLayerTimelineViewController: TimelineTrackViewDelegate {
    
    func trackView(_ trackView: TimelineTrackView, didSelectItem item: TimelineItem) {
        selectItem(item)
        delegate?.timeline(self, didSelectItem: item)
    }
    
    func trackView(_ trackView: TimelineTrackView, didTrimItem item: TimelineItem, newStartTime: CMTime, newDuration: CMTime) {
        // Validate the new placement
        var updatedItem = item
        updatedItem.startTime = newStartTime
        updatedItem.duration = newDuration
        
        let validationResult = TimelineInteractionSystem.validateItemPlacement(updatedItem)
        
        if !validationResult.isValid {
            // Show validation error
            trackView.shakeAnimation()
            return
        }
        
        // Find the track this item belongs to
        guard let trackIndex = tracks.firstIndex(where: { track in
            track.items.contains { $0.id == item.id }
        }) else { return }
        
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
    }
    
    @objc func themeDidChange() {
        updateTheme()
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
        
        // Create a main video track with the asset
        var videoTrack = TimelineTrack(type: .video)
        let videoItem = VideoTimelineItem(
            asset: asset,
            thumbnails: thumbnails,
            startTime: .zero,
            duration: duration
        )
        videoTrack.items = [videoItem]
        
        // Create an audio track if audio exists
        var newTracks = [videoTrack]
        if asset.tracks(withMediaType: .audio).count > 0 {
            var audioTrack = TimelineTrack(type: .audio(.original))
            let audioItem = AudioTimelineItem(
                trackType: .audio(.original),
                asset: asset,
                waveform: [], // Empty waveform for now, could be enhanced later
                title: "Main Audio",
                volume: 1.0,
                isMuted: false,
                startTime: .zero,
                duration: duration
            )
            audioTrack.items = [audioItem]
            newTracks.append(audioTrack)
        }
        
        // Update the timeline with tracks
        self.tracks = newTracks
    }
}
