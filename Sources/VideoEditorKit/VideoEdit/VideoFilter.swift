//
//  VideoFilter.swift
//  VideoEditorKit
//
//  Created by VideoEditorKit on 27.06.25.
//

import Foundation
import CoreImage

public enum VideoFilter: String, CaseIterable {
    case none = "none"
    
    // Photo Effects
    case chrome = "chrome"
    case fade = "fade"
    case instant = "instant"
    case noir = "noir"
    case process = "process"
    case tonal = "tonal"
    case transfer = "transfer"
    
    // Color Adjustments
    case sepiaTone = "sepiaTone"
    case colorClamp = "colorClamp"
    case colorInvert = "colorInvert"
    case colorMonochrome = "colorMonochrome"
    case colorPosterize = "colorPosterize"
    case luminance = "luminance"
    
    // Blur Effects
    case boxBlur = "boxBlur"
    case discBlur = "discBlur"
    case gaussianBlur = "gaussianBlur"
    case maskedVariableBlur = "maskedVariableBlur"
    case medianFilter = "medianFilter"
    case motionBlur = "motionBlur"
    case noiseReduction = "noiseReduction"
    
    // Light Effects
    case spotLight = "spotLight"
    
    public var name: String {
        switch self {
        case .none: return "None"
        case .chrome: return "Chrome"
        case .fade: return "Fade"
        case .instant: return "Instant"
        case .noir: return "Noir"
        case .process: return "Process"
        case .tonal: return "Tonal"
        case .transfer: return "Transfer"
        case .sepiaTone: return "Sepia Tone"
        case .colorClamp: return "Color Clamp"
        case .colorInvert: return "Color Invert"
        case .colorMonochrome: return "Monochrome"
        case .colorPosterize: return "Posterize"
        case .luminance: return "Luminance"
        case .boxBlur: return "Box Blur"
        case .discBlur: return "Disc Blur"
        case .gaussianBlur: return "Gaussian Blur"
        case .maskedVariableBlur: return "Variable Blur"
        case .medianFilter: return "Median Filter"
        case .motionBlur: return "Motion Blur"
        case .noiseReduction: return "Noise Reduction"
        case .spotLight: return "Spot Light"
        }
    }
    
    public var ciFilterName: String? {
        switch self {
        case .none: return nil
        case .chrome: return "CIPhotoEffectChrome"
        case .fade: return "CIPhotoEffectFade"
        case .instant: return "CIPhotoEffectInstant"
        case .noir: return "CIPhotoEffectNoir"
        case .process: return "CIPhotoEffectProcess"
        case .tonal: return "CIPhotoEffectTonal"
        case .transfer: return "CIPhotoEffectTransfer"
        case .sepiaTone: return "CISepiaTone"
        case .colorClamp: return "CIColorClamp"
        case .colorInvert: return "CIColorInvert"
        case .colorMonochrome: return "CIColorMonochrome"
        case .colorPosterize: return "CIColorPosterize"
        case .luminance: return "CILuminosityBlendMode"
        case .boxBlur: return "CIBoxBlur"
        case .discBlur: return "CIDiscBlur"
        case .gaussianBlur: return "CIGaussianBlur"
        case .maskedVariableBlur: return "CIMaskedVariableBlur"
        case .medianFilter: return "CIMedianFilter"
        case .motionBlur: return "CIMotionBlur"
        case .noiseReduction: return "CINoiseReduction"
        case .spotLight: return "CISpotLight"
        }
    }
    
    public var category: FilterCategory {
        switch self {
        case .none:
            return .none
        case .chrome, .fade, .instant, .noir, .process, .tonal, .transfer:
            return .photoEffects
        case .sepiaTone, .colorClamp, .colorInvert, .colorMonochrome, .colorPosterize, .luminance:
            return .colorAdjustments
        case .boxBlur, .discBlur, .gaussianBlur, .maskedVariableBlur, .medianFilter, .motionBlur, .noiseReduction:
            return .blur
        case .spotLight:
            return .lightEffects
        }
    }
    
    public var hasParameters: Bool {
        switch self {
        case .none, .chrome, .fade, .instant, .noir, .process, .tonal, .transfer, .colorInvert:
            return false
        default:
            return true
        }
    }
    
    public var defaultParameters: [String: Any] {
        switch self {
        case .sepiaTone:
            return ["inputIntensity": 1.0]
        case .colorMonochrome:
            return ["inputIntensity": 1.0, "inputColor": CIColor.gray]
        case .colorPosterize:
            return ["inputLevels": 6.0]
        case .boxBlur, .discBlur, .gaussianBlur:
            return ["inputRadius": 10.0]
        case .motionBlur:
            return ["inputRadius": 20.0, "inputAngle": 0.0]
        case .spotLight:
            return ["inputBrightness": 3.0, "inputConcentration": 0.1]
        default:
            return [:]
        }
    }
}

public enum FilterCategory: String, CaseIterable {
    case none = "none"
    case photoEffects = "photoEffects"
    case colorAdjustments = "colorAdjustments"
    case blur = "blur"
    case lightEffects = "lightEffects"
    
    public var name: String {
        switch self {
        case .none: return "None"
        case .photoEffects: return "Photo Effects"
        case .colorAdjustments: return "Color"
        case .blur: return "Blur"
        case .lightEffects: return "Light"
        }
    }
    
    public var filters: [VideoFilter] {
        return VideoFilter.allCases.filter { $0.category == self }
    }
}
