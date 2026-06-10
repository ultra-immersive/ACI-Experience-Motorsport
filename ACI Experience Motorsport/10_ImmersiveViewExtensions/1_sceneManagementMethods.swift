//
//  cleanup&Restart.swift
//
//  Created by Jacques André on 10/10/25.
//

import Foundation
import RealityKit
import _RealityKit_SwiftUI
import RealityKitContent
import AVFoundation
import SwiftUI

extension ImmersiveView {
    
    // MARK: - Scene Phase Handling
    
    /// Responds to scene phase transitions (crown press, headset removal/replacement) by cleaning up or restarting the immersive view.
    func handleScenePhase(oldValue: ScenePhase, newValue: ScenePhase) {
        scenePhaseTracking = newValue
        
        if newValue == .inactive && oldValue == .active {
            Task { @MainActor in
                closeWindow(id: "ControlVideo")
                await cleanupImmersiveView()
            }
        }
        
        if newValue == .background && oldValue == .inactive {
            Task { @MainActor in
                closeWindow(id:"ControlVideo")
                showWindow(id: "ContentView")
                await closeImmersiveSpace()
            }
        }
        
        if newValue == .background && oldValue == .active {
            Task { @MainActor in
                closeWindow(id:"ControlVideo")
                await cleanupImmersiveView()
            }
        }
        
        if newValue == .active && oldValue == .background {
            Task { @MainActor in
                closeWindow(id:"ControlVideo")
                await restartImmersiveView()
            }
        }
    }
    
    // MARK: - Initial Setup
    
    /// Loads the MainScene, configures depth sorting for the  intro sphere and guide entities, and initializes the video manager.
    func initialSetup() async {
        guard let content = self.content else {
            print("No content available for restart")
            return
        }
        
        if let immersiveContentEntity = try? await Entity(named: "MainScene", in: realityKitContentBundle) {
            await safeZoneManager.setup(parent: immersiveContentEntity)
#if !targetEnvironment(simulator)
            await safeZoneManager.startTracking()
#endif
            
            immersiveContentEntity.name = "RootEntity"
            let modelSortGroup = ModelSortGroup()
            
            if let sphereAci = immersiveContentEntity.findEntity(named: "sphereAci") {
                if let modelentity = findModelEntity(in: sphereAci) {
                    if let mat = modelentity.model?.materials.first as? ShaderGraphMaterial {
                        var material = mat
                        material.writesDepth = false
                        modelentity.model?.materials = [material]
                        modelentity.components.set(ModelSortGroupComponent(group: modelSortGroup, order: 0))
                    }
                }
            }
            
            if let textAci = immersiveContentEntity.findEntity(named: "textAci") {
                if let modelentity = findModelEntity(in: textAci) {
                    modelentity.components.set(ModelSortGroupComponent(group: modelSortGroup, order: 1))
                }
            }
            
            if let circleAci = immersiveContentEntity.findEntity(named: "circleAci") {
                if let modelentity = findModelEntity(in: circleAci) {
                    modelentity.components.set(ModelSortGroupComponent(group: modelSortGroup, order: 1))
                }
            }
            
            if let ringAci = immersiveContentEntity.findEntity(named: "ringAci") {
                if let modelentity = findModelEntity(in: ringAci) {
                    modelentity.components.set(ModelSortGroupComponent(group: modelSortGroup, order: 1))
                }
            }
            
            if let ringAci = immersiveContentEntity.findEntity(named: "GuideSphere") {
                if let modelentity = findModelEntity(in: ringAci) {
                    modelentity.components.set(ModelSortGroupComponent(group: modelSortGroup, order: 1))
                }
            }
            
            if var ringAci = immersiveContentEntity.findEntity(named: "GuideGearModel") {
                ringAci = ringAci.parent!
                if let modelentity = findModelEntity(in: ringAci) {
                    modelentity.components.set(ModelSortGroupComponent(group: modelSortGroup, order: 1))
                }
            }
            
            if let guide = rootEntity.findEntity(named: "Guide") {
                guide.components.set(OpacityComponent(opacity: 0.0))
            }
            
            if isFullScaleCarsActive, placementManager != nil {
                bindSceneToPlacement(immersiveContentEntity)
            } else {
                content.add(immersiveContentEntity)
            }
            
            rootEntity = immersiveContentEntity
            setupVideoManager(with: immersiveContentEntity)
            await MainActor.run {
                styleManager.currentSourroundingEffect = .colorMultiply(Color(red: 1, green: 1, blue: 1))
                rootEntity = immersiveContentEntity
                setupVideoManager(with: immersiveContentEntity)
            }
        }
    }
    
    // MARK: - Cleanup

