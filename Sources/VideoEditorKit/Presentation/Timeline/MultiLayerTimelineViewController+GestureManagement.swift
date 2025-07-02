//
//  MultiLayerTimelineViewController+GestureManagement.swift
//  
//
//  Created by VideoEditorKit on 01.07.25.
//

import UIKit
import AVFoundation

/*
 * TRIM LOGIC DOCUMENTATION AND EDGE CASES
 * ========================================
 * 
 * This file handles all gesture manageme        // 🎯 For visual feedback, pass the raw proposed values to allow immediate response
        // The visual feedback function will do minimal validation to maintain responsiveness
        updateVisualFeedbackForTrimming(
            item: item,
            newStartTime: proposedStartTime,
            newDuration: proposedDuration,
            direction: direction
        )
        
        print("📱 ✂️ Trimming \(direction): start=\(proposedStartTime.seconds)s, duration=\(proposedDuration.seconds)s, translation=\(translation.x)px")ine, with particular focus
 * on trimming operations. Below are the key scenarios and edge cases:
 *
 * LEFT HANDLE TRIMMING:
 * ---------------------
 * - Drag Right (positive translation): Moves startTime forward, reduces duration
 * - Drag Left (negative translation): Moves startTime backward (towards 0), increases duration
 * - Edge Case 1: Cannot move startTime below 0
 * - Edge Case 2: Cannot reduce duration below 0.1s minimum
 * - Edge Case 3: For video items, total end time (startTime + duration) cannot exceed asset duration
 *
 * RIGHT HANDLE TRIMMING:
 * ----------------------
 * - Drag Right (positive translation): Increases duration
 * - Drag Left (negative translation): Decreases duration
 * - Edge Case 1: Cannot reduce duration below 0.1s minimum
 * - Edge Case 2: For video items, total end time (startTime + duration) cannot exceed asset duration
 *
 * VISUAL FEEDBACK vs DATA MODEL:
 * ------------------------------
 * - During pan gesture: Only visual frames are updated for performance
 * - On gesture end: Data model is updated and store is notified
 * - Validation happens at both levels to ensure consistency
 *
 * PERFORMANCE CONSIDERATIONS:
 * ---------------------------
 * - updateVisualFeedbackForTrimming() uses direct CALayer frame updates
 * - No animations during pan for immediate feedback
 * - Data model updates are deferred until gesture completion
 * - Store updates are debounced to prevent excessive notifications
 */

// MARK: - Centralized Gesture Management

extension MultiLayerTimelineViewController {
    
    func setupCentralizedGestures() {
        // Setup coordinated gesture recognizers
        let trimPanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleTrimPan(_:)))
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        
        // Configure gestures for proper coordination
        trimPanGesture.delegate = self
        tapGesture.delegate = self
        
        // Add gestures to content view (not scroll view) to avoid conflict
        contentView.addGestureRecognizer(trimPanGesture)
        contentView.addGestureRecognizer(tapGesture)
        
        // Allow scroll view to handle its own pan gesture natively
        // Note: We don't set the scroll view's pan gesture delegate as it must remain the scroll view itself
        
        print("📱 🎯 Centralized gesture management setup complete")
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        // Get location in scroll view coordinates instead of content view
        let location = gesture.location(in: scrollView)
        print("📱 👆 Tap detected at location: \(location)")
        
        // Find which item was tapped
        if let (item, _) = findItemAt(location: location) {
            print("📱 ✅ Item selected: \(item.id)")
            selectItem(item)
            delegate?.timeline(self, didSelectItem: item)
            
            // Haptic feedback for selection
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        } else {
            print("📱 ❌ No item at tap location - deselecting")
            selectItem(nil)
        }
    }
    
    @objc func handleTrimPan(_ gesture: UIPanGestureRecognizer) {
        // Get location in scroll view coordinates instead of content view
        let location = gesture.location(in: scrollView)
        let translation = gesture.translation(in: scrollView)
        let velocity = gesture.velocity(in: scrollView)
        
        switch gesture.state {
        case .began:
            handleTrimPanBegan(location: location)
        case .changed:
            handleTrimPanChanged(translation: translation, velocity: velocity)
        case .ended, .cancelled:
            handleTrimPanEnded(velocity: velocity)
        default:
            break
        }
    }
    
    private func handleTrimPanBegan(location: CGPoint) {
        print("📱 🏁 Trim pan began at location: \(location)")
        
        // Determine if this is a valid trim gesture
        if let (item, trimArea) = findItemAt(location: location), trimArea != .none {
            currentGestureState = .trimming(
                item: item,
                direction: trimArea,
                initialItem: item,
                initialLocation: location
            )
            
            // Auto-select item for trimming
            selectItem(item)
            
            // Set trim flag to prevent unwanted timeline jumps during trimming
            isTrimInProgress = true
            
            // Haptic feedback for trim start
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            print("📱 ✂️ Started trimming \(trimArea) of item: \(item.id)")
        } else {
            // This is not a trim gesture, fail the gesture to allow scroll view scrolling
            currentGestureState = .none
            print("📱 ❌ Not a trim gesture - allowing scroll view to handle")
        }
    }
    
    private func handleTrimPanChanged(translation: CGPoint, velocity: CGPoint) {
        switch currentGestureState {
        case .trimming(let item, let direction, let initialItem, let initialLocation):
            handleTrimGesture(
                item: item,
                direction: direction,
                translation: translation,
                initialItem: initialItem,
                initialLocation: initialLocation
            )
            
        case .trimming, .none:
            // Should not reach here for trim pan gesture
            break
        }
    }
    
    private func handleTrimPanEnded(velocity: CGPoint) {
        print("📱 🏁 Trim pan ended with velocity: \(velocity)")
        
        switch currentGestureState {
        case .trimming(let item, let direction, let initialItem, _):
            finalizeTrimGesture(item: item, direction: direction, initialItem: initialItem)
            
            // Haptic feedback for trim end
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
        case .none:
            break
        }
        
        // Reset gesture state
        currentGestureState = .none
        isTrimInProgress = false
        currentTrimTranslation = .zero // Reset translation tracking
    }
}

