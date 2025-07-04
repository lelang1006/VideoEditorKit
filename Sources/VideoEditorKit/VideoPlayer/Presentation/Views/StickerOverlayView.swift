//
//  StickerOverlayView.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 2025-01-28.
//

import UIKit
import AVFoundation
import Combine

/// Overlay view to display stickers on top of video player
final class StickerOverlayView: UIView {
    
    // MARK: - Properties
    
    private var stickers: [StickerTimelineItem] = []
    private var videoDuration: CMTime = .zero
    private var videoSize: CGSize = .zero
    private var currentTime: CMTime = .zero
    
    private var stickerViews: [UIView] = []
    private var cancellables = Set<AnyCancellable>()
    
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
    
    func configure(
        stickers: [StickerTimelineItem],
        videoDuration: CMTime,
        videoSize: CGSize
    ) {
        self.stickers = stickers
        self.videoDuration = videoDuration
        self.videoSize = videoSize
        
        setupStickerViews()
        updateStickerVisibility()
    }
    
    func updateCurrentTime(_ time: CMTime) {
        currentTime = time
        updateStickerVisibility()
    }
    
    // MARK: - Private Methods
    
    private func setupStickerViews() {
        // Remove existing sticker views
        stickerViews.forEach { $0.removeFromSuperview() }
        stickerViews.removeAll()
        
        // Create new sticker views
        for sticker in stickers {
            let stickerView = createStickerView(for: sticker)
            addSubview(stickerView)
            stickerViews.append(stickerView)
        }
    }
    
    private func createStickerView(for sticker: StickerTimelineItem) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        let imageView = UIImageView()
        imageView.image = sticker.image
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        
        containerView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: containerView.heightAnchor)
        ])
        
        return containerView
    }
    
    private func updateStickerVisibility() {
        let currentTimeSeconds = currentTime.seconds
        
        for (index, sticker) in stickers.enumerated() {
            guard index < stickerViews.count else { continue }
            
            let stickerView = stickerViews[index]
            let startTime = sticker.startTime.seconds
            let endTime = (sticker.startTime + sticker.duration).seconds
            
            // Show sticker if current time is within its duration
            let shouldShow = currentTimeSeconds >= startTime && currentTimeSeconds <= endTime
            stickerView.isHidden = !shouldShow
            
            if shouldShow {
                updateStickerTransform(stickerView, for: sticker)
            }
        }
    }
    
    private func updateStickerTransform(_ view: UIView, for sticker: StickerTimelineItem) {
        // Calculate position relative to video bounds
        let videoRect = calculateVideoRect()
        
        // Convert normalized position to actual position
        let x = videoRect.origin.x + (sticker.position.x * videoRect.width)
        let y = videoRect.origin.y + (sticker.position.y * videoRect.height)
        
        // Set frame based on scale
        let baseSize: CGFloat = 60 // Base size for stickers
        let scaledSize = baseSize * sticker.scale
        
        view.frame = CGRect(
            x: x - scaledSize / 2,
            y: y - scaledSize / 2,
            width: scaledSize,
            height: scaledSize
        )
        
        // Apply rotation
        view.transform = CGAffineTransform(rotationAngle: sticker.rotation)
    }
    
    private func calculateVideoRect() -> CGRect {
        guard videoSize.width > 0 && videoSize.height > 0 else {
            return bounds
        }
        
        let containerSize = bounds.size
        let videoAspectRatio = videoSize.width / videoSize.height
        let containerAspectRatio = containerSize.width / containerSize.height
        
        let videoRect: CGRect
        
        if videoAspectRatio > containerAspectRatio {
            // Video is wider than container
            let height = containerSize.width / videoAspectRatio
            let y = (containerSize.height - height) / 2
            videoRect = CGRect(x: 0, y: y, width: containerSize.width, height: height)
        } else {
            // Video is taller than container
            let width = containerSize.height * videoAspectRatio
            let x = (containerSize.width - width) / 2
            videoRect = CGRect(x: x, y: 0, width: width, height: containerSize.height)
        }
        
        return videoRect
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Update sticker positions when bounds change
        updateStickerVisibility()
    }
}
