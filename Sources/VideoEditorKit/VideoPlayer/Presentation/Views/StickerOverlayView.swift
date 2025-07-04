//
//  StickerOverlayView.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 2025-07-04.
//

import UIKit
import AVFoundation
import Combine

public protocol StickerOverlayViewDelegate: AnyObject {
    func stickerOverlayView(_ overlayView: StickerOverlayView, didUpdateSticker sticker: StickerTimelineItem)
    func stickerOverlayView(_ overlayView: StickerOverlayView, didSelectSticker sticker: StickerTimelineItem)
    func stickerOverlayView(_ overlayView: StickerOverlayView, didDeleteSticker sticker: StickerTimelineItem)
}

/// Interactive sticker view with controls
public final class InteractiveStickerView: UIView {
    
    // MARK: - Properties
    
    weak var delegate: StickerOverlayViewDelegate?
    
    private let imageView: UIImageView
    private let selectionBorder: UIView
    private let deleteButton: UIButton
    private let scaleButton: UIButton
    
    private var initialTransform: CGAffineTransform = .identity
    private var initialCenter: CGPoint = .zero
    private var initialDistance: CGFloat = 0
    
    var sticker: StickerTimelineItem {
        didSet {
            updateAppearance()
        }
    }
    
    var isSelected: Bool = false {
        didSet {
            updateSelectionState()
        }
    }
    
    var isInteractionEnabled: Bool = true {
        didSet {
            isUserInteractionEnabled = isInteractionEnabled
            updateSelectionState()
        }
    }
    
    // MARK: - Init
    
    init(sticker: StickerTimelineItem) {
        self.sticker = sticker
        
        // Create image view
        self.imageView = UIImageView(image: sticker.image)
        self.imageView.contentMode = .scaleAspectFit
        self.imageView.backgroundColor = .clear
        
        // Create selection border
        self.selectionBorder = UIView()
        self.selectionBorder.layer.borderWidth = 2
        self.selectionBorder.layer.borderColor = UIColor.white.cgColor
        self.selectionBorder.layer.cornerRadius = 8
        self.selectionBorder.backgroundColor = .clear
        self.selectionBorder.isHidden = true
        
        // Create delete button
        self.deleteButton = UIButton(type: .system)
        self.deleteButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        self.deleteButton.tintColor = .systemRed
        self.deleteButton.backgroundColor = .white
        self.deleteButton.layer.cornerRadius = 12
        self.deleteButton.layer.shadowColor = UIColor.black.cgColor
        self.deleteButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.deleteButton.layer.shadowRadius = 4
        self.deleteButton.layer.shadowOpacity = 0.3
        self.deleteButton.isHidden = true
        
        // Create scale button
        self.scaleButton = UIButton(type: .system)
        self.scaleButton.setImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right"), for: .normal)
        self.scaleButton.tintColor = .systemBlue
        self.scaleButton.backgroundColor = .white
        self.scaleButton.layer.cornerRadius = 12
        self.scaleButton.layer.shadowColor = UIColor.black.cgColor
        self.scaleButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.scaleButton.layer.shadowRadius = 4
        self.scaleButton.layer.shadowOpacity = 0.3
        self.scaleButton.isHidden = true
        
        super.init(frame: .zero)
        
        setupViews()
        setupGestures()
        updateAppearance()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        addSubview(selectionBorder)
        addSubview(imageView)
        addSubview(deleteButton)
        addSubview(scaleButton)
        
        // Layout
        imageView.translatesAutoresizingMaskIntoConstraints = false
        selectionBorder.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        scaleButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Selection border
            selectionBorder.centerXAnchor.constraint(equalTo: centerXAnchor),
            selectionBorder.centerYAnchor.constraint(equalTo: centerYAnchor),
            selectionBorder.widthAnchor.constraint(equalTo: widthAnchor, constant: 8),
            selectionBorder.heightAnchor.constraint(equalTo: heightAnchor, constant: 8),
            
            // Image view fills the container
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: widthAnchor),
            imageView.heightAnchor.constraint(equalTo: heightAnchor),
            
