//
//  VideoEditorStore.swift
//  
//
//  Created by Titouan Van Belle on 28.10.20.
//

import AVFoundation
import Combine
import Foundation

extension VideoEditResult {
    var item: AVPlayerItem {
        let item = AVPlayerItem(asset: asset)
        #if !targetEnvironment(simulator)
        item.videoComposition = videoComposition
        #endif

        return item
    }
}

public final class VideoEditorStore {

    // MARK: Public Properties

    @Published private(set) var originalAsset: AVAsset

    @Published var editedPlayerItem: AVPlayerItem

    @Published var playheadProgress: CMTime = .zero

    @Published var isSeeking: Bool = false
    @Published var currentSeekingValue: Double = .zero

    @Published var speed: Double = 1.0
    @Published var trimPositions: (Double, Double) = (0.0, 1.0)
    @Published var croppingPreset: CroppingPreset?

    @Published var filter: VideoFilter?
    
    // Audio properties
    @Published var audioReplacement: AudioReplacement?
    @Published var volume: Float = 1.0
    @Published var isMuted: Bool = false

    // Sticker properties
    @Published var stickers: [StickerTimelineItem] = []

    @Published var videoEdit: VideoEdit

    // MARK: Private Properties

    private var cancellables = Set<AnyCancellable>()

    private let editor: VideoEditor
    private let generator: VideoTimelineGeneratorProtocol

    // MARK: Init

    public init(
        asset: AVAsset,
        videoEdit: VideoEdit?
    ) {
        self.originalAsset = asset
        self.editor = VideoEditor()
        self.generator = VideoTimelineGenerator()
        self.editedPlayerItem = AVPlayerItem(asset: asset)
        self.videoEdit = videoEdit ?? VideoEdit()
        
        // Initialize audio properties from VideoEdit
        self.audioReplacement = self.videoEdit.audioReplacement
        self.volume = self.videoEdit.volume
        self.isMuted = self.videoEdit.isMuted
        
        // Initialize stickers from VideoEdit
        self.stickers = self.videoEdit.stickers

        setupBindings()
    }
    
    // Internal initializer for dependency injection in tests
    internal init(
        asset: AVAsset,
        videoEdit: VideoEdit?,
        editor: VideoEditor = .init(),
        generator: VideoTimelineGeneratorProtocol = VideoTimelineGenerator()
    ) {
        self.originalAsset = asset
        self.editor = editor
        self.generator = generator
        self.editedPlayerItem = AVPlayerItem(asset: asset)
        self.videoEdit = videoEdit ?? VideoEdit()
        
        // Initialize audio properties from VideoEdit
        self.audioReplacement = self.videoEdit.audioReplacement
        self.volume = self.videoEdit.volume
        self.isMuted = self.videoEdit.isMuted
        
        // Initialize stickers from VideoEdit
        self.stickers = self.videoEdit.stickers

        setupBindings()
    }
}

// MARK: Bindings

