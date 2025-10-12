//
//  NoHouseholdsView.swift
//  Settings
//
//  Created by Tom Knighton on 12/10/2025.
//

import SwiftUI
import API
import Design

public struct NoHouseholdsView: View {
    
    @Environment(HouseholdService.self) private var households
    
    public var body: some View {
        ZStack {
            Color.layer1.ignoresSafeArea()
            
            VStack {
                ContentUnavailableView("Create a Home", systemImage: "house.fill", description: Text("Create a joined home and share recipes, mealplans, and more with your family or friends."))
                    .fixedSize(horizontal: false, vertical: true)
                
                Button(action: {
                    Task {
                        let _ = await households.create(named: "My Home")
                    }
                }) {
                    Label("Start Home", systemImage: "plus")
                        .bold()
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
                .tint(.blue)
                .buttonSizing(.flexible)
            }
            .scenePadding()
        }
        
    }
}
