//
//  LocalNotificationBannerService.swift
//  LocalNoficaionsService
//
//  Created by Sivash Alexander Alexeevich on 21.10.2021.
//

import Foundation
import UIKit

open class LocalNotificationBannerService {
    
    static var topOffsetConstraint: NSLayoutConstraint?
    public static var interBannerSpacing: CGFloat {
        get { return mStackView.spacing }
        set {
            mStackView.spacing = newValue
            topOffsetConstraint?.constant = newValue
        }
    }
    
    public static func push(banner: LocalNotificationBannerView) {
        guard let appWindow = appWindow else { return }
        
        //if stack view is somewhere else - bring it there
        if mStackView.superview != appWindow {
            mStackView.removeFromSuperview()
            appWindow.addSubview(mStackView)
            
            mStackView.leadingAnchor.constraint(equalTo: appWindow.leadingAnchor).isActive = true
            mStackView.trailingAnchor.constraint(equalTo: appWindow.trailingAnchor).isActive = true
            topOffsetConstraint = mStackView.topAnchor.constraint(equalTo: appWindow.safeAreaLayoutGuide.topAnchor, constant: interBannerSpacing)
            topOffsetConstraint?.isActive = true
            
            appWindow.layoutIfNeeded()
        }
        
        bannerWaitQueue.append(banner)
        updateBannersInvocations()
    }
    
    static func prepareBannerToLaunch(banner: LocalNotificationBannerView) {
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.loadContentViewIfNeeded()
        
        banner.lockSize()
        
        banner.setNeedsLayout()
        banner.layoutIfNeeded()
    }
    
    static func launchBanner(banner: LocalNotificationBannerView) {
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.loadContentViewIfNeeded()
        mStackView.insertArrangedSubview(banner, at: 0)
        
        if case .after(let time) = banner.autoDismissMode {
            banner.startTime = Date().timeIntervalSince1970
            DispatchQueue.main.asyncAfter(deadline: .now() + time) {
                self.updateBannersInvocations()
            }
        }
    }
    
    static var bannerWaitQueue: [LocalNotificationBannerView] = []
    static var bannerCurrentlyShowingQueue: [LocalNotificationBannerView] = []
    
    static var isPerformingInvocation = false
    static var didCallInvocationWhileAnimationWasInplace = false
    static func updateBannersInvocations() {
        
        let safeInsets = UIApplication.shared.windows.first?.safeAreaInsets ?? UIEdgeInsets.zero
        let allowedHeight = appWindow?.bounds.inset(by: safeInsets).height ?? 0.0
        var currentHeight = mStackView.bounds.height
        
        if isPerformingInvocation {
            didCallInvocationWhileAnimationWasInplace = true
            return
        } else {
            isPerformingInvocation = true
            didCallInvocationWhileAnimationWasInplace = false
        }
        
        var removeList: [LocalNotificationBannerView] = []
        var addList: [LocalNotificationBannerView] = []
        
        var copy = bannerCurrentlyShowingQueue
        var offsetCorrection: Int = 0
        
        //remove list
        for (bannerIndex, banner) in bannerCurrentlyShowingQueue.enumerated() {
            currentHeight += banner.bounds.height
            
            if banner.isInteractionInProgress {
                continue
            } else if banner.isMarkedForDismiss {
                removeList.append(banner)
                copy.remove(at: bannerIndex - offsetCorrection)
                offsetCorrection += 1
                currentHeight -= banner.bounds.height
            } else if case .after(let time) = banner.autoDismissMode, let startedAt = banner.startTime {
                if startedAt + time <= Date().timeIntervalSince1970 {
                    removeList.append(banner)
                    copy.remove(at: bannerIndex - offsetCorrection)
                    offsetCorrection += 1
                    currentHeight -= banner.bounds.height
                }
            }
        }
        
        bannerCurrentlyShowingQueue = copy
        
        //add list
        
        while let nextBanner = bannerWaitQueue.first {
            prepareBannerToLaunch(banner: nextBanner)
            
            //if there is a banner, that is simply bigger than everything - we must show it.
            //otherwise the queue will never proceed at all
            //Thats why !bannerCurrentlyShowingQueue.isEmpty
            if !bannerCurrentlyShowingQueue.isEmpty && currentHeight + nextBanner.bounds.height > allowedHeight {
                break
            }
            
            bannerWaitQueue.remove(at: 0)
            bannerCurrentlyShowingQueue.append(nextBanner)
            addList.append(nextBanner)
            prepareBannerToLaunch(banner: nextBanner)
            currentHeight += nextBanner.bounds.height
        }
        
        if removeList.isEmpty && addList.isEmpty {
            isPerformingInvocation = false
            return
        }
        
        //Animate
        UIView.animate(withDuration: 0.2, delay: 0.0, options: []) {
            for banner in removeList {
                banner.alpha = 0.0
            }
        } completion: { _ in
            
            for banner in removeList {
                mStackView.removeArrangedSubview(banner)
                banner.removeFromSuperview()
            }
            
            for banner in addList {
                launchBanner(banner: banner)
            }
            
            UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: []) {
                
                mStackView.layoutIfNeeded()
                
                for banner in bannerCurrentlyShowingQueue {
                    if banner.isInteractionInProgress {
                        banner.setCorrectPanDismissTransform()
                    }
                }
                
            } completion: { _ in
                
                self.isPerformingInvocation = false
                if didCallInvocationWhileAnimationWasInplace {
                    self.updateBannersInvocations()
                }
            }
        }
    }
    
    static let mStackView: UIStackView = {
        let stack = UIStackView()
        stack.spacing = 0
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .equalSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.layer.zPosition = 100000
        return stack
    }()
    
    static var appWindow: UIWindow? = {
        return UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
            .map { $0 as? UIWindowScene }
            .map { $0?.windows.first }
        ?? UIApplication.shared.delegate?.window
        ?? UIApplication.shared.keyWindow
    }()
}
