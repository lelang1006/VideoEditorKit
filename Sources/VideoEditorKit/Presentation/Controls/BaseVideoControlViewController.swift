import UIKit
import Combine
import PureLayout

open class BaseVideoControlViewController: UIViewController, VideoControlProtocol {
    
    // MARK: VideoControlProtocol
    public var onDismiss = PassthroughSubject<Void, Never>()
    
    // MARK: UI Components - Protected for subclasses
    lazy var borderTop: UIView = makeBorderTop()
    lazy var titleStack: UIStackView = makeTitleStackView()
    lazy var titleImageView: UIImageView = makeTitleImageView()
    lazy var titleLabel: UILabel = makeTitleLabel()
    lazy var dismissButton: UIButton = makeDismissButton()
    lazy var closeButton: UIButton = makeCloseButton()
    
    // MARK: Content View - Subclasses will add their content here
    lazy var contentView: UIView = makeContentView()
    
    // MARK: Properties
    var cancellables = Set<AnyCancellable>()
    private var videoControl: VideoControl?
    
    // MARK: Life Cycle
    open override func viewDidLoad() {
        super.viewDidLoad()
        setupBaseUI()
        setupContentView()
        setupBaseConstraints()
    }
    
    // MARK: Abstract Methods - Subclasses can override
    open func setupContentView() {
        // Subclasses should override this to add their specific content
    }
    
    open func onApplyAction() {
        // Subclasses should override this for apply logic
        onDismiss.send()
    }
    
    open func onCloseAction() {
        // Subclasses should override this for close/cancel logic
        resetToInitialValues()
        DispatchQueue.main.async { [weak self] in
            self?.onDismiss.send()
        }
    }
    
    // MARK: VideoControlProtocol Implementation
    open func configure(with videoControl: VideoControl) {
        self.videoControl = videoControl
        titleLabel.text = videoControl.title
        titleImageView.image = UIImage(named: videoControl.titleImageName, in: .module, compatibleWith: nil)
    }
    
    open func resetToInitialValues() {
        // Subclasses should override this
    }
}

// MARK: Base UI Setup
private extension BaseVideoControlViewController {
    func setupBaseUI() {
        view.backgroundColor = .white
        
        view.addSubview(borderTop)
        view.addSubview(titleStack)
        view.addSubview(contentView)
        view.addSubview(dismissButton)
        view.addSubview(closeButton)
    }
    
    func setupBaseConstraints() {
        // Border top
        borderTop.autoPinEdge(toSuperviewEdge: .left)
        borderTop.autoPinEdge(toSuperviewEdge: .right)
        borderTop.autoPinEdge(toSuperviewEdge: .top)
        borderTop.autoSetDimension(.height, toSize: 1.0)
        
        // Title stack
        titleImageView.autoSetDimension(.height, toSize: 20.0)
        titleImageView.autoSetDimension(.width, toSize: 20.0)
        
        titleStack.autoPinEdge(.top, to: .bottom, of: borderTop, withOffset: 20.0)
        titleStack.autoAlignAxis(toSuperviewAxis: .vertical)
        titleStack.autoSetDimension(.height, toSize: 20.0)
        
        // Content view
        contentView.autoPinEdge(.top, to: .bottom, of: titleStack, withOffset: 20.0)
        contentView.autoPinEdge(toSuperviewEdge: .left)
        contentView.autoPinEdge(toSuperviewEdge: .right)
        contentView.autoPinEdge(.bottom, to: .top, of: dismissButton, withOffset: -20.0)
        
        // Buttons
        dismissButton.autoPinEdge(toSuperviewSafeArea: .bottom, withInset: 0.0)
        dismissButton.autoPinEdge(toSuperviewEdge: .right, withInset: 20.0)
        closeButton.autoPinEdge(toSuperviewSafeArea: .bottom, withInset: 0.0)
        closeButton.autoPinEdge(toSuperviewEdge: .left, withInset: 20.0)
    }
}

// MARK: UI Factory Methods
private extension BaseVideoControlViewController {
    func makeBorderTop() -> UIView {
        let view = UIView()
        view.backgroundColor = .border
        return view
    }
    
    func makeTitleStackView() -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [
            titleImageView,
            titleLabel
        ])
        
        stack.spacing = 10.0
        stack.axis = .horizontal
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        return stack
    }
    
    func makeTitleLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13.0, weight: .medium)
        label.textColor = #colorLiteral(red: 0.1137254902, green: 0.1137254902, blue: 0.1215686275, alpha: 1)
        return label
    }
    
    func makeTitleImageView() -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.tintColor = #colorLiteral(red: 0.1137254902, green: 0.1137254902, blue: 0.1215686275, alpha: 1)
        return view
    }
    
    func makeDismissButton() -> UIButton {
        let button = UIButton()
        let image = UIImage(named: "Check", in: .module, compatibleWith: nil)
        button.setImage(image, for: .normal)
        button.tintColor = #colorLiteral(red: 0.1137254902, green: 0.1137254902, blue: 0.1215686275, alpha: 1)
        button.addTarget(self, action: #selector(applyButtonTapped), for: .touchUpInside)
        
        // Tăng vùng touch
        button.contentEdgeInsets = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        
        return button
    }
    
    func makeCloseButton() -> UIButton {
        let button = UIButton()
        let image = UIImage(named: "Close", in: .module, compatibleWith: nil)
        button.setImage(image, for: .normal)
        button.tintColor = #colorLiteral(red: 0.1137254902, green: 0.1137254902, blue: 0.1215686275, alpha: 1)
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        
        // Tăng vùng touch
        button.contentEdgeInsets = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        
        return button
    }
    
    func makeContentView() -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
}

// MARK: Actions
private extension BaseVideoControlViewController {
    @objc func applyButtonTapped() {
        onApplyAction()
    }
    
    @objc func closeButtonTapped() {
        onCloseAction()
    }
}
