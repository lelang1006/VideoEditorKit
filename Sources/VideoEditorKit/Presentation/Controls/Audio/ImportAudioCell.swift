//
//  ImportAudioCell.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 28.06.25.
//

import UIKit

final class ImportAudioCell: UITableViewCell {
    
    // MARK: - UI Components
    
    private lazy var iconView: UIImageView = makeIconView()
    private lazy var titleLabel: UILabel = makeTitleLabel()
    private lazy var subtitleLabel: UILabel = makeSubtitleLabel()
    
    // MARK: - Init
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - UI Setup

fileprivate extension ImportAudioCell {
    
    func setupUI() {
        backgroundColor = .clear
        selectionStyle = .default
        
        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        
        setupConstraints()
        configureContent()
    }
    
    func setupConstraints() {
        iconView.autoPinEdge(toSuperviewEdge: .left, withInset: 16)
        iconView.autoAlignAxis(toSuperviewAxis: .horizontal)
        iconView.autoSetDimensions(to: CGSize(width: 30, height: 30))
        
        titleLabel.autoPinEdge(.left, to: .right, of: iconView, withOffset: 12)
        titleLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 8)
        titleLabel.autoPinEdge(toSuperviewEdge: .right, withInset: 16)
        
        subtitleLabel.autoPinEdge(.left, to: .left, of: titleLabel)
        subtitleLabel.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 2)
        subtitleLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 8)
        subtitleLabel.autoPinEdge(toSuperviewEdge: .right, withInset: 16)
    }
    
    func configureContent() {
        titleLabel.text = "Import from Device"
        subtitleLabel.text = "Choose MP3, M4A, or WAV files"
    }
    
    func makeIconView() -> UIImageView {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "plus.circle")
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        return imageView
    }
    
    func makeTitleLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .systemBlue
        return label
    }
    
    func makeSubtitleLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        return label
    }
}
