//
//  FilterCell.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 27.06.25.
//

import UIKit
import CoreImage

final class FilterCell: UICollectionViewCell {

    // MARK: Public Properties

    var isChoosed: Bool = false {
        didSet {
            updateUI()
        }
    }

    // MARK: Private Properties

    private lazy var title: UILabel = makeTitle()
    private lazy var thumbnailView: UIImageView = makeThumbnailView()

    private var viewModel: FilterCellViewModel!
    
    // Cache for filtered thumbnails to avoid regenerating
    private static var filteredThumbnailCache = NSCache<NSString, UIImage>()
    
    // Track cache keys for easier management
    private static var cacheKeys = Set<String>()
    private static let cacheKeysQueue = DispatchQueue(label: "FilterCell.cacheKeys", attributes: .concurrent)
    
    // Shared CIContext for better performance
    private static let sharedCIContext = CIContext(options: [
        .workingColorSpace: NSNull(),
        .outputColorSpace: NSNull()
    ])

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
    func configure(with viewModel: FilterCellViewModel, originalThumbnail: UIImage?, videoId: String?) {
        self.viewModel = viewModel
        title.text = viewModel.name
        
        // Generate filtered thumbnail from original video thumbnail
        if let originalImage = originalThumbnail {
            generateFilteredThumbnail(from: originalImage, filter: viewModel.filter, videoId: videoId)
        } else {
            // Fallback to colored background based on filter category
            thumbnailView.image = nil
            thumbnailView.backgroundColor = backgroundColorForCategory(viewModel.category)
        }
        
        isChoosed = viewModel.isSelected
    }
    
