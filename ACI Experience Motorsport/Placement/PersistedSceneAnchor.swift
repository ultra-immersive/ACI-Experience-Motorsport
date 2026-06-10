//
//  PersistedSceneAnchor.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 09/03/26.
//


import Foundation
import SwiftData

/// Lightweight SwiftData model that stores the UUID of a WorldAnchor.
///
/// Only one instance should exist at a time — the most recent placement.
/// The ``ScenePlacementManager`` creates, queries, and deletes these records
/// as the staff repositions or resets the scene.
@Model
final class PersistedSceneAnchor {
    var worldAnchorID: UUID
    var timestamp: Date
    var seatX: Float = 0
    var seatY: Float = 0
    var seatZ: Float = 0

    init(worldAnchorID: UUID, seatPosition: SIMD3<Float> = .zero, timestamp: Date = .now) {
        self.worldAnchorID = worldAnchorID
        self.seatX = seatPosition.x
        self.seatY = seatPosition.y
        self.seatZ = seatPosition.z
        self.timestamp = timestamp
    }

    var seatPosition: SIMD3<Float> {
        SIMD3(seatX, seatY, seatZ)
    }
}