            // Delete button (top-left corner)
            deleteButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -12),
            deleteButton.topAnchor.constraint(equalTo: topAnchor, constant: -12),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24),
            
            // Scale button (bottom-right corner)
            scaleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 12),
            scaleButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 12),
            scaleButton.widthAnchor.constraint(equalToConstant: 24),
            scaleButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    private func setupGestures() {
        // Tap to select
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        
        // Pan to move
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        addGestureRecognizer(panGesture)
        
        // Pinch to scale
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        addGestureRecognizer(pinchGesture)
        
        // Rotation
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation))
        addGestureRecognizer(rotationGesture)
        
        // Button actions
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        
        // Scale button pan gesture
        let scalePanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleScalePan))
        scaleButton.addGestureRecognizer(scalePanGesture)
    }
    
    // MARK: - Update
    
    private func updateAppearance() {
        imageView.image = sticker.image
        
        // Apply scale and rotation
        transform = CGAffineTransform(scaleX: sticker.scale, y: sticker.scale)
            .rotated(by: sticker.rotation)
    }
    
    private func updateSelectionState() {
        let shouldShowControls = isSelected && isInteractionEnabled
        
        selectionBorder.isHidden = !shouldShowControls
        deleteButton.isHidden = !shouldShowControls
        scaleButton.isHidden = !shouldShowControls
        
        if isSelected {
            superview?.bringSubviewToFront(self)
            
            // Add subtle glow effect
            selectionBorder.layer.shadowColor = UIColor.white.cgColor
            selectionBorder.layer.shadowRadius = 8
            selectionBorder.layer.shadowOpacity = 0.8
            selectionBorder.layer.shadowOffset = .zero
        } else {
            selectionBorder.layer.shadowOpacity = 0
        }
    }
    
    // MARK: - Gesture Handlers
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard isInteractionEnabled else { return }
        delegate?.stickerOverlayView(superview as! StickerOverlayView, didSelectSticker: sticker)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard isSelected && isInteractionEnabled else { return }
        
        switch gesture.state {
        case .began:
            initialCenter = center
            
        case .changed:
            let translation = gesture.translation(in: superview)
            center = CGPoint(
                x: initialCenter.x + translation.x,
                y: initialCenter.y + translation.y
            )
            
        case .ended:
            updateStickerPosition()
            
        default:
            break
        }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard isSelected && isInteractionEnabled else { return }
        
        switch gesture.state {
        case .began:
            initialTransform = transform
            
        case .changed:
            let scale = max(0.3, min(3.0, gesture.scale))
            transform = initialTransform.scaledBy(x: scale, y: scale)
            
        case .ended:
            updateStickerScale()
            
        default:
            break
        }
    }
    
    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        guard isSelected && isInteractionEnabled else { return }
        
        switch gesture.state {
        case .began:
            initialTransform = transform
            
        case .changed:
            let rotation = gesture.rotation
            transform = initialTransform.rotated(by: rotation)
            
        case .ended:
            updateStickerRotation()
            
        default:
            break
        }
    }
    
    @objc private func handleScalePan(_ gesture: UIPanGestureRecognizer) {
        guard isSelected && isInteractionEnabled else { return }
        
        switch gesture.state {
        case .began:
            initialCenter = center
            initialDistance = 0
            
        case .changed:
            let translation = gesture.translation(in: superview)
            let distance = sqrt(translation.x * translation.x + translation.y * translation.y)
            
            if initialDistance == 0 {
                initialDistance = distance
                initialTransform = transform
            }
            
            if distance > 0 {
                let scale = max(0.3, min(3.0, distance / max(initialDistance, 1)))
                transform = initialTransform.scaledBy(x: scale, y: scale)
            }
            
        case .ended:
            updateStickerScale()
            
        default:
            break
        }
    }
    
    @objc private func deleteButtonTapped() {
        delegate?.stickerOverlayView(superview as! StickerOverlayView, didDeleteSticker: sticker)
    }
    
    // MARK: - Update Sticker Properties
    
    private func updateStickerPosition() {
        guard let superview = superview else { return }
        
        // Convert center to normalized position (0-1)
        let normalizedPosition = CGPoint(
            x: max(0, min(1, center.x / superview.bounds.width)),
            y: max(0, min(1, center.y / superview.bounds.height))
        )
        
        var updatedSticker = sticker
        updatedSticker.position = normalizedPosition
        self.sticker = updatedSticker
        
        delegate?.stickerOverlayView(superview as! StickerOverlayView, didUpdateSticker: updatedSticker)
    }
    
    private func updateStickerScale() {
        // Extract scale from transform
        let scale = max(0.3, min(3.0, sqrt(transform.a * transform.a + transform.c * transform.c)))
        
        var updatedSticker = sticker
        updatedSticker.scale = scale
        self.sticker = updatedSticker
        
        delegate?.stickerOverlayView(superview as! StickerOverlayView, didUpdateSticker: updatedSticker)
    }
    
    private func updateStickerRotation() {
        // Extract rotation from transform
        let rotation = atan2(transform.b, transform.a)
        
        var updatedSticker = sticker
        updatedSticker.rotation = rotation
        self.sticker = updatedSticker
        
        delegate?.stickerOverlayView(superview as! StickerOverlayView, didUpdateSticker: updatedSticker)
    }
}

