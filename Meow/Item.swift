//
//  Item.swift
//  Meow
//
//  Created by boyyang on 2026/7/4.
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
