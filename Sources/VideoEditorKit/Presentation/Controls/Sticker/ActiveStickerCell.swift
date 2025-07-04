//
//  ActiveStickerCell.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 03.07.25.
//

import UIKit

class ActiveStickerCell: UITableViewCell {
    
    static let reuseIdentifier = "ActiveStickerCell"
    
    // MARK: - UI Components
    
    private lazy var iconImageView: UIImageView = makeIconImageView()
    private lazy var titleLabel: UILabel = makeTitleLabel()
    private lazy var durationLabel: UILabel = makeDurationLabel()
    private lazy var removeButton: UIButton = makeRemoveButton()
    
    // MARK: - Properties
    
    private var onRemoveSticker: (() -> Void)?
    
    // MARK: - Init
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(durationLabel)
        contentView.addSubview(removeButton)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        iconImageView.autoPinEdge(toSuperviewEdge: .left, withInset: 16)
        iconImageView.autoAlignAxis(toSuperviewAxis: .horizontal)
        iconImageView.autoSetDimensions(to: CGSize(width: 32, height: 32))
        
        titleLabel.autoPinEdge(.left, to: .right, of: iconImageView, withOffset: 12)
        titleLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 12)
        titleLabel.autoPinEdge(.right, to: .left, of: removeButton, withOffset: -12)
        
        durationLabel.autoPinEdge(.left, to: .right, of: iconImageView, withOffset: 12)
        durationLabel.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 2)
        durationLabel.autoPinEdge(.right, to: .left, of: removeButton, withOffset: -12)
        
        removeButton.autoPinEdge(toSuperviewEdge: .right, withInset: 16)
        removeButton.autoAlignAxis(toSuperviewAxis: .horizontal)
        removeButton.autoSetDimensions(to: CGSize(width: 70, height: 32))
    }
    
    // MARK: - Factory Methods
    
    private func makeIconImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemPurple
        return imageView
    }
    
    private func makeTitleLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 1
        return label
    }
    
    private func makeDurationLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        return label
    }
    
    private func makeRemoveButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Remove", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.backgroundColor = .systemRed
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(removeButtonTapped), for: .touchUpInside)
        return button
    }
    
    // MARK: - Actions
    
    @objc private func removeButtonTapped() {
        onRemoveSticker?()
    }
    
    // MARK: - Configuration
    
    func configure(with sticker: StickerTimelineItem, onRemove: @escaping () -> Void) {
        self.onRemoveSticker = onRemove
        
        // Use the sticker's actual image for icon
        iconImageView.image = sticker.image
        
        // Generate title from sticker ID or use default
        titleLabel.text = "Sticker \(sticker.id.prefix(8))" // Use first 8 chars of ID
        
        // Calculate duration from CMTime
        let durationInSeconds = sticker.duration.seconds
        durationLabel.text = String(format: "%.1fs", durationInSeconds)
    }
}