// MARK: - Gesture State Management

extension MultiLayerTimelineViewController {
    
    enum GestureState {
        case none
        case trimming(item: TimelineItem, direction: TrimDirection, initialItem: TimelineItem, initialLocation: CGPoint)
    }
    
    enum TrimDirection {
        case left
        case right
        case none
    }
    
    func findItemAt(location: CGPoint) -> (TimelineItem, TrimDirection)? {
        print("📱 🔍 Finding item at location:")
        print("   👆 ScrollView: \(location)")
        
        // Check each track view and its item views directly
        for trackView in trackViews {
            // Convert scroll view location to track view coordinates
            let locationInTrackView = trackView.convert(location, from: scrollView)
            
            print("📱 🔍 Track \(trackView.track.type): location in track = \(locationInTrackView)")
            
            // Check if location is within this track view's bounds
            if trackView.bounds.contains(locationInTrackView) {
                print("📱 📍 Location is within track \(trackView.track.type)")
                
                // Check each item view in this track
                for itemView in trackView.itemViews {
                    // Convert track view location to item view coordinates
                    let locationInItemView = itemView.convert(locationInTrackView, from: trackView)
                    
                    print("📱 🔍 Item \(itemView.item.id): location in item = \(locationInItemView), bounds = \(itemView.bounds)")
                    
                    // Check if location is within this item view's bounds
                    if itemView.bounds.contains(locationInItemView) {
                        print("📱 🎯 Found item \(itemView.item.id)")
                        
                        // Determine if this is a trim gesture (near edges) or selection
                        let handleWidth: CGFloat = 44  // Large touch area for easier testing
                        let tolerance: CGFloat = 16    // Additional tolerance
                        
                        let leftHandleEndX = handleWidth + tolerance
                        let rightHandleStartX = itemView.bounds.width - handleWidth - tolerance
                        
                        print("📱 🔧 Handle detection:")
                        print("   📏 Item bounds: \(itemView.bounds)")
                        print("   ◀️ Left handle: 0 to \(leftHandleEndX)")
                        print("   ▶️ Right handle: \(rightHandleStartX) to \(itemView.bounds.width)")
                        print("   👆 Touch at: \(locationInItemView.x)")
                        
                        if locationInItemView.x <= leftHandleEndX {
                            print("📱 ◀️ Left handle detected (touch: \(locationInItemView.x) <= \(leftHandleEndX))")
                            return (itemView.item, .left)
                        } else if locationInItemView.x >= rightHandleStartX {
                            print("📱 ▶️ Right handle detected (touch: \(locationInItemView.x) >= \(rightHandleStartX))")
                            return (itemView.item, .right)
                        } else {
                            print("📱 🎯 Item center detected (touch: \(locationInItemView.x) between \(leftHandleEndX) and \(rightHandleStartX))")
                            return (itemView.item, .none)
                        }
                    }
                }
            }
        }
        
        print("📱 ❌ No item found at location")
        return nil
    }
    
