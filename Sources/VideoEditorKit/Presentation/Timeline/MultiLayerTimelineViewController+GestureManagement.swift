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
                        let handleWidth: CGFloat = 80  // Large touch area for easier testing
                        let tolerance: CGFloat = 40    // Additional tolerance
                        
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
        
        // 🎯 Calculate final trimmed item using the translation we've been tracking
        // Use initialItem as the base to ensure we calculate from the original state
        guard let finalItem = calculateFinalTrimmedItem(from: initialItem, translation: currentTrimTranslation, direction: direction) else {
            print("📱 ❌ Could not calculate final trimmed item state")
            resetTrimState()
            return
        }
        
        print("📱 ✅ Final calculated trim: start=\(finalItem.startTime.seconds)s, duration=\(finalItem.duration.seconds)s")
        print("📱 📊 Original item: start=\(initialItem.startTime.seconds)s, duration=\(initialItem.duration.seconds)s")
        print("📱 📏 Translation used: \(currentTrimTranslation.x)px")
        
        // 🎯 Reset visual state
        resetTrimState()
        
        // 🔄 The item view frame will be updated automatically when we call updateItem()
        // So we just need to make sure the data model is updated properly
        
        // 🔄 Now perform the actual data update
        updateItem(finalItem)
        
        // Ensure item remains selected
        selectedItem = finalItem
        selectItem(finalItem)
        
        // Notify delegate
        delegate?.timeline(self, didTrimItem: finalItem, newStartTime: finalItem.startTime, newDuration: finalItem.duration)
        
        // Update store for video items
        if let videoItem = finalItem as? VideoTimelineItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let totalDuration = videoItem.asset.duration.seconds
                let trimStartRatio = finalItem.startTime.seconds / totalDuration
                let trimEndRatio = (finalItem.startTime.seconds + finalItem.duration.seconds) / totalDuration
                
                print("📹 Store update - Video trim: start=\(trimStartRatio), end=\(trimEndRatio)")
                self.store.trimPositions = (trimStartRatio, trimEndRatio)
            }
        }
    }
    
    /// Calculates the final trimmed item state based on translation amount
    private func calculateFinalTrimmedItem(from item: TimelineItem, translation: CGPoint, direction: TrimDirection) -> TimelineItem? {
        // Find the item view to get current frame
        for trackView in trackViews {
            if let itemView = trackView.itemViews.first(where: { $0.item.id == item.id }) {
                let currentFrame = itemView.frame
                let pixelsPerSecond = configuration.pixelsPerSecond
                
                var newStartTime = item.startTime
                var newDuration = item.duration
                
                switch direction {
                case .left:
                    // For left handle: translation.x affects start time and duration
                    let deltaSeconds = Double(translation.x) / Double(pixelsPerSecond)
                    newStartTime = CMTime(
                        seconds: item.startTime.seconds + deltaSeconds,
                        preferredTimescale: configuration.timeScale
                    )
                    newDuration = CMTime(
                        seconds: item.duration.seconds - deltaSeconds,
                        preferredTimescale: configuration.timeScale
                    )
                    
                case .right:
                    // For right handle: translation.x affects only duration
                    let deltaSeconds = Double(translation.x) / Double(pixelsPerSecond)
                    newDuration = CMTime(
                        seconds: item.duration.seconds + deltaSeconds,
                        preferredTimescale: configuration.timeScale
                    )
                    
                case .none:
                    return nil
                }
                
                print("📱 🔄 Translation: \(translation.x)px = \(Double(translation.x) / Double(pixelsPerSecond))s")
                print("📱 🔄 Calculated: start=\(newStartTime.seconds)s, duration=\(newDuration.seconds)s")
                
                // Apply validation to ensure values stay within bounds
                let validated = validateTrimParameters(
                    for: item,
                    proposedStartTime: newStartTime,
                    proposedDuration: newDuration
                )
                
                print("📱 ✅ Final validated values: start=\(validated.startTime.seconds)s, duration=\(validated.duration.seconds)s")
                
                // Create updated item with validated values
                var finalItem = item
                finalItem.startTime = validated.startTime
                finalItem.duration = validated.duration
                
                return finalItem
            }
        }
        
        return nil
    }
}

// MARK: - Trim Validation Helpers

extension MultiLayerTimelineViewController {
    
    /// Validates and adjusts trim parameters to ensure they stay within asset bounds
    private func validateTrimParameters(
        for item: TimelineItem,
        proposedStartTime: CMTime,
        proposedDuration: CMTime
    ) -> (startTime: CMTime, duration: CMTime) {
        
        let originalStartTime = proposedStartTime.seconds
        let originalDuration = proposedDuration.seconds
        
        var validatedStartTime = proposedStartTime
        var validatedDuration = proposedDuration
        
        // Ensure startTime is not negative
        validatedStartTime = CMTime(
            seconds: max(0, proposedStartTime.seconds),
            preferredTimescale: proposedStartTime.timescale
        )
        
        // For video items, ensure we don't exceed asset duration
        if let videoItem = item as? VideoTimelineItem {
            let originalAssetDuration = videoItem.asset.duration
            let maxPossibleDuration = originalAssetDuration.seconds - validatedStartTime.seconds
            
            validatedDuration = CMTime(
                seconds: min(proposedDuration.seconds, maxPossibleDuration),
                preferredTimescale: proposedDuration.timescale
            )
            
            // Log if we had to clamp due to asset bounds
            if validatedDuration.seconds != proposedDuration.seconds {
                print("📱 ⚠️ Clamped duration due to asset bounds: \(proposedDuration.seconds)s → \(validatedDuration.seconds)s")
            }
        }
        
        // Ensure minimum duration
        validatedDuration = CMTime(
            seconds: max(0.1, validatedDuration.seconds),
            preferredTimescale: validatedDuration.timescale
        )
        
        // Log significant changes
        if abs(validatedStartTime.seconds - originalStartTime) > 0.01 {
            print("📱 ⚠️ Adjusted startTime: \(originalStartTime)s → \(validatedStartTime.seconds)s")
        }
        
        if abs(validatedDuration.seconds - originalDuration) > 0.01 {
            print("📱 ⚠️ Adjusted duration: \(originalDuration)s → \(validatedDuration.seconds)s")
        }
        
        return (validatedStartTime, validatedDuration)
    }
    
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
