//
//  TimelineLightThemeDemo.swift
//  
//
//  Created by VideoEditorKit on 29.06.25.
//

import UIKit
import AVFoundation

// MARK: - Light Theme Demo

class TimelineLightThemeDemo {
    
    static func setupLightThemeDemo() -> MultiLayerTimelineViewController {
        // Initialize timeline with light theme
        let timeline = MultiLayerTimelineViewController()
        
        // Set light theme explicitly
        TimelineThemeManager.shared.setTheme(.light)
        
        // Create sample tracks with light theme compatible colors
        timeline.tracks = [
            createVideoTrackDemo(),
            createAudioTrackDemo(),
            createTextTrackDemo(),
            createStickerTrackDemo()
        ]
        
        return timeline
    }
    
    private static func createVideoTrackDemo() -> TimelineTrack {
        let videoItem1 = VideoTimelineItem(
            asset: AVAsset(),
            thumbnails: [],
            startTime: CMTime.zero,
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )
        
        let videoItem2 = VideoTimelineItem(
            asset: AVAsset(),
            thumbnails: [],
            startTime: CMTime(seconds: 6, preferredTimescale: 600),
            duration: CMTime(seconds: 4, preferredTimescale: 600)
        )
        
        return TimelineTrack(type: .video, items: [videoItem1, videoItem2])
    }
    
    private static func createAudioTrackDemo() -> TimelineTrack {
        let audioItem = AudioTimelineItem(
            trackType: .audio(.original),
            asset: nil,
            waveform: generateSampleWaveform(),
            title: "Background Music",
            volume: 0.8,
            isMuted: false,
            startTime: CMTime.zero,
            duration: CMTime(seconds: 10, preferredTimescale: 600)
        )
        
        return TimelineTrack(type: .audio(.original), items: [audioItem])
    }
    
    private static func createTextTrackDemo() -> TimelineTrack {
        let textItem1 = TextTimelineItem(
            text: "Welcome",
            font: .systemFont(ofSize: 32, weight: .bold),
            color: .label, // Adaptive color for light/dark themes
            position: CGPoint(x: 160, y: 100),
            startTime: CMTime(seconds: 1, preferredTimescale: 600),
            duration: CMTime(seconds: 2, preferredTimescale: 600)
        )
        
        let textItem2 = TextTimelineItem(
            text: "Light Theme Demo",
            font: .systemFont(ofSize: 24, weight: .medium),
            color: .systemBlue,
            position: CGPoint(x: 160, y: 200),
            startTime: CMTime(seconds: 3, preferredTimescale: 600),
            duration: CMTime(seconds: 3, preferredTimescale: 600)
        )
        
        return TimelineTrack(type: .text, items: [textItem1, textItem2])
    }
    
    private static func createStickerTrackDemo() -> TimelineTrack {
        // Create a sample sticker image (emoji as UIImage)
        let stickerImage = createEmojiImage("✨", size: CGSize(width: 60, height: 60))
        
        let stickerItem = StickerTimelineItem(
            image: stickerImage,
            position: CGPoint(x: 50, y: 50),
            scale: 1.0,
            rotation: 0,
            startTime: CMTime(seconds: 2, preferredTimescale: 600),
            duration: CMTime(seconds: 4, preferredTimescale: 600)
        )
        
        return TimelineTrack(type: .sticker, items: [stickerItem])
    }
    
    private static func generateSampleWaveform() -> [Float] {
        return (0..<200).map { index in
            let progress = Float(index) / 200.0
            return sin(progress * .pi * 6) * 0.8 + Float.random(in: -0.2...0.2)
        }
    }
    
    private static func createEmojiImage(_ emoji: String, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.height * 0.8),
                .foregroundColor: UIColor.label
            ]
            
            let attributedString = NSAttributedString(string: emoji, attributes: attributes)
            let stringSize = attributedString.size()
            let rect = CGRect(
                x: (size.width - stringSize.width) / 2,
                y: (size.height - stringSize.height) / 2,
                width: stringSize.width,
                height: stringSize.height
            )
            
            attributedString.draw(in: rect)
        }
    }
}

// MARK: - Theme Toggle Extension

extension MultiLayerTimelineViewController {
    
    /// Adds a theme toggle button for demo purposes
    func addThemeToggleButton() {
        let toggleButton = UIButton(type: .system)
        toggleButton.setTitle("🌞/🌙", for: .normal)
        toggleButton.titleLabel?.font = .systemFont(ofSize: 24)
        toggleButton.backgroundColor = TimelineTheme.current.trackHeaderBackgroundColor
        toggleButton.layer.cornerRadius = 25
        toggleButton.addTarget(self, action: #selector(toggleTheme), for: .touchUpInside)
        
        view.addSubview(toggleButton)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toggleButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            toggleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            toggleButton.widthAnchor.constraint(equalToConstant: 50),
            toggleButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc private func toggleTheme() {
        TimelineThemeManager.shared.toggleTheme()
    }
}

// MARK: - Usage Example

extension UIViewController {
    
    func presentTimelineLightThemeDemo() {
        let timeline = TimelineLightThemeDemo.setupLightThemeDemo()
        timeline.addThemeToggleButton()
        
        // Present or embed the timeline
        timeline.modalPresentationStyle = .fullScreen
        present(timeline, animated: true)
    }
}