/// Overlay view to display stickers on top of video player during preview
public final class StickerOverlayView: UIView {
    
    // MARK: - Properties
    
    public weak var delegate: StickerOverlayViewDelegate?
    
    private var stickerViews: [String: InteractiveStickerView] = [:]
    private var stickers: [StickerTimelineItem] = []
    private var currentTime: CMTime = .zero
    private var videoSize: CGSize = .zero
    
    private var selectedStickerID: String?
    
    public var isInteractionEnabled: Bool = false {
        didSet {
            updateInteractionState()
        }
    }
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        backgroundColor = .clear
        isUserInteractionEnabled = true
    }
    
    // MARK: - Public Methods
    
    public func updateStickers(_ stickers: [StickerTimelineItem]) {
        self.stickers = stickers
        
        // Remove views for stickers that no longer exist
        let currentStickerIDs = Set(stickers.map { $0.id })
        let viewsToRemove = stickerViews.filter { !currentStickerIDs.contains($0.key) }
        viewsToRemove.forEach { id, view in
            view.removeFromSuperview()
            stickerViews.removeValue(forKey: id)
        }
        
        updateVisibleStickers()
    }
    
    public func updateCurrentTime(_ time: CMTime) {
        currentTime = time
        updateVisibleStickers()
    }
    
    public func updateVideoSize(_ size: CGSize) {
        videoSize = size
        updateStickerPositions()
    }
    
    public func selectSticker(withID id: String) {
        selectedStickerID = id
        updateSelectionStates()
    }
    
    public func deselectAllStickers() {
        selectedStickerID = nil
        updateSelectionStates()
    }
    
    // MARK: - Private Methods
    
    private func updateVisibleStickers() {
        for sticker in stickers {
            let endTime = CMTimeAdd(sticker.startTime, sticker.duration)
            let isVisible = isInteractionEnabled || (currentTime >= sticker.startTime && currentTime <= endTime)
            
            if isVisible {
                showSticker(sticker)
            } else {
                hideStickerView(withID: sticker.id)
            }
        }
    }
    
    private func showSticker(_ sticker: StickerTimelineItem) {
        let stickerView: InteractiveStickerView
        
        if let existingView = stickerViews[sticker.id] {
            stickerView = existingView
            stickerView.sticker = sticker
        } else {
            stickerView = InteractiveStickerView(sticker: sticker)
            stickerView.delegate = self
            addSubview(stickerView)
            stickerViews[sticker.id] = stickerView
        }
        
        updateStickerView(stickerView, with: sticker)
        stickerView.isHidden = false
        stickerView.isInteractionEnabled = isInteractionEnabled
        stickerView.isSelected = (sticker.id == selectedStickerID)
    }
    
    private func hideStickerView(withID id: String) {
        stickerViews[id]?.isHidden = true
    }
    
    private func updateStickerView(_ stickerView: InteractiveStickerView, with sticker: StickerTimelineItem) {
        guard bounds != .zero else { return }
        
        // Calculate video display rect (considering aspect ratio)
        let videoRect = calculateVideoDisplayRect()
        
        // Convert normalized position (0-1) to actual position within video rect
        let x = videoRect.origin.x + (sticker.position.x * videoRect.width)
        let y = videoRect.origin.y + (sticker.position.y * videoRect.height)
        
        // Base size for sticker
        let baseSize: CGFloat = 80
        let size = baseSize * sticker.scale
        
        // Set frame
        stickerView.frame = CGRect(
            x: x - size/2,
            y: y - size/2,
            width: size,
            height: size
        )
        
        // Apply rotation and scale (handled by InteractiveStickerView)
        stickerView.transform = CGAffineTransform(rotationAngle: sticker.rotation)
            .scaledBy(x: sticker.scale, y: sticker.scale)
    }
    
    private func calculateVideoDisplayRect() -> CGRect {
        guard videoSize.width > 0 && videoSize.height > 0 else {
            return bounds
        }
        
        let containerSize = bounds.size
        let videoAspectRatio = videoSize.width / videoSize.height
        let containerAspectRatio = containerSize.width / containerSize.height
        
        let videoRect: CGRect
        
        if videoAspectRatio > containerAspectRatio {
            // Video is wider than container (letterboxing on top/bottom)
            let height = containerSize.width / videoAspectRatio
            let y = (containerSize.height - height) / 2
            videoRect = CGRect(x: 0, y: y, width: containerSize.width, height: height)
        } else {
            // Video is taller than container (pillarboxing on left/right)
            let width = containerSize.height * videoAspectRatio
            let x = (containerSize.width - width) / 2
            videoRect = CGRect(x: x, y: 0, width: width, height: containerSize.height)
        }
        
        return videoRect
    }
    
    private func updateStickerPositions() {
        for (id, stickerView) in stickerViews {
            if let sticker = stickers.first(where: { $0.id == id }) {
                updateStickerView(stickerView, with: sticker)
            }
        }
    }
    
    private func updateInteractionState() {
        stickerViews.values.forEach { stickerView in
            stickerView.isInteractionEnabled = isInteractionEnabled
        }
        
        if isInteractionEnabled {
            // Show all stickers for editing
            updateVisibleStickers()
        } else {
            // Hide selection
            deselectAllStickers()
        }
    }
    
    private func updateSelectionStates() {
        stickerViews.forEach { id, view in
            view.isSelected = (id == selectedStickerID)
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        // Update sticker positions when bounds change
        updateStickerPositions()
    }
}

