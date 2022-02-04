//
//  LocalNotificationBannerView.swift
//  LocalNoficaionsService
//
//  Created by Sivash Alexander Alexeevich on 21.10.2021.
//

import Foundation
import UIKit

open class LocalNotificationBannerView: UIView {
    
    let bannerID = UUID()
    var heightFixConstraint: NSLayoutConstraint?
    var widthFixConstraint: NSLayoutConstraint?
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    internal var isMarkedForDismiss: Bool = false
    internal func loadContentViewIfNeeded() { _ = contentView }
    public internal(set) lazy var contentView: UIView = {
        let contentView = loadContentView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        //also add gesture
        let gesture = UIPanGestureRecognizer()
        gesture.addTarget(self, action: #selector(pan(gesture:)))
        interactiveDismissPanGestureRecognizer = gesture
        gesture.isEnabled = isDismissableByPanGesture
        addGestureRecognizer(gesture)
        
        return contentView
    }()
    
    ///Override to specify custom banner content, you must not call super.loadContentView()
    open func loadContentView() -> UIView {
        assertionFailure("LocalNotificationBannerView must override loadContentView()")
        return UIView()
    }
    
    /// Override or set on init to
    open var autoDismissMode: AutoDissmissMode = .after(time: 6)
    var startTime: TimeInterval?
    weak var interactiveDismissPanGestureRecognizer: UIPanGestureRecognizer?
    public enum AutoDissmissMode {
        case none
        case after(time: TimeInterval)
    }
    
    public func dismiss() {
        isMarkedForDismiss = true
        LocalNotificationBannerService.updateBannersInvocations()
    }
    
    ///When actually pushed to screen
    open func didAppear() { }
    
    ///when dismissed from screen
    open func didDisappear() { }
    
    var interactionFrameStart: CGPoint = .zero
    var currentlyKnownGestureRecognizerTranslation: CGPoint = .zero
    var isInteractionInProgress: Bool = false
    
    public func preformTemporaryReleasingHeightLock(block: () -> Void) {
        heightFixConstraint?.isActive = false
        block()
        lockSize()
    }
    
    func lockSize() {
        
        let height = systemLayoutSizeFitting(
            CGSize(width: UIScreen.main.bounds.width, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .defaultLow
        ).height
        
        frame = CGRect(
            origin: .init(x: 0, y: -100-height),
            size: CGSize(
                width: UIScreen.main.bounds.width,
                height: height
            )
        )
        
        heightFixConstraint?.isActive = false
        widthFixConstraint?.isActive = false
        
        heightFixConstraint = heightAnchor.constraint(equalToConstant: height)
        widthFixConstraint = widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width)
        
        heightFixConstraint?.isActive = true
        widthFixConstraint?.isActive = true
    }
    
    public var isDismissableByPanGesture: Bool = true {
        didSet {
            guard isDismissableByPanGesture != oldValue else { return }
            interactiveDismissPanGestureRecognizer?.isEnabled = isDismissableByPanGesture
        }
    }
    
    ///Adding new banners while one of them is in interacion (and has transform) visually breaks order. Tis thing is called to make things look correct.
    func setCorrectPanDismissTransform() {
        guard isInteractionInProgress else {
            transform = .identity
            return
        }
        
        let frameInIdentity = frame.applying(transform.inverted()).origin
        let correction = CGPoint(x: interactionFrameStart.x - frameInIdentity.x, y: interactionFrameStart.y - frameInIdentity.y)
        var shift = currentlyKnownGestureRecognizerTranslation
        shift.x += correction.x
        shift.y += correction.y
        transform = .init(translationX: shift.x / 1.5, y: shift.y * 1.5)
            
    }
    
    @objc func pan(gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: nil)
        
        switch gesture.state {
            case .began:
                isInteractionInProgress = true
                interactionFrameStart = frame.origin
                layer.zPosition = 100001
            case .changed:
                
                currentlyKnownGestureRecognizerTranslation = translation
                setCorrectPanDismissTransform()
                let h = hypot(translation.x, translation.y) / (UIScreen.main.bounds.width / 3)
                alpha = max(0.5, min(1.0, 1.0 - h))
                
            case .ended, .cancelled, .failed:
                self.isInteractionInProgress = false
                let velocity = gesture.velocity(in: nil)
                
                if gesture.state == .ended && (hypot(translation.x, translation.y) >= UIScreen.main.bounds.width/3 || hypot(velocity.x, velocity.y) >= 800) {
                    isMarkedForDismiss = true
                    isInteractionInProgress = false
                    UIView.animate(withDuration: 0.2, delay: 0.0, options: []) { [weak self] in
                        self?.alpha = 0
                    } completion: { [weak self] _ in
                        LocalNotificationBannerService.updateBannersInvocations()
                        self?.layer.zPosition = 0
                    }
                } else {
                    UIView.animate(withDuration: 0.2, delay: 0.0, options: []) { [weak self] in
                        self?.alpha = 1.0
                        self?.setCorrectPanDismissTransform()
                    } completion: { [weak self] _ in
                        LocalNotificationBannerService.updateBannersInvocations()
                        self?.layer.zPosition = 0
                    }
                }
                
            default:
                break
        }
    }
}
