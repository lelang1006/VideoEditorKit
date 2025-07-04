//
//  VideoEdit.swift
//  
//
//  Created by Titouan Van Belle on 13.10.20.
//

import AVFoundation
import Foundation

public struct VideoEdit {
    public var speedRate: Double = 1.0
    public var trimPositions: (CMTime, CMTime)?
    public var croppingPreset: CroppingPreset?
    public var filter: VideoFilter?
    public var audioReplacement: AudioReplacement?
    public var isMuted: Bool = false
    public var volume: Float = 1.0
    public var stickers: [StickerTimelineItem] = []

    public init() {}
}

public struct AudioReplacement {
    public let asset: AVAsset
    public let originalURL: URL?
    public var trimPositions: (CMTime, CMTime)?
    public let title: String
    public let duration: CMTime
    
    public init(asset: AVAsset, url: URL?, title: String) {
        self.asset = asset
        self.originalURL = url
        self.title = title
        self.duration = asset.duration
    }
}