    private func handleTrimGesture(
        item: TimelineItem,
        direction: TrimDirection,
        translation: CGPoint,
        initialItem: TimelineItem,
        initialLocation: CGPoint
    ) {
        guard direction != .none else { return }
        
        // Store current translation for visual feedback
        currentTrimTranslation = translation
        
        let pixelsPerSecond = configuration.pixelsPerSecond
        let translationInSeconds = Double(translation.x) / Double(pixelsPerSecond)
        
        var proposedStartTime = initialItem.startTime
        var proposedDuration = initialItem.duration
        
        switch direction {
        case .left:
            // Trim from the left (adjust start time and duration)
            proposedStartTime = CMTime(
                seconds: initialItem.startTime.seconds + translationInSeconds,
                preferredTimescale: initialItem.startTime.timescale
            )
            
            let adjustedSeconds = max(0, proposedStartTime.seconds) - initialItem.startTime.seconds
            proposedDuration = CMTime(
                seconds: initialItem.duration.seconds - adjustedSeconds,
                preferredTimescale: initialItem.duration.timescale
            )
            
        case .right:
            // Trim from the right (adjust duration only)
            proposedDuration = CMTime(
                seconds: initialItem.duration.seconds + translationInSeconds,
                preferredTimescale: initialItem.duration.timescale
            )
            
        case .none:
            break
        }
        
        // 🎯 For visual feedback, pass the raw proposed values to allow immediate response
        // The visual feedback function will do minimal validation to maintain responsiveness
        updateVisualFeedbackForTrimming(
            item: item,
            newStartTime: proposedStartTime,
            newDuration: proposedDuration,
            direction: direction
        )
        
        print("📱 ✂️ Trimming \(direction): start=\(proposedStartTime.seconds)s, duration=\(proposedDuration.seconds)s, translation=\(translation.x)px")
    }
    
    /// Provides lightweight visual feedback during trimming without triggering full data updates
    private func updateVisualFeedbackForTrimming(
        item: TimelineItem,
        newStartTime: CMTime,
        newDuration: CMTime,
        direction: TrimDirection
    ) {
        // Find the specific item view to update
        for trackView in trackViews {
            if let itemView = trackView.itemViews.first(where: { $0.item.id == item.id }) {
                
                print("📱 🔍 Visual feedback input: startTime=\(newStartTime.seconds)s, duration=\(newDuration.seconds)s")
                
                // 🎯 For visual feedback, use MINIMAL validation to allow immediate response
                // We only prevent truly invalid states, not minor precision issues
                var visualStartTime = newStartTime
                var visualDuration = newDuration
                
                // Only clamp if values are truly invalid (negative or zero)
                if visualStartTime.seconds < 0 {
                    visualStartTime = CMTime.zero
                    print("📱 ⚠️ Clamped negative startTime to 0")
                }
                
                if visualDuration.seconds < 0.05 { // Much smaller minimum for visual feedback
                    visualDuration = CMTime(seconds: 0.05, preferredTimescale: 600)
                    print("📱 ⚠️ Clamped tiny duration to 0.05s")
                }
                
                // For video items, check asset bounds but be lenient for visual feedback
                if let videoItem = item as? VideoTimelineItem {
                    let maxStartTime = videoItem.asset.duration.seconds - visualDuration.seconds
                    if visualStartTime.seconds > maxStartTime {
                        visualStartTime = CMTime(seconds: maxStartTime, preferredTimescale: 600)
                        print("📱 ⚠️ Clamped startTime to asset bounds")
                    }
                }
                
                print("📱 🔧 Visual feedback processed: startTime=\(visualStartTime.seconds)s, duration=\(visualDuration.seconds)s")
                
                // 🎯 Use the simplified handle movement functions from TimelineItemView
                let deltaX = currentTrimTranslation.x
                
                print("📱 🎨 Handle feedback for \(direction): deltaX=\(deltaX)")
                
                switch direction {
                case .left:
                    itemView.moveLeftHandle(by: deltaX)
                    
                case .right:
                    itemView.moveRightHandle(by: deltaX)
                    
                case .none:
                    break
                }
                
                print("📱 ✅ Handle visual feedback applied successfully")
                break
            }
        }
    }
    
