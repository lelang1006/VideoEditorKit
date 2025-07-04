//
//  StickerControlViewController.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 03.07.25.
//

import UIKit
import Combine
import AVFoundation

final class StickerControlViewController: BaseVideoControlViewController {

    // MARK: - Types
    
    enum StickerSection: Int, CaseIterable {
        case stickerLibrary = 0
        case activeSickers = 1
        
        var title: String {
            switch self {
            case .stickerLibrary: return "Sticker Library"
            case .activeSickers: return "Active Stickers"
            }
        }
    }

    // MARK: - Properties

    @Published var selectedStickers: [StickerTimelineItem] = []
    
    override var tabBarItem: UITabBarItem! {
        get {
            UITabBarItem(
                title: "Stickers",
                image: UIImage(systemName: "star.fill"),
                selectedImage: UIImage(systemName: "star.fill")
            )
        }
        set {}
    }

    // MARK: - UI Components

    private lazy var tableView: UITableView = makeTableView()
    
    // Sample stickers data
    private let availableStickers: [StickerData] = [
        StickerData(id: "star", name: "Star", systemIcon: "star.fill"),
        StickerData(id: "heart", name: "Heart", systemIcon: "heart.fill"),
        StickerData(id: "smile", name: "Smile", systemIcon: "face.smiling"),
        StickerData(id: "sun", name: "Sun", systemIcon: "sun.max.fill"),
        StickerData(id: "moon", name: "Moon", systemIcon: "moon.fill"),
        StickerData(id: "fire", name: "Fire", systemIcon: "flame.fill"),
        StickerData(id: "lightning", name: "Lightning", systemIcon: "bolt.fill"),
        StickerData(id: "music", name: "Music", systemIcon: "music.note"),
    ]

    // MARK: - Lifecycle
    
    init(stickers: [StickerTimelineItem] = []) {
        super.init(nibName: nil, bundle: nil)
        self.selectedStickers = stickers
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupTableView()
    }

    // MARK: - Setup

    private func setupViews() {
        contentView.addSubview(tableView)
        
        tableView.autoPinEdge(toSuperviewEdge: .top, withInset: 16)
        tableView.autoPinEdge(toSuperviewEdge: .left)
        tableView.autoPinEdge(toSuperviewEdge: .right)
        tableView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 16)
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(StickerLibraryCell.self, forCellReuseIdentifier: StickerLibraryCell.reuseIdentifier)
        tableView.register(ActiveStickerCell.self, forCellReuseIdentifier: ActiveStickerCell.reuseIdentifier)
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "HeaderView")
    }

    // MARK: - Factory Methods

    private func makeTableView() -> UITableView {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        return tableView
    }
    
    // MARK: - Sticker Management
    
    private func addSticker(_ stickerData: StickerData) {
        // Create UIImage from system icon name
        guard let stickerImage = UIImage(systemName: stickerData.systemIcon) else {
            print("Failed to create image for system icon: \(stickerData.systemIcon)")
            return
        }
        
        // Create a new StickerTimelineItem
        let newSticker = StickerTimelineItem(
            image: stickerImage,
            position: CGPoint(x: 0.5, y: 0.5), // Center position (50%, 50%)
            scale: 1.0,      // Default scale (bạn có thể điều chỉnh sau)
            rotation: 0.0,   // No rotation
            startTime: CMTime.zero, // Start at beginning
            duration: CMTime(seconds: 5.0, preferredTimescale: 600), // 5 seconds duration
            relativeTrimPositions: (start: 0.0, end: 1.0),
            id: UUID().uuidString
        )
        
        selectedStickers.append(newSticker)
        tableView.reloadData()
    }
    
    private func removeSticker(at index: Int) {
        guard index < selectedStickers.count else { return }
        selectedStickers.remove(at: index)
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension StickerControlViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return StickerSection.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = StickerSection(rawValue: section) else { return 0 }
        
        switch sectionType {
        case .stickerLibrary:
            return availableStickers.count
        case .activeSickers:
            return selectedStickers.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sectionType = StickerSection(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        
        switch sectionType {
        case .stickerLibrary:
            let cell = tableView.dequeueReusableCell(withIdentifier: StickerLibraryCell.reuseIdentifier, for: indexPath) as! StickerLibraryCell
            let sticker = availableStickers[indexPath.row]
            cell.configure(with: sticker) { [weak self] stickerData in
                self?.addSticker(stickerData)
            }
            return cell
            
        case .activeSickers:
            let cell = tableView.dequeueReusableCell(withIdentifier: ActiveStickerCell.reuseIdentifier, for: indexPath) as! ActiveStickerCell
            let sticker = selectedStickers[indexPath.row]
            cell.configure(with: sticker) { [weak self] in
                self?.removeSticker(at: indexPath.row)
            }
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension StickerControlViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionType = StickerSection(rawValue: section) else { return nil }
        
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderView")
        headerView?.textLabel?.text = sectionType.title
        headerView?.textLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }
}

// MARK: - Supporting Types

struct StickerData {
    let id: String
    let name: String
    let systemIcon: String
}
