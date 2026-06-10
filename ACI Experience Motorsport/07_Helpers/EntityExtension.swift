//
//  EntityExtension.swift
//
//  Created by Jacques André on 10/10/25.
//

import Foundation
import SwiftUI
import RealityKit

extension Entity {
    // MARK: - Hierarchy Traversal
    
    /// Enumerates the entity hierarchy with early termination support.
    ///
    /// Visits each entity in the hierarchy, passing it to the provided closure along with a stop flag.
    /// Setting the stop flag to true halts traversal immediately without visiting remaining entities.
    func enumerateHierarchy(_ body: (Entity, UnsafeMutablePointer<Bool>) -> Void) {
        var stop = false
        func enumerate(_ body: (Entity, UnsafeMutablePointer<Bool>) -> Void) {
            guard !stop else { return }
            body(self, &stop)
            for child in children where !stop {
                child.enumerateHierarchy(body)
            }
        }
        enumerate(body)
    }
}
