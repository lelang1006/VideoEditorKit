//
//  VideoEditorTests+Filter.swift
//  VideoEditorKitTests
//
//  Created by VideoEditorKit on 28.06.25.
//

import XCTest
import AVFoundation
@testable import VideoEditorKit

extension VideoEditorKitTests {
    
    func testFilterApplicationLogic() {
        let videoEditor = VideoEditor()
        
        // Test debug method
        videoEditor.debugFilterLogic()
        
        // Test VideoEdit with filter
        var videoEdit = VideoEdit()
        XCTAssertNil(videoEdit.filter, "Initial filter should be nil")
        
        // Set filter
        videoEdit.filter = .sepiaTone
        XCTAssertEqual(videoEdit.filter, .sepiaTone, "Filter should be set to sepiaTone")
        
        // Test filter properties
        XCTAssertEqual(VideoFilter.sepiaTone.name, "Sepia Tone")
        XCTAssertEqual(VideoFilter.sepiaTone.ciFilterName, "CISepiaTone")
        XCTAssertTrue(VideoFilter.sepiaTone.hasParameters)
        XCTAssertFalse(VideoFilter.sepiaTone.defaultParameters.isEmpty)
        
        // Test lens
        let newEdit = VideoEdit.filterLens.to(.noir, videoEdit)
        XCTAssertEqual(newEdit.filter, .noir, "Filter should be updated to noir via lens")
        XCTAssertEqual(videoEdit.filter, .sepiaTone, "Original edit should remain unchanged")
    }
    
    func testFilterCompositionInstruction() {
        let instruction = FilterVideoCompositionInstruction(
            filterName: "CISepiaTone",
            filterParameters: ["inputIntensity": 1.0]
        )
        
        XCTAssertEqual(instruction.filterName, "CISepiaTone")
        XCTAssertEqual(instruction.filterParameters["inputIntensity"] as? Double, 1.0)
        XCTAssertEqual(instruction.timeRange, .zero)
        XCTAssertFalse(instruction.enablePostProcessing)
        XCTAssertEqual(instruction.passthroughTrackID, kCMPersistentTrackID_Invalid)
    }
}
