//
//  ImmersiveView+Placement.swift
//  ACI Experience Motorsport
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

extension ImmersiveView {

    // MARK: - Placement Setup

    /// Initializes the placement system for full-scale car mode: adds root/container entities, cursor, seat indicator, confirm UI, and starts the ARKit session.
    @MainActor
    func setupPlacement(content: RealityViewContent, attachments: RealityViewAttachments) async {
        guard let pm = placementManager else { return }

        pm.prepareForNewSession()

        placementVisualization.removeAllMeshes()
        placementVisualization.contentEntity.removeFromParent()

        content.add(pm.rootEntity)
        content.add(pm.sceneContainer)

        if pm.isPlacingMode {
            content.add(placementVisualization.contentEntity)
            await placementVisualization.reset()
            pm.addCursor()
            pm.addSeatIndicator()
            if let confirmUI = attachments.entity(for: "PlacementConfirm") {
                confirmUI.name = "PlacementConfirmButton"
                pm.placementLocation.addChild(confirmUI)
                confirmUI.setPosition([0, 0.50, -0.25], relativeTo: pm.placementLocation)
                confirmUI.setOrientation(
                    .init(angle: -25 * .pi / 180, axis: [1, 0, 0]),
                    relativeTo: pm.placementLocation
                )
            }
        }

        setupPlacementCallbacks()
        pm.setupControllerBindings(gameControllerManager)

        Task { await pm.runARKitSession() }
    }

    // MARK: - Staff Controller Bindings

    /// Binds Y button (full config reset) and B button (experience restart) on the game controller — active regardless of car size mode.
    @MainActor
    func setupStaffControllerBindings() {
        gameControllerManager.onYButtonPress = {
            Task { @MainActor in
                UserDefaults.standard.set(false, forKey: "hasConfiguredFullScaleCar")
                if let pm = self.placementManager {
                    SoundManager.shared.playAmbientSound(named: "resetExperienceACI")
                    await pm.performFullReset()
                }
                await self.cleanupImmersiveView()
                await self.closeImmersiveSpace()
            }
        }

        gameControllerManager.onBButtonPress = {
            Task { @MainActor in
                let isPlacing = self.placementManager?.isPlacingMode ?? false
                if !isPlacing {
                    await self.restartImmersiveView()
                }
            }
        }
    }

    /// Clears all game controller button bindings.
    @MainActor
    func clearStaffControllerBindings() {
        gameControllerManager.onYButtonPress = nil
        gameControllerManager.onBButtonPress = nil
        gameControllerManager.onRightTriggerPress = nil
        gameControllerManager.onRightShoulderPress = nil
    }

    // MARK: - Placement Callbacks

    /// Wires up the placement manager's callbacks: cleans up visualization on confirm, triggers full reset or restart on staff actions.
    @MainActor
    func setupPlacementCallbacks() {
        guard let pm = placementManager else { return }

        pm.onPlacementConfirmed = {
            self.placementVisualization.removeAllMeshes()
            await self.placementVisualization.stopSession()
            self.placementVisualization.contentEntity.removeFromParent()
            pm.removeSeatIndicator()

            if let btn = pm.placementLocation.children.first(where: { $0.name == "PlacementConfirmButton" }) {
                btn.removeFromParent()
            }

            let seatPos = pm.userSeatWorldPosition
            self.safeZoneManager.setOrigin(
                worldPosition: SIMD2<Float>(seatPos.x, seatPos.z)
            )
        }

        pm.onFullReset = {
            await self.cleanupImmersiveView()
            await self.closeImmersiveSpace()
            self.showWindow(id: "ContentView")
        }

        pm.onExperienceRestart = {
            await self.restartImmersiveView()
        }
    }

    // MARK: - Reset Placement

    /// Re-enters placement mode, restarting scene reconstruction visualization.
    @MainActor
    func resetScenePlacement() async {
        guard let pm = placementManager else { return }
        await pm.resetPlacement()
        if let content = self.content {
            placementVisualization.contentEntity.removeFromParent()
            content.add(placementVisualization.contentEntity)
        }
        await placementVisualization.reset()
        Task { await placementVisualization.processReconstructionUpdates() }
    }

    // MARK: - Scene Content Binding

    /// Assigns the main scene entity to the placement container so it follows the placed world anchor.
    @MainActor
    func bindSceneToPlacement(_ sceneEntity: Entity) {
        guard let pm = placementManager else { return }
        pm.sceneContentEntity = sceneEntity
    }
}
