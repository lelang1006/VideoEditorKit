//
//  TimelineModels.swift
//  
//
//  Created by VideoEditorKit on 28.06.25.
//

import Foundation
import AVFoundation
import UIKit

// MARK: - Timeline Track Types

public enum TimelineTrackType {
    case video
    case audio(AudioTrackSubtype)
    case text
    case sticker
}

public enum AudioTrackSubtype {
    case original
    case replacement
    case voiceover
}

// MARK: - Timeline Item Protocol

public protocol TimelineItem {
    var id: UUID { get }
    var startTime: CMTime { get set }
    var duration: CMTime { get set }
    var trackType: TimelineTrackType { get }
    var isSelected: Bool { get set }
}

// MARK: - Concrete Timeline Items

public class VideoTimelineItem: TimelineItem {
    public let id = UUID()
    public var startTime: CMTime
    public var duration: CMTime
    public let trackType: TimelineTrackType = .video
    public var isSelected: Bool = false
    
    public let asset: AVAsset
    public let thumbnails: [CGImage]
    
    public init(asset: AVAsset, thumbnails: [CGImage], startTime: CMTime, duration: CMTime) {
        self.asset = asset
        self.thumbnails = thumbnails
        self.startTime = startTime
        self.duration = duration
    }
}

public class AudioTimelineItem: TimelineItem {
    public let id = UUID()
    public var startTime: CMTime
    public var duration: CMTime
    public let trackType: TimelineTrackType
    public var isSelected: Bool = false
    
    public let asset: AVAsset?
    public let waveform: [Float] // Audio waveform data
    public let title: String
    public let volume: Float
    public let isMuted: Bool
    
    public init(trackType: TimelineTrackType, asset: AVAsset?, waveform: [Float], title: String, volume: Float, isMuted: Bool, startTime: CMTime, duration: CMTime) {
        self.trackType = trackType
        self.asset = asset
        self.waveform = waveform
        self.title = title
        self.volume = volume
        self.isMuted = isMuted
        self.startTime = startTime
        self.duration = duration
    }
}

public class TextTimelineItem: TimelineItem {
    public let id = UUID()
    public var startTime: CMTime
    public var duration: CMTime
    public let trackType: TimelineTrackType = .text
    public var isSelected: Bool = false
    
    public let text: String
    public let font: UIFont
    public let color: UIColor
    public let position: CGPoint
    
    public init(text: String, font: UIFont, color: UIColor, position: CGPoint, startTime: CMTime, duration: CMTime) {
        self.text = text
        self.font = font
        self.color = color
        self.position = position
        self.startTime = startTime
        self.duration = duration
    }
}

public class StickerTimelineItem: TimelineItem {
    public let id = UUID()
    public var startTime: CMTime
    public var duration: CMTime
    public let trackType: TimelineTrackType = .sticker
    public var isSelected: Bool = false
    
    public let image: UIImage
    public let position: CGPoint
    public let scale: CGFloat
    public let rotation: CGFloat
    
    public init(image: UIImage, position: CGPoint, scale: CGFloat, rotation: CGFloat, startTime: CMTime, duration: CMTime) {
        self.image = image
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.startTime = startTime
        self.duration = duration
    }
}

// MARK: - Timeline Track

public struct TimelineTrack {
    public let id = UUID()
    public let type: TimelineTrackType
    public var items: [TimelineItem]
    public var isVisible: Bool = true
    public var isLocked: Bool = false
    
    public init(type: TimelineTrackType, items: [TimelineItem] = []) {
        self.type = type
        self.items = items
    }
}

// MARK: - Timeline Configuration

struct TimelineConfiguration {
    let timeScale: CMTimeScale
    let pixelsPerSecond: CGFloat
    let trackHeight: CGFloat
    let trackSpacing: CGFloat
    let minimumItemWidth: CGFloat
    
    static let `default` = TimelineConfiguration(
        timeScale: 600,
        pixelsPerSecond: 100,
        trackHeight: 64,
        trackSpacing: 8,
        minimumItemWidth: 20
    )
}

// MARK: - Timeline Configuration Extensions

extension TimelineConfiguration {
    
    static let zoomed = TimelineConfiguration(
        timeScale: 600,
        pixelsPerSecond: 200,
        trackHeight: 80,
        trackSpacing: 12,
        minimumItemWidth: 30
    )
    
    static let compact = TimelineConfiguration(
        timeScale: 600,
        pixelsPerSecond: 50,
        trackHeight: 48,
        trackSpacing: 4,
        minimumItemWidth: 15
    )
}

// MARK: - Sample Data Creation

extension TimelineTrack {
    
    static func createSampleVideoTrack() -> TimelineTrack {
        let videoItem = VideoTimelineItem(
            asset: AVAsset(), // In real usage, provide actual asset
            thumbnails: [], // In real usage, provide actual thumbnails
            startTime: CMTime.zero,
            duration: CMTime(seconds: 10, preferredTimescale: 600)
        )
        
        return TimelineTrack(type: .video, items: [videoItem])
    }
    
    static func createSampleAudioTrack() -> TimelineTrack {
        let audioItem = AudioTimelineItem(
            trackType: .audio(.original),
            asset: nil,
            waveform: Array(repeating: Float.random(in: 0...1), count: 100),
            title: "Original Audio",
            volume: 1.0,
            isMuted: false,
            startTime: CMTime.zero,
            duration: CMTime(seconds: 10, preferredTimescale: 600)
        )
        
        return TimelineTrack(type: .audio(.original), items: [audioItem])
    }
    
    static func createSampleTextTrack() -> TimelineTrack {
        let textItem = TextTimelineItem(
            text: "Sample Text",
            font: .systemFont(ofSize: 24, weight: .bold),
            color: .white,
            position: CGPoint(x: 100, y: 100),
            startTime: CMTime(seconds: 2, preferredTimescale: 600),
            duration: CMTime(seconds: 3, preferredTimescale: 600)
        )
        
        return TimelineTrack(type: .text, items: [textItem])
    }
}
