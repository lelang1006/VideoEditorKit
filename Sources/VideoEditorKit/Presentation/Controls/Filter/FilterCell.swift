//
//  FilterCell.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 27.06.25.
//

import UIKit

final class FilterCell: UICollectionViewCell {

    // MARK: Public Properties

    var isChoosed: Bool = false {
        didSet {
            updateUI()
        }
    }

    // MARK: Private Properties

    private lazy var stack: UIStackView = makeStackView()
    private lazy var title: UILabel = makeTitle()
    private lazy var thumbnailView: UIImageView = makeThumbnailView()

    private var viewModel: FilterCellViewModel!

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Configuration

extension FilterCell {
    func configure(with viewModel: FilterCellViewModel) {
        self.viewModel = viewModel
        title.text = viewModel.name
        
        // Set thumbnail based on filter type
        if let thumbnailImage = UIImage(named: viewModel.thumbnailImageName, in: .module, compatibleWith: nil) {
            thumbnailView.image = thumbnailImage
        } else {
            // Fallback to colored background based on filter category
            thumbnailView.image = nil
            thumbnailView.backgroundColor = backgroundColorForCategory(viewModel.category)
        }
        
        isChoosed = viewModel.isSelected
    }
    
    private func backgroundColorForCategory(_ category: FilterCategory) -> UIColor {
        switch category {
        case .none:
            return .systemGray5
        case .photoEffects:
            return .systemBlue.withAlphaComponent(0.3)
        case .colorAdjustments:
            return .systemPurple.withAlphaComponent(0.3)
        case .blur:
            return .systemTeal.withAlphaComponent(0.3)
        case .lightEffects:
            return .systemYellow.withAlphaComponent(0.3)
        }
    }
}

// MARK: UI

fileprivate extension FilterCell {
    func setupUI() {
        contentView.addSubview(stack)
        stack.autoPinEdgesToSuperviewEdges()
    }

    func updateUI() {
        title.font = isChoosed ? .systemFont(ofSize: 11.0, weight: .medium) : .systemFont(ofSize: 11.0)
        title.textColor = isChoosed ? .label : .secondaryLabel
        
        thumbnailView.layer.borderWidth = isChoosed ? 2.0 : 0.0
        thumbnailView.layer.borderColor = isChoosed ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
        
        // Add subtle shadow when selected
        if isChoosed {
            thumbnailView.layer.shadowColor = UIColor.systemBlue.cgColor
            thumbnailView.layer.shadowOffset = CGSize(width: 0, height: 2)
            thumbnailView.layer.shadowRadius = 4
            thumbnailView.layer.shadowOpacity = 0.3
        } else {
            thumbnailView.layer.shadowOpacity = 0
        }
    }

    func makeStackView() -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [thumbnailView, title])
        stack.axis = .vertical
        stack.spacing = 6.0
        stack.alignment = .center
        return stack
    }

    func makeTitle() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11.0)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }

    func makeThumbnailView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8.0
        imageView.backgroundColor = .systemGray5
        imageView.autoSetDimensions(to: CGSize(width: 60, height: 60))
        return imageView
    }
}