    /// Tears down all experience resources: cancels the conversational guide, stops audio/video, invalidates timers, removes entities, and resets state.
    func cleanupImmersiveView() async {
        guard !isCleaningUp else {
            print("Cleanup already in progress, skipping...")
            return
        }
        endStartedFromExperienceTimer = false
        isCleaningUp = true
        hasBeenCleaned = true
        activeModuleRunCount = 0
        moduleDDidEnd = false

        await MainActor.run {
            stopAllPanelVideos()
        }

        conversationalGuide?.cancel()
        await audioAnimator.stopAllAnimations()

        voiceLevelMonitor.stopMonitoring()
        experienceTimer.cleanup()
        await EnhancedAudioSystem.stopAllAudio()
        
        await MainActor.run {
            Self.videoSlotAssignments.removeAll()
        }
        
        await MainActor.run {
            appModel.videoManager.stop()
            appModel.videoManager.removeVideoEntity()
            appModel.videoManager.cleanup()
            appModel.player.replaceCurrentItem(with: nil)
            appModel.player.cancelPendingPrerolls()
            appModel._videoManager = nil
        }
        
        await MainActor.run {
            for (_, timer) in timers {
                timer.invalidate()
            }
            timers.removeAll()
        }
        safeZoneManager.cleanup()

        await handTrackingViewModel.cleanup()
        clearStaffControllerBindings()
        
        if let content = self.content {
            await MainActor.run {
                let entitiesToRemove = Array(content.entities)
                for entity in entitiesToRemove {
                    guard entity.parent != nil else { continue }
                    
                    if let pm = placementManager, pm.ownsEntity(entity) {
                        continue
                    }
                    if entity === placementVisualization.contentEntity {
                        continue
                    }
                    
                    removeEntityHierarchy(entity)
                    entity.removeFromParent()
                }
            }
        }
        
        await MainActor.run {
            guard rootEntity.parent != nil || !rootEntity.children.isEmpty else {
                print("Root entity already cleaned")
                return
            }
            removeEntityHierarchy(rootEntity)
            rootEntity.removeFromParent()
            rootEntity = Entity()
        }
        
        await MainActor.run {
            sphereCooldowns.removeAll()
        }
        
        isCleaningUp = false
        hasBeenCleaned = false
    }

    /// Performs a full cleanup (if needed), reinitializes hand tracking and placement, and reloads the scene.
    func restartImmersiveView() async {
        guard let content = self.content else {
            print("No content available for restart")
            return
        }
        
        if !hasBeenCleaned {
            await cleanupImmersiveView()
        }
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await handTrackingViewModel.reinitialize()
        
        await MainActor.run {
            content.add(handTrackingViewModel.setupContentEntity())
        }
        
        setupEntityCollisions(content: content)
        
        if isFullScaleCarsActive, let pm = placementManager {
            pm.prepareForNewSession()
            content.add(pm.rootEntity)
            content.add(pm.sceneContainer)
            setupPlacementCallbacks()
            pm.setupControllerBindings(gameControllerManager)
        }
        setupStaffControllerBindings()
        isClosingExperience = false
        
        await initialSetup()
        
    #if !targetEnvironment(simulator)
        await handTrackingViewModel.beginSession()
        Task { await handTrackingViewModel.processHandsUpdates() }
    #endif
    }
    
    /// Recursively strips all components and children from an entity hierarchy for complete deallocation.
    private func removeEntityHierarchy(_ entity: Entity) {
        entity.components.removeAll()
        let children = entity.children.map { $0 }
        for child in children {
            removeEntityHierarchy(child)
            child.removeFromParent()
        }
    }
    
    // MARK: - Panel Video Cleanup

    /// Pauses and detaches all per-slot panel AVPlayers so audio stops immediately.
    /// Must be called before entity teardown — removing entities does NOT stop AVPlayer audio.
    @MainActor
    func stopAllPanelVideos() {
        // 1. Stop the currently tapped/playing video first (it holds a strong AVPlayer ref)
        if let tapped = currentTappedVideo {
            tapped.player.pause()
            tapped.player.replaceCurrentItem(with: nil)
            currentTappedVideo = nil
        }

        // 2. Walk every panel slot and stop any VideoPlayerComponent player
        for i in 1...10 {
            guard let slotEntity = rootEntity.findEntity(named: "Image_\(i)"),
                  let screen = findEntityContaining("ImageScreen", in: slotEntity) else {
                continue
            }

            for child in screen.children where child.name.starts(with: "Video_") {
                if let videoComponent = child.components[VideoPlayerComponent.self],
                   let player = videoComponent.avPlayer {
                    player.pause()
                    player.replaceCurrentItem(with: nil)   // releases audio resources
                }
                // Drop the component so the player reference is released
                child.components.remove(VideoPlayerComponent.self)
            }
        }
    }
    
    // MARK: - RCP Notifications
    
    /// Posts a notification to trigger a Reality Composer Pro behavior by identifier.
    func sendNotificationtToRCP(notificationName: String) {
        guard let scene = self.scene else {
            print("No scene available")
            return
        }
        print("Sending Notification to RCP: \(notificationName)")
        NotificationCenter.default.post(
            name: NSNotification.Name("RealityKit.NotificationTrigger"),
            object: nil,
            userInfo: [
                "RealityKit.NotificationTrigger.Scene": scene,
                "RealityKit.NotificationTrigger.Identifier": notificationName
            ]
        )
    }
}
