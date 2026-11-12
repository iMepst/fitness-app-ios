//
//  Item.swift
//  Fitness App
//
//  Created by Markus Epstein on 12.11.26.
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
