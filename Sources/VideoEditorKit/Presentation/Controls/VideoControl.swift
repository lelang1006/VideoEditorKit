//
//  File.swift
//
//
//  Created by Titouan Van Belle on 27.10.20.
//

import Foundation

public enum VideoControl: CaseIterable {
    case speed
    case trim
    case crop
    case filter
    case audio
    
    public var title: String {
        switch self {
        case .speed:
            return "Speed"
        case .trim:
            return "Trim"
        case .crop:
            return "Crop"
        case .filter:
            return "Filters"
        case .audio:
            return "Audio"
        }
    }
    
    public var titleImageName: String {
        return "VideoControls/\(title)"
    }
    
    public var heightOfVideoControl: CGFloat {
        switch self {
        case .speed:
            return 210.0
        case .trim:
            return 210.0
        case .crop:
            return 210.0
        case .filter:
            return 284.0
        case .audio:
            return 320.0
        }
    }
}
