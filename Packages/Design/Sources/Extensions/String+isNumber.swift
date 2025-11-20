//
//  String+isNumber.swift
//  Design
//
//  Created by Tom Knighton on 20/09/2025.
//

import Foundation

public extension String  {
    var isNumber: Bool {
        return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }
}
