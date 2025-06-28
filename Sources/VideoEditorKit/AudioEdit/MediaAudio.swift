//
//  MediaAudio.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 28.06.25.
//

import AVFoundation
import Foundation

public struct MediaAudio {
    public let id: String
    public let title: String
    public let artist: String?
    public let duration: CMTime
    public let category: AudioCategory
    public let fileName: String
    public let previewImageName: String?
    
    public var asset: AVAsset {
        guard let url = Bundle.module.url(forResource: fileName.components(separatedBy: ".").first, withExtension: fileName.components(separatedBy: ".").last) else {
            fatalError("Audio file not found: \(fileName)")
        }
        return AVAsset(url: url)
    }
    
    public init(id: String, title: String, artist: String? = nil, duration: CMTime, category: AudioCategory, fileName: String, previewImageName: String? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.category = category
        self.fileName = fileName
        self.previewImageName = previewImageName
    }
}

public enum AudioCategory: String, CaseIterable {
    case music = "Music"
    case ambient = "Ambient" 
    case effects = "Effects"
    case speech = "Speech"
    
    public var displayName: String { rawValue }
}

// Pre-built audio library
extension MediaAudio {
    public static let library: [MediaAudio] = [
        MediaAudio(
            id: "1",
            title: "Upbeat Pop",
            artist: "VideoEditor",
            duration: CMTime(seconds: 120, preferredTimescale: 600),
            category: .music,
            fileName: "upbeat_pop.mp3",
            previewImageName: "music_upbeat"
        ),
        MediaAudio(
            id: "2", 
            title: "Relaxing Piano",
            artist: "VideoEditor",
            duration: CMTime(seconds: 180, preferredTimescale: 600),
            category: .music,
            fileName: "relaxing_piano.mp3",
            previewImageName: "music_piano"
        ),
        MediaAudio(
            id: "3",
            title: "Forest Sounds",
            artist: "Nature",
            duration: CMTime(seconds: 300, preferredTimescale: 600),
            category: .ambient,
            fileName: "forest_ambient.mp3",
            previewImageName: "ambient_forest"
        ),
        MediaAudio(
            id: "4",
            title: "City Traffic",
            artist: "Urban",
            duration: CMTime(seconds: 240, preferredTimescale: 600),
            category: .ambient,
            fileName: "city_traffic.mp3",
            previewImageName: "ambient_city"
        ),
        MediaAudio(
            id: "5",
            title: "Happy Acoustic",
            artist: "VideoEditor",
            duration: CMTime(seconds: 150, preferredTimescale: 600),
            category: .music,
            fileName: "happy_acoustic.mp3",
            previewImageName: "music_acoustic"
        )
    ]
}