    private func generateFilteredThumbnail(from originalImage: UIImage, filter: VideoFilter, videoId: String?) {
        // Create cache key based on filter, video ID, and image size
        let imageContentHash = contentHash(for: originalImage, videoId: videoId)
        let cacheKey = "\(filter.rawValue)_\(imageContentHash)" as NSString
        
        // Check cache first
        if let cachedImage = Self.filteredThumbnailCache.object(forKey: cacheKey) {
            thumbnailView.image = cachedImage
            thumbnailView.backgroundColor = .clear
            return
        }
        
        // Apply filter to the original image
        if filter == .none {
            thumbnailView.image = originalImage
            thumbnailView.backgroundColor = .clear
            // Cache the original image for "none" filter
            Self.filteredThumbnailCache.setObject(originalImage, forKey: cacheKey)
            Self.addCacheKey(String(cacheKey))
        } else {
            // Show original image immediately while processing
            thumbnailView.image = originalImage
            thumbnailView.backgroundColor = .clear
            
            // Apply filter on background queue
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.applyFilter(filter, to: originalImage, cacheKey: cacheKey) { filteredImage in
                    DispatchQueue.main.async {
                        // Only update if this cell still represents the same filter
                        if self?.viewModel?.filter == filter {
                            self?.thumbnailView.image = filteredImage ?? originalImage
                            self?.thumbnailView.backgroundColor = .clear
                        }
                    }
                }
            }
        }
    }
    
    private func contentHash(for image: UIImage, videoId: String?) -> String {
        // Combine video ID with image size for unique hash per video
        let size = image.size
        let sizeString = "\(Int(size.width))x\(Int(size.height))"
        
        if let videoId = videoId {
            return "\(videoId)_\(sizeString)"
        } else {
            // Fallback to timestamp-based hash if no video ID
            return "\(Date().timeIntervalSince1970)_\(sizeString)"
        }
    }
    
    private func applyFilter(_ filter: VideoFilter, to image: UIImage, cacheKey: NSString, completion: @escaping (UIImage?) -> Void) {
        guard let ciFilterName = filter.ciFilterName,
              let ciImage = CIImage(image: image),
              let ciFilter = CIFilter(name: ciFilterName) else {
            completion(image)
            return
        }
        
        // Configure filter
        ciFilter.setValue(ciImage, forKey: kCIInputImageKey)
        
        // Apply default parameters if needed
        for (key, value) in filter.defaultParameters {
            ciFilter.setValue(value, forKey: key)
        }
        
        // Render filtered image
        guard let outputImage = ciFilter.outputImage else {
            completion(image)
            return
        }
        
        // Use shared context for better performance
        guard let cgImage = Self.sharedCIContext.createCGImage(outputImage, from: outputImage.extent) else {
            completion(image)
            return
        }
        
        let filteredImage = UIImage(cgImage: cgImage)
        
        // Cache the result
        Self.filteredThumbnailCache.setObject(filteredImage, forKey: cacheKey)
        Self.addCacheKey(String(cacheKey))
        
        completion(filteredImage)
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

extension FilterCell {
    func setupUI() {
        contentView.addSubview(thumbnailView)
        contentView.addSubview(title)
        setupConstraints()
    }
    
    func setupConstraints() {
        // Image centered horizontally at top with fixed size
        thumbnailView.autoAlignAxis(toSuperviewAxis: .vertical)
        thumbnailView.autoPinEdge(toSuperviewEdge: .top)
        thumbnailView.autoSetDimension(.width, toSize: 60.0)
        thumbnailView.autoSetDimension(.height, toSize: 60.0)
        
        // Label centered horizontally, 8px below image
        title.autoAlignAxis(toSuperviewAxis: .vertical)
        title.autoPinEdge(.top, to: .bottom, of: thumbnailView, withOffset: 8.0)
        title.autoPinEdge(toSuperviewEdge: .left, withInset: 4.0)
        title.autoPinEdge(toSuperviewEdge: .right, withInset: 4.0)
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

    func makeThumbnailView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8.0
        imageView.backgroundColor = .systemGray5
        return imageView
    }
    
    func makeTitle() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11.0)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }
    
    // MARK: Cache Management
    
    private static func addCacheKey(_ key: String) {
        cacheKeysQueue.async(flags: .barrier) {
            cacheKeys.insert(key)
        }
    }
    
    private static func removeCacheKey(_ key: String) {
        cacheKeysQueue.async(flags: .barrier) {
            cacheKeys.remove(key)
        }
    }
    
    static func clearThumbnailCache() {
        filteredThumbnailCache.removeAllObjects()
        cacheKeysQueue.async(flags: .barrier) {
            cacheKeys.removeAll()
        }
    }
    
    static func setCacheLimit(_ limit: Int) {
        filteredThumbnailCache.countLimit = limit
    }
    
    // Clear cache for specific video when done editing
    static func clearCacheForVideo(_ videoId: String) {
        cacheKeysQueue.sync {
            let keysToRemove = cacheKeys.filter { $0.contains(videoId) }
            
            for key in keysToRemove {
                filteredThumbnailCache.removeObject(forKey: key as NSString)
            }
            
            cacheKeysQueue.async(flags: .barrier) {
                for key in keysToRemove {
                    cacheKeys.remove(key)
                }
            }
        }
    }
    
    // Clear old cache entries (keep only recent videos)
    static func clearOldCacheEntries(keepRecentCount: Int = 3) {
        cacheKeysQueue.sync {
            // Group keys by video ID
            var videoIds = Set<String>()
            for key in cacheKeys {
                if let videoId = extractVideoId(from: key) {
                    videoIds.insert(videoId)
                }
            }
            
            // If we have more videos than keepRecentCount, clear all cache
            // A more sophisticated approach would track access times
            if videoIds.count > keepRecentCount {
                clearThumbnailCache()
            }
        }
    }
    
    private static func extractVideoId(from cacheKey: String) -> String? {
        // Cache key format: "filterType_videoId_resolution"
        let components = cacheKey.components(separatedBy: "_")
        if components.count >= 2 {
            return components[1]
        }
        return nil
    }
}
