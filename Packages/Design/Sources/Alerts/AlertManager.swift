//
//  AlertManager.swift
//  Design
//
//  Created by Tom Knighton on 12/10/2025.
//

import SwiftUI
import Observation

@Observable
@MainActor
public final class AlertManager {
    
    public static let shared = AlertManager()
        
    public var isShowingAlert: Bool = false
    public var title: String = "Something Went Wrong"
    public var message: String? = "Please try again."
    
    public init() {}
    
    public func show(title: String, message: String? = nil) {
        self.title = title
        self.message = message
        isShowingAlert = true
    }
        
    public func clear() {
        self.isShowingAlert = false
    }
}
