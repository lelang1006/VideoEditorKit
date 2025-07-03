//
//  TimelineModels.swift
//  
//
//  Created by VideoEditorKit on 28.06.25.
//

import Foundation
import AVFoundation
import UIKit

// MARK: - Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Timeline Track Types

public enum TimelineTrackType {
    case video
    case audio(AudioTrackSubtype)
    case text
    case sticker
}

// MARK: - Debug Extensions
extension TimelineTrackType {
    var debugDescription: String {
        switch self {
        case .video:
            return "video"
        case .audio(let subtype):
            return "audio(\(subtype))"
        case .text:
            return "text"
        case .sticker:
            return "sticker"
        }
    }
}

public enum AudioTrackSubtype {
    case original
    case replacement
    case voiceover
}

// MARK: - Trim Behavior

public enum TrimBehavior {
    case master           // Video track - trim affects entire timeline
    case dependent        // Other tracks - trim only affects relative timing
}

public enum TrimDirection {
    case left
    case right
    case none
}

// MARK: - Timeline Item Protocol

public protocol TimelineItem {
    var id: String { get }
    var startTime: CMTime { get set }
    var duration: CMTime { get set }
    var trackType: TimelineTrackType { get }
    var isSelected: Bool { get set }
    var trimBehavior: TrimBehavior { get }
}

// MARK: - Concrete Timeline Items

public class VideoTimelineItem: TimelineItem {
    public let id: String
    public var startTime: CMTime
    public var duration: CMTime
    public let trackType: TimelineTrackType = .video
    public var isSelected: Bool = false
    
    // Master track behavior
    public let trimBehavior: TrimBehavior = .master
    
    public let asset: AVAsset
    public let thumbnails: [CGImage]
    public let trimPositions: (start: Double, end: Double) // Global trim positions (affects entire timeline)
    
    public init(asset: AVAsset, thumbnails: [CGImage], startTime: CMTime, duration: CMTime, trimPositions: (start: Double, end: Double) = (0.0, 1.0), id: String? = nil) {
        self.id = id ?? UUID().uuidString
        self.asset = asset
        self.thumbnails = thumbnails
        self.startTime = startTime
        self.duration = duration
        self.trimPositions = trimPositions
    }
    
    // Internal initializer that preserves ID (for timeline regeneration)
    internal init(id: String, asset: AVAsset, thumbnails: [CGImage], startTime: CMTime, duration: CMTime, trimPositions: (start: Double, end: Double) = (0.0, 1.0)) {
        self.id = id
        self.asset = asset
        self.thumbnails = thumbnails
        self.startTime = startTime
        self.duration = duration
        self.trimPositions = trimPositions
    }
}

public class AudioTimelineItem: TimelineItem {
    public let id: String
    public var startTime: CMTime
    public var duration: CMTime
    public let trackType: TimelineTrackType
    public var isSelected: Bool = false
    
    // Dependent track behavior
    public let trimBehavior: TrimBehavior = .dependent
    
    public let asset: AVAsset?
    public let waveform: [Float] // Audio waveform data
    public let title: String
    public let volume: Float
    public let isMuted: Bool
    
    // Relative trim positions (relative to video timeline)
    public var relativeTrimPositions: (start: Double, end: Double)
    
    public init(trackType: TimelineTrackType, asset: AVAsset?, waveform: [Float], title: String, volume: Float, isMuted: Bool, startTime: CMTime, duration: CMTime, relativeTrimPositions: (start: Double, end: Double) = (0.0, 1.0), id: String? = nil) {
        self.id = id ?? UUID().uuidString
        self.trackType = trackType
        self.asset = asset
        self.waveform = waveform
        self.title = title
        self.volume = volume
        self.isMuted = isMuted
        self.startTime = startTime
        self.duration = duration
        self.relativeTrimPositions = relativeTrimPositions
    }
    
