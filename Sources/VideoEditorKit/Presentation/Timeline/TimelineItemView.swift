//
//  TimelineItemView.swift
//  
//
//  Created by VideoEditorKit on 29.06.25.
//

import UIKit
import AVFoundation
import PureLayout

protocol TimelineItemViewDelegate: AnyObject {
    func itemView(_ itemView: TimelineItemView, didSelectItem item: TimelineItem)
    func itemView(_ itemView: TimelineItemView, didTrimItem item: TimelineItem, newStartTime: CMTime, newDuration: CMTime)
}

class TimelineItemView: UIView {
    
    // MARK: - Constants
    
    internal static let thumbnailDurationInSeconds: CGFloat = 2.0
    
    // MARK: - Properties
    
    weak var delegate: TimelineItemViewDelegate?
    
    private(set) var item: TimelineItem
    private let configuration: TimelineConfiguration
    
    private var itemIsSelected: Bool = false {
        didSet {
            updateSelectionState()
        }
    }
    
    private var isDragging: Bool = false
    private var isResizing: Bool = false
    private var resizeDirection: ResizeDirection = .none
    
    // Animation and feedback properties
    private var initialFrame: CGRect = .zero
    private var dragStartPoint: CGPoint = .zero
    private var snapIndicatorView: UIView?
    private var feedbackGenerator: UIImpactFeedbackGenerator?
    
    // UI Components
    lazy var backgroundView: UIView = makeBackgroundView()
    lazy var contentView: UIView = makeContentView()
    lazy var leftResizeHandle: UIView = makeResizeHandle()
    lazy var rightResizeHandle: UIView = makeResizeHandle()
    private lazy var shadowView: UIView = makeShadowView()
    
    // Gestures
    private var panGesture: UIPanGestureRecognizer!
    private var tapGesture: UITapGestureRecognizer!
    
    // MARK: - Init
    