    private func finalizeTrimGesture(item: TimelineItem, direction: TrimDirection, initialItem: TimelineItem) {
        print("📱 ✅ Finalizing trim gesture for item: \(item.id)")
        
        // Calculate trim changes for video items
        if let videoItem = item as? VideoTimelineItem {
            let pixelsPerSecond = configuration.pixelsPerSecond
            let deltaSeconds = Double(currentTrimTranslation.x) / Double(pixelsPerSecond)
            
            // Get current store trim state
            let currentTrim = store.trimPositions
            let asset = videoItem.asset
            let totalDuration = asset.duration.seconds
            let currentTrimmedDuration = totalDuration * (currentTrim.1 - currentTrim.0)
            
            // Calculate new trim ratios based on direction and delta
            var newTrimStartRatio = currentTrim.0
            var newTrimEndRatio = currentTrim.1
            
            switch direction {
            case .left:
                // Left trim: moving start position
                // deltaSeconds represents change in trimmed duration
                let newTrimmedDuration = currentTrimmedDuration - (deltaSeconds * store.speed)
                let durationChangeRatio = (currentTrimmedDuration - newTrimmedDuration) / totalDuration
                newTrimStartRatio = currentTrim.0 + durationChangeRatio
                
            case .right:
                // Right trim: moving end position
                let newTrimmedDuration = currentTrimmedDuration + (deltaSeconds * store.speed)
                let durationChangeRatio = (newTrimmedDuration - currentTrimmedDuration) / totalDuration
                newTrimEndRatio = currentTrim.1 + durationChangeRatio
                
            case .none:
                print("📱 ❌ Invalid trim direction")
                resetTrimState()
                return
            }
            
            // Ensure bounds are valid
            newTrimStartRatio = max(0.0, min(newTrimStartRatio, 1.0))
            newTrimEndRatio = max(0.0, min(newTrimEndRatio, 1.0))
            
            // Ensure start < end with minimum duration
            let minDurationRatio = 0.1 / totalDuration // Minimum 0.1 second
            if newTrimEndRatio - newTrimStartRatio < minDurationRatio {
                if direction == .left {
                    newTrimStartRatio = newTrimEndRatio - minDurationRatio
                } else {
                    newTrimEndRatio = newTrimStartRatio + minDurationRatio
                }
            }
            
            // Round to 4 decimal places to ensure we can reach exact 0.0 and 1.0
            let roundedStartRatio = round(newTrimStartRatio * 10000) / 10000
            let roundedEndRatio = round(newTrimEndRatio * 10000) / 10000
            
            print("📹 Store update - Video trim: start=\(roundedStartRatio), end=\(roundedEndRatio)")
            print("📹 Previous trim: start=\(currentTrim.0), end=\(currentTrim.1)")
            print("📹 Delta: \(deltaSeconds)s, Direction: \(direction)")
            print("📹 Duration change: \(currentTrimmedDuration)s -> \((roundedEndRatio - roundedStartRatio) * totalDuration)s")
            
            // Update store - this will trigger updateTracksFromStore
            store.trimPositions = (roundedStartRatio, roundedEndRatio)
        }
        
        // Reset visual state
        resetTrimState()
        
        // The timeline will be rebuilt automatically via store updates
        // Selection will be restored in updateTracksFromStore
    }
}

// MARK: - Trim Visual State Management

extension MultiLayerTimelineViewController {
    
    /// Resets the visual state after trimming is complete
    private func resetTrimState() {
        // Reset handle transforms for all item views using the new simplified function
        for trackView in trackViews {
            for itemView in trackView.itemViews {
                itemView.resetHandlePositions()
            }
        }
        
        print("📱 🧹 Reset trim visual state")
    }
}


// MARK: - UIGestureRecognizerDelegate

extension MultiLayerTimelineViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow simultaneous recognition for tap gestures with other gestures
        if gestureRecognizer is UITapGestureRecognizer || otherGestureRecognizer is UITapGestureRecognizer {
            return true
        }
        
        // For pan gestures, don't allow simultaneous recognition to avoid conflicts
        return false
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Handle our custom trim pan gesture
        if gestureRecognizer.view == contentView, let panGesture = gestureRecognizer as? UIPanGestureRecognizer {
            let location = panGesture.location(in: scrollView)  // Use scroll view coordinates
            
            // Only begin if we're actually on a trim handle
            if let (_, trimDirection) = findItemAt(location: location), trimDirection != .none {
                print("📱 ✅ Allowing trim gesture to begin for \(trimDirection) handle")
                return true
            } else {
                print("📱 ❌ Failing trim gesture - not on a handle, allowing scroll view")
                return false
            }
        }
        
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}