    /// Calculate absolute time range in original asset based on video trim positions
    public func getAbsoluteTimeRange(relativeTo videoItem: VideoTimelineItem) -> (start: Double, end: Double) {
        let videoStart = videoItem.trimPositions.start
        let videoEnd = videoItem.trimPositions.end
        let videoDuration = videoEnd - videoStart
        
        let audioStart = videoStart + (videoDuration * relativeTrimPositions.start)
        let audioEnd = videoStart + (videoDuration * relativeTrimPositions.end)
        
        return (audioStart, audioEnd)
    }
}

public class TextTimelineItem: TimelineItem {
    public let id: String
    public var startTime: CMTime
    public var duration: CMTime
    public let trackType: TimelineTrackType = .text
    public var isSelected: Bool = false
    
    // Dependent track behavior
    public let trimBehavior: TrimBehavior = .dependent
    
    public let text: String
    public let font: UIFont
    public let color: UIColor
    public let position: CGPoint
    
    // Relative trim positions (relative to video timeline)
    public var relativeTrimPositions: (start: Double, end: Double)
    
    public init(text: String, font: UIFont, color: UIColor, position: CGPoint, startTime: CMTime, duration: CMTime, relativeTrimPositions: (start: Double, end: Double) = (0.0, 1.0), id: String? = nil) {
        self.id = id ?? UUID().uuidString
        self.text = text
        self.font = font
        self.color = color
        self.position = position
        self.startTime = startTime
        self.duration = duration
        self.relativeTrimPositions = relativeTrimPositions
    }
    
    /// Calculate absolute time range in original asset based on video trim positions
    public func getAbsoluteTimeRange(relativeTo videoItem: VideoTimelineItem) -> (start: Double, end: Double) {
        let videoStart = videoItem.trimPositions.start
        let videoEnd = videoItem.trimPositions.end
        let videoDuration = videoEnd - videoStart
        
        let textStart = videoStart + (videoDuration * relativeTrimPositions.start)
        let textEnd = videoStart + (videoDuration * relativeTrimPositions.end)
        
        return (textStart, textEnd)
    }
}

public class StickerTimelineItem: TimelineItem {
    public let id: String
    public var startTime: CMTime
    public var duration: CMTime
    public let trackType: TimelineTrackType = .sticker
    public var isSelected: Bool = false
    
    // Dependent track behavior
    public let trimBehavior: TrimBehavior = .dependent
    
    public let image: UIImage
    public let position: CGPoint
    public let scale: CGFloat
    public let rotation: CGFloat
    
    // Relative trim positions (relative to video timeline)
    public var relativeTrimPositions: (start: Double, end: Double)
    
    public init(image: UIImage, position: CGPoint, scale: CGFloat, rotation: CGFloat, startTime: CMTime, duration: CMTime, relativeTrimPositions: (start: Double, end: Double) = (0.0, 1.0), id: String? = nil) {
        self.id = id ?? UUID().uuidString
        self.image = image
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.startTime = startTime
        self.duration = duration
        self.relativeTrimPositions = relativeTrimPositions
    }
    
    /// Calculate absolute time range in original asset based on video trim positions
    public func getAbsoluteTimeRange(relativeTo videoItem: VideoTimelineItem) -> (start: Double, end: Double) {
        let videoStart = videoItem.trimPositions.start
        let videoEnd = videoItem.trimPositions.end
        let videoDuration = videoEnd - videoStart
        
        let stickerStart = videoStart + (videoDuration * relativeTrimPositions.start)
        let stickerEnd = videoStart + (videoDuration * relativeTrimPositions.end)
        
        return (stickerStart, stickerEnd)
    }
}

// MARK: - Timeline Track

public struct TimelineTrack {
    public let id: String
    public let type: TimelineTrackType
    public var items: [TimelineItem]
    public var isVisible: Bool = true
    public var isLocked: Bool = false
    
    public init(type: TimelineTrackType, items: [TimelineItem] = [], id: String? = nil) {
        self.id = id ?? UUID().uuidString
        self.type = type
        self.items = items
    }
}

// MARK: - Timeline Zoom Level

