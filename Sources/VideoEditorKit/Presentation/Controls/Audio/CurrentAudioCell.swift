//
//  CurrentAudioCell.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 28.06.25.
//

import UIKit
import AVFoundation

final class CurrentAudioCell: UITableViewCell {
    
    // MARK: - Properties
    
    var onTrimTapped: (() -> Void)?
    
    // MARK: - UI Components
    
    private lazy var titleLabel: UILabel = makeTitleLabel()
    private lazy var durationLabel: UILabel = makeDurationLabel()
    private lazy var trimButton: UIButton = makeTrimButton()
    
    // MARK: - Init
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    
    func configure(with audioReplacement: AudioReplacement?, isOriginalAudio: Bool) {
        if isOriginalAudio {
            titleLabel.text = "Original Video Audio"
            durationLabel.text = "Built-in"
            trimButton.isHidden = true
        } else if let audio = audioReplacement {
            titleLabel.text = audio.title
            durationLabel.text = formatDuration(audio.duration)
            trimButton.isHidden = false
        }
    }
}

// MARK: - UI Setup

fileprivate extension CurrentAudioCell {
    
    func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(durationLabel)
        contentView.addSubview(trimButton)
        
        setupConstraints()
    }
    
    func setupConstraints() {
        titleLabel.autoPinEdge(toSuperviewEdge: .left, withInset: 16)
        titleLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 8)
        titleLabel.autoPinEdge(.right, to: .left, of: trimButton, withOffset: -8)
        
        durationLabel.autoPinEdge(.left, to: .left, of: titleLabel)
        durationLabel.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 4)
        durationLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 8)
        
        trimButton.autoPinEdge(toSuperviewEdge: .right, withInset: 16)
        trimButton.autoAlignAxis(toSuperviewAxis: .horizontal)
        trimButton.autoSetDimensions(to: CGSize(width: 60, height: 30))
    }
    
    func makeTitleLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        return label
    }
    
    func makeDurationLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        return label
    }
    
    func makeTrimButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Trim", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 6
        button.addTarget(self, action: #selector(trimButtonTapped), for: .touchUpInside)
        return button
    }
    
    @objc func trimButtonTapped() {
        onTrimTapped?()
    }
    
    func formatDuration(_ duration: CMTime) -> String {
        let seconds = CMTimeGetSeconds(duration)
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
