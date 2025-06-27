//
//  VideoEditorViewFactory.swift
//
//
//  Created by Titouan Van Belle on 11.09.20.
//

import AVFoundation
import VideoPlayer
import VideoEditor

protocol VideoEditorViewFactoryProtocol {
    func makeVideoPlayerController() -> VideoPlayerController
    func makeVideoTimelineViewController(store: VideoEditorStore) -> VideoTimelineViewController
    func makeVideoControlListController(store: VideoEditorStore) -> VideoControlListController
    func makeCropVideoControlViewController(croppingPreset: CroppingPreset?) -> CropVideoControlViewController
    func makeSpeedVideoControlViewController(speed: Double) -> SpeedVideoControlViewController
    func makeFilterVideoControlViewController(selectedFilter: VideoFilter?) -> FilterVideoControlViewController
    func makeTrimVideoControlViewController(asset: AVAsset, trimPositions: (Double, Double)) -> TrimVideoControlViewController
}

final class VideoEditorViewFactory: VideoEditorViewFactoryProtocol {

    func makeVideoPlayerController() -> VideoPlayerController {
        var theme = VideoPlayerController.Theme()
        theme.backgroundStyle = .plain(.white)
        return VideoPlayerController(capabilities: .none, theme: theme)
    }

    func makeVideoTimelineViewController(store: VideoEditorStore) -> VideoTimelineViewController {
        VideoTimelineViewController(store: store)
    }

    func makeVideoControlListController(store: VideoEditorStore) -> VideoControlListController {
        VideoControlListController(store: store, viewFactory: self)
    }

    func makeCropVideoControlViewController(croppingPreset: CroppingPreset?) -> CropVideoControlViewController {
        CropVideoControlViewController(croppingPreset: croppingPreset)
    }

    func makeSpeedVideoControlViewController(speed: Double) -> SpeedVideoControlViewController {
        SpeedVideoControlViewController(speed: speed)
    }

    func makeFilterVideoControlViewController(selectedFilter: VideoFilter?) -> FilterVideoControlViewController {
        FilterVideoControlViewController(selectedFilter: selectedFilter)
    }

    func makeTrimVideoControlViewController(asset: AVAsset, trimPositions: (Double, Double)) -> TrimVideoControlViewController {
        TrimVideoControlViewController(asset: asset, trimPositions: trimPositions)
    }
}
