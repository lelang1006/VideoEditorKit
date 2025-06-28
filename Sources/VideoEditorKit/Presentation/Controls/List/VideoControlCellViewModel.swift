//
//  VideoEditCellViewModel.swift
//  
//
//  Created by Titouan Van Belle on 27.10.20.
//

import Foundation

final class VideoControlCellViewModel: NSObject {

    let videoControl: VideoControl

    // MARK: Init

    init(videoControl: VideoControl) {
        self.videoControl = videoControl
    }

    var name: String {
        switch videoControl {
        case .speed:
            return "Speed"
        case .trim:
            return "Trim"
        case .crop:
            return "Crop"
        case .filter:
            return "Filter"
        case .audio:
            return "Audio"
        }
    }

    var imageName: String {
        switch videoControl {
        case .speed:
            return "VideoControls/Speed"
        case .trim:
            return "VideoControls/Trim"
        case .crop:
            return "VideoControls/Crop"
        case .filter:
            return "VideoControls/Filter"  // Không có 's' ở cuối
        case .audio:
            return "VideoControls/Audio"
        }
    }
}
