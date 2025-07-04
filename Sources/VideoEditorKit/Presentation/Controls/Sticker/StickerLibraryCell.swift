//
//  StickerLibraryCell.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 03.07.25.
//

import UIKit

class StickerLibraryCell: UITableViewCell {
    
    static let reuseIdentifier = "StickerLibraryCell"
    
    // MARK: - UI Components
    
    private lazy var iconImageView: UIImageView = makeIconImageView()
    private lazy var titleLabel: UILabel = makeTitleLabel()
    private lazy var addButton: UIButton = makeAddButton()
    
    // MARK: - Properties
    
    private var onAddSticker: ((StickerData) -> Void)?
    private var stickerData: StickerData?
    
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
        contentView.addSubview(addButton)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        iconImageView.autoPinEdge(toSuperviewEdge: .left, withInset: 16)
        iconImageView.autoAlignAxis(toSuperviewAxis: .horizontal)
        iconImageView.autoSetDimensions(to: CGSize(width: 32, height: 32))
        
        titleLabel.autoPinEdge(.left, to: .right, of: iconImageView, withOffset: 12)
        titleLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        titleLabel.autoPinEdge(.right, to: .left, of: addButton, withOffset: -12)
        
        addButton.autoPinEdge(toSuperviewEdge: .right, withInset: 16)
        addButton.autoAlignAxis(toSuperviewAxis: .horizontal)
        addButton.autoSetDimensions(to: CGSize(width: 60, height: 32))
    }
    
    // MARK: - Factory Methods
    
    private func makeIconImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemBlue
        return imageView
    }
    
    private func makeTitleLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 1
        return label
    }
    
    private func makeAddButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Add", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        return button
    }
    
    // MARK: - Actions
    
    @objc private func addButtonTapped() {
        guard let stickerData = stickerData else { return }
        onAddSticker?(stickerData)
    }
    
    // MARK: - Configuration
    
    func configure(with sticker: StickerData, onAdd: @escaping (StickerData) -> Void) {
        self.stickerData = sticker
        self.onAddSticker = onAdd
        
        iconImageView.image = UIImage(systemName: sticker.systemIcon)
        titleLabel.text = sticker.name
    }
}
