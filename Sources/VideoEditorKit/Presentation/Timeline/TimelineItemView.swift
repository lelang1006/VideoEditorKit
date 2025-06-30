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
    
    private(set) var itemIsSelected: Bool = false {
        didSet {
            updateSelectionState()
        }
    }
    
    private var isResizing: Bool = false
    private var resizeDirection: ResizeDirection = .none
    private var isLeftHandleHighlighted: Bool = false
    private var isRightHandleHighlighted: Bool = false
    
    // Animation and feedback properties
    private var initialFrame: CGRect = .zero
    private var initialStartTime: CMTime = .zero
    private var initialDuration: CMTime = .zero
    private var dragStartPoint: CGPoint = .zero
    private var snapIndicatorView: UIView?
    private var feedbackGenerator: UIImpactFeedbackGenerator?
    private var isTrimInProgress: Bool = false
    
    // UI Components
    lazy var backgroundView: UIView = makeBackgroundView()
    lazy var contentView: UIView = makeContentView()
    lazy var leftResizeHandle: UIView = makeLeftResizeHandle()
    lazy var rightResizeHandle: UIView = makeRightResizeHandle()
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
        print("📱 ⭐ setSelected called with: \(selected), current itemIsSelected: \(itemIsSelected), isTrimInProgress: \(isTrimInProgress)")
        
        // If trim is in progress, ignore deselection attempts to prevent flicker
        if isTrimInProgress && !selected {
            print("📱 🚫 Ignoring deselection during trim operation")
            return
        }
        
        itemIsSelected = selected
        print("📱 ⭐ setSelected completed, new itemIsSelected: \(itemIsSelected)")
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
        
        // Set appearance immediately (no animation)
        snapIndicator.alpha = 1
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
        
        print("📱 TimelineItemView updateSelectionState: itemIsSelected = \(itemIsSelected)")
        
        // Update immediately without animation
        if itemIsSelected {
            layer.borderColor = theme.selectionBorderColor.cgColor
            layer.borderWidth = 2
            shadowView.alpha = 1
            // Remove transform to avoid touch detection issues
            transform = .identity
            
            // Show handles only when selected
            leftResizeHandle.alpha = 1.0
            rightResizeHandle.alpha = 1.0
            
            print("📱 ✅ Item selected with border (no scale)")
            print("📱 🔧 Handles now visible - left alpha: \(leftResizeHandle.alpha), right alpha: \(rightResizeHandle.alpha)")
        } else {
            layer.borderWidth = 0
            shadowView.alpha = 0
            transform = .identity
            
            // Hide handles when not selected
            leftResizeHandle.alpha = 0.0
            rightResizeHandle.alpha = 0.0
            
            print("📱 ❌ Item deselected")
            print("📱 🔧 Handles now hidden - left alpha: \(leftResizeHandle.alpha), right alpha: \(rightResizeHandle.alpha)")
        }
    }
    
    func updateLayout() {
        let x = CGFloat(item.startTime.seconds) * configuration.pixelsPerSecond
        let width = CGFloat(item.duration.seconds) * configuration.pixelsPerSecond
        let newFrame = CGRect(x: x, y: frame.origin.y, width: max(width, configuration.minimumItemWidth), height: frame.height)
        
        print("📱 🚀 updateLayout - setting frame directly (no animation)")
        frame = newFrame
        
        // Schedule a layout pass to avoid constraint conflicts
        DispatchQueue.main.async {
            self.setNeedsLayout()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let bounds = self.bounds
        
        // Layout main UI components using frames
        shadowView.frame = bounds
        backgroundView.frame = bounds
        contentView.frame = bounds.inset(by: UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4))
        
        // Layout resize handles với kích thước giống HandleLayer (20px width)
        let handleWidth: CGFloat = 20
        leftResizeHandle.frame = CGRect(x: 0, y: 0, width: handleWidth, height: bounds.height)
        rightResizeHandle.frame = CGRect(x: bounds.width - handleWidth, y: 0, width: handleWidth, height: bounds.height)
        
        // Layout arrow icons trong handles
        layoutHandleIcons()
        
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
    
    private func layoutHandleIcons() {
        // Layout left arrow icon
        if let leftImageView = leftResizeHandle.subviews.first as? UIImageView {
            // Icon size giống HandleLayer: 6x16
            let iconSize = CGSize(width: 6, height: 16)
            leftImageView.frame = CGRect(
                x: (leftResizeHandle.bounds.width - iconSize.width) / 2,
                y: (leftResizeHandle.bounds.height - iconSize.height) / 2,
                width: iconSize.width,
                height: iconSize.height
            )
        }
        
        // Layout right arrow icon
        if let rightImageView = rightResizeHandle.subviews.first as? UIImageView {
            // Icon size giống HandleLayer: 6x16
            let iconSize = CGSize(width: 6, height: 16)
            rightImageView.frame = CGRect(
                x: (rightResizeHandle.bounds.width - iconSize.width) / 2,
                y: (rightResizeHandle.bounds.height - iconSize.height) / 2,
                width: iconSize.width,
                height: iconSize.height
            )
        }
    }
}

