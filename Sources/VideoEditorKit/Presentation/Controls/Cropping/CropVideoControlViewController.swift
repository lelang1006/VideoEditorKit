//
//  CropVideoControlViewController.swift
//
//
//  Created by Titouan Van Belle on 14.09.20.
//

import Combine
import UIKit

// Internal - chỉ factory sử dụng
final class CropVideoControlViewController: BaseVideoControlViewController {

    // MARK: Inner Types

    enum Section: Hashable {
        case main
    }

    typealias Datasource = UICollectionViewDiffableDataSource<Section, CroppingPresetCellViewModel>

    // MARK: Public Properties

    @Published var croppingPreset: CroppingPreset?
    private var initialCroppingPreset: CroppingPreset?

    override var tabBarItem: UITabBarItem! {
        get {
            UITabBarItem(
                title: "Crop",
                image: UIImage(named: "Crop", in: .module, compatibleWith: nil),
                selectedImage: UIImage(named: "Crop-Selected", in: .module, compatibleWith: nil)
            )
        }
        set {}
    }

    // MARK: Private Properties

    private lazy var collectionView: UICollectionView = makeCollectionView()

    private var datasource: Datasource!
    private let cropItems: [CroppingPreset] = CroppingPreset.allCases
    
    // MARK: Init

    init(croppingPreset: CroppingPreset? = nil) {
        self.croppingPreset = croppingPreset
        self.initialCroppingPreset = croppingPreset
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: BaseVideoControlViewController Override
    override func setupContentView() {
        super.setupContentView()
        
        // Add collection view to content view
        contentView.addSubview(collectionView)
        
        // Setup constraints
        collectionView.autoSetDimension(.height, toSize: 100.0)
        collectionView.autoPinEdge(toSuperviewEdge: .left)
        collectionView.autoPinEdge(toSuperviewEdge: .right)
        collectionView.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        // Setup collection view
        setupCollectionView()
        
        // Load initial data
        loadPresets(with: croppingPreset)
        
        // Setup bindings
        setupBindings()
    }
        
    override func resetToInitialValues() {
        croppingPreset = initialCroppingPreset
    }
}

// MARK: Data

fileprivate extension CropVideoControlViewController {
    func loadPresets(with selectedPreset: CroppingPreset? = nil) {
        let viewModels = cropItems.map { preset in
            CroppingPresetCellViewModel(
                croppingPreset: preset,
                isSelected: selectedPreset == preset
            )
        }
        var snapshot = NSDiffableDataSourceSnapshot<Section, CroppingPresetCellViewModel>()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModels, toSection: .main)
        datasource.apply(snapshot, animatingDifferences: true)
    }
}

// MARK: Bindings

fileprivate extension CropVideoControlViewController {
    func setupBindings() {
        // Bind croppingPreset changes để reload data với selection state mới
        $croppingPreset
            .dropFirst(1) // Bỏ qua giá trị initial để tránh reload không cần thiết
            .sink { [weak self] newValue in
                self?.loadPresets(with: newValue) // Truyền giá trị mới vào để đảm bảo UI update đúng
            }
            .store(in: &cancellables)
    }
}

// MARK: UI

fileprivate extension CropVideoControlViewController {
    func setupUI() {
        setupView()
        setupConstraints()
        setupCollectionView()
    }

    func setupView() {
        view.backgroundColor = .white

        view.addSubview(collectionView)
    }

    func setupConstraints() {
        collectionView.autoSetDimension(.height, toSize: 100.0)
        collectionView.autoPinEdge(toSuperviewEdge: .left)
        collectionView.autoPinEdge(toSuperviewEdge: .right)
        collectionView.autoAlignAxis(toSuperviewAxis: .horizontal)
    }

    func setupCollectionView() {
        let identifier = "CroppingPresetView"
        collectionView.delegate = self
        collectionView.register(CroppingPresetCell.self, forCellWithReuseIdentifier: identifier)
        datasource = Datasource(collectionView: collectionView) { collectionView, indexPath, preset in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: identifier,
                for: indexPath
            ) as! CroppingPresetCell

            cell.configure(with: preset)
            cell.setNeedsLayout()
            cell.layoutIfNeeded()

            return cell
        }
    }

    func makeCollectionView() -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2

        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        return view
    }
}


extension CropVideoControlViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        CGSize(width: 90, height: 100)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        guard let viewModel = datasource.itemIdentifier(for: indexPath) else {
            return
        }
        // Chỉ cần cập nhật croppingPreset, setupBindings() sẽ tự động reload UI
        if viewModel.croppingPreset == croppingPreset {
            croppingPreset = nil
        } else {
            croppingPreset = viewModel.croppingPreset
        }
    }
}
