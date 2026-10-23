//
//  Item.swift
//  Golf101
//
//  Created by Hsiaoyi Chen on 2026/10/23.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
