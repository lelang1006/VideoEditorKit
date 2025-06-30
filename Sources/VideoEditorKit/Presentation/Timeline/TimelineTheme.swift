//
//  TimelineTheme.swift
//  
//
//  Created by VideoEditorKit on 29.06.25.
//

import UIKit

// MARK: - Timeline Theme System

public enum TimelineThemeMode {
    case light
    case dark
}

public struct TimelineTheme {
    
    // MARK: - Current Theme
    
    public static var current: TimelineTheme = .light
    
    // MARK: - Theme Properties
    
    public let mode: TimelineThemeMode
    
    // Background Colors
    public let backgroundColor: UIColor
    public let contentBackgroundColor: UIColor
    public let trackBackgroundColor: UIColor
    public let trackHeaderBackgroundColor: UIColor
    
    // Text Colors
    public let primaryTextColor: UIColor
    public let secondaryTextColor: UIColor
    public let timeRulerTextColor: UIColor
    
    // Interactive Colors
    public let selectionBorderColor: UIColor
    public let playheadColor: UIColor
    public let snapIndicatorColor: UIColor
    public let deleteButtonColor: UIColor
    public let resizeHandleColor: UIColor
    
    // Item Colors
    public let videoItemColor: UIColor
    public let audioItemColor: UIColor
    public let textItemColor: UIColor
    public let stickerItemColor: UIColor
    
    // Shadow & Border
    public let shadowColor: UIColor
    public let borderColor: UIColor
    public let separatorColor: UIColor
    
    // MARK: - Predefined Themes
    
    public static let light = TimelineTheme(
        mode: .light,
        
        // Background Colors
        backgroundColor: UIColor.systemBackground,
        contentBackgroundColor: UIColor.systemBackground,
        trackBackgroundColor: UIColor.systemGray6,
        trackHeaderBackgroundColor: UIColor.systemBackground,
        
        // Text Colors
        primaryTextColor: UIColor.label,
        secondaryTextColor: UIColor.secondaryLabel,
        timeRulerTextColor: UIColor.label,
        
        // Interactive Colors
        selectionBorderColor: UIColor.systemBlue,
        playheadColor: UIColor.systemRed,
        snapIndicatorColor: UIColor.systemBlue,
        deleteButtonColor: UIColor.systemRed,
        resizeHandleColor: UIColor.systemBlue,
        
        // Item Colors
        videoItemColor: UIColor.systemBlue.withAlphaComponent(0.7),
        audioItemColor: UIColor.systemGreen.withAlphaComponent(0.7),
        textItemColor: UIColor.systemOrange.withAlphaComponent(0.7),
        stickerItemColor: UIColor.systemPurple.withAlphaComponent(0.7),
        
        // Shadow & Border
        shadowColor: UIColor.black.withAlphaComponent(0.2),
        borderColor: UIColor.systemGray4,
        separatorColor: UIColor.separator
    )
    
    public static let dark = TimelineTheme(
        mode: .dark,
        
        // Background Colors
        backgroundColor: UIColor.black,
        contentBackgroundColor: UIColor.black,
        trackBackgroundColor: UIColor.black.withAlphaComponent(0.3),
        trackHeaderBackgroundColor: UIColor.black.withAlphaComponent(0.5),
        
        // Text Colors
        primaryTextColor: UIColor.white,
        secondaryTextColor: UIColor.lightGray,
        timeRulerTextColor: UIColor.white,
        
        // Interactive Colors
        selectionBorderColor: UIColor.systemYellow,
        playheadColor: UIColor.systemYellow,
        snapIndicatorColor: UIColor.systemYellow,
        deleteButtonColor: UIColor.systemRed,
        resizeHandleColor: UIColor.systemYellow,
        
        // Item Colors
        videoItemColor: UIColor.systemBlue.withAlphaComponent(0.8),
        audioItemColor: UIColor.systemGreen.withAlphaComponent(0.8),
        textItemColor: UIColor.systemOrange.withAlphaComponent(0.8),
        stickerItemColor: UIColor.systemPurple.withAlphaComponent(0.8),
        
        // Shadow & Border
        shadowColor: UIColor.black.withAlphaComponent(0.4),
        borderColor: UIColor.gray,
        separatorColor: UIColor.darkGray
    )
}

// MARK: - Theme Manager

public class TimelineThemeManager {
    
    public static let shared = TimelineThemeManager()
    
    private init() {}
    
    public var currentTheme: TimelineTheme {
        get { TimelineTheme.current }
        set { 
            TimelineTheme.current = newValue
            NotificationCenter.default.post(name: .timelineThemeDidChange, object: newValue)
        }
    }
    
    public func setTheme(_ theme: TimelineTheme) {
        currentTheme = theme
    }
    
    public func toggleTheme() {
        switch currentTheme.mode {
        case .light:
            setTheme(.dark)
        case .dark:
            setTheme(.light)
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    public static let timelineThemeDidChange = Notification.Name("timelineThemeDidChange")
}

// MARK: - UIView Theme Extensions

extension UIView {
    
    public func applyTimelineTheme() {
        switch self {
        case let view as TimelineItemView:
            view.updateTheme()
        case let view as TimelineTrackView:
            view.updateTheme()
        case let view as MultiLayerTimelineViewController:
            view.updateTheme()
        default:
            break
        }
    }
}

// MARK: - Theme-aware Components Protocol

public protocol TimelineThemeAware {
    func updateTheme()
}
