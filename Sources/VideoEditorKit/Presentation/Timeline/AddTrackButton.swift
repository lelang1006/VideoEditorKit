//
//  AddTrackButton.swift
//  
//
//  Created by VideoEditorKit on 29.06.25.
//

import UIKit
import PureLayout

protocol AddTrackButtonDelegate: AnyObject {
    func addTrackButtonTapped(_ button: AddTrackButton)
}

class AddTrackButton: UIView {
    
    // MARK: - Properties
    
    weak var delegate: AddTrackButtonDelegate?
    
    lazy var button: UIButton = makeButton()
    lazy var label: UILabel = makeLabel()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Methods

extension AddTrackButton {
    
    func setupUI() {
        backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
        layer.cornerRadius = 8
        layer.borderWidth = 2
        layer.borderColor = UIColor.systemBlue.cgColor
        layer.masksToBounds = true
        
        addSubview(button)
        addSubview(label)
        
        setupConstraints()
    }
    
    func setupConstraints() {
        button.autoAlignAxis(toSuperviewAxis: .vertical)
        button.autoPinEdge(toSuperviewEdge: .top, withInset: 12)
        button.autoSetDimensions(to: CGSize(width: 24, height: 24))
        
        label.autoPinEdge(.top, to: .bottom, of: button, withOffset: 4)
        label.autoAlignAxis(toSuperviewAxis: .vertical)
        label.autoPinEdge(toSuperviewEdge: .bottom, withInset: 8)
        label.autoPinEdge(toSuperviewEdge: .left, withInset: 8)
        label.autoPinEdge(toSuperviewEdge: .right, withInset: 8)
    }
    
    @objc func buttonTapped() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Animate button press
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = .identity
            }
        }
        
        delegate?.addTrackButtonTapped(self)
    }
}

// MARK: - Factory Methods

extension AddTrackButton {
    
    func makeButton() -> UIButton {
        let button = UIButton()
        button.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.backgroundColor = .white
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        return button
    }
    
    func makeLabel() -> UILabel {
        let label = UILabel()
        label.text = "Add Track"
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemBlue
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }
}
