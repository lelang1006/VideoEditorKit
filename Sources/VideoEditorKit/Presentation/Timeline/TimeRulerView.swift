//
//  TimeRulerView.swift
//  
//
//  Created by VideoEditorKit on 29.06.25.
//

import UIKit
import AVFoundation
import PureLayout

class TimeRulerView: UIView {
    
    // MARK: - Properties
    
    let configuration: TimelineConfiguration
    var duration: CMTime = .zero
    
    lazy var scrollView: UIScrollView = makeScrollView()
    lazy var rulerContentView: UIView = makeRulerContentView()
    
    // MARK: - Init
    
    init(configuration: TimelineConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        drawTimeMarkers(in: rect)
    }
}

// MARK: - Public Methods

extension TimeRulerView {
    
    func setDuration(_ duration: CMTime) {
        self.duration = duration
        updateContentSize()
        setNeedsDisplay()
    }
    
    func setDuration(_ duration: CMTime, contentWidth: CGFloat) {
        self.duration = duration
        // Use the exact content width from the main timeline
        scrollView.contentSize = CGSize(width: contentWidth, height: bounds.height)
        rulerContentView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: bounds.height)
        
        setNeedsDisplay()
    }
    
    func setContentOffset(_ offset: CGPoint) {
        scrollView.setContentOffset(offset, animated: false)
    }
    
    func setContentInset(_ inset: UIEdgeInsets) {
        scrollView.contentInset = inset
    }
}

// MARK: - Methods

extension TimeRulerView {
    
    func setupUI() {
        updateTheme()
        
        addSubview(scrollView)
        scrollView.addSubview(rulerContentView)
        
        setupConstraints()
    }
    
    func setupConstraints() {
        scrollView.autoPinEdgesToSuperviewEdges()
        rulerContentView.autoPinEdgesToSuperviewEdges()
        rulerContentView.autoMatch(.height, to: .height, of: scrollView)
    }
    
