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
    
    func setContentOffset(_ offset: CGPoint) {
        scrollView.setContentOffset(offset, animated: false)
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
        let contentWidth = CGFloat(duration.seconds) * configuration.pixelsPerSecond
        scrollView.contentSize = CGSize(width: contentWidth, height: bounds.height)
        rulerContentView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: bounds.height)
    }
    
    func drawTimeMarkers(in rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
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
        if timePerView < 10 {
            return (major: 1.0, minor: 0.2) // 1s major, 200ms minor
        } else if timePerView < 60 {
            return (major: 5.0, minor: 1.0) // 5s major, 1s minor
        } else if timePerView < 300 {
            return (major: 30.0, minor: 5.0) // 30s major, 5s minor
        } else {
            return (major: 60.0, minor: 10.0) // 1min major, 10s minor
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
            
            // Draw time label
            drawTimeLabel(at: CGPoint(x: x, y: 5), time: currentTime, context: context)
            
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
        let milliseconds = Int((seconds - Double(totalSeconds)) * 100)
        
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        } else {
            return String(format: "%02d.%02d", remainingSeconds, milliseconds)
        }
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
