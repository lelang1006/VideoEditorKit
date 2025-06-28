//
//  VideoEditor+Debug.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 28.06.25.
//

import AVFoundation
import Foundation

extension VideoEditor {
    
    /// Debug method để test filter logic
    public func debugFilterLogic() {
        print("=== VideoEditor Filter Logic Debug ===")
        
        // Test các filters có available không
        let filters = VideoFilter.allCases
        print("Total filters available: \(filters.count)")
        
        for filter in filters {
            print("Filter: \(filter.name)")
            print("  Raw value: \(filter.rawValue)")
            print("  CI Filter: \(filter.ciFilterName ?? "none")")
            print("  Category: \(filter.category.name)")
            print("  Has parameters: \(filter.hasParameters)")
            if filter.hasParameters {
                print("  Default parameters: \(filter.defaultParameters)")
            }
            print("---")
        }
        
        // Test VideoEdit với filter
        var videoEdit = VideoEdit()
        videoEdit.filter = .sepiaTone
        print("VideoEdit with sepia filter: \(videoEdit.filter?.name ?? "none")")
        
        // Test lens
        let newEdit = VideoEdit.filterLens.to(.noir, videoEdit)
        print("After applying noir lens: \(newEdit.filter?.name ?? "none")")
        
        print("=== Debug Complete ===")
    }
}