    init(item: TimelineItem, configuration: TimelineConfiguration) {
        self.item = item
        self.configuration = configuration
        super.init(frame: .zero)
        
        // Disable AutoLayout for the main view since we'll position it using frames
        translatesAutoresizingMaskIntoConstraints = true
        
        setupUI()
        setupGestures()
        updateContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Public Methods

extension TimelineItemView {
    
    func setSelected(_ selected: Bool) {
        itemIsSelected = selected
    }
    
    func updateItemData(_ newItem: TimelineItem) {
        item = newItem
        updateContent()
        updateLayout()
    }
    
    func snapToGrid(_ time: CMTime) -> CMTime {
        let snapInterval = CMTime(seconds: 0.5, preferredTimescale: configuration.timeScale) // Snap to 0.5 second intervals
        let snapValue = time.seconds / snapInterval.seconds
        let snappedValue = round(snapValue) * snapInterval.seconds
        return CMTime(seconds: snappedValue, preferredTimescale: configuration.timeScale)
    }
    
    func showSnapIndicator(at position: CGFloat) {
        removeSnapIndicator()
        
        let theme = TimelineTheme.current
        snapIndicatorView = UIView()
        snapIndicatorView?.backgroundColor = theme.snapIndicatorColor
        snapIndicatorView?.layer.cornerRadius = 1
        
        guard let snapIndicator = snapIndicatorView,
              let superview = superview else { return }
        
        superview.addSubview(snapIndicator)
        snapIndicator.frame = CGRect(x: position, y: 0, width: 2, height: superview.bounds.height)
        
        // Animate appearance
        snapIndicator.alpha = 0
        UIView.animate(withDuration: 0.1) {
            snapIndicator.alpha = 1
        }
    }
    
    func removeSnapIndicator() {
        snapIndicatorView?.removeFromSuperview()
        snapIndicatorView = nil
    }
}

// MARK: - Methods

extension TimelineItemView {
    
    func setupUI() {
        // Setup view hierarchy
        addSubview(shadowView)
        addSubview(backgroundView)
        addSubview(contentView)
        addSubview(leftResizeHandle)
        addSubview(rightResizeHandle)
        
        setupConstraints()
        updateSelectionState()
        
        // Initialize feedback generator
        feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        feedbackGenerator?.prepare()
    }
    
    func setupConstraints() {
        // Disable AutoLayout for all subviews since we'll use frame-based layout
        shadowView.translatesAutoresizingMaskIntoConstraints = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = true
        contentView.translatesAutoresizingMaskIntoConstraints = true
        leftResizeHandle.translatesAutoresizingMaskIntoConstraints = true
        rightResizeHandle.translatesAutoresizingMaskIntoConstraints = true
        
        // Layout will be handled in layoutSubviews
        setNeedsLayout()
    }
    
    func setupGestures() {
        // Main pan gesture for dragging and resizing
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
        
        // Tap gesture for selection
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
        
        // Enable user interaction
        isUserInteractionEnabled = true
    }
    
    func updateContent() {
        switch item.trackType {
        case .video:
            updateVideoContent()
        case .audio:
            updateAudioContent()
        case .text:
            updateTextContent()
        case .sticker:
            updateStickerContent()
        }
    }
    
    func updateVideoContent() {
        let theme = TimelineTheme.current
        backgroundView.backgroundColor = theme.videoItemColor
        
        // Add video thumbnails if available
        if let videoItem = item as? VideoTimelineItem {
            addVideoThumbnails(videoItem.thumbnails)
        }
    }
    
    func updateAudioContent() {
        let theme = TimelineTheme.current
        backgroundView.backgroundColor = theme.audioItemColor
        
        if let audioItem = item as? AudioTimelineItem {
            addWaveform(audioItem.waveform)
        }
    }
    
    func updateTextContent() {
        let theme = TimelineTheme.current
        backgroundView.backgroundColor = theme.textItemColor
        
        if let textItem = item as? TextTimelineItem {
            // Content will be shown through visual representation in contentView
        }
    }
    
    func updateStickerContent() {
        let theme = TimelineTheme.current
        backgroundView.backgroundColor = theme.stickerItemColor
        
        if let stickerItem = item as? StickerTimelineItem {
            addStickerPreview(stickerItem.image)
        }
    }
    
    func addVideoThumbnails(_ thumbnails: [CGImage]) {
        // Clear existing thumbnails
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        guard !thumbnails.isEmpty else { 
            return 
        }
        
        // Create image views for thumbnails
        // Each thumbnail represents a fixed duration of video (see thumbnailDurationInSeconds)
        for (index, thumbnail) in thumbnails.enumerated() {
            let imageView = UIImageView()
            imageView.image = UIImage(cgImage: thumbnail, scale: 1.0, orientation: .up)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.backgroundColor = .clear
            
            // Disable AutoLayout for thumbnail views
            imageView.translatesAutoresizingMaskIntoConstraints = true
            
            contentView.addSubview(imageView)
        }
        
        // Layout thumbnails - each represents the configured duration
        layoutThumbnails()
    }
    
    private func layoutThumbnails() {
        let contentBounds = contentView.bounds
        guard contentBounds.height > 4 else { return }
        
        // Each thumbnail represents a fixed duration of video
        let thumbnailWidth = Self.thumbnailDurationInSeconds * configuration.pixelsPerSecond
        let thumbnailHeight = contentBounds.height - 4
        let inset: CGFloat = 2
        
        var currentX: CGFloat = inset
        
        for (index, subview) in contentView.subviews.enumerated() {
            if let imageView = subview as? UIImageView {
                let frame = CGRect(
                    x: currentX,
                    y: inset,
                    width: thumbnailWidth,
                    height: thumbnailHeight
                )
                imageView.frame = frame
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                
                currentX += thumbnailWidth
            }
        }
    }
    
    func addWaveform(_ waveform: [Float]) {
        let waveformView = WaveformView(waveform: waveform)
        waveformView.translatesAutoresizingMaskIntoConstraints = true
        contentView.addSubview(waveformView)
        
        // Layout using frames in layoutSubviews
        setNeedsLayout()
    }
    
    func addStickerPreview(_ image: UIImage) {
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = true
        contentView.addSubview(imageView)
        
        // Layout using frames in layoutSubviews
        setNeedsLayout()
    }
    
    func updateSelectionState() {
        let theme = TimelineTheme.current
        
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut]) {
            if self.itemIsSelected {
                self.layer.borderColor = theme.selectionBorderColor.cgColor
                self.layer.borderWidth = 2
                self.leftResizeHandle.isHidden = false
                self.rightResizeHandle.isHidden = false
                self.shadowView.alpha = 1
                self.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
            } else {
                self.layer.borderWidth = 0
                self.leftResizeHandle.isHidden = true
                self.rightResizeHandle.isHidden = true
                self.shadowView.alpha = 0
                self.transform = .identity
            }
        }
    }
    
    func updateLayout() {
        let x = CGFloat(item.startTime.seconds) * configuration.pixelsPerSecond
        let width = CGFloat(item.duration.seconds) * configuration.pixelsPerSecond
        
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
            self.frame = CGRect(x: x, y: self.frame.origin.y, width: max(width, self.configuration.minimumItemWidth), height: self.frame.height)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let bounds = self.bounds
        
        // Layout main UI components using frames
        shadowView.frame = bounds
        backgroundView.frame = bounds
        contentView.frame = bounds.inset(by: UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4))
        
