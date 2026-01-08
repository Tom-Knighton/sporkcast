//
//  View+Transform.swift
//  Design
//
//  Created by Tom Knighton on 04/01/2026.
//

import SwiftUI

public extension View {
    func transform(@ViewBuilder content: (_ view: Self) -> some View) -> some View {
        content(self)
    }
}