// MARK: - Gesture Handlers

private extension TimelineItemView {
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        print("📱 TimelineItemView handleTap - setting selected to true")
        setSelected(true)
        // Simple haptic feedback for selection
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        delegate?.itemView(self, didSelectItem: item)
    }
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        let translation = gesture.translation(in: superview)
        let velocity = gesture.velocity(in: superview)
        
        switch gesture.state {
        case .began:
            initialFrame = frame
            initialStartTime = item.startTime
            initialDuration = item.duration
            dragStartPoint = location
            determineGestureType(at: location)
            startDragAnimation()
            
            // Visual feedback cho handles
            updateHandleHighlight()
        case .changed:
            handlePanChanged(translation: translation, velocity: velocity)
        case .ended, .cancelled:
            handlePanEnded(velocity: velocity)
        default:
            break
        }
    }
    
    func startDragAnimation() {
        // Simple haptic feedback for drag start
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // No animation needed - removed resize animation
    }
    
    func determineGestureType(at location: CGPoint) {
        print("📱 🔍 determineGestureType: location=\(location), itemIsSelected=\(itemIsSelected)")
        print("📱 🔍 View bounds: \(bounds), transform: \(transform)")
        print("📱 🔍 Left handle: frame=\(leftResizeHandle.frame), alpha=\(leftResizeHandle.alpha)")
        print("📱 🔍 Right handle: frame=\(rightResizeHandle.frame), alpha=\(rightResizeHandle.alpha)")
        
        // Convert location to account for transform scale
        let scaledLocation: CGPoint
        if transform != .identity {
            // If view is scaled, adjust the location accordingly
            let scaleX = transform.a
            let scaleY = transform.d
            scaledLocation = CGPoint(x: location.x / scaleX, y: location.y / scaleY)
            print("📱 🔧 Original location: \(location), scaled location: \(scaledLocation)")
        } else {
            scaledLocation = location
        }
        
        // Use bounds checking with expanded touch areas
        let handleWidth: CGFloat = 20
        let tolerance: CGFloat = 20 // Increased tolerance for much easier touch
        
        // Define expanded touch areas for handles using original bounds (not scaled)
        let originalBounds = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        let leftHandleTouchArea = CGRect(x: -tolerance, y: 0, width: handleWidth + tolerance * 2, height: originalBounds.height)
        let rightHandleTouchArea = CGRect(x: originalBounds.width - handleWidth - tolerance, y: 0, width: handleWidth + tolerance * 2, height: originalBounds.height)
        
        print("📱 🔍 Touch areas: left=\(leftHandleTouchArea), right=\(rightHandleTouchArea)")
        print("📱 🔍 Using location: \(scaledLocation)")
        print("📱 🔍 Checking handles: left contains=\(leftHandleTouchArea.contains(scaledLocation)), right contains=\(rightHandleTouchArea.contains(scaledLocation))")
        
        // Check left handle touch (with expanded touch area)
        if leftHandleTouchArea.contains(scaledLocation) {
            print("📱 🎯 Touch on LEFT HANDLE")
            
            // Auto-select item if not selected yet
            if !itemIsSelected {
                print("📱 🔄 Auto-selecting item for handle resize")
                setSelected(true)
                delegate?.itemView(self, didSelectItem: item)
            }
            
            isResizing = true
            resizeDirection = .left
            isLeftHandleHighlighted = true
            isTrimInProgress = true // Set trim flag to prevent deselection during trim
            return
        } 
        
        // Check right handle touch (with expanded touch area)
        else if rightHandleTouchArea.contains(scaledLocation) {
            print("📱 🎯 Touch on RIGHT HANDLE") 
            
            // Auto-select item if not selected yet
            if !itemIsSelected {
                print("📱 🔄 Auto-selecting item for handle resize")
                setSelected(true)
                delegate?.itemView(self, didSelectItem: item)
            }
            
            isResizing = true
            resizeDirection = .right
            isRightHandleHighlighted = true
            isTrimInProgress = true // Set trim flag to prevent deselection during trim
            return
        }
        
        // If not touching handles, allow tap to select but no resize
        print("📱 🎯 Touch on ITEM BODY - Selection only")
        isResizing = false
        resizeDirection = .none
    }
    
    func handlePanChanged(translation: CGPoint, velocity: CGPoint) {
        if isResizing {
            handleResize(translation: translation)
        }
        // No drag functionality - only resize via handles
    }
    
    func handleResize(translation: CGPoint) {
        // Only move the handle view itself, don't change the TimelineItemView frame
        switch resizeDirection {
        case .left:
            // Move left handle based on translation
            let handleWidth: CGFloat = 20
            let newX = leftResizeHandle.frame.origin.x + translation.x
            
            // Allow more generous left movement to enable reverting trim back to original position
            // For video items, calculate how far left we can go based on original asset start time
            let maxLeftMovement: CGFloat
            if case .video = item.trackType, let videoItem = item as? VideoTimelineItem {
                // Calculate how much we can expand back towards the original video start (time 0)
                let currentStartTimePixels = CGFloat(item.startTime.seconds) * configuration.pixelsPerSecond
                // Allow expanding all the way back to video start time (0), plus some buffer
                maxLeftMovement = currentStartTimePixels + 50 // 50px buffer for easier interaction
            } else {
                // For other item types, use a reasonable limit
                maxLeftMovement = 100
            }
            
            // Constrain handle movement within expanded bounds
            let constrainedX = max(-maxLeftMovement, min(newX, bounds.width - handleWidth - 20))
            
            leftResizeHandle.frame = CGRect(
                x: constrainedX,
                y: 0,
                width: handleWidth,
                height: bounds.height
            )
            layoutHandleIcons()
            
            print("📱 📍 Left handle moved to X: \(constrainedX) (translation: \(translation.x), maxLeft: -\(maxLeftMovement))")
            
        case .right:
            // Move right handle based on translation
            let handleWidth: CGFloat = 20
            let newX = rightResizeHandle.frame.origin.x + translation.x
            
            // Allow more generous right movement to enable expanding video duration
            let maxRightMovement: CGFloat
            if case .video = item.trackType, let videoItem = item as? VideoTimelineItem {
                // Calculate how much we can expand based on remaining video duration
                let currentEndTime = item.startTime + item.duration
                let originalAssetDuration = videoItem.asset.duration
                let remainingDuration = originalAssetDuration - currentEndTime
                let remainingPixels = CGFloat(remainingDuration.seconds) * configuration.pixelsPerSecond
                maxRightMovement = remainingPixels + 50 // 50px buffer for easier interaction
            } else {
                // For other item types, use a reasonable limit
                maxRightMovement = 200
            }
            
            // Constrain handle movement within expanded bounds  
            let constrainedX = max(20, min(newX, bounds.width + maxRightMovement))
            
            rightResizeHandle.frame = CGRect(
                x: constrainedX,
                y: 0,
                width: handleWidth,
                height: bounds.height
            )
            layoutHandleIcons()
            
            print("📱 📍 Right handle moved to X: \(constrainedX) (translation: \(translation.x), maxRight: +\(maxRightMovement))")
            
        case .none:
            break
        }
        
        // Reset translation to prevent accumulation
        panGesture.setTranslation(.zero, in: superview)
    }
    
    private func updateLeftHandlePosition(relativeX: CGFloat) {
        let handleWidth: CGFloat = 20
        // Chỉ thay đổi X position của handle TRONG item, không di chuyển item
        leftResizeHandle.frame = CGRect(
            x: relativeX, // Relative position trong item
            y: 0, 
            width: handleWidth, 
            height: bounds.height
        )
        layoutHandleIcons() // Update arrow icon position
        print("📱 🔧 Left handle frame updated: \(leftResizeHandle.frame)")
    }
    
    private func updateRightHandlePosition(relativeX: CGFloat) {
        let handleWidth: CGFloat = 20
        // Chỉ thay đổi X position của handle TRONG item, không di chuyển item
        rightResizeHandle.frame = CGRect(
            x: relativeX,
            y: 0,
            width: handleWidth,
            height: bounds.height
        )
        layoutHandleIcons() // Update arrow icon position
        print("📱 🔧 Right handle frame updated: \(rightResizeHandle.frame)")
    }
    
    func handlePanEnded(velocity: CGPoint) {
        removeSnapIndicator()
        
        if isResizing {
            print("📱 🔧 Pan ended in RESIZE mode, calling performTrimBasedOnHandlePositions...")
            
            // RESIZE mode: Thực hiện trim video dựa trên vị trí handles
            performTrimBasedOnHandlePositions()
            
            // No animation needed - removed resize end animation
            
            print("📱 🔚 Resize completed, ensuring item stays selected")
            // Đảm bảo item vẫn được selected sau khi trim
            setSelected(true)
        }
        
        // Simple haptic feedback for drag end
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Reset states
        isResizing = false
        isLeftHandleHighlighted = false
        isRightHandleHighlighted = false
        resizeDirection = .none
        initialFrame = .zero
        isTrimInProgress = false // Clear trim flag to allow normal selection behavior
        
        // Reset handle highlight
        updateHandleHighlight()
        
        // Reset handle positions về normal
        resetHandlePositions()
        
        print("📱 🔚 Pan ended, item should remain selected: \(itemIsSelected)")
    }
    
    private func performTrimBasedOnHandlePositions() {
        print("📱 🎬 performTrimBasedOnHandlePositions called with resizeDirection: \(resizeDirection)")
        
        let pixelsPerSecond = configuration.pixelsPerSecond
        
        switch resizeDirection {
        case .left:
            // For left handle trim, we need to calculate based on how far we can expand left
            let handleRelativeX = leftResizeHandle.frame.origin.x // Relative position trong item
            
            // If handleRelativeX is negative, we're expanding to the left (reverting trim)
            // If handleRelativeX is positive, we're trimming more from the left
            let deltaTime = CMTime(
                seconds: Double(handleRelativeX) / Double(pixelsPerSecond),
                preferredTimescale: configuration.timeScale
            )
            
            // Calculate new start time and duration
            let newStartTime = initialStartTime + deltaTime  
            let newDuration = initialDuration - deltaTime
            
            print("📱 🔍 LEFT TRIM validation: handleRelativeX=\(handleRelativeX), deltaTime=\(deltaTime.seconds), newStartTime=\(newStartTime.seconds), newDuration=\(newDuration.seconds)")
            
            // For video items, we can expand all the way back to the original asset start (time 0)
            // but the calculated newStartTime should never go below 0
            let absoluteMinStartTime: CMTime = .zero
            let minimumDuration = CMTime(seconds: 0.5, preferredTimescale: configuration.timeScale)
            
            // Clamp the newStartTime to not go below 0, and adjust duration accordingly
            let clampedStartTime = max(newStartTime, absoluteMinStartTime)
            let adjustedDuration = (initialStartTime + initialDuration) - clampedStartTime
            
            print("📱 🔍 Video item: absoluteMinStartTime=\(absoluteMinStartTime.seconds)")
            print("📱 🔍 Original calculation: newStartTime=\(newStartTime.seconds), newDuration=\(newDuration.seconds)")
            print("📱 🔍 Clamped calculation: clampedStartTime=\(clampedStartTime.seconds), adjustedDuration=\(adjustedDuration.seconds)")
            print("📱 🔍 Validation: clampedStartTime(\(clampedStartTime.seconds)) >= absoluteMinStartTime(\(absoluteMinStartTime.seconds))? \(clampedStartTime >= absoluteMinStartTime)")
            print("📱 🔍 Validation: adjustedDuration(\(adjustedDuration.seconds)) >= minimumDuration(\(minimumDuration.seconds))? \(adjustedDuration >= minimumDuration)")
            
            if clampedStartTime >= absoluteMinStartTime && adjustedDuration >= minimumDuration {
                item.startTime = clampedStartTime
                item.duration = adjustedDuration
                
                // Update frame immediately during trim for responsive feel
                let newItemX = CGFloat(clampedStartTime.seconds) * pixelsPerSecond
                let newItemWidth = CGFloat(adjustedDuration.seconds) * pixelsPerSecond
                
                // Use CATransaction to update frame without triggering layout conflicts
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                frame = CGRect(x: newItemX, y: frame.origin.y, width: newItemWidth, height: frame.height)
                CATransaction.commit()
                
                delegate?.itemView(self, didTrimItem: item, newStartTime: clampedStartTime, newDuration: adjustedDuration)
                print("📱 ✅ LEFT TRIM completed: startTime=\(clampedStartTime.seconds)s, duration=\(adjustedDuration.seconds)s")
                print("📱 📦 Item frame updated: \(frame)")
                print("📱 🔄 After LEFT TRIM delegate call, itemIsSelected: \(itemIsSelected)")
            } else {
                print("📱 ❌ LEFT TRIM validation failed!")
                print("📱 ❌ clampedStartTime: \(clampedStartTime.seconds), absoluteMinStartTime: \(absoluteMinStartTime.seconds)")
                print("📱 ❌ adjustedDuration: \(adjustedDuration.seconds), minimumDuration: \(minimumDuration.seconds)")
            }
            
        case .right:
            // Calculate new duration based on right handle position
            let handleRelativeX = rightResizeHandle.frame.origin.x // Relative position trong item
            let handleWidth: CGFloat = 20
            let newWidth = handleRelativeX + handleWidth // Total width dựa trên handle position
            let newDuration = CMTime(
                seconds: Double(newWidth) / Double(pixelsPerSecond),
                preferredTimescale: configuration.timeScale
            )
            
            print("📱 🔍 RIGHT TRIM validation: handleRelativeX=\(handleRelativeX), newWidth=\(newWidth), newDuration=\(newDuration.seconds)")
            
            // Validate constraints - check both minimum duration and asset bounds for video items
            let minimumDuration = CMTime(seconds: 0.5, preferredTimescale: configuration.timeScale)
            let maxAllowedDuration: CMTime
            
            // For video items, don't allow expanding beyond original asset duration
            if case .video = item.trackType, let videoItem = item as? VideoTimelineItem {
                // Calculate maximum allowed duration from current start time
                let originalAssetDuration = videoItem.asset.duration
                let maxDurationFromCurrentStart = originalAssetDuration - item.startTime
                maxAllowedDuration = maxDurationFromCurrentStart
                print("📱 🔍 Video item: originalAssetDuration=\(originalAssetDuration.seconds), maxAllowedDuration=\(maxAllowedDuration.seconds)")
            } else {
                // For other item types, use a generous maximum
                maxAllowedDuration = CMTime(seconds: 3600, preferredTimescale: configuration.timeScale) // 1 hour
                print("📱 🔍 Non-video item: maxAllowedDuration=\(maxAllowedDuration.seconds)")
            }
            
            // Clamp the duration to valid range
            let clampedDuration = max(minimumDuration, min(newDuration, maxAllowedDuration))
            
            print("📱 🔍 Original calculation: newDuration=\(newDuration.seconds)")
            print("📱 🔍 Clamped calculation: clampedDuration=\(clampedDuration.seconds)")
            print("📱 🔍 Range: min=\(minimumDuration.seconds), max=\(maxAllowedDuration.seconds)")
            
            if clampedDuration >= minimumDuration && clampedDuration <= maxAllowedDuration {
                item.duration = clampedDuration
                
                // Update frame immediately during trim for responsive feel
                let newItemWidth = CGFloat(clampedDuration.seconds) * pixelsPerSecond
                
                // Use CATransaction to update frame without triggering layout conflicts
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                frame = CGRect(x: frame.origin.x, y: frame.origin.y, width: newItemWidth, height: frame.height)
                CATransaction.commit()
                
                delegate?.itemView(self, didTrimItem: item, newStartTime: item.startTime, newDuration: clampedDuration)
                print("📱 ✅ RIGHT TRIM completed: duration=\(clampedDuration.seconds)s")
                print("📱 📦 Item frame updated: \(frame)")
                print("📱 🔄 After RIGHT TRIM delegate call, itemIsSelected: \(itemIsSelected)")
            } else {
                print("📱 ❌ RIGHT TRIM validation failed:")
                print("   clampedDuration: \(clampedDuration.seconds)s (min: \(minimumDuration.seconds)s, max: \(maxAllowedDuration.seconds)s)")
            }
            
        case .none:
            break
        }
    }
    
    private func resetHandlePositions() {
        // Reset handles về vị trí normal
        let handleWidth: CGFloat = 20
        leftResizeHandle.frame = CGRect(x: 0, y: 0, width: handleWidth, height: bounds.height)
        rightResizeHandle.frame = CGRect(x: bounds.width - handleWidth, y: 0, width: handleWidth, height: bounds.height)
        layoutHandleIcons()
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
        let view = UIView()
        view.backgroundColor = UIColor.border // Màu giống HandleLayer
        view.layer.cornerRadius = 4 // Làm tròn góc như HandleLayer
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray4.cgColor
        view.alpha = 0.0  // Hidden until selected
        
        // Thêm shadow nhẹ để nổi bật
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 1)
        view.layer.shadowRadius = 2
        view.layer.shadowOpacity = 0.2
        
        return view
    }
    
    func makeLeftResizeHandle() -> UIView {
        let view = makeResizeHandle()
        
        // Thêm left arrow icon giống HandleLayer
        let imageView = UIImageView()
        if let leftArrowImage = UIImage(named: "LeftArrow", in: .module, compatibleWith: nil) {
            imageView.image = leftArrowImage
            imageView.contentMode = .scaleAspectFit
            imageView.tintColor = .black
        }
        
        view.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = true
        
        return view
    }
    
    func makeRightResizeHandle() -> UIView {
        let view = makeResizeHandle()
        
        // Thêm right arrow icon giống HandleLayer
        let imageView = UIImageView()
        if let rightArrowImage = UIImage(named: "RightArrow", in: .module, compatibleWith: nil) {
            imageView.image = rightArrowImage
            imageView.contentMode = .scaleAspectFit
            imageView.tintColor = .black
        }
        
        view.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = true
        
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
        
        // Update resize handles với màu giống HandleLayer
        leftResizeHandle.backgroundColor = UIColor.border
        rightResizeHandle.backgroundColor = UIColor.border
        
        // Update shadow
        shadowView.layer.shadowColor = theme.shadowColor.cgColor
        
        // Update selection if selected
        if itemIsSelected {
            layer.borderColor = theme.selectionBorderColor.cgColor
        }
    }
    
    private func updateHandleHighlight() {
        // Update immediately without animation
        // Left handle highlight
        if isLeftHandleHighlighted {
            leftResizeHandle.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.9)
            leftResizeHandle.transform = CGAffineTransform(scaleX: 1.1, y: 1.0)
        } else {
            leftResizeHandle.backgroundColor = UIColor.border
            leftResizeHandle.transform = .identity
        }
        
        // Right handle highlight
        if isRightHandleHighlighted {
            rightResizeHandle.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.9)
            rightResizeHandle.transform = CGAffineTransform(scaleX: 1.1, y: 1.0)
        } else {
            rightResizeHandle.backgroundColor = UIColor.border
            rightResizeHandle.transform = .identity
        }
    }
}
