//
//  VideoEditorViewController.swift
//
//
//  Created by Titouan Van Belle on 11.09.20.
//

import AVFoundation
import Combine
import PureLayout
import UIKit

public final class VideoEditorViewController: UIViewController {

    // MARK: Published Properties

    public var onEditCompleted = PassthroughSubject<(AVPlayerItem, VideoEdit), Never>()

    // MARK: Private Properties

    private lazy var saveButtonItem: UIBarButtonItem = makeSaveButtonItem()
    private lazy var dismissButtonItem: UIBarButtonItem = makeDismissButtonItem()

    private lazy var videoPlayerController: VideoPlayerController = makeVideoPlayerController()
    private lazy var playButton: PlayPauseButton = makePlayButton()

    private lazy var timeStack: UIStackView = makeTimeStack()
    private lazy var currentTimeLabel: UILabel = makeCurrentTimeLabel()
    private lazy var durationLabel: UILabel = makeDurationLabel()

    private lazy var muteButton: UIButton = makeMuteButton()
    private lazy var fullscreenButton: UIButton = makeFullscreenButton()
    private lazy var controlsView: UIView = makeControlsView()
    private lazy var videoTimelineViewController: MultiLayerTimelineViewController = makeVideoTimelineViewController()
    private lazy var videoControlListController: VideoControlListController = makeVideoControlListControllers()

    // Thêm property để quản lý controller hiện tại
    private var currentVideoControlController: VideoControlProtocol?
    
    // Cached thumbnail for filter preview
    private lazy var videoThumbnail: UIImage? = generateVideoThumbnail()

    private var videoControlHeightConstraint: NSLayoutConstraint!

    private var cancellables = Set<AnyCancellable>()
    private var durationUpdateCancellable: Cancellable?
    
    // Track timeline generation to prevent unnecessary regeneration during trim operations
    private var currentTimelineAsset: AVAsset?

    private let store: VideoEditorStore
    private let viewFactory: VideoEditorViewFactoryProtocol
    private let videoId: String?

    // MARK: Init

    public init(asset: AVAsset, videoEdit: VideoEdit? = nil, videoId: String? = nil) {
        self.store = VideoEditorStore(asset: asset, videoEdit: videoEdit)
        self.viewFactory = VideoEditorViewFactory()
        self.videoId = videoId

        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Life Cycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupBindings()
        configureAudioSession() // Configure audio session here
        
        // Configure filter thumbnail cache
        FilterCell.setCacheLimit(50) // Cache up to 50 filtered thumbnails

        #if targetEnvironment(simulator)
        print("Warning: Cropping only works on real device and has been disabled on simulator")
        #endif
    }
}

// MARK: Bindings

