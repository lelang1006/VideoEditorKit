import UIKit
import Combine
import VideoEditor

public protocol VideoControlProtocol: UIViewController {
    var onDismiss: PassthroughSubject<Void, Never> { get }
    
    func configure(with videoControl: VideoControl)
    func resetToInitialValues()
}