// MARK: - StickerOverlayViewDelegate

extension StickerOverlayView: StickerOverlayViewDelegate {
    public func stickerOverlayView(_ overlayView: StickerOverlayView, didUpdateSticker sticker: StickerTimelineItem) {
        // Update in stickers array
        if let index = stickers.firstIndex(where: { $0.id == sticker.id }) {
            stickers[index] = sticker
        }
        
        // Forward to external delegate
        delegate?.stickerOverlayView(self, didUpdateSticker: sticker)
    }
    
    public func stickerOverlayView(_ overlayView: StickerOverlayView, didSelectSticker sticker: StickerTimelineItem) {
        selectedStickerID = sticker.id
        updateSelectionStates()
        delegate?.stickerOverlayView(self, didSelectSticker: sticker)
    }
    
    public func stickerOverlayView(_ overlayView: StickerOverlayView, didDeleteSticker sticker: StickerTimelineItem) {
        // Remove from local array
        stickers.removeAll { $0.id == sticker.id }
        
        // Remove view
        stickerViews[sticker.id]?.removeFromSuperview()
        stickerViews.removeValue(forKey: sticker.id)
        
        // Clear selection if this was the selected sticker
        if selectedStickerID == sticker.id {
            selectedStickerID = nil
        }
        
        // Forward to external delegate
        delegate?.stickerOverlayView(self, didDeleteSticker: sticker)
    }
}
