//
//  FilterVideoCompositor.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 28.06.25.
//

import AVFoundation
import CoreImage
import CoreVideo

/// Custom video composition instruction that carries filter information
final class FilterVideoCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    
    let filterName: String
    let filterParameters: [String: Any]
    
    var timeRange: CMTimeRange = .zero
    var enablePostProcessing: Bool = false
    var containsTweening: Bool = false
    var requiredSourceTrackIDs: [NSValue]? = nil
    var passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
    var layerInstructions: [AVVideoCompositionLayerInstruction] = []
    
    init(filterName: String, filterParameters: [String: Any]) {
        self.filterName = filterName
        self.filterParameters = filterParameters
        super.init()
    }
}

/// Custom video compositor that applies CoreImage filters to video frames
final class FilterVideoCompositor: NSObject, AVVideoCompositing {
    
    // MARK: - Properties
    
    private let ciContext: CIContext
    private let renderQueue = DispatchQueue(label: "FilterVideoCompositor.renderQueue", qos: .userInitiated)
    
    // MARK: - AVVideoCompositing Protocol
    
    var sourcePixelBufferAttributes: [String : Any]? {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferOpenGLESCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }
    
    var requiredPixelBufferAttributesForRenderContext: [String : Any] {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferOpenGLESCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }
    
    // MARK: - Init
    
    override init() {
        // Create CIContext for rendering
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            ciContext = CIContext(mtlDevice: metalDevice)
        } else {
            ciContext = CIContext(options: [
                .workingColorSpace: NSNull(),
                .outputColorSpace: NSNull()
            ])
        }
        super.init()
    }
    
    // MARK: - AVVideoCompositing Methods
    
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        // Called when render context changes
    }
    
    func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        renderQueue.async { [weak self] in
            self?.processRequest(asyncVideoCompositionRequest)
        }
    }
    
    func cancelAllPendingVideoCompositionRequests() {
        // Cancel any pending requests
        renderQueue.async {
            // Implementation for canceling requests if needed
        }
    }
    
    // MARK: - Private Methods
    
    private func processRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? FilterVideoCompositionInstruction else {
            // Fallback to passthrough for non-filter instructions
            self.passthroughRequest(request)
            return
        }
        
        guard let sourceTrackID = instruction.layerInstructions.first?.trackID,
              let sourcePixelBuffer = request.sourceFrame(byTrackID: sourceTrackID) else {
            request.finish(with: NSError(domain: "FilterVideoCompositor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get source frame"]))
            return
        }
        
        // Get filter info from instruction
        let filterName = instruction.filterName
        let filterParameters = instruction.filterParameters
        
        // Create output pixel buffer
        let renderContext = request.renderContext
        guard let outputPixelBuffer = renderContext.newPixelBuffer() else {
            request.finish(with: NSError(domain: "FilterVideoCompositor", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create output buffer"]))
            return
        }
        
        // Create CIImage from source
        let sourceImage = CIImage(cvPixelBuffer: sourcePixelBuffer)
        
        // Apply filter if specified
        let outputImage: CIImage
        if let filter = CIFilter(name: filterName) {
            filter.setValue(sourceImage, forKey: kCIInputImageKey)
            
            // Apply filter parameters with error handling
            for (key, value) in filterParameters {
                do {
                    filter.setValue(value, forKey: key)
                } catch {
                    print("Warning: Failed to set filter parameter \(key): \(error)")
                }
            }
            
            outputImage = filter.outputImage ?? sourceImage
        } else {
            print("Warning: Failed to create filter with name: \(filterName)")
            outputImage = sourceImage
        }
        
        // Render to output buffer with bounds checking
        let outputExtent = outputImage.extent
        let renderRect = CGRect(origin: .zero, size: CGSize(width: CVPixelBufferGetWidth(outputPixelBuffer), height: CVPixelBufferGetHeight(outputPixelBuffer)))
        
        ciContext.render(outputImage, to: outputPixelBuffer, bounds: renderRect, colorSpace: nil)
        
        // Finish request
        request.finish(withComposedVideoFrame: outputPixelBuffer)
    }
    
    private func passthroughRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        // For non-filter instructions, pass through the source frame
        guard let sourceTrackIDs = request.videoCompositionInstruction.requiredSourceTrackIDs,
              let firstTrackIDValue = sourceTrackIDs.first else {
            request.finish(with: NSError(domain: "FilterVideoCompositor", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to get source track ID for passthrough"]))
            return
        }
        
        var trackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
        firstTrackIDValue.getValue(&trackID)
        
        guard let sourcePixelBuffer = request.sourceFrame(byTrackID: trackID) else {
            request.finish(with: NSError(domain: "FilterVideoCompositor", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to get source frame for passthrough"]))
            return
        }
        
        request.finish(withComposedVideoFrame: sourcePixelBuffer)
    }
}
