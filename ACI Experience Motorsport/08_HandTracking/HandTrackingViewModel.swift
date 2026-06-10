//
//  HandTrackingViewModel.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 16/10/25.
//

import Foundation
import SwiftUI
import ARKit
import RealityKit
import Combine

/// Manages ARKit hand tracking with fingertip visualization and session lifecycle control.
///
/// Coordinates hand tracking provider updates, creates and positions fingertip entities at index finger
/// locations, and provides cleanup and reinitialization support for session restarts.
@MainActor
class HandTrackingViewModel: ObservableObject {
    
    // MARK: - Properties
    
    private var session = ARKitSession()
    private var handTracking = HandTrackingProvider()
    private var meshEntities = [UUID: ModelEntity]()
    private var contentEntity = Entity()
    private var fingerEntities: [HandAnchor.Chirality: ModelEntity] = [:]
    private var isProcessingUpdates = false
    private var handTrackingTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        createFingerEntities()
    }
    
    /// Creates fingertip visualization entities for both hands.
    private func createFingerEntities() {
        fingerEntities = [
            .left: ModelEntity.createFingertip(),
            .right: ModelEntity.createFingertip()
        ]
    }
    
    // MARK: - Content Entity Setup
    
    /// Sets up and returns the content entity with fingertip entities attached.
    ///
    /// Creates a fresh content entity hierarchy and adds fingertip tracking entities
    /// for both left and right hands.
    func setupContentEntity() -> Entity {
        contentEntity = Entity()
        
        for entity in fingerEntities.values {
            contentEntity.addChild(entity)
        }
        
        return contentEntity
    }
    
    // MARK: - Cleanup
    
    /// Performs complete cleanup of hand tracking resources and state.
    ///
    /// Stops update processing, cancels tracking tasks, terminates the AR session,
    /// and removes all entity components and hierarchy relationships. Must be called
    /// before session restart or experience closure.
    func cleanup() async {
        isProcessingUpdates = false
        
        handTrackingTask?.cancel()
        handTrackingTask = nil
        
        session.stop()
        
        for (_, entity) in fingerEntities {
            entity.components.removeAll()
            entity.removeFromParent()
        }
        fingerEntities.removeAll()
        
        for (_, entity) in meshEntities {
            entity.components.removeAll()
            entity.removeFromParent()
        }
        meshEntities.removeAll()
        
        contentEntity.children.forEach { child in
            child.components.removeAll()
            child.removeFromParent()
        }
        contentEntity.components.removeAll()
        
    }
    
    // MARK: - Restart Support
    
    /// Reinitializes the hand tracking system after cleanup.
    ///
    /// Creates fresh ARKit session and hand tracking provider instances, recreates
    /// fingertip entities, and resets all state. Required after cleanup before starting
    /// a new tracking session.
    func reinitialize() async {
        
        session = ARKitSession()
        handTracking = HandTrackingProvider()
        
        createFingerEntities()
        
        meshEntities.removeAll()
        isProcessingUpdates = false
        
    }
    
    // MARK: - Hand Tracking Updates
    
    /// Continuously processes hand tracking anchor updates to position fingertip entities.
    ///
    /// Subscribes to hand tracking provider updates, calculates index fingertip transforms
    /// for both hands, and updates entity positions in real-time. Respects cancellation
    /// and processing state flags for clean shutdown.
    func processHandsUpdates() async {
        guard !isProcessingUpdates else {
            return
        }
        
        isProcessingUpdates = true
        
        handTrackingTask = Task {
            for await update in handTracking.anchorUpdates {
                if !isProcessingUpdates || Task.isCancelled {
                    break
                }
                
                let handAnchor = update.anchor
                
                guard handAnchor.isTracked else { continue }
                let fingerTip = handAnchor.handSkeleton?.joint(.indexFingerTip)
                guard fingerTip?.isTracked == true else { continue }
                
                let originFromWrist = handAnchor.originFromAnchorTransform
                let wristFromIndex = fingerTip?.anchorFromJointTransform
                let originFromIndex = originFromWrist * wristFromIndex!
                
                fingerEntities[handAnchor.chirality]?.setTransformMatrix(originFromIndex, relativeTo: nil)
            }
        }
        
        await handTrackingTask?.value
        isProcessingUpdates = false
    }
    
    // MARK: - Session Management
    
    /// Starts the ARKit session with hand tracking enabled.
    ///
    /// Runs the AR session with the hand tracking provider, enabling hand and fingertip
    /// anchor updates to begin flowing through the system.
    func beginSession() async {
        do {
            try await session.run([handTracking])
        } catch {
            print(" Session trigger error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Pause / Resume
    
    /// Pauses hand tracking updates and removes collision from fingertip entities.
    /// The ARKit session stays running — only processing and interaction are suspended.
    func pause() {
        guard isProcessingUpdates else { return }
        
        isProcessingUpdates = false
        handTrackingTask?.cancel()
        handTrackingTask = nil
        
        for (_, entity) in fingerEntities {
            entity.components.remove(CollisionComponent.self)
            entity.components.remove(ModelComponent.self)
            entity.components.set(OpacityComponent(opacity: 0))
        }
    }
    /// Resumes hand tracking updates and restores collision on fingertip entities.
    /// Call after `pause()` — the ARKit session must still be running.
    func resume() {
        guard !isProcessingUpdates else {
            return
        }
        
        // Restore collision on finger entities
        let handGroup = CollisionGroup(rawValue: 1 << 1)
        let handMask = CollisionGroup.all.subtracting(handGroup)
        let handFilter = CollisionFilter(group: handGroup, mask: handMask)
        
        for (_, entity) in fingerEntities {
            entity.collision = CollisionComponent(shapes: [.generateSphere(radius: 0.02)])
            entity.collision?.filter = handFilter
        }
        
        for (_, entity) in fingerEntities {
            entity.components.set(ModelComponent(
                mesh: .generateSphere(radius: 0.02),
                materials: [SimpleMaterial(color: .green, isMetallic: false)]
            ))
        }
        
        Task {
            await processHandsUpdates()
        }
        
    }
}

// MARK: - Fingertip Entity Factory

extension ModelEntity {
    /// Creates a fingertip visualization entity with collision filtering.
    ///
    /// Generates a small green sphere with custom collision properties that allow it to interact
    /// with scene objects while avoiding collisions with other hand entities. Initially invisible.
    class func createFingertip() -> ModelEntity {
        let entity = ModelEntity(
            mesh: .generateSphere(radius: 0.02),
            materials: [SimpleMaterial(color: .green, isMetallic: false)],
            collisionShape: .generateSphere(radius: 0.02),
            mass: 0.0
        )
        
        let handGroup = CollisionGroup(rawValue: 1 << 1)
        let handMask = CollisionGroup.all.subtracting(handGroup)
        let handFilter = CollisionFilter(group: handGroup, mask: handMask)
        entity.collision?.filter = handFilter
        
        entity.components.set(OpacityComponent(opacity: 0))
        entity.name = "hand"
        
        return entity
    }
}
