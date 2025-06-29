//
//  TimelineInteractionSystem.swift
//  
//
//  Created by VideoEditorKit on 29.06.25.
//

import UIKit
import AVFoundation

// MARK: - Timeline Interaction System

class TimelineInteractionSystem {
    
    // MARK: - Collision Detection
    
    static func detectCollisions(for item: TimelineItem, in track: TimelineTrack, excluding excludedItem: TimelineItem? = nil) -> [TimelineItem] {
        let itemStartTime = item.startTime
        let itemEndTime = item.startTime + item.duration
        
        return track.items.filter { otherItem in
            // Skip the item itself or any excluded item
            if otherItem.id == item.id || otherItem.id == excludedItem?.id {
                return false
            }
            
            let otherStartTime = otherItem.startTime
            let otherEndTime = otherItem.startTime + otherItem.duration
            
            // Check for overlap
            return itemStartTime < otherEndTime && itemEndTime > otherStartTime
        }
    }
    
    static func findValidPosition(for item: TimelineItem, in track: TimelineTrack, preferredStartTime: CMTime) -> CMTime {
        var candidateStartTime = preferredStartTime
        let itemDuration = item.duration
        
        // Get all other items in the track
        let otherItems = track.items.filter { $0.id != item.id }
        
        // Sort by start time
        let sortedItems = otherItems.sorted { $0.startTime < $1.startTime }
        
        // Try to place at preferred time first
        if !hasCollision(startTime: candidateStartTime, duration: itemDuration, with: sortedItems) {
            return candidateStartTime
        }
        
        // Find the next available slot
        for otherItem in sortedItems {
            let otherEndTime = otherItem.startTime + otherItem.duration
            
            // Check if we can fit after this item
            if candidateStartTime < otherEndTime {
                candidateStartTime = otherEndTime
                
                // Check if this position conflicts with the next item
                if let nextItem = sortedItems.first(where: { $0.startTime > candidateStartTime }) {
                    let availableSpace = nextItem.startTime - candidateStartTime
                    if availableSpace < itemDuration {
                        // Not enough space, continue to next slot
                        continue
                    }
                }
                
                // This position works
                break
            }
        }
        
        return candidateStartTime
    }
    
    private static func hasCollision(startTime: CMTime, duration: CMTime, with items: [TimelineItem]) -> Bool {
        let endTime = startTime + duration
        
        return items.contains { item in
            let itemEndTime = item.startTime + item.duration
            return startTime < itemEndTime && endTime > item.startTime
        }
    }
    
    // MARK: - Snapping
    
    struct SnapPoint {
        let time: CMTime
        let type: SnapType
        let sourceItem: TimelineItem?
    }
    
    enum SnapType {
        case itemStart
        case itemEnd
        case playhead
        case gridMark
    }
    
    static func findSnapPoints(for item: TimelineItem, in tracks: [TimelineTrack], playheadTime: CMTime, gridInterval: CMTime) -> [SnapPoint] {
        var snapPoints: [SnapPoint] = []
        
        // Add playhead snap point
        snapPoints.append(SnapPoint(time: playheadTime, type: .playhead, sourceItem: nil))
        
        // Add grid snap points (every gridInterval)
        let maxTime = tracks.flatMap { $0.items }.map { $0.startTime + $0.duration }.max() ?? CMTime.zero
        var gridTime = CMTime.zero
        while gridTime <= maxTime {
            snapPoints.append(SnapPoint(time: gridTime, type: .gridMark, sourceItem: nil))
            gridTime = gridTime + gridInterval
        }
        
        // Add item-based snap points
        for track in tracks {
            for otherItem in track.items {
                if otherItem.id != item.id {
                    // Start of other items
                    snapPoints.append(SnapPoint(time: otherItem.startTime, type: .itemStart, sourceItem: otherItem))
                    // End of other items
                    snapPoints.append(SnapPoint(time: otherItem.startTime + otherItem.duration, type: .itemEnd, sourceItem: otherItem))
                }
            }
        }
        
        return snapPoints
    }
    
    static func findNearestSnapPoint(to time: CMTime, in snapPoints: [SnapPoint], tolerance: CMTime) -> SnapPoint? {
        return snapPoints
            .filter { abs($0.time.seconds - time.seconds) <= tolerance.seconds }
            .min { abs($0.time.seconds - time.seconds) < abs($1.time.seconds - time.seconds) }
    }
    
    // MARK: - Magnetic Alignment
    
