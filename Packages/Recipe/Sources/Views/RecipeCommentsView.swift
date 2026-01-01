//
//  RecipeCommentsView.swift
//  Recipe
//
//  Created by Tom Knighton on 01/01/2026.
//

import Models
import SwiftUI

struct RecipeCommentsView: View {
    
    @Environment(RecipeViewModel.self) private var vm
 
    var body: some View {
        Text("Hi \(vm.recipe.ratingInfo?.ratings.count ?? 0) Ratings")
    }
}
