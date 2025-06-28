//
//  MediaAudioCell.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 28.06.25.
//

import UIKit
import AVFoundation

final class MediaAudioCell: UITableViewCell {
    
    // MARK: - UI Components
    
    private lazy var thumbnailView: UIImageView = makeThumbnailView()
    private lazy var titleLabel: UILabel = makeTitleLabel()
    private lazy var artistLabel: UILabel = makeArtistLabel()
    private lazy var durationLabel: UILabel = makeDurationLabel()
    private lazy var categoryLabel: UILabel = makeCategoryLabel()
    private lazy var selectionIndicator: UIImageView = makeSelectionIndicator()
    
    // MARK: - Init
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    
    func configure(with mediaAudio: MediaAudio, isSelected: Bool) {
        titleLabel.text = mediaAudio.title
        artistLabel.text = mediaAudio.artist
        durationLabel.text = formatDuration(mediaAudio.duration)
        categoryLabel.text = mediaAudio.category.displayName
        
        if let imageName = mediaAudio.previewImageName {
            thumbnailView.image = UIImage(named: imageName, in: .module, compatibleWith: nil)
        } else {
            thumbnailView.image = UIImage(systemName: "music.note")
        }
        
        selectionIndicator.isHidden = !isSelected
        backgroundColor = isSelected ? .systemBlue.withAlphaComponent(0.1) : .clear
    }
}

// MARK: - UI Setup

fileprivate extension MediaAudioCell {
    
    func setupUI() {
        selectionStyle = .none
        
        contentView.addSubview(thumbnailView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(artistLabel)
        contentView.addSubview(durationLabel)
        contentView.addSubview(categoryLabel)
        contentView.addSubview(selectionIndicator)
        
        setupConstraints()
    }
    
    func setupConstraints() {
        // Thumbnail
        thumbnailView.autoPinEdge(toSuperviewEdge: .left, withInset: 16)
        thumbnailView.autoAlignAxis(toSuperviewAxis: .horizontal)
        thumbnailView.autoSetDimensions(to: CGSize(width: 50, height: 50))
        
        // Title
        titleLabel.autoPinEdge(.left, to: .right, of: thumbnailView, withOffset: 12)
        titleLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 8)
        titleLabel.autoPinEdge(.right, to: .left, of: selectionIndicator, withOffset: -8)
        
        // Artist
        artistLabel.autoPinEdge(.left, to: .left, of: titleLabel)
        artistLabel.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 2)
        artistLabel.autoPinEdge(.right, to: .right, of: titleLabel)
        
        // Duration & Category on same line
        durationLabel.autoPinEdge(.left, to: .left, of: titleLabel)
        durationLabel.autoPinEdge(.top, to: .bottom, of: artistLabel, withOffset: 4)
        durationLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 8)
        
        categoryLabel.autoPinEdge(.left, to: .right, of: durationLabel, withOffset: 12)
        categoryLabel.autoAlignAxis(.horizontal, toSameAxisOf: durationLabel)
        
        // Selection indicator
        selectionIndicator.autoPinEdge(toSuperviewEdge: .right, withInset: 16)
        selectionIndicator.autoAlignAxis(toSuperviewAxis: .horizontal)
        selectionIndicator.autoSetDimensions(to: CGSize(width: 24, height: 24))
    }
    
    func makeThumbnailView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .systemGray5
        return imageView
    }
    
    func makeTitleLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        return label
    }
    
    func makeArtistLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        return label
    }
    
    func makeDurationLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        return label
    }
    
    func makeCategoryLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemBlue
        return label
    }
    
    func makeSelectionIndicator() -> UIImageView {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark.circle.fill")
        imageView.tintColor = .systemBlue
        return imageView
    }
    
    func formatDuration(_ duration: CMTime) -> String {
        let seconds = CMTimeGetSeconds(duration)
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
