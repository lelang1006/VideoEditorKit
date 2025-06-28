//
//  VideoEditor.swift
//
//
//  Created by Titouan Van Belle on 13.10.20.
//

import AVFoundation
import Combine
import CoreImage

enum VideoEditorError: Error {
    case unknown
    case filterCreationFailed
}

public protocol VideoEditorProtocol {
    func apply(edit: VideoEdit, to originalAsset: AVAsset) -> AnyPublisher<VideoEditResult, Error>
}

public final class VideoEditor: VideoEditorProtocol {

    // MARK: Init

    public init() {}

    public func apply(edit: VideoEdit, to originalAsset: AVAsset) -> AnyPublisher<VideoEditResult, Error> {
        Future { promise in
            let composition = AVMutableComposition()

            guard let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                  let videoTrack = originalAsset.tracks(withMediaType: .video).first else {
                promise(.failure(VideoEditorError.unknown))
                return
            }

            let range: CMTimeRange
            let duration: CMTime
            if let trimPositions = edit.trimPositions {
                let value = trimPositions.1.seconds - trimPositions.0.seconds
                duration = CMTime(seconds: value, preferredTimescale: originalAsset.duration.timescale)
                range = CMTimeRange(start: trimPositions.0, duration: duration)
            } else {
                duration = originalAsset.duration
                range = CMTimeRange(start: .zero, duration: duration)
            }

            do {
                try videoCompositionTrack.insertTimeRange(range, of: videoTrack, at: .zero)

                let newDuration = Double(duration.seconds) / edit.speedRate
                let time = CMTime(seconds: newDuration, preferredTimescale: duration.timescale)
                let newRange = CMTimeRange(start: .zero, duration: duration)
                videoCompositionTrack.scaleTimeRange(newRange, toDuration: time)
                videoCompositionTrack.preferredTransform = videoTrack.preferredTransform

                // Handle audio processing
                try self.processAudio(
                    edit: edit,
                    originalAsset: originalAsset,
                    composition: composition,
                    range: range,
                    newRange: newRange,
                    newDuration: time
                )
            } catch {
                promise(.failure(VideoEditorError.unknown))
                return
            }

            let videoComposition = self.makeVideoComposition(
                edit: edit,
                videoCompositionTrack: videoCompositionTrack,
                videoTrack: videoTrack,
                duration: composition.duration
            )

            let result = VideoEditResult(
                asset: composition,
                videoComposition: videoComposition
            )

            promise(.success(result))
        }.eraseToAnyPublisher()
    }
}

