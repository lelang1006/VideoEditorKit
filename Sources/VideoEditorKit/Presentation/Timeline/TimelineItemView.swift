//
//  TimelineItemView.swift
//  
//
//  Created by VideoEditorKit on 29.06.25.
//

import UIKit
import AVFoundation
import PureLayout



class TimelineItemView: UIView {
    
    // MARK: - Constants
    
    internal static let thumbnailDurationInSeconds: CGFloat = 2.0
    
    // MARK: - Properties
    
    private(set) var item: TimelineItem
    private let configuration: TimelineConfiguration
    
    private(set) var itemIsSelected: Bool = false {
        didSet {
            updateSelectionState()
        }
    }
    
    // UI Components
    lazy var backgroundView: UIView = makeBackgroundView()
    lazy var contentView: UIView = makeContentView()
    lazy var leftResizeHandle: UIView = makeLeftResizeHandle()
    lazy var rightResizeHandle: UIView = makeRightResizeHandle()
    private lazy var shadowView: UIView = makeShadowView()
    
    // Trimming state
    private var isTrimmingInProgress: Bool = false
    
    // MARK: - Init
    
    init(item: TimelineItem, configuration: TimelineConfiguration) {
        self.item = item
        self.configuration = configuration
        super.init(frame: .zero)
        
        // Disable AutoLayout for the main view since we'll position it using frames
        translatesAutoresizingMaskIntoConstraints = true
        
        setupUI()
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
    
    func updateSelectionState() {
        let theme = TimelineTheme.current
        
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
        } else {
            layer.borderWidth = 0
            shadowView.alpha = 0
            transform = .identity
            
            // Hide handles when not selected
            leftResizeHandle.alpha = 0.0
            rightResizeHandle.alpha = 0.0
        }
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
        // Clear existing content
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        // Create container for better organization
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = true
        containerView.backgroundColor = .clear
        contentView.addSubview(containerView)
        
        // Add icon image view
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(systemName: "star.fill")
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconImageView.translatesAutoresizingMaskIntoConstraints = true
        containerView.addSubview(iconImageView)
        
        // Add preview image view
        let previewImageView = UIImageView(image: image)
        previewImageView.contentMode = .scaleAspectFit
        previewImageView.translatesAutoresizingMaskIntoConstraints = true
        previewImageView.layer.cornerRadius = 4
        previewImageView.clipsToBounds = true
        containerView.addSubview(previewImageView)
        
        // Add label for sticker identifier
        let stickerLabel = UILabel()
        stickerLabel.text = "Sticker"
        stickerLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        stickerLabel.textColor = .white
        stickerLabel.textAlignment = .center
        stickerLabel.translatesAutoresizingMaskIntoConstraints = true
        containerView.addSubview(stickerLabel)
        
        // Layout using frames in layoutSubviews
        setNeedsLayout()
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
        
        // Only reset handle positions if we're not currently trimming
        if !isTrimmingInProgress {
            leftResizeHandle.frame = CGRect(x: 0, y: 0, width: handleWidth, height: bounds.height)
            rightResizeHandle.frame = CGRect(x: bounds.width - handleWidth, y: 0, width: handleWidth, height: bounds.height)
        } else {
            print("📱 🚫 Skipping handle layout during trimming")
        }
        
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
            // Layout sticker preview with enhanced UI
            if let containerView = contentView.subviews.first {
                containerView.frame = contentView.bounds
                
                let bounds = containerView.bounds
                let iconSize: CGFloat = 16
                let previewSize: CGFloat = min(bounds.height - 20, 30)
                let labelHeight: CGFloat = 12
                
                // Layout icon (left side) - icon uses system image
                if let iconImageView = containerView.subviews.first(where: { 
                    if let imageView = $0 as? UIImageView,
                       let image = imageView.image {
                        return image.isSymbolImage
                    }
                    return false
                }) {
                    iconImageView.frame = CGRect(
                        x: 8,
                        y: (bounds.height - iconSize) / 2,
                        width: iconSize,
                        height: iconSize
                    )
                }
                
                // Layout preview image (center) - preview uses regular image
                if let previewImageView = containerView.subviews.first(where: { 
                    if let imageView = $0 as? UIImageView,
                       let image = imageView.image {
                        return !image.isSymbolImage
                    }
                    return false
                }) {
                    previewImageView.frame = CGRect(
                        x: (bounds.width - previewSize) / 2,
                        y: 4,
                        width: previewSize,
                        height: previewSize
                    )
                }
                
                // Layout label (bottom)
                if let label = containerView.subviews.first(where: { $0 is UILabel }) {
                    label.frame = CGRect(
                        x: 4,
                        y: bounds.height - labelHeight - 2,
                        width: bounds.width - 8,
                        height: labelHeight
                    )
                }
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
}

// MARK: - Handle Movement for Trimming Feedback

extension TimelineItemView {
    
    /// Moves the left handle by the specified offset for visual feedback during trimming
    func moveLeftHandle(by offsetX: CGFloat) {
        print("📱 🎨 TimelineItemView.moveLeftHandle: offsetX=\(offsetX)")
        
        // Set trimming flag to prevent layoutSubviews from resetting positions
        isTrimmingInProgress = true
        
        // Ensure item is selected and handle is visible
        setSelected(true)
        leftResizeHandle.alpha = 1.0
        leftResizeHandle.isHidden = false
        
        // Make handle visible for debugging
        leftResizeHandle.backgroundColor = UIColor.blue
        leftResizeHandle.layer.borderWidth = 3
        leftResizeHandle.layer.borderColor = UIColor.cyan.cgColor
        
        // Disable clipping to allow handle to move outside bounds
        clipsToBounds = false
        leftResizeHandle.clipsToBounds = false
        superview?.clipsToBounds = false
        
        // Calculate movement limits for left handle
        let handleWidth: CGFloat = 20
        let pixelsPerSecond = configuration.pixelsPerSecond
        
        // Calculate how far left we can go (based on available trim space)
        var maxLeftMovement: CGFloat = -200  // Default: allow 200px left movement
        var maxRightMovement: CGFloat = bounds.width - handleWidth  // Default: to right edge
        
        if let videoItem = item as? VideoTimelineItem {
            // For video items, calculate based on actual trim positions
            let currentDuration = item.duration.seconds
            let assetDuration = videoItem.asset.duration.seconds
            let currentTrimPositions = videoItem.trimPositions
            
            // Tính toán space còn lại dựa trên trim positions thực tế
            let currentTrimStartTime = currentTrimPositions.start * assetDuration
            let currentTrimEndTime = currentTrimPositions.end * assetDuration
            
            // Space có thể trim thêm từ bên trái (từ đầu asset đến current start)
            let availableLeftTrimSpace = currentTrimStartTime
            
            // Space có thể extend về bên phải (giữ nguyên current end, chỉ di chuyển start về trái)
            let maxPossibleStartExtension = availableLeftTrimSpace
            
            // Giới hạn hợp lý cho left handle movement
            let maxReasonableLeftTrim = min(maxPossibleStartExtension, 3.0) // Max 3 seconds
            maxLeftMovement = -CGFloat(maxReasonableLeftTrim * Double(pixelsPerSecond))
            
            // Allow right movement but keep minimum 0.1s duration
            let minDuration = 0.1
            let maxTrimFromLeft = currentDuration - minDuration
            maxRightMovement = CGFloat(maxTrimFromLeft * Double(pixelsPerSecond))
            
            print("📱 📏 LEFT HANDLE LIMITS (ACCURATE):")
            print("  - Asset duration: \(assetDuration)s")
            print("  - Current trim: start=\(currentTrimPositions.start), end=\(currentTrimPositions.end)")
            print("  - Current trim times: \(currentTrimStartTime)s to \(currentTrimEndTime)s")
            print("  - Available left space: \(availableLeftTrimSpace)s")
            print("  - Max reasonable left trim: \(maxReasonableLeftTrim)s")
            print("  - Max left movement: \(maxLeftMovement)px")
            print("  - Max right movement: \(maxRightMovement)px")
        }
        
        // Apply limits to the offset
        let clampedOffsetX = max(maxLeftMovement, min(offsetX, maxRightMovement))
        
        if clampedOffsetX != offsetX {
            print("📱 ⚠️ LEFT HANDLE: Clamped offset from \(offsetX) to \(clampedOffsetX)")
        }
        
        print("📱 🏗️ BEFORE RECALCULATION:")
        print("  - Current handle frame: \(leftResizeHandle.frame)")
        print("  - Self bounds: \(bounds)")
        print("  - Original offsetX: \(offsetX), Clamped: \(clampedOffsetX)")
        
        // Calculate new frame position directly (no transform!)
        let newX = clampedOffsetX // Use clamped value
        let newFrame = CGRect(
            x: newX,
            y: 0,
            width: handleWidth,
            height: bounds.height
        )
        
        print("📱 🧮 FRAME CALCULATION:")
        print("  - New frame calculated: \(newFrame)")
        
        // Set the new frame directly
        leftResizeHandle.frame = newFrame
        
        print("📱 ✅ AFTER FRAME SET:")
        print("  - Actual handle frame: \(leftResizeHandle.frame)")
        print("  - Handle center: \(leftResizeHandle.center)")
        
        // Force display update
        leftResizeHandle.setNeedsDisplay()
        setNeedsDisplay()
        
        print("📱 🎯 LEFT HANDLE MOVED TO: x=\(leftResizeHandle.frame.origin.x)")
    }
    
    /// Moves the right handle by the specified offset for visual feedback during trimming
    func moveRightHandle(by offsetX: CGFloat) {
        print("📱 🎨 TimelineItemView.moveRightHandle: offsetX=\(offsetX)")
        
        // Set trimming flag to prevent layoutSubviews from resetting positions
        isTrimmingInProgress = true
        
        // Ensure item is selected and handle is visible
        setSelected(true)
        rightResizeHandle.alpha = 1.0
        rightResizeHandle.isHidden = false
        
        // Make handle visible for debugging
        rightResizeHandle.backgroundColor = UIColor.blue
        rightResizeHandle.layer.borderWidth = 3
        rightResizeHandle.layer.borderColor = UIColor.cyan.cgColor
        
        // Disable clipping to allow handle to move outside bounds
        clipsToBounds = false
        rightResizeHandle.clipsToBounds = false
        superview?.clipsToBounds = false
        
        // Calculate movement limits for right handle
        let pixelsPerSecond = configuration.pixelsPerSecond
        
        // Calculate how far left and right we can move the right handle
        var maxLeftMovement: CGFloat = -200  // Default: allow 200px left movement
        var maxRightMovement: CGFloat = 200  // Default: allow 200px right movement
        
        if let videoItem = item as? VideoTimelineItem {
            // For video items, calculate based on actual trim positions
            let currentDuration = item.duration.seconds
            let assetDuration = videoItem.asset.duration.seconds
            let currentTrimPositions = videoItem.trimPositions
            
            // Tính toán space còn lại dựa trên trim positions thực tế
            let currentTrimStartTime = currentTrimPositions.start * assetDuration
            let currentTrimEndTime = currentTrimPositions.end * assetDuration
            
            // Space có thể extend thêm từ bên phải (từ current end đến cuối asset)
            let availableRightExtendSpace = assetDuration - currentTrimEndTime
            
            // Space có thể trim từ bên phải (di chuyển end về trái, giữ nguyên start)
            let minDuration = 0.1
            let maxTrimFromRight = currentDuration - minDuration
            maxLeftMovement = -CGFloat(maxTrimFromRight * Double(pixelsPerSecond))
            
            // Giới hạn hợp lý cho right handle movement
            let maxReasonableRightExtension = min(availableRightExtendSpace, 3.0) // Max 3 seconds
            maxRightMovement = CGFloat(maxReasonableRightExtension * Double(pixelsPerSecond))
            
            print("📱 📏 RIGHT HANDLE LIMITS (ACCURATE):")
            print("  - Asset duration: \(assetDuration)s")
            print("  - Current trim: start=\(currentTrimPositions.start), end=\(currentTrimPositions.end)")
            print("  - Current trim times: \(currentTrimStartTime)s to \(currentTrimEndTime)s")
            print("  - Available right space: \(availableRightExtendSpace)s")
            print("  - Max reasonable right extension: \(maxReasonableRightExtension)s")
            print("  - Max left movement: \(maxLeftMovement)px")
            print("  - Max right movement: \(maxRightMovement)px")
        }
        
        // Apply limits to the offset
        let clampedOffsetX = max(maxLeftMovement, min(offsetX, maxRightMovement))
        
        if clampedOffsetX != offsetX {
            print("📱 ⚠️ RIGHT HANDLE: Clamped offset from \(offsetX) to \(clampedOffsetX)")
        }
        
        print("📱 🏗️ RIGHT BEFORE RECALCULATION:")
        print("  - Current handle frame: \(rightResizeHandle.frame)")
        print("  - Self bounds: \(bounds)")
        print("  - Original offsetX: \(offsetX), Clamped: \(clampedOffsetX)")
        
        // Calculate new frame position directly (no transform!)
        let handleWidth: CGFloat = 20
        let originalRightX = bounds.width - handleWidth // Original right handle position
        let newX = originalRightX + clampedOffsetX // Use clamped value
        let newFrame = CGRect(
            x: newX,
            y: 0,
            width: handleWidth,
            height: bounds.height
        )
        
        print("📱 🧮 RIGHT FRAME CALCULATION:")
        print("  - Original right X: \(originalRightX)")
        print("  - New frame calculated: \(newFrame)")
        
        // Set the new frame directly
        rightResizeHandle.frame = newFrame
        
        print("📱 ✅ RIGHT AFTER FRAME SET:")
        print("  - Actual handle frame: \(rightResizeHandle.frame)")
        print("  - Handle center: \(rightResizeHandle.center)")
        
        // Force display update
        rightResizeHandle.setNeedsDisplay()
        setNeedsDisplay()
        
        print("📱 🎯 RIGHT HANDLE MOVED TO: x=\(rightResizeHandle.frame.origin.x)")
    }
    
    /// Resets both handles to their original positions
    func resetHandlePositions() {
        print("📱 🧹 TimelineItemView.resetHandlePositions")
        
        // Clear trimming flag to allow normal layout
        isTrimmingInProgress = false
        
        // Reset transforms (not needed but for safety)
        leftResizeHandle.transform = .identity
        rightResizeHandle.transform = .identity
        
        // Reset colors back to normal
        leftResizeHandle.backgroundColor = UIColor.white
        rightResizeHandle.backgroundColor = UIColor.white
        leftResizeHandle.layer.borderWidth = 0
        rightResizeHandle.layer.borderWidth = 0
        
        print("📱 ✅ Handles reset - trimming flag cleared")
        
        // Trigger layout to restore original positions
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    /// Immediately highlights the specified handle using the same visual feedback as during trimming
    func highlightHandle(direction: MultiLayerTimelineViewController.TrimDirection) {
        print("📱 🎨 TimelineItemView.highlightHandle: \(direction)")
        
        // Ensure item is selected and handles are visible
        setSelected(true)
        
        switch direction {
        case .left:
            leftResizeHandle.alpha = 1.0
            leftResizeHandle.isHidden = false
            
            // Apply the same highlighting used during trimming
            leftResizeHandle.backgroundColor = UIColor.red
            leftResizeHandle.layer.borderWidth = 3
            leftResizeHandle.layer.borderColor = UIColor.yellow.cgColor
            
        case .right:
            rightResizeHandle.alpha = 1.0
            rightResizeHandle.isHidden = false
            
            // Apply the same highlighting used during trimming
            rightResizeHandle.backgroundColor = UIColor.blue
            rightResizeHandle.layer.borderWidth = 3
            rightResizeHandle.layer.borderColor = UIColor.cyan.cgColor
            
        case .none:
            // Do nothing for .none case
            break
        }
        
        print("📱 ✅ Handle highlighted: \(direction)")
    }
}