enum TimelineZoomLevel: String, CaseIterable {
    case veryCompact = "Very Compact"     // Xem nhiều nhất (20px/s)
    case compact = "Compact"              // Xem nhiều (44px/s)  
    case normal = "Normal"                // Cân bằng (100px/s)
    case detailed = "Detailed"            // Chi tiết (150px/s)
    case veryDetailed = "Very Detailed"   // Chi tiết nhất (200px/s)
    
    var pixelsPerSecond: CGFloat {
        switch self {
        case .veryCompact: return 20
        case .compact: return 44
        case .normal: return 100
        case .detailed: return 150
        case .veryDetailed: return 200
        }
    }
    
    var description: String {
        switch self {
        case .veryCompact: return "Xem toàn bộ video trên màn hình"
        case .compact: return "Xem nhiều phần của video"
        case .normal: return "Mức zoom cân bằng"
        case .detailed: return "Xem chi tiết từng phần"
        case .veryDetailed: return "Xem rất chi tiết, chỉnh sửa chính xác"
        }
    }
}

// MARK: - Timeline Configuration

struct TimelineConfiguration {
    let timeScale: CMTimeScale
    let pixelsPerSecond: CGFloat
    let trackHeight: CGFloat
    let trackSpacing: CGFloat
    let minimumItemWidth: CGFloat
    let trackHeaderWidth: CGFloat
    
    // Default sử dụng Compact level
    static let `default` = TimelineConfiguration.from(zoomLevel: .compact)
    
    // Factory method từ zoom level
    static func from(zoomLevel: TimelineZoomLevel) -> TimelineConfiguration {
        return TimelineConfiguration(
            timeScale: 600,
            pixelsPerSecond: zoomLevel.pixelsPerSecond,
            trackHeight: 64,
            trackSpacing: 8,
            minimumItemWidth: 20,
            trackHeaderWidth: 120
        )
    }
}

// MARK: - Timeline Configuration Extensions

extension TimelineConfiguration {
    
    // Preset configurations sử dụng zoom levels
    static let veryCompact = TimelineConfiguration.from(zoomLevel: .veryCompact)
    static let compact = TimelineConfiguration.from(zoomLevel: .compact)
    static let normal = TimelineConfiguration.from(zoomLevel: .normal) 
    static let detailed = TimelineConfiguration.from(zoomLevel: .detailed)
    static let veryDetailed = TimelineConfiguration.from(zoomLevel: .veryDetailed)
    
    // Deprecated - để backward compatibility
    static let zoomed = TimelineConfiguration.from(zoomLevel: .veryDetailed)
    
    // Method để thay đổi zoom level
    func withZoomLevel(_ zoomLevel: TimelineZoomLevel) -> TimelineConfiguration {
        return TimelineConfiguration(
            timeScale: self.timeScale,
            pixelsPerSecond: zoomLevel.pixelsPerSecond,
            trackHeight: self.trackHeight,
            trackSpacing: self.trackSpacing,
            minimumItemWidth: self.minimumItemWidth,
            trackHeaderWidth: self.trackHeaderWidth
        )
    }
    
    // Get current zoom level
    var currentZoomLevel: TimelineZoomLevel? {
        return TimelineZoomLevel.allCases.first { $0.pixelsPerSecond == self.pixelsPerSecond }
    }
}

// MARK: - Sample Data Creation

extension TimelineTrack {
    
    static func createSampleVideoTrack() -> TimelineTrack {
        let videoItem = VideoTimelineItem(
            asset: AVAsset(), // In real usage, provide actual asset
            thumbnails: [], // In real usage, provide actual thumbnails
            startTime: CMTime.zero,
            duration: CMTime(seconds: 10, preferredTimescale: 600),
            trimPositions: (0.0, 1.0) // No trim initially
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
            duration: CMTime(seconds: 10, preferredTimescale: 600),
            relativeTrimPositions: (0.0, 1.0) // No trim initially
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
            duration: CMTime(seconds: 3, preferredTimescale: 600),
            relativeTrimPositions: (0.0, 1.0) // No trim initially
        )
        
        return TimelineTrack(type: .text, items: [textItem])
    }
}
