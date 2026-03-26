//
//  ShoppingItemDragPayload.swift
//  ShoppingLists
//
//  Created by Tom Knighton on 21/03/2026.
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ShoppingItemDragPayload: Codable, Hashable, Transferable {
    let itemId: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .shoppingItemDragPayload)
    }
}

private extension UTType {
    static let shoppingItemDragPayload = UTType(exportedAs: "com.sporkcast.shopping-item")
}
