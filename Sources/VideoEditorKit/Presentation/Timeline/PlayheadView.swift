//
//  PlayheadView.swift
//  
//
//  Created by VideoEditorKit on 29.06.25.
//

import UIKit
import AVFoundation
import PureLayout

class PlayheadView: UIView {
    
   // MARK: - Gesture Handling

extension PlayheadView { MARK: - Properties
    
    var currentTime: CMTime = .zero
    var isDragging: Bool = false
    
    // UI Components
    lazy var lineView: UIView = makeLineView()
    lazy var headView: UIView = makeHeadView()
    lazy var timeLabel: UILabel = makeTimeLabel()
    
    // Gesture
    var panGesture: UIPanGestureRecognizer!
    
    // Callbacks
    var onTimeChanged: ((CMTime) -> Void)?
    var onDragStateChanged: ((Bool) -> Void)?
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateTimeLabel()
    }
}

// MARK: - Public Methods

extension PlayheadView {
    
    func setCurrentTime(_ time: CMTime, animated: Bool = false) {
        currentTime = time
        updateTimeLabel()
        
        if animated {
            UIView.animate(withDuration: 0.1) {
                self.updateHeadPosition()
            }
        } else {
            updateHeadPosition()
        }
    }
    
    func setDragging(_ dragging: Bool) {
        isDragging = dragging
        updateAppearance()
    }
}

// MARK: - Methods

extension PlayheadView {
    
    func setupUI() {
        backgroundColor = .clear
        
        addSubview(lineView)
        addSubview(headView)
        addSubview(timeLabel)
        
        setupConstraints()
        updateAppearance()
    }
    
    func setupConstraints() {
        // Line view (vertical line)
        lineView.autoAlignAxis(toSuperviewAxis: .vertical)
        lineView.autoPinEdge(.top, to: .bottom, of: headView)
        lineView.autoPinEdge(toSuperviewEdge: .bottom)
        lineView.autoSetDimension(.width, toSize: 2)
        
        // Head view (triangle/diamond at top)
        headView.autoAlignAxis(toSuperviewAxis: .vertical)
        headView.autoPinEdge(toSuperviewEdge: .top)
        headView.autoSetDimensions(to: CGSize(width: 12, height: 12))
        
        // Time label (shows current time)
        timeLabel.autoAlignAxis(toSuperviewAxis: .vertical)
        timeLabel.autoPinEdge(.bottom, to: .top, of: headView, withOffset: -4)
        timeLabel.autoSetDimension(.height, toSize: 20)
    }
    
    func setupGestures() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        headView.addGestureRecognizer(panGesture)
        headView.isUserInteractionEnabled = true
        
        // Add tap gesture for quick positioning
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true
    }
    
    func updateAppearance() {
        let theme = TimelineTheme.current
        
        if isDragging {
            // Highlight when dragging
            lineView.backgroundColor = theme.playheadColor
            headView.backgroundColor = theme.playheadColor
            timeLabel.backgroundColor = theme.playheadColor.withAlphaComponent(0.9)
            timeLabel.textColor = theme.backgroundColor
            
            // Make time label more prominent
            timeLabel.isHidden = false
            timeLabel.layer.cornerRadius = 4
            timeLabel.clipsToBounds = true
            
            // Add glow effect
            headView.layer.shadowColor = theme.playheadColor.cgColor
            headView.layer.shadowOpacity = 0.8
            headView.layer.shadowRadius = 4
            headView.layer.shadowOffset = .zero
        } else {
            // Normal state
            lineView.backgroundColor = theme.playheadColor
            headView.backgroundColor = theme.playheadColor
            timeLabel.backgroundColor = theme.backgroundColor.withAlphaComponent(0.8)
            timeLabel.textColor = theme.primaryTextColor
            
            // Hide time label in normal state (show only when dragging)
            timeLabel.isHidden = true
            
            // Remove glow effect
            headView.layer.shadowOpacity = 0
        }
    }
    
    func updateTimeLabel() {
        let timeString = formatTime(currentTime.seconds)
        timeLabel.text = timeString
    }
    
    func updateHeadPosition() {
        // This method can be used for additional positioning logic if needed
        // The actual positioning is handled by the parent timeline view
    }
    
    func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        let milliseconds = Int((seconds - Double(totalSeconds)) * 100)
        
        return String(format: "%d:%02d.%02d", minutes, remainingSeconds, milliseconds)
    }
}

// MARK: - Gesture Handlers

private extension PlayheadView {
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            isDragging = true
            updateAppearance()
            onDragStateChanged?(true)
            
        case .changed:
            let translation = gesture.translation(in: superview)
            
            // Calculate new time based on horizontal movement
            // This calculation should be done by the parent timeline view
            // Here we just provide the translation for the parent to handle
            handleDragTranslation(translation)
            
        case .ended, .cancelled:
            isDragging = false
            updateAppearance()
            onDragStateChanged?(false)
            
        default:
            break
        }
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: superview)
        // Convert tap location to time and notify parent
        if let superview = superview {
            let relativeX = location.x
            // Parent timeline should handle this conversion
            handleTapAtPosition(relativeX)
        }
    }
    
    func handleDragTranslation(_ translation: CGPoint) {
        // This should be implemented by the parent timeline view
        // We'll use a callback to notify the parent
        
        // For now, we'll move the view visually and let parent handle time calculation
        transform = CGAffineTransform(translationX: translation.x, y: 0)
    }
    
    func handleTapAtPosition(_ x: CGFloat) {
        // This should be implemented by the parent timeline view
        // Use callback to notify parent about tap position
    }
}

// MARK: - Factory Methods

extension PlayheadView {
    
    func makeLineView() -> UIView {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }
    
    func makeHeadView() -> UIView {
        let view = PlayheadIndicatorView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 6
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.black.cgColor
        return view
    }
    
    func makeTimeLabel() -> UILabel {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        label.textAlignment = .center
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.isHidden = true
        return label
    }
}

// MARK: - PlayheadIndicatorView

class PlayheadIndicatorView: UIView {
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Draw diamond shape for playhead indicator
        context.setFillColor(backgroundColor?.cgColor ?? UIColor.white.cgColor)
        
        let path = UIBezierPath()
        let centerX = rect.midX
        let centerY = rect.midY
        let radius = min(rect.width, rect.height) / 2
        
        // Create diamond shape
        path.move(to: CGPoint(x: centerX, y: centerY - radius))
        path.addLine(to: CGPoint(x: centerX + radius, y: centerY))
        path.addLine(to: CGPoint(x: centerX, y: centerY + radius))
        path.addLine(to: CGPoint(x: centerX - radius, y: centerY))
        path.close()
        
        context.addPath(path.cgPath)
        context.fillPath()
        
        // Draw border
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(1.0)
        context.addPath(path.cgPath)
        context.strokePath()
    }
}

// MARK: - TimelineThemeAware

extension PlayheadView: TimelineThemeAware {
    
    public func updateTheme() {
        updateAppearance()
    }
}
