import UIKit
import AVFoundation

/// Scroll direction enum to track the current scrolling direction
enum ScrollDirection {
    case none
    case horizontal
    case vertical
    case crazy // Diagonal movement that needs to be locked
}

/// Handles timeline scroll behavior with direction locking
/// Implements the direction lock algorithm from:
/// https://bogdanconstantinescu.com/blog/proper-direction-lock-for-uiscrollview.html
class TimelineScrollHandler: NSObject {
    
    // MARK: - Properties
    
    weak var timelineViewController: MultiLayerTimelineViewController?
    
    private var initialOffset: CGPoint = .zero
    private var isSeeking = false
    private var isScrollDisabled = false
    
    // Direction lock sensitivity threshold (not used in blog post implementation)
    private let directionLockThreshold: CGFloat = 10.0
    
    // MARK: - Initialization
    
    init(timelineViewController: MultiLayerTimelineViewController) {
        self.timelineViewController = timelineViewController
        super.init()
        print("📱 🔍 TimelineScrollHandler initialized")
    }
    
    // MARK: - Public Methods
    
    func setupScrollViewDelegate(_ scrollView: UIScrollView) {
        print("📱 🔍 Setting up scroll view delegate")
        scrollView.delegate = self
        scrollView.isDirectionalLockEnabled = false // We handle direction lock ourselves
        print("📱 🔍 Scroll view delegate set to TimelineScrollHandler")
    }
    
    func configureDirectionalScrolling(for scrollView: UIScrollView) {
        print("📱 🔍 Configuring directional scrolling")
        print("📱 🔍 Current scroll view delegate: \(String(describing: scrollView.delegate))")
        scrollView.isDirectionalLockEnabled = false
        
        // Verify delegate is set to us
        if scrollView.delegate === self {
            print("📱 ✅ Scroll view delegate is correctly set to TimelineScrollHandler")
        } else {
            print("📱 ❌ WARNING: Scroll view delegate is NOT set to TimelineScrollHandler!")
        }
    }
    
    func forceDirectionalScrolling(for scrollView: UIScrollView) {
        // This method configures the scroll view for our custom direction locking
        scrollView.isDirectionalLockEnabled = false
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
    }
    
    func resetScrollDirection() {
        // Reset initial offset for new scroll session
        initialOffset = .zero
    }
    
    func disableScroll() {
        isScrollDisabled = true
    }
    
    func enableScroll() {
        isScrollDisabled = false
    }
    
    func updatePlayheadPosition() {
        guard let timelineVC = timelineViewController else { return }
        
        // Update carret layer frame
        timelineVC.updateCarretLayerFrame()
        
        // Calculate scroll position to center current time under the playhead
        let currentTime = timelineVC.store.playheadProgress
        
        if currentTime.seconds >= 0 {
            // Convert current time to pixels
            let currentTimePixels = CGFloat(currentTime.seconds) * timelineVC.configuration.pixelsPerSecond
            // Calculate offset to center this time position under the fixed playhead
            let centerOffset = currentTimePixels - timelineVC.scrollView.contentInset.left
            let point = CGPoint(x: centerOffset, y: 0)
            
            // Update main timeline scroll
            timelineVC.scrollView.setContentOffset(point, animated: false)
            
            // Sync time ruler scroll position (both have same contentInset now)
            timelineVC.timeRulerView.setContentOffset(CGPoint(x: timelineVC.scrollView.contentOffset.x, y: 0))
        }
    }
    
    func updateScrollViewContentOffset(fractionCompleted: Double) {
        guard let timelineVC = timelineViewController else { return }
        
        // Get the maximum duration from all tracks
        let maxDuration = timelineVC.tracks.flatMap { $0.items }.map { $0.startTime + $0.duration }.max() ?? CMTime.zero
        
        if maxDuration.seconds > 0 {
            // Calculate the target time based on the fraction
            let targetTime = maxDuration.seconds * fractionCompleted
            
            // Convert time to pixels using the timeline's configuration
            let targetPixels = CGFloat(targetTime) * timelineVC.configuration.pixelsPerSecond
            
            // Calculate the offset, accounting for content insets
            let centerOffset = targetPixels - timelineVC.scrollView.contentInset.left
            let targetOffset = CGPoint(x: centerOffset, y: timelineVC.scrollView.contentOffset.y)
            
            // Update the scroll view's content offset
            timelineVC.scrollView.setContentOffset(targetOffset, animated: false)
            
            // Sync time ruler scroll position
            timelineVC.timeRulerView.setContentOffset(CGPoint(x: targetOffset.x, y: 0))
        }
    }
    
    // MARK: - Private Methods
    
    private func determineScrollDirection(from initialOffset: CGPoint, to currentOffset: CGPoint) -> ScrollDirection {
        // EXACT logic from blog post
        print("📱 🔍 determineScrollDirection: initial=\(initialOffset), current=\(currentOffset)")
        
        // If the scrolling direction is changed on both X and Y it means the
        // scrolling started in one corner and goes diagonal. This will be
        // called ScrollDirectionCrazy
        if initialOffset.x != currentOffset.x && initialOffset.y != currentOffset.y {
            print("📱 🔍 Direction: CRAZY (both X and Y changed)")
            return .crazy
        } else {
            if initialOffset.x > currentOffset.x {
                print("📱 🔍 Direction: HORIZONTAL Left")
                return .horizontal // Left
            } else if initialOffset.x < currentOffset.x {
                print("📱 🔍 Direction: HORIZONTAL Right")
                return .horizontal // Right
            } else if initialOffset.y > currentOffset.y {
                print("📱 🔍 Direction: VERTICAL Up")
                return .vertical // Up
            } else if initialOffset.y < currentOffset.y {
                print("📱 🔍 Direction: VERTICAL Down")
                return .vertical // Down
            } else {
                print("📱 🔍 Direction: NONE")
                return .none
            }
        }
    }
    
