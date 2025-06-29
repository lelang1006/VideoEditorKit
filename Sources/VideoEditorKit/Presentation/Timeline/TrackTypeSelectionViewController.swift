//
//  TrackTypeSelectionViewController.swift
//  
//
//  Created by VideoEditorKit on 29.06.25.
//

import UIKit
import PureLayout

protocol TrackTypeSelectionDelegate: AnyObject {
    func didSelectTrackType(_ type: TimelineTrackType)
}

class TrackTypeSelectionViewController: UIViewController {
    
    // MARK: - Properties
    
    weak var delegate: TrackTypeSelectionDelegate?
    
    private lazy var containerView: UIView = makeContainerView()
    private lazy var titleLabel: UILabel = makeTitleLabel()
    private lazy var trackOptionsStackView: UIStackView = makeTrackOptionsStackView()
    private lazy var cancelButton: UIButton = makeCancelButton()
    
    private let availableTrackTypes: [TimelineTrackType] = [
        .audio(.replacement),
        .audio(.voiceover),
        .text,
        .sticker
    ]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTrackOptions()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }
}

// MARK: - Private Methods

private extension TrackTypeSelectionViewController {
    
    func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(trackOptionsStackView)
        containerView.addSubview(cancelButton)
        
        setupConstraints()
    }
    
    func setupConstraints() {
        containerView.autoAlignAxis(toSuperviewAxis: .vertical)
        containerView.autoAlignAxis(toSuperviewAxis: .horizontal)
        containerView.autoPinEdge(toSuperviewEdge: .left, withInset: 40)
        containerView.autoPinEdge(toSuperviewEdge: .right, withInset: 40)
        
        titleLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 20)
        titleLabel.autoPinEdge(toSuperviewEdge: .left, withInset: 20)
        titleLabel.autoPinEdge(toSuperviewEdge: .right, withInset: 20)
        
        trackOptionsStackView.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 20)
        trackOptionsStackView.autoPinEdge(toSuperviewEdge: .left, withInset: 20)
        trackOptionsStackView.autoPinEdge(toSuperviewEdge: .right, withInset: 20)
        
        cancelButton.autoPinEdge(.top, to: .bottom, of: trackOptionsStackView, withOffset: 20)
        cancelButton.autoPinEdge(toSuperviewEdge: .left, withInset: 20)
        cancelButton.autoPinEdge(toSuperviewEdge: .right, withInset: 20)
        cancelButton.autoPinEdge(toSuperviewEdge: .bottom, withInset: 20)
        cancelButton.autoSetDimension(.height, toSize: 44)
    }
    
    func setupTrackOptions() {
        for trackType in availableTrackTypes {
            let optionView = TrackTypeOptionView(trackType: trackType)
            optionView.delegate = self
            trackOptionsStackView.addArrangedSubview(optionView)
            optionView.autoSetDimension(.height, toSize: 60)
        }
    }
    
    func animateIn() {
        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        containerView.alpha = 0
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.containerView.transform = .identity
            self.containerView.alpha = 1
        }
    }
    
    func animateOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.2, animations: {
            self.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            self.containerView.alpha = 0
            self.view.alpha = 0
        }) { _ in
            completion()
        }
    }
    
    @objc func cancelButtonTapped() {
        animateOut {
            self.dismiss(animated: false)
        }
    }
}

// MARK: - Factory Methods

private extension TrackTypeSelectionViewController {
    
    func makeContainerView() -> UIView {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }
    
    func makeTitleLabel() -> UILabel {
        let label = UILabel()
        label.text = "Add New Track"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .label
        return label
    }
    
    func makeTrackOptionsStackView() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .fill
        stackView.distribution = .fill
        return stackView
    }
    
    func makeCancelButton() -> UIButton {
        let button = UIButton()
        button.setTitle("Cancel", for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        return button
    }
}

// MARK: - TrackTypeOptionViewDelegate

extension TrackTypeSelectionViewController: TrackTypeOptionViewDelegate {
    
    func trackTypeOptionTapped(_ trackType: TimelineTrackType) {
        delegate?.didSelectTrackType(trackType)
        animateOut {
            self.dismiss(animated: false)
        }
    }
}

// MARK: - TrackTypeOptionView

protocol TrackTypeOptionViewDelegate: AnyObject {
    func trackTypeOptionTapped(_ trackType: TimelineTrackType)
}

private class TrackTypeOptionView: UIView {
    
    weak var delegate: TrackTypeOptionViewDelegate?
    
    private let trackType: TimelineTrackType
    private lazy var iconImageView: UIImageView = makeIconImageView()
    private lazy var titleLabel: UILabel = makeTitleLabel()
    private lazy var descriptionLabel: UILabel = makeDescriptionLabel()
    
    init(trackType: TimelineTrackType) {
        self.trackType = trackType
        super.init(frame: .zero)
        setupUI()
        updateContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.systemGray6
        layer.cornerRadius = 12
        
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        
        setupConstraints()
        setupGesture()
    }
    
    private func setupConstraints() {
        iconImageView.autoPinEdge(toSuperviewEdge: .left, withInset: 16)
        iconImageView.autoAlignAxis(toSuperviewAxis: .horizontal)
        iconImageView.autoSetDimensions(to: CGSize(width: 32, height: 32))
        
        titleLabel.autoPinEdge(.left, to: .right, of: iconImageView, withOffset: 12)
        titleLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 12)
        titleLabel.autoPinEdge(toSuperviewEdge: .right, withInset: 16)
        
        descriptionLabel.autoPinEdge(.left, to: .right, of: iconImageView, withOffset: 12)
        descriptionLabel.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 2)
        descriptionLabel.autoPinEdge(toSuperviewEdge: .right, withInset: 16)
        descriptionLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 12)
    }
    
    private func setupGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(optionTapped))
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true
    }
    
    private func updateContent() {
        switch trackType {
        case .audio(let subtype):
            switch subtype {
            case .replacement:
                iconImageView.image = UIImage(systemName: "music.note")
                titleLabel.text = "Audio Track"
                descriptionLabel.text = "Add background music or sound effects"
            case .voiceover:
                iconImageView.image = UIImage(systemName: "mic.fill")
                titleLabel.text = "Voiceover"
                descriptionLabel.text = "Record voice narration"
            case .original:
                break // Not shown in options
            }
        case .text:
            iconImageView.image = UIImage(systemName: "text.bubble.fill")
            titleLabel.text = "Text & Titles"
            descriptionLabel.text = "Add text overlays and titles"
        case .sticker:
            iconImageView.image = UIImage(systemName: "star.fill")
            titleLabel.text = "Stickers & Emojis"
            descriptionLabel.text = "Add fun stickers and emojis"
        case .video:
            break // Video track is always present
        }
        
        iconImageView.tintColor = .systemBlue
    }
    
    @objc private func optionTapped() {
        // Animate tap
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = .identity
            }
        }
        
        delegate?.trackTypeOptionTapped(trackType)
    }
    
    private func makeIconImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemBlue
        return imageView
    }
    
    private func makeTitleLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }
    
    private func makeDescriptionLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }
}
