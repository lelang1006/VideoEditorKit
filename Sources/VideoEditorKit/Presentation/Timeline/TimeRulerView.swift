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
    lazy var rulerContentView: RulerContentView = makeRulerContentView()
    
    // MARK: - Init
    
    init(configuration: TimelineConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Don't override draw - let the rulerContentView handle drawing
}

// MARK: - Public Methods

extension TimeRulerView {
    
    func setDuration(_ duration: CMTime) {
        self.duration = duration
        updateContentSize()
        rulerContentView.setNeedsDisplay()
    }
    
    func setDuration(_ duration: CMTime, contentWidth: CGFloat) {
        self.duration = duration
        scrollView.contentSize = CGSize(width: contentWidth, height: 30)
        rulerContentView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: 30)
        rulerContentView.setNeedsDisplay()
    }
    
    func setContentOffset(_ offset: CGPoint) {
        print("📏 TimeRulerView setContentOffset: \(offset)")
        scrollView.setContentOffset(offset, animated: false)
        
        // Trigger redraw when scrolling to update visible labels
        DispatchQueue.main.async {
            self.rulerContentView.setNeedsDisplay()
        }
    }
    
    func setContentInset(_ inset: UIEdgeInsets) {
        print("📏 TimeRulerView setContentInset: \(inset)")
        scrollView.contentInset = inset
        
        // Debug centering info
        debugCenteringInfo()
        
        // Trigger redraw to update labels
        DispatchQueue.main.async {
            self.rulerContentView.setNeedsDisplay()
        }
    }
    
    func refreshDrawing() {
        rulerContentView.setNeedsDisplay()
    }
    
    func debugCenteringInfo() {
        let scrollOffset = scrollView.contentOffset.x
        let contentInset = scrollView.contentInset.left
        let effectiveOffset = scrollOffset + contentInset
        
        print("📏 DEBUG TimeRulerView Centering:")
        print("📏   - ScrollView contentOffset.x: \(scrollOffset)")
        print("📏   - ScrollView contentInset.left: \(contentInset)")
        print("📏   - Effective offset: \(effectiveOffset)")
        print("📏   - 00:00 marker should align with TimelineItemView start")
        print("📏   - Both should appear at ViewCenter (187.5)")
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
    }
    
    func updateContentSize() {
        let contentWidth = CGFloat(duration.seconds) * configuration.pixelsPerSecond
        scrollView.contentSize = CGSize(width: contentWidth, height: 30)
        rulerContentView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: 30)
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
        let viewWidth = scrollView.bounds.width
        let timePerView = Double(viewWidth) / Double(pixelsPerSecond)
        
        // Simplified intervals for better readability
        if timePerView < 10 {
            return (major: 2.0, minor: 0.5) // 2s major, 500ms minor
        } else if timePerView < 60 {
            return (major: 5.0, minor: 1.0) // 5s major, 1s minor
        } else if timePerView < 300 {
            return (major: 30.0, minor: 10.0) // 30s major, 10s minor
        } else {
            return (major: 60.0, minor: 30.0) // 1min major, 30s minor
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
            
            // Draw time labels at every 2-second interval
            if Int(currentTime) % 2 == 0 {
                drawTimeLabel(at: CGPoint(x: x, y: 5), time: currentTime, context: context)
            }
            
            currentTime += interval
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
        
        // Fix: Ensure label position doesn't go negative and has proper bounds
        let labelX = max(0, point.x - size.width / 2) // Prevent negative x position
        let labelY: CGFloat = point.y
        
        let rect = CGRect(
            x: labelX,
            y: labelY,
            width: size.width,
            height: size.height
        )
        
        // Only draw if label fits within the content view bounds
        let contentBounds = rulerContentView.bounds
        if rect.minX >= 0 && rect.maxX <= contentBounds.width {
            attributedString.draw(in: rect)
        }
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
    
    func makeRulerContentView() -> RulerContentView {
        let view = RulerContentView()
        view.backgroundColor = .clear
        view.timeRulerView = self
        return view
    }
}

// MARK: - RulerContentView

class RulerContentView: UIView {
    weak var timeRulerView: TimeRulerView?
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        timeRulerView?.drawTimeMarkers(in: rect)
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
