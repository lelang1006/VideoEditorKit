//
//  SpeedVideoControlViewController.swift
//
//
//  Created by Titouan Van Belle on 14.09.20.
//

import Combine
import PureLayout
import UIKit

final class SpeedVideoControlViewController: BaseVideoControlViewController {

    // MARK: Public Properties

    @Published var speed: Double

    @Published var isUpdating: Bool = false

    private var initialSpeed: Double

    override var tabBarItem: UITabBarItem! {
        get {
            UITabBarItem(
                title: "Speed",
                image: UIImage(named: "Speed", in: .module, compatibleWith: nil),
                selectedImage: UIImage(named: "Speed-Selected", in: .module, compatibleWith: nil)
            )
        }
        set {}
    }

    // MARK: Private Properties

    private lazy var slider: Slider = makeSlider()

    // MARK: Init

    init(speed: Double) {
        self.speed = speed
        self.initialSpeed = speed
        debugPrint("SpeedVideoControlViewController init with speed: \(speed)")

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: BaseVideoControlViewController Override
    override func setupContentView() {
        super.setupContentView()
        
        debugPrint("setupContentView - current speed: \(speed)")
        // Add slider to content view
        contentView.addSubview(slider)
        
        // Setup constraints
        let inset: CGFloat = 28.0
        slider.autoPinEdge(toSuperviewEdge: .left, withInset: inset)
        slider.autoPinEdge(toSuperviewEdge: .right, withInset: inset)
        slider.autoSetDimension(.height, toSize: 48.0)
        slider.autoAlignAxis(toSuperviewAxis: .horizontal)
                
        // Setup bindings
        setupBindings()
    }
    
    override func onApplyAction() {
        debugPrint("onApplyAction - saving speed: \(speed) as initialSpeed")
        // Keep current value as initial for next time
        initialSpeed = speed
        super.onApplyAction()
    }
            
    override func resetToInitialValues() {
        speed = initialSpeed
    }
    
    // MARK: Bindings

    fileprivate func setupBindings() {
        // Đảm bảo slider đã được set đúng giá trị trước khi setup bindings
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            debugPrint("setupBindings: slider.value = \(self.slider.value), speed = \(self.speed)")
            
            self.slider.$value
                .dropFirst() // Bỏ qua giá trị đầu tiên để tránh override
                .assign(to: \.speed, weakly: self)
                .store(in: &self.cancellables)
        }
    }

    func makeSlider() -> Slider {
        let slider = Slider()
        slider.range = .stepped(values: [0.25, 0.5, 0.75, 1.0, 2.0, 5.0, 10.0])
        slider.value = speed
        slider.isContinuous = false

        return slider
    }
}
