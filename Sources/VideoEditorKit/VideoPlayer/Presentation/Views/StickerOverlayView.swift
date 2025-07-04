//
//  StickerOverlayView.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 2025-07-04.
//

import UIKit
import AVFoundation
import Combine

/// Overlay view to display stickers on top of video player during preview
final class StickerOverlayView: UIView {
    
    // MARK: - Properties
    
    private var stickerViews: [String: UIImageView] = [:]
    private var stickers: [StickerTimelineItem] = []
    private var currentTime: CMTime = .zero
    private var videoSize: CGSize = .zero
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }
    
    // MARK: - Public Methods
    
    func updateStickers(_ stickers: [StickerTimelineItem]) {
        self.stickers = stickers
        updateVisibleStickers()
    }
    
    func updateCurrentTime(_ time: CMTime) {
        currentTime = time
        updateVisibleStickers()
    }
    
    func updateVideoSize(_ size: CGSize) {
        videoSize = size
        updateStickerPositions()
    }
    
    // MARK: - Private Methods
    
    private func updateVisibleStickers() {
        // Hide all stickers first
        stickerViews.values.forEach { $0.isHidden = true }
        
        // Show stickers that should be visible at current time
        for sticker in stickers {
            let endTime = CMTimeAdd(sticker.startTime, sticker.duration)
            let isVisible = currentTime >= sticker.startTime && currentTime <= endTime
            
            if isVisible {
                showSticker(sticker)
            }
        }
    }
    
    private func showSticker(_ sticker: StickerTimelineItem) {
        let imageView: UIImageView
        
        if let existingView = stickerViews[sticker.id] {
            imageView = existingView
        } else {
            imageView = UIImageView(image: sticker.image)
            imageView.contentMode = .scaleAspectFit
            imageView.backgroundColor = .clear
            addSubview(imageView)
            stickerViews[sticker.id] = imageView
        }
        
        // Position and transform the sticker
        updateStickerView(imageView, with: sticker)
        imageView.isHidden = false
    }
    
    private func updateStickerView(_ imageView: UIImageView, with sticker: StickerTimelineItem) {
        guard bounds.size != .zero else { return }
        
        // Calculate video display rect (considering aspect ratio)
        let videoRect = calculateVideoDisplayRect()
        
        // Convert normalized position (0-1) to actual position within video rect
        let x = videoRect.origin.x + (sticker.position.x * videoRect.width)
        let y = videoRect.origin.y + (sticker.position.y * videoRect.height)
        
        // Calculate size based on scale
        let baseSize: CGFloat = 80 // Default sticker size
        let size = baseSize * sticker.scale
        
        // Set frame
        imageView.frame = CGRect(
            x: x - size/2,
            y: y - size/2,
            width: size,
            height: size
        )
        
        // Apply rotation
        imageView.transform = CGAffineTransform(rotationAngle: sticker.rotation)
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
        for (id, imageView) in stickerViews {
            if let sticker = stickers.first(where: { $0.id == id }) {
                updateStickerView(imageView, with: sticker)
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Update sticker positions when bounds change
        updateStickerPositions()
    }
}
