//
//  TrimVideoControlViewController.swift
//
//
//  Created by Titouan Van Belle on 14.09.20.
//

import AVFoundation
import Combine
import PureLayout
import UIKit

final class TrimVideoControlViewController: BaseVideoControlViewController {

    // MARK: Public Properties
    @Published var trimPositions: (Double, Double)
    private let initialTrimPositions: (Double, Double)

    override var tabBarItem: UITabBarItem! {
        get {
            UITabBarItem(
                title: "Trim",
                image: UIImage(named: "Trim", in: .module, compatibleWith: nil),
                selectedImage: UIImage(named: "Trim-Selected", in: .module, compatibleWith: nil)
            )
        }
        set {}
    }

    // MARK: Private Properties
    private lazy var trimmingControlView: TrimmingControlView = makeTrimmingControlView()
    private let asset: AVAsset
    private let generator: VideoTimelineGeneratorProtocol

    // MARK: Init
    init(asset: AVAsset, trimPositions: (Double, Double), generator: VideoTimelineGeneratorProtocol = VideoTimelineGenerator()) {
        self.asset = asset
        self.trimPositions = trimPositions
        self.initialTrimPositions = trimPositions
        self.generator = generator
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: BaseVideoControlViewController Override
    override func setupContentView() {
        super.setupContentView()
        
        // Add trimming control view to content view
        contentView.addSubview(trimmingControlView)
        
        // Setup constraints
        trimmingControlView.autoSetDimension(.height, toSize: 60.0)
        trimmingControlView.autoPinEdge(toSuperviewEdge: .left, withInset: 28.0)
        trimmingControlView.autoPinEdge(toSuperviewEdge: .right, withInset: 28.0)
        trimmingControlView.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        // Setup bindings
        setupBindings()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard let track = asset.tracks(withMediaType: AVMediaType.video).first else {
            print("Warning: No video track found")
            return
        }
        
        let assetSize = track.naturalSize.applying(track.preferredTransform)
        let ratio = abs(assetSize.width) / abs(assetSize.height)
        
        // Validate ratio to prevent division by zero or invalid values
        guard ratio.isFinite && ratio > 0 else {
            print("Warning: Invalid aspect ratio: \(ratio)")
            return
        }

        let bounds = trimmingControlView.bounds
        guard bounds.width > 0 && bounds.height > 0 else {
            print("Warning: Invalid bounds: \(bounds)")
            return
        }
        
        let frameWidth = bounds.height * ratio
        
        // Validate frameWidth to prevent division by zero
        guard frameWidth > 0 && frameWidth.isFinite else {
            print("Warning: Invalid frameWidth: \(frameWidth)")
            return
        }
        
        let frameCount = bounds.width / frameWidth
        
        // Validate frameCount before converting to Int
        guard frameCount.isFinite && frameCount >= 0 else {
            print("Warning: Invalid frameCount: \(frameCount)")
            return
        }
        
        let count = max(1, Int(frameCount) + 1) // Ensure at least 1 frame

        generator.videoTimeline(for: asset, in: trimmingControlView.bounds, numberOfFrames: count)
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] images in
                guard let self = self else { return }
                self.updateVideoTimeline(with: images, assetAspectRatio: ratio)
            }
            .store(in: &cancellables)
    }
            
    override func resetToInitialValues() {
        trimPositions = initialTrimPositions
    }
    
    // MARK: Public Methods
    func updateNewTrimPositions(_ trimPositions: (Double, Double)) {
        self.trimPositions = trimPositions
        trimmingControlView.setTrimPositions(trimPositions, animated: true)
    }
}

// MARK: Bindings

fileprivate extension TrimVideoControlViewController {
    func setupBindings() {
        trimmingControlView.$trimPositions
            .dropFirst(1)
            .assign(to: \.trimPositions, weakly: self)
            .store(in: &cancellables)
    }

    func updateVideoTimeline(with images: [CGImage], assetAspectRatio: CGFloat) {
        guard !trimmingControlView.isConfigured else { return }
        guard !images.isEmpty else { return }

        trimmingControlView.configure(with: images, assetAspectRatio: assetAspectRatio)
    }
}

// MARK: UI

fileprivate extension TrimVideoControlViewController {
    func makeTrimmingControlView() -> TrimmingControlView {
        TrimmingControlView(trimPositions: trimPositions)
    }
}