        // Layout resize handles
        leftResizeHandle.frame = CGRect(x: 0, y: 0, width: 8, height: bounds.height)
        rightResizeHandle.frame = CGRect(x: bounds.width - 8, y: 0, width: 8, height: bounds.height)
        
        // Layout content based on item type
        switch item.trackType {
        case .video:
            // Layout video thumbnails using fixed 2-second width approach
            if contentView.subviews.contains(where: { $0 is UIImageView }) {
                layoutThumbnails()
            }
        case .audio:
            // Layout waveform view
            if let waveformView = contentView.subviews.first(where: { $0 is WaveformView }) {
                waveformView.frame = contentView.bounds
            }
        case .sticker:
            // Layout sticker preview
            if let imageView = contentView.subviews.first(where: { $0 is UIImageView }) {
                let size = CGSize(width: 40, height: 40)
                imageView.frame = CGRect(
                    x: (contentView.bounds.width - size.width) / 2,
                    y: (contentView.bounds.height - size.height) / 2,
                    width: size.width,
                    height: size.height
                )
            }
        case .text:
            // Text items might not need special layout
            break
        }
    }
}

// MARK: - Gesture Handlers

private extension TimelineItemView {
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        setSelected(true)
        TimelineHapticFeedback.selection()
        delegate?.itemView(self, didSelectItem: item)
    }
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        let translation = gesture.translation(in: superview)
        let velocity = gesture.velocity(in: superview)
        
        switch gesture.state {
        case .began:
            initialFrame = frame
            dragStartPoint = location
            determineGestureType(at: location)
            startDragAnimation()
        case .changed:
            handlePanChanged(translation: translation, velocity: velocity)
        case .ended, .cancelled:
            handlePanEnded(velocity: velocity)
        default:
            break
        }
    }
    
    func startDragAnimation() {
        TimelineHapticFeedback.dragStart()
        
        if isDragging {
            TimelineAnimationSystem.animateDragStart(self)
        } else if isResizing {
            TimelineAnimationSystem.animateResizeStart(self)
        }
    }
    
    func determineGestureType(at location: CGPoint) {
        let resizeThreshold: CGFloat = 12
        
        if location.x <= resizeThreshold && !leftResizeHandle.isHidden {
            isResizing = true
            resizeDirection = .left
        } else if location.x >= bounds.width - resizeThreshold && !rightResizeHandle.isHidden {
            isResizing = true
            resizeDirection = .right
        } else {
            isDragging = true
            resizeDirection = .none
        }
    }
    
    func handlePanChanged(translation: CGPoint, velocity: CGPoint) {
        if isDragging {
            handleDrag(translation: translation)
        } else if isResizing {
            handleResize(translation: translation)
        }
    }
    
    func handleDrag(translation: CGPoint) {
        // Calculate new position
        var newFrame = initialFrame
        newFrame.origin.x += translation.x
        
        // Constrain to superview bounds
        if let superview = superview {
            newFrame.origin.x = max(0, min(newFrame.origin.x, superview.bounds.width - newFrame.width))
        }
        
        // Calculate snapped time
        let newStartTime = CMTime(
            seconds: Double(newFrame.origin.x) / Double(configuration.pixelsPerSecond),
            preferredTimescale: configuration.timeScale
        )
        let snappedTime = snapToGrid(newStartTime)
        let snappedX = CGFloat(snappedTime.seconds) * configuration.pixelsPerSecond
        
        // Show snap indicator if close to snap point
        if abs(newFrame.origin.x - snappedX) < 10 {
            showSnapIndicator(at: snappedX)
            newFrame.origin.x = snappedX
            TimelineHapticFeedback.snap()
        } else {
            removeSnapIndicator()
        }
        
        frame = newFrame
    }
    
    func handleResize(translation: CGPoint) {
        let pixelsPerSecond = configuration.pixelsPerSecond
        let timeChange = CMTime(seconds: Double(translation.x) / Double(pixelsPerSecond), preferredTimescale: configuration.timeScale)
        
        var newStartTime = item.startTime
        var newDuration = item.duration
        var newFrame = initialFrame
        
        switch resizeDirection {
        case .left:
            // Trim from start
            let candidateStartTime = item.startTime + timeChange
            let candidateDuration = item.duration - timeChange
            
            // Ensure minimum duration
            let minimumDuration = CMTime(seconds: 0.1, preferredTimescale: configuration.timeScale)
            if candidateDuration >= minimumDuration && candidateStartTime >= .zero {
                newStartTime = snapToGrid(candidateStartTime)
                newDuration = item.duration - (newStartTime - item.startTime)
                
                let snappedX = CGFloat(newStartTime.seconds) * pixelsPerSecond
                let snappedWidth = CGFloat(newDuration.seconds) * pixelsPerSecond
                
                newFrame.origin.x = snappedX
                newFrame.size.width = max(snappedWidth, configuration.minimumItemWidth)
            }
            
        case .right:
            // Trim from end
            let candidateDuration = item.duration + timeChange
            let minimumDuration = CMTime(seconds: 0.1, preferredTimescale: configuration.timeScale)
            
            if candidateDuration >= minimumDuration {
                newDuration = snapToGrid(candidateDuration)
                let snappedWidth = CGFloat(newDuration.seconds) * pixelsPerSecond
                newFrame.size.width = max(snappedWidth, configuration.minimumItemWidth)
            }
            
        case .none:
            break
        }
        
        // Show visual feedback for snapping
        let isSnapped = (resizeDirection == .left && abs(translation.x - (CGFloat(newStartTime.seconds) * pixelsPerSecond - initialFrame.origin.x)) < 5) ||
                       (resizeDirection == .right && abs(translation.x - (CGFloat(newDuration.seconds) * pixelsPerSecond - initialFrame.width)) < 5)
        
        if isSnapped {
            TimelineHapticFeedback.snap()
        }
        
        frame = newFrame
    }
    
    func handlePanEnded(velocity: CGPoint) {
        removeSnapIndicator()
        
        // Calculate final position/size based on current frame
        let finalStartTime = CMTime(
            seconds: Double(frame.origin.x) / Double(configuration.pixelsPerSecond),
            preferredTimescale: configuration.timeScale
        )
        let finalDuration = CMTime(
            seconds: Double(frame.width) / Double(configuration.pixelsPerSecond),
            preferredTimescale: configuration.timeScale
        )
        
        // Animate back to normal state
        if isDragging {
            TimelineAnimationSystem.animateDragEnd(self, velocity: velocity)
        } else if isResizing {
            TimelineAnimationSystem.animateResizeEnd(self)
        }
        
        TimelineHapticFeedback.dragEnd()
        
        // Update item data
        if isDragging {
            item.startTime = finalStartTime
            delegate?.itemView(self, didTrimItem: item, newStartTime: finalStartTime, newDuration: item.duration)
        } else if isResizing {
            item.startTime = finalStartTime
            item.duration = finalDuration
            delegate?.itemView(self, didTrimItem: item, newStartTime: finalStartTime, newDuration: finalDuration)
        }
        
        // Reset state
        isDragging = false
        isResizing = false
        resizeDirection = .none
        initialFrame = .zero
    }
}