fileprivate extension VideoEditorViewController {
    func subscribeToDurationUpdate(for item: AVPlayerItem) {
        durationUpdateCancellable?.cancel()
        durationUpdateCancellable = item
            .publisher(for: \.duration)
            .sink { [weak self] playheadProgress in
                guard let self = self else { return }
                self.updateDurationLabel()
            }
    }

    func setupBindings() {
        store.$playheadProgress
            .sink { [weak self] playheadProgress in
                guard let self = self else { return }
                self.updateCurrentTimeLabel()
            }
            .store(in: &cancellables)
        
        store.$editedPlayerItem
            .sink { [weak self] item in
                guard let self = self else { return }
                self.videoPlayerController.load(item: item, autoPlay: false)
                
                // Only initialize timeline if this is a different asset to avoid resetting trim during operations
                if self.currentTimelineAsset !== item.asset {
                    print("📹 Initializing timeline for new asset")
                    self.videoTimelineViewController.initializeTimeline()
                    self.currentTimelineAsset = item.asset
                } else {
                    print("📹 Skipping timeline initialization - same asset")
                }
                
                self.subscribeToDurationUpdate(for: item)
                // Update mute button icon when new item is loaded
                DispatchQueue.main.async {
                    self.updateMuteButtonIcon()
                }
            }
            .store(in: &cancellables)



        videoPlayerController.$currentTime
            .assign(to: \.playheadProgress, weakly: store)
            .store(in: &cancellables)

        videoPlayerController.$isPlaying
            .sink { [weak self] isPlaying in
                guard let self = self else { return }
                self.playButton.isPaused = !isPlaying
            }
            .store(in: &cancellables)

        // Monitor player mute state and update button icon
        videoPlayerController.player.publisher(for: \.isMuted)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateMuteButtonIcon()
            }
            .store(in: &cancellables)

        store.$isSeeking
            .filter { $0 }
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.videoPlayerController.pause()
            }.store(in: &cancellables)

        store.$currentSeekingValue
            .filter { [weak self] _ in
                guard let self = self else { return false }
                return self.store.isSeeking
            }
            .sink { [weak self] seekingValue in
                guard let self = self else { return }
                self.videoPlayerController.seek(toFraction: seekingValue)
            }
            .store(in: &cancellables)

        videoControlListController.didSelectVideoControl
            .sink { [weak self] videoControl in
                guard let self = self else { return }
                self.presentVideoControlController(for: videoControl)
            }
            .store(in: &cancellables)
        
        // Bind stickers to video player overlay
        store.$stickers
            .combineLatest(store.$editedPlayerItem)
            .sink { [weak self] stickers, playerItem in
                guard let self = self else { return }
                self.updateVideoPlayerStickers(stickers, playerItem: playerItem)
            }
            .store(in: &cancellables)
    }
}

// MARK: UI

