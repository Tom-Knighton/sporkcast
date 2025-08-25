//
//  TitleKey.swift
//  Recipe
//
//  Created by Tom Knighton on 24/08/2025.
//

import Foundation
import SwiftUI

struct TitleBottomYKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
