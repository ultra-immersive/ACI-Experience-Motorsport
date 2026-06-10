//
//  SafeZoneManager.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 26/02/26.
//

import Foundation
import ARKit
import RealityKit
import SwiftUI
import RealityKitContent

/// Tracks the user's head position via ARKit and enforces a circular safe zone around the seated position.
///
/// When the experience needs the user back in position (e.g. when the cars are fullsize), it activates
/// a particle ring on the floor and polls until the user is inside the radius and seated.
@MainActor
@Observable
class SafeZoneManager {
    
    var safeRadius: Float = 0.5
    var sittingHeightThreshold: Float = 1.5

    private var originPosition: SIMD2<Float>?
    private var particleEntity: Entity?
    private var worldTracking: WorldTrackingProvider?
    private var session: ARKitSession?
    private var trackingTask: Task<Void, Never>?
    private var returnCheckTask: Task<Void, Never>?
    
    /// Loads the particle ring asset from RCP and adds it (initially not emitting) to the parent entity.
    func setup(parent: Entity) async {
        guard let loaded = try? await Entity(named: "Assets/ParticleRingusda", in: realityKitContentBundle) else {
            print("SafeZone: Could not load particle asset from RCP")
            return
        }
        loaded.scale = [2, 2, 2]
        loaded.name = "SafeZoneParticles"
        setEmitting(false, on: loaded)
        parent.addChild(loaded)
        particleEntity = loaded
    }
    
    /// Starts the ARKit world tracking session used for head position queries.
    func startTracking() async {
        if session == nil || worldTracking == nil {
            session = ARKitSession()
            worldTracking = WorldTrackingProvider()
        }
        guard let session, let worldTracking else { return }
        do {
            try await session.run([worldTracking])
        } catch {
            print("SafeZone: Failed to start world tracking: \(error)")
        }
    }
    
    /// Sets the safe zone center to a specific world-space XZ position and moves the particle ring there.
    func setOrigin(worldPosition: SIMD2<Float>) {
        originPosition = worldPosition
        let groundY: Float = 0
        particleEntity?.setPosition(
            SIMD3<Float>(worldPosition.x, groundY, worldPosition.y),
            relativeTo: nil
        )
    }
    
    /// Captures the safe zone origin from the user's current head position.
    func captureOriginFromHead() {
        guard let worldTracking,
              let anchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else { return }
        let t = anchor.originFromAnchorTransform
        let headXZ = SIMD2<Float>(t.columns.3.x, t.columns.3.z)
        setOrigin(worldPosition: headXZ)
    }

    /// Returns the current device transform from world tracking, used by the billboard system.
    func currentDeviceTransform() -> simd_float4x4? {
        guard let worldTracking else { return nil }
        return worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())?.originFromAnchorTransform
    }
    
    /// Activates the particle ring and polls until the user is inside the safe radius and seated, then calls the completion handler.
    func requestReturn(completion: @escaping @MainActor () -> Void) {
        guard originPosition != nil else {
            completion()
            return
        }
        if let entity = particleEntity { setEmitting(true, on: entity) }
        
        returnCheckTask?.cancel()
        returnCheckTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if self.isUserInSafeZoneAndSeated() {
                    if let entity = self.particleEntity { self.setEmitting(false, on: entity) }
                    completion()
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
    
    /// Cancels any active return-to-seat check and turns off the particle ring.
    func cancelReturnRequest() {
        returnCheckTask?.cancel()
        returnCheckTask = nil
        if let entity = particleEntity { setEmitting(false, on: entity) }
    }
    
    /// Returns whether the user's head is currently within the safe radius.
    func isUserInsideSafeZone() -> Bool {
        guard let origin = originPosition,
              let worldTracking,
              let anchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else { return true }
        let t = anchor.originFromAnchorTransform
        let headXZ = SIMD2<Float>(t.columns.3.x, t.columns.3.z)
        return simd_distance(headXZ, origin) <= safeRadius
    }
    
    /// Returns whether the user is inside the safe radius **and** below the sitting height threshold.
    func isUserInSafeZoneAndSeated() -> Bool {
        guard let origin = originPosition,
              let worldTracking,
              let anchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else { return false }
        let t = anchor.originFromAnchorTransform
        let headXZ = SIMD2<Float>(t.columns.3.x, t.columns.3.z)
        let headY = t.columns.3.y
        return simd_distance(headXZ, origin) <= safeRadius && headY <= sittingHeightThreshold
    }

    /// Polls for up to `duration` seconds, returning `true` as soon as the user is in the safe zone and seated.
    func quickCheck(duration: TimeInterval = 2.0) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(duration)
        while ContinuousClock.now < deadline {
            if isUserInSafeZoneAndSeated() { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }

    /// Stops tracking, removes the particle entity, and releases all resources.
    func cleanup() {
        returnCheckTask?.cancel()
        returnCheckTask = nil
        trackingTask?.cancel()
        trackingTask = nil
        session?.stop()
        session = nil
        worldTracking = nil
        particleEntity?.removeFromParent()
        particleEntity = nil
        originPosition = nil
    }
    
    private func setEmitting(_ emitting: Bool, on entity: Entity) {
        if var particles = entity.components[ParticleEmitterComponent.self] {
            particles.isEmitting = emitting
            entity.components[ParticleEmitterComponent.self] = particles
        }
        for child in entity.children { setEmitting(emitting, on: child) }
    }
}
