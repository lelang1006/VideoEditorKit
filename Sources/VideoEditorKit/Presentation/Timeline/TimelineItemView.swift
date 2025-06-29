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
    func itemView(_ itemView: TimelineItemView, didDeleteItem item: TimelineItem)
}

class TimelineItemView: UIView {
    
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
    lazy var titleLabel: UILabel = makeTitleLabel()
    lazy var leftResizeHandle: UIView = makeResizeHandle()
    lazy var rightResizeHandle: UIView = makeResizeHandle()
    private lazy var deleteButton: UIButton = makeDeleteButton()
    private lazy var shadowView: UIView = makeShadowView()
    
    // Gestures
    private var panGesture: UIPanGestureRecognizer!
    private var tapGesture: UITapGestureRecognizer!
    
    // MARK: - Init
    
    init(item: TimelineItem, configuration: TimelineConfiguration) {
        self.item = item
        self.configuration = configuration
        super.init(frame: .zero)
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
        addSubview(titleLabel)
        addSubview(leftResizeHandle)
        addSubview(rightResizeHandle)
        addSubview(deleteButton)
        
        setupConstraints()
        updateSelectionState()
        
        // Initialize feedback generator
        feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        feedbackGenerator?.prepare()
    }
    
    func setupConstraints() {
        shadowView.autoPinEdgesToSuperviewEdges()
        backgroundView.autoPinEdgesToSuperviewEdges()
        
        contentView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4))
        
        titleLabel.autoPinEdge(toSuperviewEdge: .left, withInset: 8)
        titleLabel.autoPinEdge(toSuperviewEdge: .right, withInset: 8)
        titleLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        leftResizeHandle.autoPinEdge(toSuperviewEdge: .left)
        leftResizeHandle.autoPinEdge(toSuperviewEdge: .top)
        leftResizeHandle.autoPinEdge(toSuperviewEdge: .bottom)
        leftResizeHandle.autoSetDimension(.width, toSize: 8)
        
        rightResizeHandle.autoPinEdge(toSuperviewEdge: .right)
        rightResizeHandle.autoPinEdge(toSuperviewEdge: .top)
        rightResizeHandle.autoPinEdge(toSuperviewEdge: .bottom)
        rightResizeHandle.autoSetDimension(.width, toSize: 8)
        
        deleteButton.autoPinEdge(toSuperviewEdge: .top, withInset: 4)
        deleteButton.autoPinEdge(toSuperviewEdge: .right, withInset: 4)
        deleteButton.autoSetDimensions(to: CGSize(width: 20, height: 20))
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
        titleLabel.text = "Video"
        titleLabel.textColor = theme.primaryTextColor
        
        // Add video thumbnails if available
        if let videoItem = item as? VideoTimelineItem {
            addVideoThumbnails(videoItem.thumbnails)
        }
    }
    
    func updateAudioContent() {
        let theme = TimelineTheme.current
        backgroundView.backgroundColor = theme.audioItemColor
        titleLabel.textColor = theme.primaryTextColor
        
        if let audioItem = item as? AudioTimelineItem {
            titleLabel.text = audioItem.title
            addWaveform(audioItem.waveform)
        }
    }
    
    func updateTextContent() {
        let theme = TimelineTheme.current
        backgroundView.backgroundColor = theme.textItemColor
        titleLabel.textColor = theme.primaryTextColor
        
        if let textItem = item as? TextTimelineItem {
            titleLabel.text = textItem.text
        }
    }
    
    func updateStickerContent() {
        let theme = TimelineTheme.current
        backgroundView.backgroundColor = theme.stickerItemColor
        titleLabel.text = "Sticker"
        titleLabel.textColor = theme.primaryTextColor
        
        if let stickerItem = item as? StickerTimelineItem {
            addStickerPreview(stickerItem.image)
        }
    }
    
    func addVideoThumbnails(_ thumbnails: [CGImage]) {
        // Create thumbnail strip
        let thumbnailHeight = contentView.bounds.height - 4
        let thumbnailWidth = thumbnailHeight * (16.0/9.0) // Assume 16:9 aspect ratio
        
        for (index, thumbnail) in thumbnails.enumerated() {
            let imageView = UIImageView(image: UIImage(cgImage: thumbnail))
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            
            contentView.addSubview(imageView)
            
            let x = CGFloat(index) * thumbnailWidth
            imageView.frame = CGRect(x: x, y: 2, width: thumbnailWidth, height: thumbnailHeight)
        }
    }
    
    func addWaveform(_ waveform: [Float]) {
        let waveformView = WaveformView(waveform: waveform)
        contentView.addSubview(waveformView)
        waveformView.autoPinEdgesToSuperviewEdges()
    }
    
    func addStickerPreview(_ image: UIImage) {
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        contentView.addSubview(imageView)
        
        imageView.autoAlignAxis(toSuperviewAxis: .horizontal)
        imageView.autoAlignAxis(toSuperviewAxis: .vertical)
        imageView.autoSetDimensions(to: CGSize(width: 40, height: 40))
    }
    
    func updateSelectionState() {
        let theme = TimelineTheme.current
        
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut]) {
            if self.itemIsSelected {
                self.layer.borderColor = theme.selectionBorderColor.cgColor
                self.layer.borderWidth = 2
                self.leftResizeHandle.isHidden = false
                self.rightResizeHandle.isHidden = false
                self.deleteButton.isHidden = false
                self.shadowView.alpha = 1
                self.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
            } else {
                self.layer.borderWidth = 0
                self.leftResizeHandle.isHidden = true
                self.rightResizeHandle.isHidden = true
                self.deleteButton.isHidden = true
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
        
        // Update content based on new duration
        updateResizeVisualFeedback(newDuration: newDuration)
    }
    
    func updateResizeVisualFeedback(newDuration: CMTime) {
        // Update title to show new duration
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.minute, .second]
        let durationString = formatter.string(from: newDuration.seconds) ?? "0s"
        
        UIView.transition(with: titleLabel, duration: 0.1, options: .transitionCrossDissolve) {
            self.titleLabel.text = "\(self.getItemTitle()) - \(durationString)"
        }
    }
    
    func getItemTitle() -> String {
        switch item.trackType {
        case .video:
            return "Video"
        case .audio:
            if let audioItem = item as? AudioTimelineItem {
                return audioItem.title
            }
            return "Audio"
        case .text:
            if let textItem = item as? TextTimelineItem {
                return textItem.text.prefix(10) + (textItem.text.count > 10 ? "..." : "")
            }
            return "Text"
        case .sticker:
            return "Sticker"
        }
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
        
        // Reset title to original
        UIView.transition(with: titleLabel, duration: 0.2, options: .transitionCrossDissolve) {
            switch self.item.trackType {
            case .video:
                self.titleLabel.text = "Video"
            case .audio:
                if let audioItem = self.item as? AudioTimelineItem {
                    self.titleLabel.text = audioItem.title
                }
            case .text:
                if let textItem = self.item as? TextTimelineItem {
                    self.titleLabel.text = textItem.text
                }
            case .sticker:
                self.titleLabel.text = "Sticker"
            }
        }
        
        // Reset state
        isDragging = false
        isResizing = false
        resizeDirection = .none
        initialFrame = .zero
    }
    
    @objc func deleteButtonTapped() {
        TimelineHapticFeedback.delete()
        
        // Animate deletion
        TimelineAnimationSystem.animateItemRemoval(self) {
            self.delegate?.itemView(self, didDeleteItem: self.item)
        }
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
    
    func makeTitleLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }
    
    func makeResizeHandle() -> UIView {
        let theme = TimelineTheme.current
        let view = UIView()
        view.backgroundColor = theme.resizeHandleColor.withAlphaComponent(0.8)
        view.isHidden = true
        return view
    }
    
    func makeDeleteButton() -> UIButton {
        let theme = TimelineTheme.current
        let button = UIButton()
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = theme.deleteButtonColor
        button.backgroundColor = theme.backgroundColor.withAlphaComponent(0.9)
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        button.isHidden = true
        return button
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
        
        // Update delete button
        deleteButton.tintColor = theme.deleteButtonColor
        deleteButton.backgroundColor = theme.backgroundColor.withAlphaComponent(0.9)
        
        // Update shadow
        shadowView.layer.shadowColor = theme.shadowColor.cgColor
        
        // Update selection if selected
        if itemIsSelected {
            layer.borderColor = theme.selectionBorderColor.cgColor
        }
    }
}
