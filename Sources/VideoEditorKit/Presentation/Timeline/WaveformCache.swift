//
//  WaveformCache.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 29.06.25.
//

import Foundation
import AVFoundation
import Accelerate
import os.log
import UIKit

/// A thread-safe cache for audio waveform data to avoid regenerating waveforms for the same audio asset
final class WaveformCache {
    
    // MARK: - Singleton
    
    static let shared = WaveformCache()
    
    // MARK: - Properties
    
    private let cache = NSCache<NSString, NSArray>()
    private let cacheQueue = DispatchQueue(label: "waveform.cache.queue", qos: .userInitiated)
    private let generationQueue = DispatchQueue(label: "waveform.generation.queue", qos: .userInitiated)
    
    private let logger = Logger(subsystem: "VideoEditorKit", category: "WaveformCache")
    
    // MARK: - Configuration
    
    private struct Configuration {
        static let maxCacheSize = 50 // Maximum number of waveforms to cache
        static let defaultSampleCount = 200 // Default number of samples for waveform
        static let maxMemoryMB = 20 // Maximum memory usage in MB
    }
    
    // MARK: - Init
    
    private init() {
        setupCache()
    }
    
    // MARK: - Setup
    
    private func setupCache() {
        cache.countLimit = Configuration.maxCacheSize
        cache.totalCostLimit = Configuration.maxMemoryMB * 1024 * 1024 // Convert MB to bytes
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        logger.warning("Memory warning received, clearing waveform cache")
        clearCache()
    }
    
    // MARK: - Public Methods
    
