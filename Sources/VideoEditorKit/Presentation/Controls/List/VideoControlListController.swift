//
//  VideoEditsListController.swift
//  
//
//  Created by Titouan Van Belle on 27.10.20.
//

import Combine
import UIKit

final class VideoControlListController: UIViewController {

    // MARK: Inner Types

    enum Section: Hashable {
        case main
    }

    typealias Datasource = UICollectionViewDiffableDataSource<Section, VideoControlCellViewModel>

    // MARK: Public Properties

    var didSelectVideoControl = PassthroughSubject<VideoControl, Never>()

    // MARK: Private Properties

    private lazy var collectionView: UICollectionView = makeCollectionView()

    private var datasource: Datasource!

    private let viewFactory: VideoEditorViewFactoryProtocol
    private let store: VideoEditorStore
    private var viewModels: [VideoControlCellViewModel] = []
    // MARK: Init

    init(store: VideoEditorStore, viewFactory: VideoEditorViewFactoryProtocol) {
        self.store = store
        self.viewFactory = viewFactory

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let allCases = VideoControl.allCases
        viewModels = allCases.map(VideoControlCellViewModel.init)

        setupUI()

        loadVideoControls()
    }
}

// MARK: Data

fileprivate extension VideoControlListController {
    func loadVideoControls() {
        
        var snapshot = NSDiffableDataSourceSnapshot<Section, VideoControlCellViewModel>()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModels, toSection: .main)
        datasource.apply(snapshot, animatingDifferences: true)
    }
}

// MARK: UI

fileprivate extension VideoControlListController {
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
        collectionView.autoPinEdge(toSuperviewEdge: .top)
        collectionView.autoPinEdge(toSuperviewEdge: .bottom)
        collectionView.autoPinEdge(toSuperviewEdge: .left, withInset: 0)
        collectionView.autoPinEdge(toSuperviewEdge: .right, withInset: 0)
    }

    func setupCollectionView() {
        let identifier = "VideoControlCell"
        collectionView.delegate = self
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        collectionView.register(VideoControlCell.self, forCellWithReuseIdentifier: identifier)
        datasource = Datasource(collectionView: collectionView) { collectionView, indexPath, videoControl in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: identifier,
                for: indexPath
            ) as! VideoControlCell

            cell.configure(with: videoControl)
            cell.setNeedsLayout()
            cell.layoutIfNeeded()

            return cell
        }
    }

    func makeCollectionView() -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8

        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.isScrollEnabled = viewModels.count > 5
        return view
    }
}


// MARK: Collection View Delegate Flow Layout

extension VideoControlListController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        // Tính toán width để fit 4 items với spacing
        let numerOfItems = viewModels.count > 5 ? 4.5 : CGFloat(viewModels.count)
        let totalSpacing = (numerOfItems - 1) * 8
        let availableWidth = collectionView.bounds.width - totalSpacing - 32
        let itemWidth = availableWidth / numerOfItems
        return CGSize(width: itemWidth, height: 60.0)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let viewModel = datasource.itemIdentifier(for: indexPath) {
            didSelectVideoControl.send(viewModel.videoControl)
        }
    }
}
