import UIKit
import Combine

public protocol VideoControlProtocol: UIViewController {
    var onDismiss: PassthroughSubject<Void, Never> { get }
    
    func configure(with videoControl: VideoControl)
    func resetToInitialValues()
}
