//
//  CroppingPresetView.swift
//  
//
//  Created by Titouan Van Belle on 09.10.20.
//

import UIKit
import UIKit

final class CroppingPresetCell: UICollectionViewCell {

    // MARK: Public Properties

    var isChoosed: Bool = false {
        didSet {
            updateUI()
        }
    }

    // MARK: Private Properties

    private lazy var stack: UIStackView = makeStackView()
    private lazy var title: UILabel = makeTitle()
    private lazy var imageView: UIImageView = makeImageView()

    private var viewModel: CroppingPresetCellViewModel!

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Bindings

extension CroppingPresetCell {
    func configure(with viewModel: CroppingPresetCellViewModel) {
        self.viewModel = viewModel
        title.text = viewModel.name
        imageView.image = UIImage(named: viewModel.imageName, in: .module, compatibleWith: nil)
        // Set isChoosed từ viewModel
        isChoosed = viewModel.isSelected
    }
}

// MARK: UI

fileprivate extension CroppingPresetCell {
    func setupUI() {
        setupView()
        setupConstraints()
    }

    func setupView() {
        addSubview(stack)
    }

    func setupConstraints() {
        imageView.autoSetDimension(.height, toSize: 48.0)
        imageView.autoSetDimension(.width, toSize: 48.0)

        stack.autoCenterInSuperview()
    }

    func updateUI() {
        title.font = isChoosed ? .systemFont(ofSize: 12.0, weight: .medium) : .systemFont(ofSize: 12.0)
        imageView.tintColor = isChoosed ? .croppingPresetSelected : .croppingPreset
    }

    func makeTitle() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12.0)
        label.textColor = UIColor.foreground
        return label
    }

    func makeImageView() -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.tintColor = .croppingPreset
        return view
    }

    func makeStackView() -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [
            imageView,
            title
        ])

        stack.spacing = 10.0
        stack.axis = .vertical
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        return stack
    }
}
