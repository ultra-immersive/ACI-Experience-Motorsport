//
//  Module_D.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 21/10/25.
//

import Foundation
import RealityKit
import AVFoundation

extension ImmersiveView {
    
    // MARK: - Module D Crossfade
    
    /// Crossfades from the intro panel video into full immersive VR180 playback.
    ///
    /// The VR180 video starts at the exact timecode the intro player has reached,
    /// creating a seamless portal-to-full-immersive transition. When the VR180 video
    /// ends, the scene is fully restored to interactive free-browse mode.
    func performModuleDCrossfade(
        introEntity: Entity,
        introConfig: VideoConfig,
        crossfadeDuration: TimeInterval,
        vrResourceName: String
    ) {
        guard let root = rootEntity.findEntity(named: "Root") else {
            print("Module D crossfade: Root entity not found")
            return
        }
        
        let seamlessStartTime: TimeInterval
        if let videoComponent = introEntity.components[VideoPlayerComponent.self],
           let introPlayer = videoComponent.avPlayer {
            seamlessStartTime = introPlayer.currentTime().seconds
            introPlayer.pause()
        } else {
            seamlessStartTime = introConfig.endTime ?? 27.0
        }
        
        root.components.set(OpacityComponent(opacity: 1.0))
        
        let videoManager = appModel.videoManager
        let originalOnVideoEnd = videoManager.onVideoEnd
        
        /// Restores the full scene when the VR180 video finishes — fades environment back in,
        /// re-enables panel interactivity, resumes background audio, and clears Module D state.
        videoManager.onVideoEnd = { [weak videoManager] video in
            guard let videoManager else { return }
            
            Task { @MainActor in
                guard !moduleDDidEnd else { return }
                moduleDDidEnd = true
                
                self.closeWindow(id: "ControlVideo")
                
                if let vrEntity = videoManager.videoEntity {
                    vrEntity.components.set(OpacityComponent(opacity: 1.0))
                    graduallyChangeOpacity(entity: vrEntity, targetOpacity: 0, duration: 1.5)
                }
                
                graduallyChangeColorEffect(
                    duration: 1.5,
                    styleManager: self.styleManager,
                    startColor: [0, 0, 0],
                    targetColor: [1, 1, 1],
                    completion: {}
                )
                
                if let generalOpacity = self.rootEntity.findEntity(named: "GeneralOpacity") {
                    graduallyChangeOpacity(entity: generalOpacity, targetOpacity: 1, duration: 2) {}
                }
                
                self.showAllSlots()
                if let guide = rootEntity.findEntity(named: "Guide") {
                    graduallyChangeOpacity(entity: guide, targetOpacity: 1.0, duration: 1)
                }

                
                try? await Task.sleep(for: .seconds(2.5))
                
                self.currentTappedVideo = nil
                self.isVideoAnimating = false
                
                if let playbackID = self.experienceBackgroundPlaybackID {
                    await EnhancedAudioSystem.fadeInAndResume(
                        playbackID: playbackID,
                        duration: 2.0
                    ) {}
                }
                
                self.seekAllVideosToPreview()
                videoManager.removeVideoEntity()
                videoManager.onVideoEnd = originalOnVideoEnd
                
                self.experienceTimer.moduleDidEnd(.D)
                self.activeModuleRunCount -= 1
                
                self.watchedVideoIDs.insert(introConfig.id)
                self.checkExperienceCompletion()
                
                if let assignedSlot = Self.videoSlotAssignments[introConfig.id] {
                    await self.addWatchedOverlay(to: introEntity, slot: assignedSlot, title: introConfig.title)
                }
            }
        }
        
        // Load and play the VR180 video at the intro's current timecode.
        Task {
            await self.loadAndPlayVideo(
                resourceName: vrResourceName,
                autoPlay: true,
                title: "Module_D_VR180",
                startTime: seamlessStartTime
            )
            
            let vm = self.appModel.videoManager
            if vm.videoState == .ready || vm.videoState == .paused {
                vm.play()
            }
        }
        
        // Fade out background audio during the crossfade.
        if let playbackID = experienceBackgroundPlaybackID {
            Task {
                await EnhancedAudioSystem.fadeOutAndPause(
                    playbackID: playbackID,
                    duration: crossfadeDuration
                ) {}
            }
        }
        
        EnhancedAudioSystem.playAudio(on: root, resourceName: "/Root/Disappearing_wav")
        
        // Fade the scene out to reveal the VR180 video behind it, then transition environment to black.
        if let generalOpacity = rootEntity.findEntity(named: "GeneralOpacity") {
            graduallyChangeOpacity(
                entity: generalOpacity,
                targetOpacity: 0,
                duration: crossfadeDuration
            ) {
                self.handleVideoEnd(entity: introEntity, config: introConfig)
                
                graduallyChangeColorEffect(
                    duration: 1.5,
                    styleManager: self.styleManager,
                    startColor: [1, 1, 1],
                    targetColor: [0, 0, 0],
                    completion: {}
                )
            }
        }
    }
}
