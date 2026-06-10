//
//  ScenePlacementManager.swift
//  ACI Experience Motorsport
//

import Foundation
import RealityKit
import ARKit
import SwiftUI
import SwiftData
import RealityKitContent

/// Manages world-anchored scene placement for the full-scale car experience.
///
/// Uses ARKit plane detection and raycasting to project a cursor onto the floor,
/// persists the placement via SwiftData + WorldAnchor, and provides staff controls
/// for confirming, resetting, and fully clearing the scene position.
@MainActor
@Observable
class ScenePlacementManager {
    var modelSortGroup = ModelSortGroup(depthPass: .postPass)
    private var seatPositionLocked: Bool = false
    private var lockedFloorY: Float = 0
    var userSeatWorldPosition: SIMD3<Float> = .zero
    private var seatIndicator: Entity?

    var isPlacingMode: Bool = true
    var isScenePlaced: Bool = false
    var deviceAnchorPresent: Bool = false
    var planeAnchorsPresent: Bool = false
    var planeToProjectOnFound: Bool = false

    var onPlacementConfirmed: (() async -> Void)?
    var onFullReset: (() async -> Void)?
    var onExperienceRestart: (() async -> Void)?

    let rootEntity = Entity()
    let placementLocation = Entity()
    let sceneContainer = Entity()

    private let deviceLocation = Entity()
    private let raycastOrigin = Entity()
    private var cursor: Entity?

    let worldTracking = WorldTrackingProvider()
    private let planeDetection = PlaneDetectionProvider()
    private var session = ARKitSession()
    private var planeAnchorHandler: PlaneAnchorHandler

    private var modelContext: ModelContext
    private var persistedAnchorID: UUID?

    var sceneContentEntity: Entity? {
        didSet {
            guard let entity = sceneContentEntity else { return }
            sceneContainer.addChild(entity)
            if !isScenePlaced { sceneContainer.isEnabled = false }
            if let pending = pendingAnchorTransform {
                applyTransformToContainer(pending, tracked: pendingAnchorTracked)
                pendingAnchorTransform = nil
                Task { await onPlacementConfirmed?() }
            }
        }
    }

    private var pendingAnchorTransform: simd_float4x4?
    private var pendingAnchorTracked: Bool = true
    private var worldAnchors: [UUID: WorldAnchor] = [:]

    init(context: ModelContext) {
        self.modelContext = context
        sceneContainer.name = "ScenePlacementContainer"
        rootEntity.addChild(placementLocation)
        deviceLocation.addChild(raycastOrigin)
        raycastOrigin.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        planeAnchorHandler = PlaneAnchorHandler(rootEntity: rootEntity)
        loadPersistedAnchor()
    }
    
    /// Unlocks the seat position so the next device anchor update re-captures it.
    func recaptureSeatPosition() {
        seatPositionLocked = false
    }

    /// Loads and shows the particle ring at the seat position during placement mode.
    func addSeatIndicator() {
        guard seatIndicator == nil else { return }
        Task {
            guard let loaded = try? await Entity(named: "Assets/ParticleRingusda", in: realityKitContentBundle) else { return }
            loaded.name = "SeatIndicatorParticles"
            loaded.scale = [2, 2, 2]
            loaded.enumerateHierarchy { entity, stop in
                entity.components.set(ModelSortGroupComponent(group: modelSortGroup, order: 0))
            }
            setEmitting(true, on: loaded)
            seatIndicator = loaded
            rootEntity.addChild(loaded)
            if seatPositionLocked {
                loaded.position = userSeatWorldPosition
            }
        }
    }

    /// Removes the seat indicator particle ring from the scene.
    func removeSeatIndicator() {
        if let entity = seatIndicator { setEmitting(false, on: entity) }
        seatIndicator?.removeFromParent()
        seatIndicator = nil
    }

    private func setEmitting(_ emitting: Bool, on entity: Entity) {
        if var particles = entity.components[ParticleEmitterComponent.self] {
            particles.isEmitting = emitting
            entity.components[ParticleEmitterComponent.self] = particles
        }
        for child in entity.children { setEmitting(emitting, on: child) }
    }

    /// Detaches all entities and resets state for a fresh placement session.
    func prepareForNewSession() {
        rootEntity.removeFromParent()
        sceneContainer.removeFromParent()
        sceneContentEntity = nil
        pendingAnchorTransform = nil
        seatIndicator?.removeFromParent()
        seatIndicator = nil
        userSeatWorldPosition = .zero
        seatPositionLocked = false
        lockedFloorY = 0

        for child in sceneContainer.children { child.removeFromParent() }
        sceneContainer.isEnabled = false

        if placementLocation.parent !== rootEntity { rootEntity.addChild(placementLocation) }
        if raycastOrigin.parent !== deviceLocation {
            deviceLocation.addChild(raycastOrigin)
            raycastOrigin.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        }

        cursor?.removeFromParent()
        cursor = nil
        for child in placementLocation.children { child.removeFromParent() }
        for child in rootEntity.children where child !== placementLocation { child.removeFromParent() }

        planeAnchorHandler = PlaneAnchorHandler(rootEntity: rootEntity)
        planeToProjectOnFound = false
        deviceAnchorPresent = false
        planeAnchorsPresent = false
    }

