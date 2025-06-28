//
//  FilterVideoControlViewController.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 27.06.25.
//

import UIKit
import Combine

final class FilterVideoControlViewController: BaseVideoControlViewController {

    // MARK: Inner Types
    enum Section: Hashable {
        case category(FilterCategory)
    }

    typealias Datasource = UICollectionViewDiffableDataSource<Section, FilterCellViewModel>

    // MARK: Public Properties

    @Published var selectedFilter: VideoFilter?
    private var initialFilter: VideoFilter?

    override var tabBarItem: UITabBarItem! {
        get {
            UITabBarItem(
                title: "Filters",
                image: UIImage(named: "Filter", in: .module, compatibleWith: nil),
                selectedImage: UIImage(named: "Filter-Selected", in: .module, compatibleWith: nil)
            )
        }
        set {}
    }

    // MARK: Private Properties

    private lazy var segmentedControl: UISegmentedControl = makeSegmentedControl()
    private lazy var collectionView: UICollectionView = makeCollectionView()
    private var datasource: Datasource!
    private var originalThumbnail: UIImage?
    
    private var currentCategory: FilterCategory = .photoEffects {
        didSet {
            loadFilters()
        }
    }

    // MARK: Init

    public init(selectedFilter: VideoFilter? = nil, originalThumbnail: UIImage? = nil) {
        self.selectedFilter = selectedFilter
        self.initialFilter = selectedFilter
        self.originalThumbnail = originalThumbnail
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: BaseVideoControlViewController Override

    override func setupContentView() {
        super.setupContentView()
        
        debugPrint("setupContentView - current filter: \(selectedFilter?.name ?? "none")")
        
        setupSegmentedControl()
        setupCollectionView()
        loadFilters()
        setupBindings()
    }

    override func resetToInitialValues() {
        selectedFilter = initialFilter
    }

    override func onApplyAction() {
        debugPrint("onApplyAction - saving filter: \(selectedFilter?.name ?? "none") as initialFilter")
        initialFilter = selectedFilter
    }
}

// MARK: Data

fileprivate extension FilterVideoControlViewController {
    func loadFilters() {
        let filters = currentCategory.filters
        let viewModels = filters.map { filter in
            FilterCellViewModel(
                filter: filter,
                isSelected: selectedFilter == filter
            )
        }
        
        var snapshot = NSDiffableDataSourceSnapshot<Section, FilterCellViewModel>()
        let section = Section.category(currentCategory)
        snapshot.appendSections([section])
        snapshot.appendItems(viewModels, toSection: section)
        datasource.apply(snapshot, animatingDifferences: true)
    }
}

// MARK: Bindings

fileprivate extension FilterVideoControlViewController {
    func setupBindings() {
        // Bind selectedFilter changes để reload data với selection state mới
        $selectedFilter
            .dropFirst(1)
            .sink { [weak self] _ in
                self?.loadFilters()
            }
            .store(in: &cancellables)
    }
}

// MARK: Actions

fileprivate extension FilterVideoControlViewController {
    @objc func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        let categories = FilterCategory.allCases.filter { $0 != .none }
        currentCategory = categories[sender.selectedSegmentIndex]
    }
}

// MARK: Collection View

extension FilterVideoControlViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 64, height: 84)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let viewModel = datasource.itemIdentifier(for: indexPath) else { return }

        // Toggle logic với data-driven approach
        if viewModel.filter == selectedFilter {
            selectedFilter = nil
        } else {
            selectedFilter = viewModel.filter
        }

        collectionView.deselectItem(at: indexPath, animated: false)
    }
}

// MARK: UI

fileprivate extension FilterVideoControlViewController {
    func setupSegmentedControl() {
        let categories = FilterCategory.allCases.filter { $0 != .none }
        let titles = categories.map { $0.name }
        
        segmentedControl.removeAllSegments()
        for (index, title) in titles.enumerated() {
            segmentedControl.insertSegment(withTitle: title, at: index, animated: false)
        }
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentedControlValueChanged(_:)), for: .valueChanged)
        
        contentView.addSubview(segmentedControl)
        segmentedControl.autoPinEdge(toSuperviewEdge: .top, withInset: 8)
        segmentedControl.autoPinEdge(toSuperviewEdge: .left, withInset: 16)
        segmentedControl.autoPinEdge(toSuperviewEdge: .right, withInset: 16)
        segmentedControl.autoSetDimension(.height, toSize: 32.0)
    }
    
    func setupCollectionView() {
        let identifier = "FilterCell"
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        collectionView.delegate = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(FilterCell.self, forCellWithReuseIdentifier: identifier)
        
        datasource = Datasource(collectionView: collectionView) { [weak self] collectionView, indexPath, filterViewModel in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: identifier,
                for: indexPath
            ) as! FilterCell

            cell.configure(with: filterViewModel, originalThumbnail: self?.originalThumbnail)
            cell.setNeedsLayout()
            cell.layoutIfNeeded()

            return cell
        }

        // Setup constraints
        contentView.addSubview(collectionView)
        let inset: CGFloat = 0.0
        collectionView.autoPinEdge(.top, to: .bottom, of: segmentedControl, withOffset: 24)
        collectionView.autoPinEdge(toSuperviewEdge: .left, withInset: inset)
        collectionView.autoPinEdge(toSuperviewEdge: .right, withInset: inset)
        collectionView.autoPinEdge(toSuperviewEdge: .bottom, withInset: inset)
    }

    func makeSegmentedControl() -> UISegmentedControl {
        let control = UISegmentedControl()
        control.backgroundColor = .systemBackground
        control.selectedSegmentTintColor = .systemBlue
        control.setTitleTextAttributes([.foregroundColor: UIColor.label], for: .normal)
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        return control
    }

    func makeCollectionView() -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 12.0
        layout.minimumLineSpacing = 12.0

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        return collectionView
    }
}