    func updateContentSize() {
        // Use same content width calculation as main timeline
        // This ensures the ruler scrolls in sync with the timeline
        let durationWidth = CGFloat(duration.seconds) * configuration.pixelsPerSecond
        
        // Add the same padding that the main timeline uses
        // This should be calculated from the parent view, but for now we'll estimate
        let timelineContentWidth: CGFloat = 255.0 // This should match the main timeline calculation
        let contentWidth = durationWidth + timelineContentWidth
        
        scrollView.contentSize = CGSize(width: contentWidth, height: bounds.height)
        rulerContentView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: bounds.height)
    }
    
    func drawTimeMarkers(in rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { 
            return 
        }
        
        let totalSeconds = duration.seconds
        let pixelsPerSecond = configuration.pixelsPerSecond
        
        // Calculate appropriate time intervals
        let (majorInterval, minorInterval) = calculateTimeIntervals(for: totalSeconds, pixelsPerSecond: pixelsPerSecond)
        
        // Draw major tick marks (with time labels)
        drawMajorTicks(context: context, interval: majorInterval, totalSeconds: totalSeconds, pixelsPerSecond: pixelsPerSecond, rect: rect)
        
        // Draw minor tick marks
        drawMinorTicks(context: context, interval: minorInterval, totalSeconds: totalSeconds, pixelsPerSecond: pixelsPerSecond, rect: rect)
    }
    
    func calculateTimeIntervals(for totalSeconds: Double, pixelsPerSecond: CGFloat) -> (major: Double, minor: Double) {
        let viewWidth = bounds.width
        let timePerView = Double(viewWidth) / Double(pixelsPerSecond)
        
        // Determine appropriate intervals based on zoom level
        // Since we want to show labels every thumbnailDurationInSeconds, adjust intervals accordingly
        let labelInterval = Double(TimelineItemView.thumbnailDurationInSeconds)
        if timePerView < 10 {
            return (major: labelInterval, minor: 0.5) // thumbnailDurationInSeconds major (for labels), 500ms minor
        } else if timePerView < 60 {
            return (major: labelInterval, minor: 1.0) // thumbnailDurationInSeconds major (for labels), 1s minor
        } else if timePerView < 300 {
            return (major: 10.0, minor: labelInterval) // 10s major, thumbnailDurationInSeconds minor (labels every thumbnailDurationInSeconds)
        } else {
            return (major: 30.0, minor: 10.0) // 30s major, 10s minor
        }
    }
    
    func drawMajorTicks(context: CGContext, interval: Double, totalSeconds: Double, pixelsPerSecond: CGFloat, rect: CGRect) {
        let theme = TimelineTheme.current
        context.setStrokeColor(theme.primaryTextColor.cgColor)
        context.setLineWidth(1.0)
        
        var currentTime: Double = 0
        while currentTime <= totalSeconds {
            let x = CGFloat(currentTime) * pixelsPerSecond
            
            // Draw tick line
            context.move(to: CGPoint(x: x, y: rect.height - 10))
            context.addLine(to: CGPoint(x: x, y: rect.height))
            context.strokePath()
            
            // Show time labels based on thumbnailDurationInSeconds (configurable interval)
            let currentTimeInt = Int(currentTime)
            let labelIntervalInt = Int(TimelineItemView.thumbnailDurationInSeconds)
            if currentTimeInt % labelIntervalInt == 0 {
                drawTimeLabel(at: CGPoint(x: x, y: 5), time: currentTime, context: context)
            }
            
            currentTime += interval
        }
        
        // Also ensure we draw labels at 2-second intervals even if they don't align with major ticks
        var labelTime: Double = 0
        while labelTime <= totalSeconds {
            if Int(labelTime) % 2 == 0 {
                let x = CGFloat(labelTime) * pixelsPerSecond
                let currentTimeInt = Int(labelTime)
                
                // Only draw if we haven't already drawn a label at this position
                let alreadyDrawn = Int(labelTime / interval) * Int(interval) == Int(labelTime)
                if !alreadyDrawn {
                    drawTimeLabel(at: CGPoint(x: x, y: 5), time: labelTime, context: context)
                }
            }
            labelTime += Double(TimelineItemView.thumbnailDurationInSeconds) // Always increment by thumbnailDurationInSeconds for labels
        }
    }
    
    func drawMinorTicks(context: CGContext, interval: Double, totalSeconds: Double, pixelsPerSecond: CGFloat, rect: CGRect) {
        let theme = TimelineTheme.current
        context.setStrokeColor(theme.secondaryTextColor.cgColor)
        context.setLineWidth(0.5)
        
        var currentTime: Double = 0
        while currentTime <= totalSeconds {
            let x = CGFloat(currentTime) * pixelsPerSecond
            
            // Draw smaller tick line
            context.move(to: CGPoint(x: x, y: rect.height - 5))
            context.addLine(to: CGPoint(x: x, y: rect.height))
            context.strokePath()
            
            currentTime += interval
        }
    }
    
    func drawTimeLabel(at point: CGPoint, time: Double, context: CGContext) {
        let timeString = formatTime(time)
        let theme = TimelineTheme.current
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: theme.timeRulerTextColor
        ]
        
        let attributedString = NSAttributedString(string: timeString, attributes: attributes)
        let size = attributedString.size()
        
        let rect = CGRect(
            x: point.x - size.width / 2,
            y: point.y,
            width: size.width,
            height: size.height
        )
        
        attributedString.draw(in: rect)
    }
    
    func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        
        // Always format as MM:SS
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Factory Methods

extension TimeRulerView {
    
    func makeScrollView() -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isUserInteractionEnabled = false // Timeline handles scrolling
        return scrollView
    }
    
    func makeRulerContentView() -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
}

// MARK: - TimelineThemeAware

extension TimeRulerView: TimelineThemeAware {
    
    public func updateTheme() {
        let theme = TimelineTheme.current
        backgroundColor = theme.trackHeaderBackgroundColor
        
        // Trigger redraw with new colors
        rulerContentView.setNeedsDisplay()
    }
}
