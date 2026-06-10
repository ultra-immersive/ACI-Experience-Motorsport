//
//  collisionFunctions.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 10/10/25.
//

import Foundation
import RealityKit
import _RealityKit_SwiftUI

extension ImmersiveView {
    
    // MARK: - Collision Setup
    
    /// Registers collision subscriptions for all interactive entity pairs (e.g. hand → start sphere).
    func setupEntityCollisions(content: RealityViewContent) {
        let collisionConfigurations = [
            ("sphereAci", "hand", "sphereAci"),
        ]
        
        for (entity, collider, notificationID) in collisionConfigurations {
            setupCollisionDetection(for: entity, entityToCollide: collider, notificationID: notificationID, on: content)
        }
    }
    
    /// Subscribes to collision events between two named entities, enforces a cooldown, and fires the corresponding RCP notification.
    func setupCollisionDetection(for entityName: String, entityToCollide: String, notificationID identifier: String, on content: RealityViewContent) {
        let entity = content.entities.first?.findEntity(named: entityName)
        
        _ = content.subscribe(to: CollisionEvents.Began.self, on: entity) { collisionEvent in
            let (entityA, entityB) = (collisionEvent.entityA.name, collisionEvent.entityB.name)
            
            if (entityA == entityToCollide && entityB == entityName || entityA == entityName && entityB == entityToCollide) {
                if !canInteractWithSphere(identifier: identifier) {
                    return
                }
                
                print("Collision between \(entityA) and \(entityB)")
                setSphereOnCooldown(identifier: identifier)
                
                switch identifier {
                case "sphereAci":
                    sendNotificationtToRCP(notificationName: "StartSphere_Touched")
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Cooldown Management
    
    /// Returns `true` if the cooldown period has elapsed since the last interaction with the given identifier.
    func canInteractWithSphere(identifier: String) -> Bool {
        guard let lastInteraction = sphereCooldowns[identifier] else {
            return true
        }
        let timeSinceLastInteraction = Date().timeIntervalSince(lastInteraction)
        return timeSinceLastInteraction >= cooldownDuration
    }
    
    /// Records the current time as the last interaction for the given identifier, starting the cooldown.
    func setSphereOnCooldown(identifier: String) {
        sphereCooldowns[identifier] = Date()
    }
}