fileprivate extension VideoEditor {
    
    func processAudio(
        edit: VideoEdit,
        originalAsset: AVAsset,
        composition: AVMutableComposition,
        range: CMTimeRange,
        newRange: CMTimeRange,
        newDuration: CMTime
    ) throws {
        // Skip audio processing if muted
        if edit.isMuted {
            return
        }
        
        // If we have audio replacement, use the replacement audio
        if let audioReplacement = edit.audioReplacement {
            try addReplacementAudio(
                audioReplacement: audioReplacement,
                composition: composition,
                videoDuration: newDuration,
                volume: edit.volume
            )
        } else {
            // Use original audio
            try addOriginalAudio(
                originalAsset: originalAsset,
                composition: composition,
                range: range,
                newRange: newRange,
                newDuration: newDuration,
                volume: edit.volume
            )
        }
    }
    
    func addOriginalAudio(
        originalAsset: AVAsset,
        composition: AVMutableComposition,
        range: CMTimeRange,
        newRange: CMTimeRange,
        newDuration: CMTime,
        volume: Float
    ) throws {
        guard let audioTrack = originalAsset.tracks(withMediaType: .audio).first else {
            return // No original audio track
        }
        
        guard let audioCompositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoEditorError.unknown
        }
        
        try audioCompositionTrack.insertTimeRange(range, of: audioTrack, at: .zero)
        audioCompositionTrack.scaleTimeRange(newRange, toDuration: newDuration)
        
        // Apply volume if different from default
        if volume != 1.0 {
            let volumeParams = AVMutableAudioMixInputParameters(track: audioCompositionTrack)
            volumeParams.setVolume(volume, at: .zero)
            // Note: AudioMix would be applied in the final composition
        }
    }
    
    func addReplacementAudio(
        audioReplacement: AudioReplacement,
        composition: AVMutableComposition,
        videoDuration: CMTime,
        volume: Float
    ) throws {
        guard let replacementAudioTrack = audioReplacement.asset.tracks(withMediaType: .audio).first else {
            return // No audio track in replacement
        }
        
        guard let audioCompositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoEditorError.unknown
        }
        
        // Determine the audio range to use
        let audioRange: CMTimeRange
        if let trimPositions = audioReplacement.trimPositions {
            let trimDuration = CMTimeSubtract(trimPositions.1, trimPositions.0)
            audioRange = CMTimeRange(start: trimPositions.0, duration: trimDuration)
        } else {
            audioRange = CMTimeRange(start: .zero, duration: audioReplacement.duration)
        }
        
        // Insert the audio, repeating if necessary to match video duration
        var currentTime = CMTime.zero
        let audioDuration = audioRange.duration
        
        while CMTimeCompare(currentTime, videoDuration) < 0 {
            let remainingTime = CMTimeSubtract(videoDuration, currentTime)
            let insertDuration = CMTimeMinimum(audioDuration, remainingTime)
            let insertRange = CMTimeRange(start: audioRange.start, duration: insertDuration)
            
            try audioCompositionTrack.insertTimeRange(insertRange, of: replacementAudioTrack, at: currentTime)
            currentTime = CMTimeAdd(currentTime, insertDuration)
            
            // Break if we've filled the entire video duration
            if CMTimeCompare(insertDuration, audioDuration) < 0 {
                break
            }
        }
        
        // Apply volume if different from default
        if volume != 1.0 {
            let volumeParams = AVMutableAudioMixInputParameters(track: audioCompositionTrack)
            volumeParams.setVolume(volume, at: .zero)
            // Note: AudioMix would be applied in the final composition
        }
    }

    func makeVideoComposition(
        edit: VideoEdit,
        videoCompositionTrack: AVCompositionTrack,
        videoTrack: AVAssetTrack,
        duration: CMTime
    ) -> AVVideoComposition {
        let naturalSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        let renderSize = makeRenderSize(naturalSize: naturalSize, croppingPreset: edit.croppingPreset)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        let videoLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoCompositionTrack)

        if let transform = makeLayerInstructionTransform(naturalSize: naturalSize, renderSize: renderSize, croppingPreset: edit.croppingPreset) {
            videoLayerInstruction.setTransform(transform, at: .zero)
        }

        instruction.layerInstructions = [
            videoLayerInstruction
        ]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderScale = 1.0

        // Apply filter if specified
        if let filter = edit.filter, filter != .none, let ciFilterName = filter.ciFilterName {
            videoComposition.customVideoCompositorClass = FilterVideoCompositor.self
            
            // Create custom instruction with filter info
            let filterInstruction = FilterVideoCompositionInstruction(
                filterName: ciFilterName,
                filterParameters: filter.defaultParameters
            )
            filterInstruction.timeRange = instruction.timeRange
            filterInstruction.layerInstructions = [videoLayerInstruction]
            
            videoComposition.instructions = [filterInstruction]
        } else {
            videoComposition.instructions = [instruction]
        }

        return videoComposition
    }

    func makeLayerInstructionTransform(
        naturalSize: CGSize,
        renderSize: CGSize,
        croppingPreset: CroppingPreset?
    ) -> CGAffineTransform? {
        guard croppingPreset != nil else {
            return nil
        }

        let widthOffset = -(naturalSize.width - renderSize.width) / 2
        let heightOffset = -(naturalSize.height - renderSize.height) / 2

        return CGAffineTransform(translationX: widthOffset, y: heightOffset)
    }

    func makeRenderSize(
        naturalSize: CGSize,
        croppingPreset: CroppingPreset?
    ) -> CGSize {
        guard let croppingPreset = croppingPreset else {
            return CGSize(width: abs(naturalSize.width), height: abs(naturalSize.height))
        }

        let width = naturalSize.width
        let height = naturalSize.height

        let renderSize: CGSize
        if width > height {
            let newWidth = height * CGFloat(croppingPreset.widthToHeightRatio)
            renderSize = CGSize(width: newWidth, height: height)
        } else {
            let newHeight = width / CGFloat(croppingPreset.widthToHeightRatio)
            renderSize = CGSize(width: width, height: newHeight)
        }

        return renderSize
    }
}