    static func magneticAlign(item: TimelineItem, to snapPoint: SnapPoint, edge: ItemEdge) -> CMTime {
        switch edge {
        case .start:
            return snapPoint.time
        case .end:
            return snapPoint.time - item.duration
        }
    }
    
    enum ItemEdge {
        case start
        case end
    }
    
    // MARK: - Timeline Validation
    
    static func validateItemPlacement(_ item: TimelineItem) -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // Check minimum duration
        let minimumDuration = CMTime(seconds: 0.1, preferredTimescale: 600)
        if item.duration < minimumDuration {
            issues.append(.durationTooShort)
        }
        
        // Check negative start time
        if item.startTime < CMTime.zero {
            issues.append(.negativeStartTime)
        }
        
        // Check maximum duration based on item type
        let maximumDuration = getMaximumDuration(for: item.trackType)
        if item.duration > maximumDuration {
            issues.append(.durationTooLong)
        }
        
        return ValidationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    private static func getMaximumDuration(for trackType: TimelineTrackType) -> CMTime {
        switch trackType {
        case .video:
            return CMTime(seconds: 3600, preferredTimescale: 600) // 1 hour max
        case .audio:
            return CMTime(seconds: 3600, preferredTimescale: 600) // 1 hour max
        case .text:
            return CMTime(seconds: 300, preferredTimescale: 600) // 5 minutes max
        case .sticker:
            return CMTime(seconds: 300, preferredTimescale: 600) // 5 minutes max
        }
    }
    
    struct ValidationResult {
        let isValid: Bool
        let issues: [ValidationIssue]
    }
    
    enum ValidationIssue {
        case durationTooShort
        case durationTooLong
        case negativeStartTime
        case overlapsWithOtherItems
    }
}

// MARK: - Timeline Zoom System

class TimelineZoomSystem {
    
    static let zoomLevels: [CGFloat] = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0]
    static let defaultZoomLevel: CGFloat = 1.0
    
    static func nextZoomLevel(current: CGFloat, zoomIn: Bool) -> CGFloat {
        guard let currentIndex = zoomLevels.firstIndex(of: current) else {
            return defaultZoomLevel
        }
        
        if zoomIn {
            let nextIndex = min(currentIndex + 1, zoomLevels.count - 1)
            return zoomLevels[nextIndex]
        } else {
            let nextIndex = max(currentIndex - 1, 0)
            return zoomLevels[nextIndex]
        }
    }
    
    static func pixelsPerSecond(for zoomLevel: CGFloat, basePixelsPerSecond: CGFloat) -> CGFloat {
        return basePixelsPerSecond * zoomLevel
    }
    
    static func zoomToFit(contentWidth: CGFloat, viewWidth: CGFloat, basePixelsPerSecond: CGFloat) -> CGFloat {
        let targetPixelsPerSecond = viewWidth / (contentWidth / basePixelsPerSecond)
        
        // Find the closest zoom level
        return zoomLevels.min { level1, level2 in
            let pixels1 = basePixelsPerSecond * level1
            let pixels2 = basePixelsPerSecond * level2
            return abs(pixels1 - targetPixelsPerSecond) < abs(pixels2 - targetPixelsPerSecond)
        } ?? defaultZoomLevel
    }
}

// MARK: - Timeline Performance Optimizations

class TimelinePerformanceSystem {
    
    private static var visibleItemCache: [String: [TimelineItem]] = [:]
    
    static func getVisibleItems(in tracks: [TimelineTrack], visibleTimeRange: CMTimeRange) -> [TimelineItem] {
        let cacheKey = "\(visibleTimeRange.start.seconds)-\(visibleTimeRange.duration.seconds)"
        
        if let cachedItems = visibleItemCache[cacheKey] {
            return cachedItems
        }
        
        let visibleItems = tracks.flatMap { track in
            track.items.filter { item in
                let itemTimeRange = CMTimeRange(start: item.startTime, duration: item.duration)
                return visibleTimeRange.intersection(itemTimeRange).duration > CMTime.zero
            }
        }
        
        visibleItemCache[cacheKey] = visibleItems
        return visibleItems
    }
    
    static func clearCache() {
        visibleItemCache.removeAll()
    }
    
    static func shouldUpdateView(for scrollOffset: CGFloat, lastUpdateOffset: CGFloat, threshold: CGFloat = 50) -> Bool {
        return abs(scrollOffset - lastUpdateOffset) > threshold
    }
}
