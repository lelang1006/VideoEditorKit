//
//  TimelineAnimationSystem.swift
//  
//
//  Created by VideoEditorKit on 29.06.25.
//

import UIKit
import AVFoundation

// MARK: - Timeline Animation System

class TimelineAnimationSystem {
    
    // MARK: - Animation Constants
    
    struct AnimationConstants {
        static let defaultDuration: TimeInterval = 0.3
        static let springDamping: CGFloat = 0.8
        static let springVelocity: CGFloat = 0.6
        static let selectionScale: CGFloat = 1.05
        static let dragScale: CGFloat = 1.08
        static let resizeScale: CGFloat = 1.02
        static let shadowOpacity: Float = 0.3
        static let pulseScale: CGFloat = 1.1
        static let bounceScale: CGFloat = 0.95
    }
    
    // MARK: - Selection Animations
    
    static func animateSelection(_ view: UIView, selected: Bool, completion: (() -> Void)? = nil) {
        let scale = selected ? AnimationConstants.selectionScale : 1.0
        let shadowOpacity = selected ? AnimationConstants.shadowOpacity : 0.0
        
        UIView.animate(
            withDuration: AnimationConstants.defaultDuration,
            delay: 0,
            usingSpringWithDamping: AnimationConstants.springDamping,
            initialSpringVelocity: AnimationConstants.springVelocity,
            options: [.allowUserInteraction, .curveEaseOut]
        ) {
            view.transform = CGAffineTransform(scaleX: scale, y: scale)
            view.layer.shadowOpacity = shadowOpacity
        } completion: { _ in
            completion?()
        }
    }
    
    // MARK: - Drag Animations
    
