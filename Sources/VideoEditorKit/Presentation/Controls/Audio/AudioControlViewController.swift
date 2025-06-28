//
//  AudioControlViewController.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 28.06.25.
//

import UIKit
import Combine
import AVFoundation
import UniformTypeIdentifiers

final class AudioControlViewController: BaseVideoControlViewController {

    // MARK: - Types
    
    enum AudioSection: Int, CaseIterable {
        case currentAudio = 0
        case mediaLibrary = 1
        case userImport = 2
        case controls = 3
        
        var title: String {
            switch self {
            case .currentAudio: return "Current Audio"
            case .mediaLibrary: return "Audio Library"
            case .userImport: return "Import Audio"
            case .controls: return "Audio Settings"
            }
        }
    }

    // MARK: - Properties

    @Published var selectedAudioReplacement: AudioReplacement?
    @Published var volume: Float = 1.0
    @Published var isMuted: Bool = false
    
    override var tabBarItem: UITabBarItem! {
        get {
            UITabBarItem(
                title: "Audio",
                image: UIImage(named: "Audio", in: .module, compatibleWith: nil),
                selectedImage: UIImage(named: "Audio-Selected", in: .module, compatibleWith: nil)
            )
        }
        set {}
    }

    // MARK: - UI Components
    
    private lazy var tableView: UITableView = makeTableView()
    private var mediaLibraryAudios: [MediaAudio] = MediaAudio.library

    // MARK: - Init

    public init(audioReplacement: AudioReplacement? = nil, volume: Float = 1.0, isMuted: Bool = false) {
        self.selectedAudioReplacement = audioReplacement
        self.volume = volume
        self.isMuted = isMuted
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - BaseVideoControlViewController Override

    override func setupContentView() {
        super.setupContentView()
        setupTableView()
        setupBindings()
    }

    override func resetToInitialValues() {
        selectedAudioReplacement = nil
        volume = 1.0
        isMuted = false
    }

}

// MARK: - Setup

fileprivate extension AudioControlViewController {
    
    func setupTableView() {
        contentView.addSubview(tableView)
        
        tableView.autoPinEdge(toSuperviewEdge: .top, withInset: 16)
        tableView.autoPinEdge(toSuperviewEdge: .left)
        tableView.autoPinEdge(toSuperviewEdge: .right)
        tableView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 16)
    }
    
    func setupBindings() {
        // Bind published properties changes
        $selectedAudioReplacement
            .dropFirst(1)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
        
        $volume
            .dropFirst(1)
            .sink { [weak self] _ in
                self?.reloadControlsSection()
            }
            .store(in: &cancellables)
        
        $isMuted
            .dropFirst(1)
            .sink { [weak self] _ in
                self?.reloadControlsSection()
            }
            .store(in: &cancellables)
    }
    
    func reloadControlsSection() {
        DispatchQueue.main.async {
            self.tableView.reloadSections(IndexSet(integer: AudioSection.controls.rawValue), with: .none)
        }
    }
}

// MARK: - TableView

fileprivate extension AudioControlViewController {
    
    func makeTableView() -> UITableView {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        
        // Register cells
        tableView.register(CurrentAudioCell.self, forCellReuseIdentifier: "CurrentAudioCell")
        tableView.register(MediaAudioCell.self, forCellReuseIdentifier: "MediaAudioCell")
        tableView.register(ImportAudioCell.self, forCellReuseIdentifier: "ImportAudioCell")
        tableView.register(AudioControlsCell.self, forCellReuseIdentifier: "AudioControlsCell")
        
        return tableView
    }
}

// MARK: - UITableViewDataSource

extension AudioControlViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return AudioSection.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let audioSection = AudioSection(rawValue: section)!
        
        switch audioSection {
        case .currentAudio: return 1
        case .mediaLibrary: return mediaLibraryAudios.count
        case .userImport: return 1
        case .controls: return 1
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let audioSection = AudioSection(rawValue: section)!
        return audioSection.title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let audioSection = AudioSection(rawValue: indexPath.section)!
        
        switch audioSection {
        case .currentAudio:
            let cell = tableView.dequeueReusableCell(withIdentifier: "CurrentAudioCell", for: indexPath) as! CurrentAudioCell
            cell.configure(with: selectedAudioReplacement, isOriginalAudio: selectedAudioReplacement == nil)
            cell.onTrimTapped = { [weak self] in
                self?.showAudioTrimControls()
            }
            return cell
            
        case .mediaLibrary:
            let cell = tableView.dequeueReusableCell(withIdentifier: "MediaAudioCell", for: indexPath) as! MediaAudioCell
            let mediaAudio = mediaLibraryAudios[indexPath.row]
            let isSelected = selectedAudioReplacement?.title == mediaAudio.title
            cell.configure(with: mediaAudio, isSelected: isSelected)
            return cell
            
        case .userImport:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ImportAudioCell", for: indexPath) as! ImportAudioCell
            return cell
            
        case .controls:
            let cell = tableView.dequeueReusableCell(withIdentifier: "AudioControlsCell", for: indexPath) as! AudioControlsCell
            cell.configure(volume: volume, isMuted: isMuted)
            cell.onVolumeChanged = { [weak self] volume in
                self?.volume = volume
            }
            cell.onMuteToggled = { [weak self] isMuted in
                self?.isMuted = isMuted
            }
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension AudioControlViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let audioSection = AudioSection(rawValue: indexPath.section)!
        
        switch audioSection {
        case .mediaLibrary:
            let mediaAudio = mediaLibraryAudios[indexPath.row]
            selectMediaAudio(mediaAudio)
            
        case .userImport:
            presentAudioPicker()
            
        default:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let audioSection = AudioSection(rawValue: indexPath.section)!
        
        switch audioSection {
        case .currentAudio: return 60
        case .mediaLibrary: return 70
        case .userImport: return 50
        case .controls: return 80
        }
    }
}

// MARK: - Audio Selection

fileprivate extension AudioControlViewController {
    
    func selectMediaAudio(_ mediaAudio: MediaAudio) {
        let audioReplacement = AudioReplacement(
            asset: mediaAudio.asset,
            url: nil,
            title: mediaAudio.title
        )
        
        selectedAudioReplacement = audioReplacement
    }
    
    func presentAudioPicker() {
        let documentPicker: UIDocumentPickerViewController
        
        if #available(iOS 14.0, *) {
            let documentTypes: [UTType] = [.audio, .mp3]
            documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: documentTypes, asCopy: true)
        } else {
            // Fallback for iOS 13 - use UTI strings
            documentPicker = UIDocumentPickerViewController(documentTypes: ["public.audio", "public.mp3"], in: .import)
        }
        
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true)
    }
    
    func showAudioTrimControls() {
        guard let audioReplacement = selectedAudioReplacement else { return }
        
        // TODO: Implement AudioTrimViewController
        let alert = UIAlertController(title: "Audio Trim", message: "Audio trimming will be implemented in next phase", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate

extension AudioControlViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let audioURL = urls.first else { return }
        
        let asset = AVAsset(url: audioURL)
        let title = audioURL.deletingPathExtension().lastPathComponent
        
        let audioReplacement = AudioReplacement(
            asset: asset,
            url: audioURL,
            title: title
        )
        
        selectedAudioReplacement = audioReplacement
    }
}
