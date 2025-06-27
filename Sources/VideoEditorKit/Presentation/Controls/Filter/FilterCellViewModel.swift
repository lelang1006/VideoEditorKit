//
//  FilterCellViewModel.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 27.06.25.
//

import Foundation

struct FilterCellViewModel: Hashable {
    let filter: VideoFilter
    let isSelected: Bool
    
    var name: String { filter.name }
    var thumbnailImageName: String { filter.thumbnailImageName }
    var category: FilterCategory { filter.category }
}