    static func animateDragStart(_ view: UIView) {
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: [.allowUserInteraction, .curveEaseOut]
        ) {
            view.transform = CGAffineTransform(scaleX: AnimationConstants.dragScale, y: AnimationConstants.dragScale)
            view.alpha = 0.9
            view.layer.shadowOpacity = AnimationConstants.shadowOpacity + 0.2
            view.layer.shadowRadius = 8
        }
    }
    
    static func animateDragEnd(_ view: UIView, velocity: CGPoint, completion: (() -> Void)? = nil) {
        let springVelocity = min(abs(velocity.x) / 500, 2.0)
        
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: AnimationConstants.springDamping,
            initialSpringVelocity: springVelocity,
            options: [.allowUserInteraction]
        ) {
            view.transform = .identity
            view.alpha = 1.0
            view.layer.shadowOpacity = view.isSelected ? AnimationConstants.shadowOpacity : 0
            view.layer.shadowRadius = 4
        } completion: { _ in
            completion?()
        }
    }
    
    // MARK: - Resize Animations
    
    static func animateResizeStart(_ view: UIView) {
        let theme = TimelineTheme.current
        UIView.animate(
            withDuration: 0.15,
            delay: 0,
            options: [.allowUserInteraction, .curveEaseOut]
        ) {
            view.layer.borderWidth = 3
            view.layer.borderColor = theme.resizeHandleColor.cgColor
        }
    }
    
    static func animateResizeEnd(_ view: UIView, completion: (() -> Void)? = nil) {
        let theme = TimelineTheme.current
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.allowUserInteraction, .curveEaseInOut]
        ) {
            view.layer.borderWidth = view.isSelected ? 2 : 0
            view.layer.borderColor = theme.selectionBorderColor.cgColor
        } completion: { _ in
            completion?()
        }
    }
    
    // MARK: - Snap Animations
    
    static func animateSnapFeedback(_ view: UIView) {
        let originalTransform = view.transform
        
        UIView.animateKeyframes(
            withDuration: 0.3,
            delay: 0,
            options: [.allowUserInteraction]
        ) {
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.3) {
                view.transform = originalTransform.scaledBy(x: AnimationConstants.pulseScale, y: AnimationConstants.pulseScale)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.3, relativeDuration: 0.4) {
                view.transform = originalTransform.scaledBy(x: AnimationConstants.bounceScale, y: AnimationConstants.bounceScale)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.7, relativeDuration: 0.3) {
                view.transform = originalTransform
            }
        }
    }
    
    // MARK: - Item Addition/Removal Animations
    
    static func animateItemAddition(_ view: UIView, completion: (() -> Void)? = nil) {
        view.alpha = 0
        view.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.8,
            options: [.allowUserInteraction]
        ) {
            view.alpha = 1
            view.transform = .identity
        } completion: { _ in
            completion?()
        }
    }
    
    static func animateItemRemoval(_ view: UIView, completion: (() -> Void)? = nil) {
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [.curveEaseInOut]
        ) {
            view.alpha = 0
            view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        } completion: { _ in
            view.removeFromSuperview()
            completion?()
        }
    }
    
    // MARK: - Playhead Animations
    
    static func animatePlayheadMovement(_ view: UIView, to position: CGFloat, duration: TimeInterval = 0.2) {
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            view.center.x = position
        }
    }
    
    // MARK: - Track Animations
    
    static func animateTrackExpansion(_ view: UIView, expanded: Bool, completion: (() -> Void)? = nil) {
        let scale: CGFloat = expanded ? 1.02 : 1.0
        let alpha: CGFloat = expanded ? 1.0 : 0.9
        
        UIView.animate(
            withDuration: AnimationConstants.defaultDuration,
            delay: 0,
            usingSpringWithDamping: AnimationConstants.springDamping,
            initialSpringVelocity: 0
        ) {
            view.transform = CGAffineTransform(scaleX: scale, y: scale)
            view.alpha = alpha
        } completion: { _ in
            completion?()
        }
    }
    
    // MARK: - Zoom Animations
    
    static func animateZoom(_ scrollView: UIScrollView, to zoomScale: CGFloat, completion: (() -> Void)? = nil) {
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0
        ) {
            scrollView.zoomScale = zoomScale
        } completion: { _ in
            completion?()
        }
    }
    
    // MARK: - Error/Validation Animations
    
    static func animateValidationError(_ view: UIView) {
        let originalColor = view.backgroundColor
        let theme = TimelineTheme.current
        
        UIView.animateKeyframes(
            withDuration: 0.6,
            delay: 0,
            options: [.allowUserInteraction]
        ) {
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.2) {
                view.backgroundColor = theme.deleteButtonColor.withAlphaComponent(0.3)
                view.transform = CGAffineTransform(translationX: -5, y: 0)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.2, relativeDuration: 0.2) {
                view.transform = CGAffineTransform(translationX: 5, y: 0)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.4, relativeDuration: 0.2) {
                view.transform = CGAffineTransform(translationX: -3, y: 0)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.6, relativeDuration: 0.2) {
                view.transform = CGAffineTransform(translationX: 3, y: 0)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.8, relativeDuration: 0.2) {
                view.backgroundColor = originalColor
                view.transform = .identity
            }
        }
    }
}

// MARK: - UIView Animation Extensions

extension UIView {
    
    var isSelected: Bool {
        get {
            return layer.borderWidth > 0
        }
    }
    
    func pulseAnimation() {
        TimelineAnimationSystem.animateSnapFeedback(self)
    }
    
    func shakeAnimation() {
        TimelineAnimationSystem.animateValidationError(self)
    }
}

// MARK: - Haptic Feedback System

class TimelineHapticFeedback {
    
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    static func prepareGenerators() {
        selectionGenerator.prepare()
        impactGenerator.prepare()
        heavyImpactGenerator.prepare()
    }
    
    static func selection() {
        selectionGenerator.selectionChanged()
    }
    
    static func lightImpact() {
        impactGenerator.impactOccurred()
    }
    
    static func heavyImpact() {
        heavyImpactGenerator.impactOccurred()
    }
    
    static func snap() {
        lightImpact()
    }
    
    static func dragStart() {
        lightImpact()
    }
    
    static func dragEnd() {
        selection()
    }
    
    static func delete() {
        heavyImpact()
    }
}
