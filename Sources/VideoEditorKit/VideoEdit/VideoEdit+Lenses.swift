//
//  VideoEdit+Lenses.swift
//  
//
//  Created by Titouan Van Belle on 06.11.20.
//

import CoreMedia
import Foundation

extension VideoEdit {
    static let speedRateLens = Lens<VideoEdit, Double>(
        from: { $0.speedRate },
        to: { speedRate, previousEdit in
            var edit = VideoEdit()
            edit.croppingPreset = previousEdit.croppingPreset
            edit.speedRate = speedRate
            edit.trimPositions = previousEdit.trimPositions
            edit.filter = previousEdit.filter
            edit.audioReplacement = previousEdit.audioReplacement
            edit.volume = previousEdit.volume
            edit.isMuted = previousEdit.isMuted
            edit.stickers = previousEdit.stickers
            return edit
        }
    )

    static let trimPositionsLens = Lens<VideoEdit, (CMTime, CMTime)?>(
        from: { $0.trimPositions },
        to: { trimPositions, previousEdit in
            var edit = VideoEdit()
            edit.croppingPreset = previousEdit.croppingPreset
            edit.speedRate = previousEdit.speedRate
            edit.trimPositions = trimPositions
            edit.filter = previousEdit.filter
            edit.audioReplacement = previousEdit.audioReplacement
            edit.volume = previousEdit.volume
            edit.isMuted = previousEdit.isMuted
            edit.stickers = previousEdit.stickers
            return edit
        }
    )

    static let croppingPresetLens = Lens<VideoEdit, CroppingPreset?>(
        from: { $0.croppingPreset },
        to: { croppingPreset, previousEdit in
            var edit = VideoEdit()
            edit.croppingPreset = croppingPreset
            edit.speedRate = previousEdit.speedRate
            edit.trimPositions = previousEdit.trimPositions
            edit.filter = previousEdit.filter
            edit.audioReplacement = previousEdit.audioReplacement
            edit.volume = previousEdit.volume
            edit.isMuted = previousEdit.isMuted
            edit.stickers = previousEdit.stickers
            return edit
        }
    )
    
    static let filterLens = Lens<VideoEdit, VideoFilter?>(
        from: { $0.filter },
        to: { filter, previousEdit in
            var edit = VideoEdit()
            edit.croppingPreset = previousEdit.croppingPreset
            edit.speedRate = previousEdit.speedRate
            edit.trimPositions = previousEdit.trimPositions
            edit.filter = filter
            edit.audioReplacement = previousEdit.audioReplacement
            edit.volume = previousEdit.volume
            edit.isMuted = previousEdit.isMuted
            edit.stickers = previousEdit.stickers
            return edit
        }
    )
    
    static let audioReplacementLens = Lens<VideoEdit, AudioReplacement?>(
        from: { $0.audioReplacement },
        to: { audioReplacement, previousEdit in
            var edit = VideoEdit()
            edit.croppingPreset = previousEdit.croppingPreset
            edit.speedRate = previousEdit.speedRate
            edit.trimPositions = previousEdit.trimPositions
            edit.filter = previousEdit.filter
            edit.audioReplacement = audioReplacement
            edit.volume = previousEdit.volume
            edit.isMuted = previousEdit.isMuted
            edit.stickers = previousEdit.stickers
            return edit
        }
    )
    
    static let volumeLens = Lens<VideoEdit, Float>(
        from: { $0.volume },
        to: { volume, previousEdit in
            var edit = VideoEdit()
            edit.croppingPreset = previousEdit.croppingPreset
            edit.speedRate = previousEdit.speedRate
            edit.trimPositions = previousEdit.trimPositions
            edit.filter = previousEdit.filter
            edit.audioReplacement = previousEdit.audioReplacement
            edit.volume = volume
            edit.isMuted = previousEdit.isMuted
            edit.stickers = previousEdit.stickers
            return edit
        }
    )
    
    static let isMutedLens = Lens<VideoEdit, Bool>(
        from: { $0.isMuted },
        to: { isMuted, previousEdit in
            var edit = VideoEdit()
            edit.croppingPreset = previousEdit.croppingPreset
            edit.speedRate = previousEdit.speedRate
            edit.trimPositions = previousEdit.trimPositions
            edit.filter = previousEdit.filter
            edit.audioReplacement = previousEdit.audioReplacement
            edit.volume = previousEdit.volume
            edit.isMuted = isMuted
            edit.stickers = previousEdit.stickers
            return edit
        }
    )
    
    static let stickers = Lens<VideoEdit, [StickerTimelineItem]>(
        from: { $0.stickers },
        to: { stickers, previousEdit in
            var edit = VideoEdit()
            edit.croppingPreset = previousEdit.croppingPreset
            edit.speedRate = previousEdit.speedRate
            edit.trimPositions = previousEdit.trimPositions
            edit.filter = previousEdit.filter
            edit.audioReplacement = previousEdit.audioReplacement
            edit.volume = previousEdit.volume
            edit.isMuted = previousEdit.isMuted
            edit.stickers = stickers
            return edit
        }
    )
}