// MARK: - Factory Methods

extension TimelineItemView {
    
    func makeBackgroundView() -> UIView {
        let view = UIView()
        view.layer.cornerRadius = 4
        view.clipsToBounds = true
        return view
    }
    
    func makeContentView() -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.clipsToBounds = true
        return view
    }
    
    func makeResizeHandle() -> UIView {
        let theme = TimelineTheme.current
        let view = UIView()
        view.backgroundColor = theme.resizeHandleColor.withAlphaComponent(0.8)
        view.isHidden = true
        return view
    }
    
    func makeShadowView() -> UIView {
        let theme = TimelineTheme.current
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.shadowColor = theme.shadowColor.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.layer.shadowOpacity = 0.3
        view.alpha = 0
        return view
    }
}

// MARK: - Supporting Types

private enum ResizeDirection {
    case none
    case left
    case right
}

// MARK: - WaveformView

private class WaveformView: UIView {
    
    private let waveform: [Float]
    
    init(waveform: [Float]) {
        self.waveform = waveform
        super.init(frame: .zero)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(1.0)
        
        let barWidth = rect.width / CGFloat(waveform.count)
        let centerY = rect.height / 2
        
        for (index, amplitude) in waveform.enumerated() {
            let x = CGFloat(index) * barWidth
            let height = CGFloat(amplitude) * rect.height * 0.4
            
            context.move(to: CGPoint(x: x, y: centerY - height))
            context.addLine(to: CGPoint(x: x, y: centerY + height))
            context.strokePath()
        }
    }
}

// MARK: - TimelineThemeAware

extension TimelineItemView: TimelineThemeAware {
    
    public func updateTheme() {
        let theme = TimelineTheme.current
        
        // Update colors based on content
        updateContent()
        
        // Update resize handles
        leftResizeHandle.backgroundColor = theme.resizeHandleColor.withAlphaComponent(0.8)
        rightResizeHandle.backgroundColor = theme.resizeHandleColor.withAlphaComponent(0.8)
        
        // Update shadow
        shadowView.layer.shadowColor = theme.shadowColor.cgColor
        
        // Update selection if selected
        if itemIsSelected {
            layer.borderColor = theme.selectionBorderColor.cgColor
        }
    }
}