fileprivate extension VideoEditorViewController {
    func setupUI() {
        setupNavigationItems()
        setupView()
        setupConstraints()
    }

    func setupNavigationItems() {
        let lNegativeSeperator = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        lNegativeSeperator.width = 10

        let rNegativeSeperator = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        rNegativeSeperator.width = 10

        navigationItem.rightBarButtonItems = [rNegativeSeperator, saveButtonItem]
        navigationItem.leftBarButtonItems = [lNegativeSeperator, dismissButtonItem]
    }

    func setupView() {
        view.backgroundColor = .background

        add(videoPlayerController)
        view.addSubview(controlsView)
        add(videoTimelineViewController)
        add(videoControlListController)
    }

    func setupConstraints() {
        videoPlayerController.view.autoPinEdge(toSuperviewEdge: .top)
        videoPlayerController.view.autoPinEdge(toSuperviewEdge: .left)
        videoPlayerController.view.autoPinEdge(toSuperviewEdge: .right)
        videoPlayerController.view.autoPinEdge(.bottom, to: .top, of: controlsView)

        // Set button dimensions
        playButton.autoSetDimension(.height, toSize: 44.0)
        playButton.autoSetDimension(.width, toSize: 44.0)
        muteButton.autoSetDimension(.height, toSize: 44.0)
        muteButton.autoSetDimension(.width, toSize: 44.0)
        fullscreenButton.autoSetDimension(.height, toSize: 44.0)
        fullscreenButton.autoSetDimension(.width, toSize: 44.0)

        // Controls view constraints
        controlsView.autoSetDimension(.height, toSize: 44.0)
        controlsView.autoPinEdge(toSuperviewEdge: .left)
        controlsView.autoPinEdge(toSuperviewEdge: .right)
        controlsView.autoPinEdge(.bottom, to: .top, of: videoTimelineViewController.view)
        
        // Layout buttons in controls view
        // Play button - left side with 16pt margin
        playButton.autoPinEdge(toSuperviewEdge: .left, withInset: 8)
        playButton.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        // Fullscreen button - right side with 16pt margin
        fullscreenButton.autoPinEdge(toSuperviewEdge: .right, withInset: 8)
        fullscreenButton.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        // Mute button - 8pt to the left of fullscreen button
        muteButton.autoPinEdge(.right, to: .left, of: fullscreenButton, withOffset: 0)
        muteButton.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        // Time stack - centered horizontally
        timeStack.autoAlignAxis(toSuperviewAxis: .horizontal)
        timeStack.autoAlignAxis(toSuperviewAxis: .vertical)

        videoTimelineViewController.view.autoSetDimension(.height, toSize: 220.0)
        videoTimelineViewController.view.autoPinEdge(toSuperviewEdge: .left)
        videoTimelineViewController.view.autoPinEdge(toSuperviewEdge: .right)
        videoTimelineViewController.view.autoPinEdge(.bottom, to: .top, of: videoControlListController.view)

        videoControlListController.view.autoPinEdge(toSuperviewSafeArea: .bottom)
        videoControlListController.view.autoPinEdge(toSuperviewEdge: .left)
        videoControlListController.view.autoPinEdge(toSuperviewEdge: .right)
        videoControlListController.view.autoSetDimension(.height, toSize: 60.0)
    }

    func updateDurationLabel() {
        var durationInSeconds = videoPlayerController.player.currentItem?.duration.seconds ?? 0.0
        durationInSeconds = durationInSeconds.isNaN ? 0.0 : durationInSeconds
        let formattedDuration = durationInSeconds >= 3600 ?
            DateComponentsFormatter.longDurationFormatter.string(from: durationInSeconds) ?? "" :
            DateComponentsFormatter.shortDurationFormatter.string(from: durationInSeconds) ?? ""

        durationLabel.text = formattedDuration
    }

    func updateCurrentTimeLabel() {
        let currentTimeInSeconds = videoPlayerController.currentTime.seconds
        let formattedCurrentTime = currentTimeInSeconds >= 3600 ?
            DateComponentsFormatter.longDurationFormatter.string(from: currentTimeInSeconds) ?? "" :
            DateComponentsFormatter.shortDurationFormatter.string(from: currentTimeInSeconds) ?? ""

        currentTimeLabel.text = formattedCurrentTime
    }

    func makeSaveButtonItem() -> UIBarButtonItem {
        let image = UIImage(named: "Check", in: .module, compatibleWith: nil)
        let buttonItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(save))
        buttonItem.tintColor = #colorLiteral(red: 0.1137254902, green: 0.1137254902, blue: 0.1215686275, alpha: 1)
        return buttonItem
    }

    func makeDismissButtonItem() -> UIBarButtonItem {
        let imageName = isModal ? "Close" : "Back"
        let image = UIImage(named: imageName, in: .module, compatibleWith: nil)
        let buttonItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(cancel))
        buttonItem.tintColor = #colorLiteral(red: 0.1137254902, green: 0.1137254902, blue: 0.1215686275, alpha: 1)
        return buttonItem
    }

    func makeVideoPlayerController() -> VideoPlayerController {
        let controller = viewFactory.makeVideoPlayerController()
        return controller
    }

    func makePlayButton() -> PlayPauseButton {
        let button = PlayPauseButton()
        button.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
        button.tintColor = #colorLiteral(red: 0.1137254902, green: 0.1137254902, blue: 0.1215686275, alpha: 1)
        button.imageEdgeInsets = .init(top: 13, left: 15, bottom: 13, right: 15)
        return button
    }

    func makeTimeStack() -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [
            currentTimeLabel,
            makeSeparatorLabel(),
            durationLabel
        ])

        return stack
    }

    func makeSeparatorLabel() -> UILabel {
        let label = UILabel()
        label.textAlignment = .center
        label.text = " | "
        label.font = .systemFont(ofSize: 13.0)
        label.textColor = .foreground
        return label
    }

    func makeDurationLabel() -> UILabel {
        let label = UILabel()
        label.textAlignment = .center
        label.text = "0:00"
        label.font = .systemFont(ofSize: 13.0)
        label.textColor = .foreground
        return label
    }

    func makeCurrentTimeLabel() -> UILabel {
        let label = UILabel()
        label.textAlignment = .center
        label.text = "0:00"
        label.font = .systemFont(ofSize: 13.0)
        label.textColor = .foreground
        return label
    }

    func makeFullscreenButton() -> UIButton {
        let button = UIButton()
        let image = UIImage(named: "EnterFullscreen", in: .module, compatibleWith: nil)
        button.addTarget(self, action: #selector(fullscreenButtonTapped), for: .touchUpInside)
        button.setImage(image, for: .normal)
        button.tintColor = #colorLiteral(red: 0.1137254902, green: 0.1137254902, blue: 0.1215686275, alpha: 1)
        button.imageEdgeInsets = .init(top: 14, left: 13, bottom: 14, right: 13)
        return button
    }

    func makeMuteButton() -> UIButton {
        let button = UIButton()
        let speakerImage = UIImage(named: "Speaker", in: .module, compatibleWith: nil)
        button.addTarget(self, action: #selector(muteButtonTapped), for: .touchUpInside)
        button.setImage(speakerImage, for: .normal)
        button.tintColor = #colorLiteral(red: 0.1137254902, green: 0.1137254902, blue: 0.1215686275, alpha: 1)
        button.imageEdgeInsets = .init(top: 14, left: 13, bottom: 14, right: 13)
        return button
    }

    func makeControlsView() -> UIView {
        let containerView = UIView()
        
        // Add all subviews
        containerView.addSubview(playButton)
        containerView.addSubview(timeStack)
        containerView.addSubview(muteButton)
        containerView.addSubview(fullscreenButton)
        
        return containerView
    }

    func makeVideoTimelineViewController() -> MultiLayerTimelineViewController {
        let controller = MultiLayerTimelineViewController(store: store)
        controller.delegate = self
        return controller
    }

    func makeVideoControlListControllers() -> VideoControlListController {
        viewFactory.makeVideoControlListController(store: store)
    }

    func presentVideoControlController(for videoControl: VideoControl) {
        navigationItem.rightBarButtonItems = []
        navigationItem.leftBarButtonItems = []
        
        // Tạo controller riêng biệt dựa trên VideoControl type
        let controller = createVideoControlController(for: videoControl)
        currentVideoControlController = controller
        
        // Setup bindings cho controller mới
        setupVideoControlBindings(for: controller, videoControl: videoControl)
        
        if controller.view.superview == nil {
            let height: CGFloat = videoControl.heightOfVideoControl
            let offset = -(height + view.safeAreaInsets.bottom)

            add(controller)

            controller.view.autoPinEdge(toSuperviewEdge: .right)
            controller.view.autoPinEdge(toSuperviewEdge: .left)
            controller.view.autoSetDimension(.height, toSize: height)
            controller.view.autoPinEdge(toSuperviewSafeArea: .bottom, withInset: offset)

            self.view.layoutIfNeeded()
        }

        controller.configure(with: videoControl)
        animateVideoControlViewControllerIn(controller)
    }
    
    private func createVideoControlController(for videoControl: VideoControl) -> VideoControlProtocol {
        switch videoControl {
        case .crop:
            return viewFactory.makeCropVideoControlViewController(croppingPreset: store.croppingPreset)
        case .speed:
            debugPrint("Creating SpeedController with store.speed: \(store.speed)")
            return viewFactory.makeSpeedVideoControlViewController(speed: store.speed)
        case .filter:
            return viewFactory.makeFilterVideoControlViewController(selectedFilter: store.filter, thumbnail: videoThumbnail, videoId: videoId)
        case .trim:
            return viewFactory.makeTrimVideoControlViewController(asset: store.originalAsset, trimPositions: store.trimPositions)
        case .audio:
            return viewFactory.makeAudioControlViewController(
                audioReplacement: store.audioReplacement,
                volume: store.volume,
                isMuted: store.isMuted
            )
        case .sticker:
            return viewFactory.makeStickerControlViewController(stickers: store.stickers)
        }
    }
    
    private func setupVideoControlBindings(for controller: VideoControlProtocol, videoControl: VideoControl) {
        // Bind onDismiss cho tất cả controllers
        controller.onDismiss
            .sink { [unowned self] _ in
                self.animateVideoControlViewControllerOut(controller)
            }
            .store(in: &cancellables)
        
        // Bind specific properties dựa trên controller type
        switch videoControl {
        case .crop:
            if let cropController = controller as? CropVideoControlViewController {
                cropController.$croppingPreset
                    .dropFirst(1)
                    .assign(to: \.croppingPreset, weakly: store)
                    .store(in: &cancellables)
            }
        case .speed:
            if let speedController = controller as? SpeedVideoControlViewController {
                speedController.$speed
                    .dropFirst(1)
                    .assign(to: \.speed, weakly: store)
                    .store(in: &cancellables)
            }
        case .filter:
            if let filterController = controller as? FilterVideoControlViewController {
                filterController.$selectedFilter
                    .dropFirst(1)
                    .assign(to: \.filter, weakly: store)
                    .store(in: &cancellables)
            }
        case .trim:
            if let trimController = controller as? TrimVideoControlViewController {
                trimController.$trimPositions
                    .dropFirst(1)
                    .assign(to: \.trimPositions, weakly: store)
                    .store(in: &cancellables)
            }
        case .audio:
            if let audioController = controller as? AudioControlViewController {
                audioController.$selectedAudioReplacement
                    .dropFirst(1)
                    .assign(to: \.audioReplacement, weakly: store)
                    .store(in: &cancellables)
                
                audioController.$volume
                    .dropFirst(1)
                    .assign(to: \.volume, weakly: store)
                    .store(in: &cancellables)
                
                audioController.$isMuted
                    .dropFirst(1)
                    .assign(to: \.isMuted, weakly: store)
                    .store(in: &cancellables)
            }
        case .sticker:
            if let stickerController = controller as? StickerControlViewController {
                stickerController.$selectedStickers
                    .dropFirst(1)
                    .assign(to: \.stickers, weakly: store)
                    .store(in: &cancellables)
            }
        }
    }

    func animateVideoControlViewControllerIn(_ controller: VideoControlProtocol) {
        let y = -(controller.view.bounds.height + view.safeAreaInsets.bottom)
        UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .curveEaseInOut, animations: {
            controller.view.transform = CGAffineTransform(translationX: 0, y: y)
        })
    }

    func animateVideoControlViewControllerOut(_ controller: VideoControlProtocol) {
        UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .curveEaseInOut, animations: {
            controller.view.transform = .identity
        }, completion: { _ in
            // Remove controller và show navigation bar buttons
            controller.removeFromParent()
            controller.view.removeFromSuperview()
            self.currentVideoControlController = nil
            self.setupNavigationItems()
        })
    }

    func updateMuteButtonIcon() {
        let isMuted = videoPlayerController.player.isMuted
        let imageName = isMuted ? "SpeakerMute" : "Speaker"
        let image = UIImage(named: imageName, in: .module, compatibleWith: nil)
        muteButton.setImage(image, for: .normal)
    }
}