fileprivate extension VideoEditorStore {
    func setupBindings() {
        $videoEdit
            .setFailureType(to: Error.self)
            .flatMap { [weak self] edit -> AnyPublisher<VideoEditResult, Error> in
                self!.editor.apply(edit: edit, to: self!.originalAsset)
            }
            .map(\.item)
            .replaceError(with: AVPlayerItem(asset: originalAsset))
            .assign(to: \.editedPlayerItem, weakly: self)
            .store(in: &cancellables)

        $speed
            .dropFirst(1)
            .filter { [weak self] speed in
                guard let self = self else { return false }
                return speed != self.videoEdit.speedRate
            }
            .compactMap { [weak self] speedRate in
                guard let self = self else { return nil }
                return VideoEdit.speedRateLens.to(speedRate, self.videoEdit)
            }
            .assign(to: \.videoEdit, weakly: self)
            .store(in: &cancellables)

        $trimPositions
            .dropFirst(1)
            .compactMap { [weak self] trimPositions in
                guard let self = self else { return nil }
                let startTime = CMTime(
                    seconds: self.originalDuration.seconds * trimPositions.0,
                    preferredTimescale: self.originalDuration.timescale
                )
                let endTime = CMTime(
                    seconds: self.originalDuration.seconds * trimPositions.1,
                    preferredTimescale: self.originalDuration.timescale
                )
                let positions = (startTime, endTime)

                return VideoEdit.trimPositionsLens.to(positions, self.videoEdit)
            }
            .assign(to: \.videoEdit, weakly: self)
            .store(in: &cancellables)

        $croppingPreset
            .dropFirst(1)
            .filter { [weak self] croppingPreset in
                guard let self = self else { return false }
                return croppingPreset != self.videoEdit.croppingPreset
            }
            .compactMap { [weak self] croppingPreset in
                guard let self = self else { return nil }
                return VideoEdit.croppingPresetLens.to(croppingPreset, self.videoEdit)
            }
            .assign(to: \.videoEdit, weakly: self)
            .store(in: &cancellables)

        $filter
            .dropFirst(1)
            .filter { [weak self] filter in
                guard let self = self else { return false }
                return filter != self.videoEdit.filter
            }
            .compactMap { [weak self] filter in
                guard let self = self else { return nil }
                return VideoEdit.filterLens.to(filter, self.videoEdit)
            }
            .assign(to: \.videoEdit, weakly: self)
            .store(in: &cancellables)

        $audioReplacement
            .dropFirst(1)
            .filter { [weak self] audioReplacement in
                guard let self = self else { return false }
                return audioReplacement?.title != self.videoEdit.audioReplacement?.title
            }
            .compactMap { [weak self] audioReplacement in
                guard let self = self else { return nil }
                return VideoEdit.audioReplacementLens.to(audioReplacement, self.videoEdit)
            }
            .assign(to: \.videoEdit, weakly: self)
            .store(in: &cancellables)
            
        $volume
            .dropFirst(1)
            .filter { [weak self] volume in
                guard let self = self else { return false }
                return volume != self.videoEdit.volume
            }
            .compactMap { [weak self] volume in
                guard let self = self else { return nil }
                return VideoEdit.volumeLens.to(volume, self.videoEdit)
            }
            .assign(to: \.videoEdit, weakly: self)
            .store(in: &cancellables)
            
        $isMuted
            .dropFirst(1)
            .filter { [weak self] isMuted in
                guard let self = self else { return false }
                return isMuted != self.videoEdit.isMuted
            }
            .compactMap { [weak self] isMuted in
                guard let self = self else { return nil }
                return VideoEdit.isMutedLens.to(isMuted, self.videoEdit)
            }
            .assign(to: \.videoEdit, weakly: self)
            .store(in: &cancellables)

        $stickers
            .dropFirst(1)
            .filter { [weak self] stickers in
                guard let self = self else { return false }
                return stickers != self.videoEdit.stickers
            }
            .compactMap { [weak self] stickers in
                guard let self = self else { return nil }
                return VideoEdit.stickers.to(stickers, self.videoEdit)
            }
            .assign(to: \.videoEdit, weakly: self)
            .store(in: &cancellables)

    }
}

// MARK: Public Accessors

extension VideoEditorStore {
    var currentSeekingTime: CMTime {
        CMTime(seconds: duration.seconds * currentSeekingValue, preferredTimescale: duration.timescale)
    }

    var assetAspectRatio: CGFloat {
        guard let track = editedPlayerItem.asset.tracks(withMediaType: AVMediaType.video).first else {
            return .zero
        }

        let assetSize = track.naturalSize.applying(track.preferredTransform)

        return abs(assetSize.width) / abs(assetSize.height)
    }

    var originalDuration: CMTime {
        originalAsset.duration
    }

    var duration: CMTime {
        editedPlayerItem.asset.duration
    }

    var fractionCompleted: Double {
        guard duration != .zero else {
            return .zero
        }

        return playheadProgress.seconds / duration.seconds
    }
    
    func videoTimeline(for asset: AVAsset, in bounds: CGRect) -> AnyPublisher<[CGImage], Error> {
        generator.videoTimeline(for: asset, in: bounds, numberOfFrames: numberOfFrames())
    }

    func export(to url: URL) -> AnyPublisher<Void, Error> {
        editor.apply(edit: videoEdit, to: originalAsset)
            .flatMap { $0.export(to: url) }
            .eraseToAnyPublisher()
    }
    
    // MARK: Sticker Management
    
    func addSticker(_ sticker: StickerTimelineItem) {
        print("📱 🏪 VideoEditorStore.addSticker called with: \(sticker.id)")
        print("📱 🏪 Before adding: \(stickers.count) stickers")
        stickers.append(sticker)
        print("📱 🏪 After adding: \(stickers.count) stickers")
    }
    
    func removeSticker(withId id: String) {
        stickers.removeAll { $0.id == id }
    }
    
    func updateSticker(_ sticker: StickerTimelineItem) {
        if let index = stickers.firstIndex(where: { $0.id == sticker.id }) {
            stickers[index] = sticker
        }
    }
}

// MARK: Private Accessors

fileprivate extension VideoEditorStore {
    func numberOfFrames() -> Int {
        // Calculate number of thumbnails based on video duration
        // Each thumbnail represents a fixed duration (see TimelineItemView.thumbnailDurationInSeconds)
        let durationInSeconds = originalAsset.duration.seconds
        return Int(ceil(durationInSeconds / TimelineItemView.thumbnailDurationInSeconds))
    }
}

