//
//  VideoTimeline.swift
//
//
//  Created by Titouan Van Belle on 14.09.20.
//

import AVFoundation
import PureLayout
import UIKit

public class TrimmingControlView: UIControl {

    // MARK: Public Properties

    @Published var isTrimming: Bool = false

    @Published public var trimPositions: (Double, Double) {
        didSet {
            // Khi trimPositions được set từ bên ngoài, cập nhật internal values
            if !isTrimming { // Chỉ update khi không đang trim để tránh conflict
                updateInternalValues()
            }
        }
    }

    public override var bounds: CGRect {
        didSet {
            updateLeftHandleFrame()
            updateRightHandleFrame()
        }
    }

    public var isConfigured: Bool = false

    // MARK: Private Properties

    private var internalLeftTrimValue: CGFloat {
        didSet {
            updateLeftHandleFrame()
        }
    }

    public var internalRightTrimValue: CGFloat {
        didSet {
            updateRightHandleFrame()
        }
    }

    private var handleWidth: CGFloat = 20.0

    private var isLeftHandleHighlighted = false
    private var isRightHandleHighlighted = false

    private var leftHandleMinX: CGFloat {
        leftHandle.frame.minX
    }

    private var rightHandleMaxX: CGFloat {
        rightHandle.frame.maxX
    }

    private lazy var rightHandle: CALayer = makeRightHandle()
    private lazy var leftHandle: CALayer = makeLeftHandle()
    private lazy var rightDimmedBackground: CALayer = makeRightDimmedBackground()
    private lazy var leftDimmedBackground: CALayer = makeLeftDimmedBackground()
    private lazy var timeline: VideoTimelineView = makeVideoTimeline()

    // MARK: Init

    init(trimPositions: (Double, Double)) {
        self.trimPositions = trimPositions
        internalLeftTrimValue = CGFloat(trimPositions.0)
        internalRightTrimValue = CGFloat(trimPositions.1)
        
        super.init(frame: .zero)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let location = touch.location(in: self)
        if leftHandle.frame.contains(location) {
            isTrimming = true
            isLeftHandleHighlighted = true
        } else if rightHandle.frame.contains(location) {
            isTrimming = true
            isRightHandleHighlighted = true
        }

        return true
    }

    public override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let location = touch.location(in: self)

        if isLeftHandleHighlighted {
            internalLeftTrimValue = self.leftHandleValue(for: location.x)
        } else if isRightHandleHighlighted {
            internalRightTrimValue = self.rightHandleValue(for: location.x)
        }

        return true
    }

    public override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        isLeftHandleHighlighted = false
        isRightHandleHighlighted = false
        isTrimming = false

        trimPositions = (Double(internalLeftTrimValue), Double(internalRightTrimValue))
    }

    // MARK: Public Methods
    
    public func setTrimPositions(_ newPositions: (Double, Double), animated: Bool = false) {
        trimPositions = newPositions
        updateInternalValues()
        
        if animated {
            updateHandleFramesAnimated()
        } else {
            updateLeftHandleFrame()
            updateRightHandleFrame()
        }
    }
}

// MARK: Control Helpers

fileprivate extension TrimmingControlView {
    func leftHandleValue(for x: CGFloat) -> CGFloat {
        min(1.0, max(0.0, x / bounds.width))
    }

    func rightHandleValue(for x: CGFloat) -> CGFloat {
        min(1.0, max(0.0, x / bounds.width))
    }

    func boundedSeekerValue(seekerPosition: CGFloat) -> CGFloat {
        if (rightHandleMaxX - leftHandleMinX) == .zero {
            return .zero
        }

        return (seekerPosition - leftHandleMinX) / (rightHandleMaxX - leftHandleMinX)
    }
}

// MARK: UI

extension TrimmingControlView {
    func configure(with frames: [CGImage], assetAspectRatio: CGFloat) {
        timeline.configure(with: frames, assetAspectRatio: assetAspectRatio)
        isConfigured = true
    }
}

// MARK: UI

fileprivate extension TrimmingControlView {
    func setupUI() {
        setupView()
        setupConstraints()
    }

    func setupView() {
        addSubview(timeline)

        layer.addSublayer(leftDimmedBackground)
        layer.addSublayer(rightDimmedBackground)
        layer.addSublayer(leftHandle)
        layer.addSublayer(rightHandle)
    }

    func setupConstraints() {
        timeline.autoPinEdgesToSuperviewEdges()
    }

    func updateLeftHandleFrame() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        leftHandle.frame = CGRect(
            x: bounds.width * internalLeftTrimValue,
            y: 0,
            width: handleWidth,
            height: bounds.height
        )

        leftDimmedBackground.frame = CGRect(
            x: 0,
            y: 0,
            width: leftHandle.frame.maxX,
            height: bounds.height
        )

        CATransaction.commit()
    }

    func updateRightHandleFrame() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        rightHandle.frame = CGRect(
            x: bounds.width * internalRightTrimValue - handleWidth,
            y: 0,
            width: handleWidth,
            height: bounds.height
        )

        rightDimmedBackground.frame = CGRect(
            x: rightHandle.frame.minX,
            y: 0,
            width: bounds.width - rightHandle.frame.minX,
            height: bounds.height
        )

        CATransaction.commit()
    }

    func makeVideoTimeline() -> VideoTimelineView {
        let view = VideoTimelineView()
        view.isUserInteractionEnabled = false
        return view
    }

    func makeRightHandle() -> CALayer {
        HandleLayer(side: .right)
    }

    func makeLeftHandle() -> CALayer {
        HandleLayer(side: .left)
    }

    func makeRightDimmedBackground() -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = UIColor.black.withAlphaComponent(0.5).cgColor
        return layer
    }

    func makeLeftDimmedBackground() -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = UIColor.black.withAlphaComponent(0.5).cgColor
        return layer
    }
}

// MARK: Private Methods

fileprivate extension TrimmingControlView {
    func updateInternalValues() {
        internalLeftTrimValue = CGFloat(trimPositions.0)
        internalRightTrimValue = CGFloat(trimPositions.1)
    }
    
    func updateHandleFramesAnimated() {
        UIView.animate(withDuration: 0.3, animations: {
            self.updateLeftHandleFrame()
            self.updateRightHandleFrame()
        })
    }
}