// MARK: Actions

fileprivate extension VideoEditorViewController {
    @objc func fullscreenButtonTapped() {
        videoPlayerController.enterFullscreen()
    }

    @objc func playButtonTapped() {
        if videoPlayerController.isPlaying {
            videoPlayerController.pause()
        } else {
            videoPlayerController.play()
        }
    }

    @objc func muteButtonTapped() {
        videoPlayerController.player.isMuted.toggle()
        updateMuteButtonIcon()
    }

    @objc func save() {
        let item = AVPlayerItem(asset: store.editedPlayerItem.asset)

        #if !targetEnvironment(simulator)
        item.videoComposition = store.editedPlayerItem.videoComposition
        #endif

        onEditCompleted.send((item, store.videoEdit))
        dismiss(animated: true)
    }

    @objc func cancel() {
        let alert = UIAlertController(title: "Are you sure?", message: "The video edit will be lost when dismiss the screen.", preferredStyle: .alert)

        let dismissAction = UIAlertAction(
            title: "Yes",
            style: .destructive,
            handler: { _ in
                if self.isModal {
                    self.dismiss(animated: true)
                } else {
                    self.navigationController?.popViewController(animated: true)
                }
            }
        )
        alert.addAction(dismissAction)

        let cancelAction = UIAlertAction(
            title: "No",
            style: .cancel,
            handler: { _ in }
        )
        alert.addAction(cancelAction)

        present(alert, animated: true)
    }
    
    private func generateVideoThumbnail() -> UIImage? {
        let imageGenerator = AVAssetImageGenerator(asset: store.originalAsset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Calculate size to maintain aspect ratio with minimum dimension of 100
        guard let videoTrack = store.originalAsset.tracks(withMediaType: .video).first else {
            return nil
        }
        
        let videoSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        let videoWidth = abs(videoSize.width)
        let videoHeight = abs(videoSize.height)
        
        let aspectRatio = videoWidth / videoHeight
        let targetSize: CGSize
        
        if videoWidth < videoHeight {
            // Portrait or square - width is smaller
            targetSize = CGSize(width: 100, height: 100 / aspectRatio)
        } else {
            // Landscape - height is smaller
            targetSize = CGSize(width: 100 * aspectRatio, height: 100)
        }
        
        imageGenerator.maximumSize = targetSize
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: CMTime.zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("Error generating thumbnail: \(error)")
            return nil
        }
    }
    
    func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use playback category to ensure audio plays even when device is muted
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            print("🔊 Audio session configured for media playback")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }
}

