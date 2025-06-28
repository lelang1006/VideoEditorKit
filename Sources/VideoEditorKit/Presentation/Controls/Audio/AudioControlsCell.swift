//
//  AudioControlsCell.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 28.06.25.
//

import UIKit

final class AudioControlsCell: UITableViewCell {
    
    // MARK: - Properties
    
    var onVolumeChanged: ((Float) -> Void)?
    var onMuteToggled: ((Bool) -> Void)?
    
    // MARK: - UI Components
    
    private lazy var volumeLabel: UILabel = makeVolumeLabel()
    private lazy var volumeSlider: UISlider = makeVolumeSlider()
    private lazy var muteToggle: UISwitch = makeMuteToggle()
    private lazy var muteLabel: UILabel = makeMuteLabel()
    
    // MARK: - Init
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    
    func configure(volume: Float, isMuted: Bool) {
        volumeSlider.value = volume
        muteToggle.isOn = isMuted
        updateVolumeLabel(volume)
        
        // Disable slider when muted
        volumeSlider.isEnabled = !isMuted
        volumeSlider.alpha = isMuted ? 0.5 : 1.0
    }
}

// MARK: - UI Setup

fileprivate extension AudioControlsCell {
    
    func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(volumeLabel)
        contentView.addSubview(volumeSlider)
        contentView.addSubview(muteLabel)
        contentView.addSubview(muteToggle)
        
        setupConstraints()
    }
    
    func setupConstraints() {
        // Volume label
        volumeLabel.autoPinEdge(toSuperviewEdge: .left, withInset: 16)
        volumeLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 12)
        
        // Volume slider
        volumeSlider.autoPinEdge(.left, to: .right, of: volumeLabel, withOffset: 12)
        volumeSlider.autoAlignAxis(.horizontal, toSameAxisOf: volumeLabel)
        volumeSlider.autoPinEdge(toSuperviewEdge: .right, withInset: 16)
        
        // Mute label
        muteLabel.autoPinEdge(.left, to: .left, of: volumeLabel)
        muteLabel.autoPinEdge(.top, to: .bottom, of: volumeLabel, withOffset: 12)
        muteLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 12)
        
        // Mute toggle
        muteToggle.autoPinEdge(toSuperviewEdge: .right, withInset: 16)
        muteToggle.autoAlignAxis(.horizontal, toSameAxisOf: muteLabel)
    }
    
    func makeVolumeLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        label.text = "Volume: 100%"
        return label
    }
    
    func makeVolumeSlider() -> UISlider {
        let slider = UISlider()
        slider.minimumValue = 0.0
        slider.maximumValue = 2.0  // 200% volume
        slider.value = 1.0
        slider.addTarget(self, action: #selector(volumeChanged(_:)), for: .valueChanged)
        return slider
    }
    
    func makeMuteLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        label.text = "Mute"
        return label
    }
    
    func makeMuteToggle() -> UISwitch {
        let toggle = UISwitch()
        toggle.addTarget(self, action: #selector(muteToggled(_:)), for: .valueChanged)
        return toggle
    }
    
    @objc func volumeChanged(_ slider: UISlider) {
        updateVolumeLabel(slider.value)
        onVolumeChanged?(slider.value)
    }
    
    @objc func muteToggled(_ toggle: UISwitch) {
        onMuteToggled?(toggle.isOn)
        
        // Update slider state
        volumeSlider.isEnabled = !toggle.isOn
        volumeSlider.alpha = toggle.isOn ? 0.5 : 1.0
    }
    
    func updateVolumeLabel(_ volume: Float) {
        let percentage = Int(volume * 100)
        volumeLabel.text = "Volume: \(percentage)%"
    }
}