    /// Generates or retrieves cached waveform data for the given audio asset
    /// - Parameters:
    ///   - asset: The audio asset to generate waveform for
    ///   - sampleCount: Number of samples in the waveform (default: 200)
    ///   - completion: Completion handler with waveform data or error
    func getWaveform(
        for asset: AVAsset,
        sampleCount: Int = Configuration.defaultSampleCount,
        completion: @escaping (Result<[Float], Error>) -> Void
    ) {
        let cacheKey = generateCacheKey(for: asset, sampleCount: sampleCount)
        
        // Check cache first
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            if let cachedWaveform = self.cache.object(forKey: cacheKey as NSString) as? [Float] {
                self.logger.debug("Cache hit for waveform: \(cacheKey)")
                DispatchQueue.main.async {
                    completion(.success(cachedWaveform))
                }
                return
            }
            
            // Generate new waveform
            self.logger.debug("Cache miss, generating waveform: \(cacheKey)")
            self.generateWaveform(for: asset, sampleCount: sampleCount, cacheKey: cacheKey, completion: completion)
        }
    }
    
    /// Synchronously retrieves cached waveform if available
    /// - Parameters:
    ///   - asset: The audio asset
    ///   - sampleCount: Number of samples in the waveform
    /// - Returns: Cached waveform data or nil if not cached
    func getCachedWaveform(for asset: AVAsset, sampleCount: Int = Configuration.defaultSampleCount) -> [Float]? {
        let cacheKey = generateCacheKey(for: asset, sampleCount: sampleCount)
        return cache.object(forKey: cacheKey as NSString) as? [Float]
    }
    
    /// Preloads waveform data for an asset (useful for background loading)
    /// - Parameters:
    ///   - asset: The audio asset
    ///   - sampleCount: Number of samples in the waveform
    func preloadWaveform(for asset: AVAsset, sampleCount: Int = Configuration.defaultSampleCount) {
        getWaveform(for: asset, sampleCount: sampleCount) { [weak self] result in
            switch result {
            case .success:
                self?.logger.debug("Preloaded waveform for asset")
            case .failure(let error):
                self?.logger.error("Failed to preload waveform: \(error.localizedDescription)")
            }
        }
    }
    
    /// Clears all cached waveforms
    func clearCache() {
        cacheQueue.async { [weak self] in
            self?.cache.removeAllObjects()
            self?.logger.debug("Waveform cache cleared")
        }
    }
    
    // MARK: - Private Methods
    
    private func generateCacheKey(for asset: AVAsset, sampleCount: Int) -> String {
        // Use a combination of asset duration and sample count as cache key
        let duration = asset.duration.seconds
        
        // Try to get creation date from metadata
        var creationDateComponent: String = "0"
        if let creationDateItem = asset.creationDate {
            if let dateValue = creationDateItem.dateValue {
                creationDateComponent = String(dateValue.timeIntervalSince1970)
            } else if let stringValue = creationDateItem.stringValue {
                creationDateComponent = stringValue.hash.description
            }
        }
        
        // Also include URL if available for better uniqueness
        var urlComponent = ""
        if let url = (asset as? AVURLAsset)?.url {
            urlComponent = url.absoluteString.hash.description
        }
        
        return "waveform_\(duration)_\(creationDateComponent)_\(sampleCount)_\(urlComponent)"
    }
    
    private func generateWaveform(
        for asset: AVAsset,
        sampleCount: Int,
        cacheKey: String,
        completion: @escaping (Result<[Float], Error>) -> Void
    ) {
        generationQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let waveform = try self.extractWaveform(from: asset, sampleCount: sampleCount)
                
                // Cache the result
                self.cacheQueue.async {
                    let cost = waveform.count * MemoryLayout<Float>.size
                    self.cache.setObject(waveform as NSArray, forKey: cacheKey as NSString, cost: cost)
                }
                
                DispatchQueue.main.async {
                    completion(.success(waveform))
                }
                
            } catch {
                self.logger.error("Failed to generate waveform: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func extractWaveform(from asset: AVAsset, sampleCount: Int) throws -> [Float] {
        // Get the audio track
        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            throw WaveformError.noAudioTrack
        }
        
        // Create asset reader
        let assetReader = try AVAssetReader(asset: asset)
        
        // Configure audio output settings for PCM format
        let audioOutputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        
        let audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: audioOutputSettings)
        audioOutput.alwaysCopiesSampleData = false
        
        if assetReader.canAdd(audioOutput) {
            assetReader.add(audioOutput)
        } else {
            throw WaveformError.cannotAddAudioOutput
        }
        
        // Start reading
        guard assetReader.startReading() else {
            throw WaveformError.cannotStartReading
        }
        
        // Process audio samples
        var audioSamples: [Float] = []
        
        while assetReader.status == .reading {
            if let sampleBuffer = audioOutput.copyNextSampleBuffer() {
                if let samples = self.processAudioBuffer(sampleBuffer) {
                    audioSamples.append(contentsOf: samples)
                }
                CMSampleBufferInvalidate(sampleBuffer)
            }
        }
        
        // Check for errors
        if assetReader.status == .failed {
            throw assetReader.error ?? WaveformError.readingFailed
        }
        
        // Generate waveform by downsampling
        let waveform = downsampleAudio(audioSamples, targetSampleCount: sampleCount)
        
        logger.debug("Generated waveform with \(waveform.count) samples from \(audioSamples.count) audio samples")
        
        return waveform
    }
    
    private func processAudioBuffer(_ sampleBuffer: CMSampleBuffer) -> [Float]? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }
        
        let length = CMBlockBufferGetDataLength(blockBuffer)
        let sampleCount = length / MemoryLayout<Int16>.size
        
        var data = Data(count: length)
        let status = data.withUnsafeMutableBytes { bytes in
            CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard status == kCMBlockBufferNoErr else {
            return nil
        }
        
        // Convert Int16 samples to Float
        let int16Samples = data.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Int16.self))
        }
        
        let floatSamples = int16Samples.map { Float($0) / Float(Int16.max) }
        return floatSamples
    }
    
    private func downsampleAudio(_ samples: [Float], targetSampleCount: Int) -> [Float] {
        guard samples.count > targetSampleCount else {
            return samples
        }
        
        let blockSize = samples.count / targetSampleCount
        var waveform: [Float] = []
        
        for i in 0..<targetSampleCount {
            let startIndex = i * blockSize
            let endIndex = min(startIndex + blockSize, samples.count)
            
            if startIndex < samples.count {
                let blockSamples = Array(samples[startIndex..<endIndex])
                
                // Calculate RMS (Root Mean Square) for the block
                let rms = sqrt(blockSamples.map { $0 * $0 }.reduce(0, +) / Float(blockSamples.count))
                waveform.append(rms)
            }
        }
        
        return waveform
    }
}

// MARK: - WaveformError

enum WaveformError: Error {
    case noAudioTrack
    case cannotAddAudioOutput
    case cannotStartReading
    case readingFailed
    
    var localizedDescription: String {
        switch self {
        case .noAudioTrack:
            return "No audio track found in asset"
        case .cannotAddAudioOutput:
            return "Cannot add audio output to asset reader"
        case .cannotStartReading:
            return "Cannot start reading audio data"
        case .readingFailed:
            return "Failed to read audio data"
        }
    }
}

// MARK: - Extensions

extension WaveformCache {
    
    /// Generates a waveform with custom configuration
    /// - Parameters:
    ///   - asset: The audio asset
    ///   - config: Waveform generation configuration
    ///   - completion: Completion handler
    func getWaveform(
        for asset: AVAsset,
        config: WaveformConfiguration,
        completion: @escaping (Result<[Float], Error>) -> Void
    ) {
        getWaveform(for: asset, sampleCount: config.sampleCount, completion: completion)
    }
}

// MARK: - WaveformConfiguration

struct WaveformConfiguration {
    let sampleCount: Int
    let normalizeAmplitude: Bool
    
    init(sampleCount: Int = 200, normalizeAmplitude: Bool = true) {
        self.sampleCount = sampleCount
        self.normalizeAmplitude = normalizeAmplitude
    }
}