// MARK: - MultiLayerTimelineDelegate

extension VideoEditorViewController: MultiLayerTimelineDelegate {
    
    func timeline(_ timeline: MultiLayerTimelineViewController, didSelectItem item: TimelineItem) {
        // Handle timeline item selection
        // This could update video controls or highlight the selected item
        print("📱 Timeline item selected: \(item)")
    }
    
    func timeline(_ timeline: MultiLayerTimelineViewController, didTrimItem item: TimelineItem, newStartTime: CMTime, newDuration: CMTime) {
        // Handle timeline item trimming
        // Update the store with new trim positions
        print("✂️ Timeline item trimmed: \(item) - Start: \(newStartTime.seconds)s, Duration: \(newDuration.seconds)s")
        
        // You could update the store here:
        // store.updateTrimPositions(for: item, startTime: newStartTime, duration: newDuration)
    }
    
    func timeline(_ timeline: MultiLayerTimelineViewController, didAddTrackOfType type: TimelineTrackType) {
        // Handle new track addition
        print("➕ New track added: \(type)")
        
        // You could update the store or show a picker for the new track content:
        // store.addTrack(of: type)
        // or present content picker for this track type
    }
}

// MARK: - Private Helper Methods
    
private extension VideoEditorViewController {
    func updateVideoPlayerStickers(_ stickers: [StickerTimelineItem], playerItem: AVPlayerItem) {
        // Get video size from the player item
        let videoSize = getVideoSize(from: playerItem)
        
        // Update stickers in video player overlay
        videoPlayerController.updateStickers(stickers, videoSize: videoSize)
    }
    
    func getVideoSize(from playerItem: AVPlayerItem) -> CGSize {
        guard let track = playerItem.asset.tracks(withMediaType: .video).first else {
            return CGSize(width: 1920, height: 1080) // Default size
        }
        
        let naturalSize = track.naturalSize
        let transform = track.preferredTransform
        
        // Apply transform to get actual video dimensions
        let videoSize = naturalSize.applying(transform)
        return CGSize(width: abs(videoSize.width), height: abs(videoSize.height))
    }
}