    private func determineScrollDirectionAxis(from initialOffset: CGPoint, to currentOffset: CGPoint) -> ScrollDirection {
        let scrollDirection = determineScrollDirection(from: initialOffset, to: currentOffset)
        print("📱 🔍 determineScrollDirectionAxis: detected direction = \(scrollDirection)")
        
        switch scrollDirection {
        case .horizontal:
            return .horizontal
        case .vertical:
            return .vertical
        default:
            return .none
        }
    }
    
    private func handleHorizontalScrolling(in scrollView: UIScrollView) {
        guard let timelineVC = timelineViewController else { return }
        
        // Update time ruler scroll position to sync with timeline
        timelineVC.timeRulerView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: 0))
        
        // Calculate current time based on scroll position
        if isSeeking {
            // Convert scroll position back to time
            let scrollOffsetWithInset = scrollView.contentOffset.x + scrollView.contentInset.left
            let timeSeconds = Double(scrollOffsetWithInset) / Double(timelineVC.configuration.pixelsPerSecond)
            let newTime = CMTime(seconds: max(timeSeconds, 0), preferredTimescale: timelineVC.configuration.timeScale)
            timelineVC.playheadPosition = newTime
        }
        
        // Update seeker value for store integration
        let maxDuration = timelineVC.tracks.flatMap { $0.items }.map { $0.startTime + $0.duration }.max() ?? CMTime.zero
        if maxDuration.seconds > 0 {
            let currentTimeSeconds = Double(scrollView.contentOffset.x + scrollView.contentInset.left) / Double(timelineVC.configuration.pixelsPerSecond)
            timelineVC.seekerValue = currentTimeSeconds / maxDuration.seconds
        }
    }
}

// MARK: - UIScrollViewDelegate

extension TimelineScrollHandler: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        print("📱 🔍 TimelineScrollHandler: scrollViewWillBeginDragging called")
        
        // If scrolling is disabled, prevent dragging
        if isScrollDisabled {
            print("📱 🚫 Scroll is disabled, preventing drag")
            return
        }
        
        // EXACT implementation from blog post
        // Store initial offset for direction lock calculations
        initialOffset = scrollView.contentOffset
        isSeeking = true
        
        // Notify timeline that seeking started
        timelineViewController?.isSeeking = true
        
        print("📱 🔓 Scroll began - stored initial offset: \(initialOffset)")
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        print("📱 🔍 TimelineScrollHandler: scrollViewDidScroll called - current offset: \(scrollView.contentOffset), initial: \(initialOffset)")
        
        // If scrolling is disabled, prevent any scroll movement
        if isScrollDisabled {
            print("📱 🚫 Scroll disabled, forcing back to initial offset")
            scrollView.contentOffset = initialOffset
            return
        }
        
        // EXACT implementation from blog post
        let scrollDirection = determineScrollDirectionAxis(from: initialOffset, to: scrollView.contentOffset)
        print("📱 🔍 Determined scroll direction: \(scrollDirection)")
        
        if scrollDirection == .vertical {
            print("📱 🔒 Scrolling direction: vertical")
            // Only handle vertical scrolling if needed
        } else if scrollDirection == .horizontal {
            print("📱 🔒 Scrolling direction: horizontal")
            // Handle horizontal scrolling for timeline
            handleHorizontalScrolling(in: scrollView)
        } else {
            // This is probably crazy movement: diagonal scrolling
            // EXACT logic from blog post
            let deltaX = abs(scrollView.contentOffset.x - initialOffset.x)
            let deltaY = abs(scrollView.contentOffset.y - initialOffset.y)
            print("📱 🔍 Diagonal detected - deltaX: \(deltaX), deltaY: \(deltaY)")
            
            var newOffset: CGPoint
            
            if deltaX > deltaY {
                // Stronger horizontal movement
                newOffset = CGPoint(x: scrollView.contentOffset.x, y: initialOffset.y)
                print("📱 🔒 BLOG POST LOCK: Horizontal chosen (deltaX: \(deltaX) > deltaY: \(deltaY))")
            } else {
                // Stronger vertical movement
                newOffset = CGPoint(x: initialOffset.x, y: scrollView.contentOffset.y)
                print("📱 🔒 BLOG POST LOCK: Vertical chosen (deltaY: \(deltaY) >= deltaX: \(deltaX))")
            }
            
            print("📱 🔒 Setting new offset: \(newOffset)")
            // Setting the new offset to the scrollView makes it behave like a proper
            // directional lock, that allows you to scroll in only one direction at any given time
            scrollView.contentOffset = newOffset
            
            // If we locked to horizontal, handle timeline logic
            if newOffset.x != initialOffset.x {
                print("📱 🔒 Handling horizontal scrolling after lock")
                handleHorizontalScrolling(in: scrollView)
            }
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        print("📱 🔍 TimelineScrollHandler: scrollViewDidEndDragging called")
        if !decelerate {
            scrollViewDidEndDecelerating(scrollView)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        print("📱 🔍 TimelineScrollHandler: scrollViewDidEndDecelerating called")
        isSeeking = false
        
        // Notify timeline that seeking ended
        timelineViewController?.isSeeking = false
        
        print("📱 🔓 Scroll ended")
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        // Handle programmatic scrolling end
        if let timelineVC = timelineViewController {
            // The timeline view controller will handle position updates
            timelineVC.playheadPosition = timelineVC.playheadPosition // This will trigger updates
        }
    }
}
