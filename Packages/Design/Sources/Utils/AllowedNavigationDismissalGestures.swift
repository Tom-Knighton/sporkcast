//
//  AllowedNavigationDismissalGestures.swift
//  Design
//
//  Created by Tom Knighton on 01/01/2026.
//  From https://gist.github.com/DabbyNdubisi/c4045a0231435c22be887cb6d9109507
//


import SwiftUI
import UIKit
import Foundation

// MARK: - AllowedNavigationDismissalGestures

public struct AllowedNavigationDismissalGestures: OptionSet, Sendable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let none: AllowedNavigationDismissalGestures = []
    
    /// Default behaviour
    public static let all: AllowedNavigationDismissalGestures = [.swipeToGoBack, .zoomTransitionGesturesOnly]
    
    /// Includes both regular left-right swipe to go back and edge-pan for zoom transition dismisall
    public static let edgePanGesturesOnly: AllowedNavigationDismissalGestures = [.swipeToGoBack, .zoomEdgePanToDismiss]
    
    /// Includes all zoom transition gestures: edge-pan, swipe-down, pinch
    public static let zoomTransitionGesturesOnly: AllowedNavigationDismissalGestures = [.zoomEdgePanToDismiss, .zoomSwipeDownToDismiss, .zoomPinchToDismiss]
    
    public static let swipeToGoBack = AllowedNavigationDismissalGestures(rawValue: 1 << 0)
    public static let zoomEdgePanToDismiss = AllowedNavigationDismissalGestures(rawValue: 1 << 1)
    public static let zoomSwipeDownToDismiss = AllowedNavigationDismissalGestures(rawValue: 1 << 2)
    public static let zoomPinchToDismiss = AllowedNavigationDismissalGestures(rawValue: 1 << 3)
}

public extension View {
    func navigationAllowDismissalGestures(_ gestures: AllowedNavigationDismissalGestures = .all) -> some View {
        modifier(NavigationAllowedDismissalGesturesModifier(allowedDismissalGestures: gestures))
    }
}

// MARK: - NavigationAllowedDismissalGesturesModifier

private struct NavigationAllowedDismissalGesturesModifier: ViewModifier {
    var allowedDismissalGestures: AllowedNavigationDismissalGestures
    
    func body(content: Content) -> some View {
        content
            .background(
                NavigationDismissalGestureUpdater(allowedDismissalGestures: allowedDismissalGestures)
                    .frame(width: .zero, height: .zero)
            )
    }
}

// MARK: - NavigationDismissalGestureUpdater

private struct NavigationDismissalGestureUpdater: UIViewControllerRepresentable {
    @State private var viewMountRetryCount = 0
    
    var allowedDismissalGestures: AllowedNavigationDismissalGestures
    
    func makeUIViewController(context: Context) -> UIViewController { .init() }
    
    func updateUIViewController(_ viewController: UIViewController, context: Context) {
        Task { @MainActor in
            guard
                let parentVC = viewController.parent,
                let navigationController = parentVC.navigationController
            else {
                // updateUIViewController could get called a bit too early
                // before the view heirarchy has been fully setup
                if viewMountRetryCount < Constants.maxRetryCountForNavigationHeirarchy {
                    viewMountRetryCount += 1
                    try await Task.sleep(for: .milliseconds(100))
                    return updateUIViewController(viewController, context: context)
                } else {
                    // unable to find navigation controller
                    return
                }
            }
            
            guard navigationController.topViewController == parentVC else {
                return
            }
            
            navigationController.interactivePopGestureRecognizer?.isEnabled = allowedDismissalGestures.contains(.swipeToGoBack)
            
            let viewLevelGestures = parentVC.view.gestureRecognizers ?? []
            for gesture in viewLevelGestures {
                switch String(describing: type(of: gesture)) {
                case Constants.zoomEdgePanToDismissClassType:
                    gesture.isEnabled = allowedDismissalGestures.contains(.zoomEdgePanToDismiss)
                    
                case Constants.zoomSwipeDownToDismissClassType:
                    gesture.isEnabled = allowedDismissalGestures.contains(.zoomSwipeDownToDismiss)
                    
                case Constants.zoomPinchToDismissClassType:
                    gesture.isEnabled = allowedDismissalGestures.contains(.zoomPinchToDismiss)
                    
                default:
                    continue
                }
            }
        }
    }
    
    static func dismantleUIViewController(_ viewController: UIViewController, coordinator: Coordinator) {
        viewController.parent?.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        (viewController.parent?.view.gestureRecognizers ?? []).forEach({ gesture in
            if Constants.navigationZoomGestureTypeClasses.contains(String(describing: type(of: gesture))) {
                gesture.isEnabled = true
            }
        })
    }
    
    // MARK: Private
    
    private enum Constants {
        static let maxRetryCountForNavigationHeirarchy = 2
        
        // MARK: - Base64 decode helper
        
        @inline(__always)
        private static func decodeBase64(_ value: String) -> String {
            guard
                let data = Data(base64Encoded: value),
                let decoded = String(data: data, encoding: .utf8)
            else {
                assertionFailure("Failed to decode base64 string.")
                return ""
            }
            return decoded
        }
        
        @inline(__always)
        private static func obfuscatedTypeName(_ p1: String, _ p2: String, _ p3: String) -> String {
            decodeBase64(p1) + decodeBase64(p2) + decodeBase64(p3)
        }
        
        // MARK: - Obfuscated UIKit private gesture recognizer type names
        
        // "-UIParallaxTransitionPanGestureRecognizer"
        static let zoomEdgePanToDismissClassType: String = obfuscatedTypeName(
            "X1VJUGFyYWxsYXhU",
            "cmFuc2l0aW9uUGFuR2Vz",
            "dHVyZVJlY29nbml6ZXI="
        )
        
        static let zoomSwipeDownToDismissClassType: String = {
            if #available(iOS 26, *) {
                // "-UIContentSwipeDismissGestureRecognizer"
                return obfuscatedTypeName(
                    "X1VJQ29udGVudA==",
                    "U3dpcGVEaXNtaXNzR2U=",
                    "c3R1cmVSZWNvZ25pemVy"
                )
            } else {
                // "-UISwipeDownGestureRecognizer"
                return obfuscatedTypeName(
                    "X1VJU3dpcGU=",
                    "RG93bkdlc3R1",
                    "cmVSZWNvZ25pemVy"
                )
            }
        }()
        
        // "-UITransformGestureRecognizer"
        static let zoomPinchToDismissClassType: String = obfuscatedTypeName(
            "X1VJVHJhbnNmb3I=",
            "bUdlc3R1cg==",
            "ZVJlY29nbml6ZXI="
        )
        
        static let navigationZoomGestureTypeClasses: Set<String> = [
            zoomEdgePanToDismissClassType,
            zoomSwipeDownToDismissClassType,
            zoomPinchToDismissClassType,
        ]
    }

}
