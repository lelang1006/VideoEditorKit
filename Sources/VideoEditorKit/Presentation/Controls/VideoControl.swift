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
        }
    }
    
    public var titleImageName: String {
        switch self {
        case .filter:
            return "Filter"
        default:
            return "VideoControls/\(title)"
        }
    }
}