    /// Returns whether the given entity belongs to this placement manager.
    func ownsEntity(_ entity: Entity) -> Bool {
        return entity === rootEntity || entity === sceneContainer
    }

    /// Binds right trigger (confirm placement) and right shoulder (recapture seat) to the game controller.
    func setupControllerBindings(_ controller: GameControllerManager) {
        controller.onRightTriggerPress = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                if self.isPlacingMode && self.planeToProjectOnFound {
                    await self.confirmPlacement()
                }
            }
        }
        controller.onRightShoulderPress = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                if self.isPlacingMode { self.recaptureSeatPosition() }
            }
        }
    }

    func clearControllerBindings(_ controller: GameControllerManager) {
        controller.onRightTriggerPress = nil
        controller.onRightShoulderPress = nil
    }

    /// Starts the ARKit session with world tracking and plane detection providers.
    func runARKitSession() async {
        do {
            try await session.run([worldTracking, planeDetection])
        } catch {
            print("ScenePlacement: ARKit session failed – \(error.localizedDescription)")
        }
    }

    /// Continuously updates the placement cursor position from the device anchor at 90 Hz.
    func processDeviceAnchorUpdates() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: NSEC_PER_SEC / 90)
            guard worldTracking.state == .running else { continue }
            let anchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
            deviceAnchorPresent = anchor != nil
            planeAnchorsPresent = !planeAnchorHandler.planeAnchors.isEmpty
            guard let anchor, anchor.isTracked else { continue }
            updatePlacementLocation(anchor)
        }
    }

    /// Processes world anchor add/update/remove events for placement persistence.
    func processWorldAnchorUpdates() async {
        for await update in worldTracking.anchorUpdates {
            processAnchorUpdate(update)
        }
    }

    /// Forwards plane detection updates to the plane anchor handler during placement mode.
    func processPlaneDetectionUpdates() async {
        for await update in planeDetection.anchorUpdates {
            if isPlacingMode { await planeAnchorHandler.process(update) }
        }
    }

    /// Confirms the current cursor position as the scene placement, persists it as a WorldAnchor via SwiftData.
    func confirmPlacement() async {
        guard isPlacingMode else { return }
        let transform = placementLocation.transformMatrix(relativeTo: nil)
        let anchor = WorldAnchor(originFromAnchorTransform: transform)

        do {
            try await worldTracking.addAnchor(anchor)
            let record = PersistedSceneAnchor(worldAnchorID: anchor.id, seatPosition: userSeatWorldPosition)
            modelContext.insert(record)
            try modelContext.save()
            persistedAnchorID = anchor.id
            applyTransformToContainer(transform, tracked: true)
            await onPlacementConfirmed?()
            SoundManager.shared.playAmbientSound(named: "placementSuccessLancia")
        } catch {
            print("Failed to place scene: \(error)")
        }
    }

    /// Clears the current placement and returns to placement mode, keeping the staff configuration.
    func resetPlacement() async {
        if let id = persistedAnchorID { try? await worldTracking.removeAnchor(forID: id) }
        seatPositionLocked = false
        lockedFloorY = 0
        deleteAllPersistedAnchors()
        sceneContainer.isEnabled = false
        persistedAnchorID = nil
        pendingAnchorTransform = nil
        isScenePlaced = false
        isPlacingMode = true
        planeToProjectOnFound = false
        removeSeatIndicator()
        userSeatWorldPosition = .zero
        addCursor()
        addSeatIndicator()
    }

    /// Fully resets placement **and** staff configuration, returning to the initial setup flow.
    func performFullReset() async {
        if let id = persistedAnchorID { try? await worldTracking.removeAnchor(forID: id) }
        seatPositionLocked = false
        lockedFloorY = 0
        removeSeatIndicator()
        userSeatWorldPosition = .zero
        deleteAllPersistedAnchors()
        sceneContainer.isEnabled = false
        persistedAnchorID = nil
        pendingAnchorTransform = nil
        isScenePlaced = false
        isPlacingMode = true
        planeToProjectOnFound = false
        UserDefaults.standard.set(false, forKey: "hasConfiguredFullScaleCar")
    }

    /// Loads and adds the placement cursor entity to the placement location.
    func addCursor() {
        guard cursor == nil else { return }
        Task {
            if let loaded = try? await Entity(named: "Assets/Cursor", in: realityKitContentBundle) {
                loaded.name = "PlacementCursor"
                loaded.enumerateHierarchy { entity, stop in
                    entity.components.set(ModelSortGroupComponent(group: modelSortGroup, order: 0))
                }
                loaded.position.z = -2.5
                cursor = loaded
                placementLocation.addChild(cursor!)
            }
        }
    }

    func removeCursor() { cursor?.removeFromParent(); cursor = nil }

    /// Stops the ARKit session and removes cursor/seat indicator entities.
    func cleanup() {
        session.stop()
        removeCursor()
        removeSeatIndicator()
        planeAnchorHandler.removeAll()
    }

    private func applyTransformToContainer(_ transform: simd_float4x4, tracked: Bool) {
        sceneContainer.position = transform.translation
        sceneContainer.orientation = transform.rotation
        sceneContainer.isEnabled = tracked
        isPlacingMode = false
        isScenePlaced = true
        removeCursor()
    }

    /// Raycasts downward from the user's head to lock the seat position on the first valid floor hit, then tracks head yaw for cursor orientation.
    private func updatePlacementLocation(_ deviceAnchor: DeviceAnchor) {
        guard isPlacingMode else { return }

        let deviceMatrix = deviceAnchor.originFromAnchorTransform
        let aligned = deviceMatrix.gravityAligned

        if !seatPositionLocked {
            let headXZ = SIMD2<Float>(deviceMatrix.columns.3.x, deviceMatrix.columns.3.z)
            let rayOrigin = SIMD3<Float>(headXZ.x, deviceMatrix.columns.3.y, headXZ.y)

            let allHits = rootEntity.scene?.raycast(
                origin: rayOrigin, direction: [0, -1, 0], length: 3, query: .all,
                mask: PlaneAnchor.horizontalCollisionGroup
            ) ?? []

            guard let hit = allHits.min(by: { $0.position.y < $1.position.y }),
                  hit.distance > 0.5 else { return }

            userSeatWorldPosition = SIMD3<Float>(headXZ.x, hit.position.y, headXZ.y)
            lockedFloorY = hit.position.y
            seatPositionLocked = true

            seatIndicator?.position = SIMD3<Float>(headXZ.x, hit.position.y + 0.002, headXZ.y)
            planeToProjectOnFound = true
        }

        var t = aligned
        t.translation = userSeatWorldPosition
        placementLocation.transform = Transform(matrix: t)
    }

    private func processAnchorUpdate(_ update: AnchorUpdate<WorldAnchor>) {
        let anchor = update.anchor
        switch update.event {
        case .added:
            worldAnchors[anchor.id] = anchor
            if anchor.id == persistedAnchorID {
                if sceneContentEntity != nil {
                    applyTransformToContainer(anchor.originFromAnchorTransform, tracked: anchor.isTracked)
                    Task { await onPlacementConfirmed?() }
                } else {
                    pendingAnchorTransform = anchor.originFromAnchorTransform
                    pendingAnchorTracked = anchor.isTracked
                }
            } else { Task { try? await worldTracking.removeAnchor(forID: anchor.id) } }

        case .updated:
            worldAnchors[anchor.id] = anchor
            if anchor.id == persistedAnchorID {
                if sceneContentEntity != nil {
                    sceneContainer.position = anchor.originFromAnchorTransform.translation
                    sceneContainer.orientation = anchor.originFromAnchorTransform.rotation
                    sceneContainer.isEnabled = anchor.isTracked
                } else {
                    pendingAnchorTransform = anchor.originFromAnchorTransform
                    pendingAnchorTracked = anchor.isTracked
                }
            }

        case .removed:
            worldAnchors.removeValue(forKey: anchor.id)
            if anchor.id == persistedAnchorID { sceneContainer.isEnabled = false; isScenePlaced = false }
        }
    }

    private func loadPersistedAnchor() {
        let descriptor = FetchDescriptor<PersistedSceneAnchor>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        do {
            let records = try modelContext.fetch(descriptor)
            if let latest = records.first {
                persistedAnchorID = latest.worldAnchorID
                userSeatWorldPosition = latest.seatPosition
                seatPositionLocked = true
                isPlacingMode = false
            } else { isPlacingMode = true }
            if records.count > 1 {
                for old in records.dropFirst() { modelContext.delete(old) }
                try? modelContext.save()
            }
        } catch { isPlacingMode = true }
    }

    private func deleteAllPersistedAnchors() {
        let descriptor = FetchDescriptor<PersistedSceneAnchor>()
        if let records = try? modelContext.fetch(descriptor) {
            records.forEach { modelContext.delete($0) }
            try? modelContext.save()
        }
    }
}
