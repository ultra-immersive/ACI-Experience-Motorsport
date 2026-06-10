//
//  EnhancedAudioSystem.swift
//
//  Created by Jacques André on 29/09/25.
//

import Foundation
import RealityKit
import QuartzCore
import AVFoundation
import RealityKitContent

/// Manages spatial audio playback with fade effects and entity-scoped audio control.
///
/// Provides a high-level interface for playing, stopping, and fading audio on RealityKit entities.
/// Tracks active playback sessions per entity, supports completion callbacks, and handles
/// audio cleanup with optional fade-out effects. Thread-safe for concurrent audio operations.
/// All audio files comes from AudioScene in RCP
struct EnhancedAudioSystem {
    typealias PlaybackID = String
    private static var pausedPlaybacks: Set<PlaybackID> = []
    private static var targetVolumes: [PlaybackID: Float] = [:]
    private static var loopingPlaybacks: Set<PlaybackID> = []
    
    private static var audioControllers: [PlaybackID: AudioPlaybackController] = [:]
    private static var audioResources: [PlaybackID: (resource: AudioFileResource, duration: TimeInterval)] = [:]
    private static var completionHandlers: [PlaybackID: () -> Void] = [:]
    private static var playbackToEntity: [PlaybackID: String] = [:]
    private static var entityToPlaybacks: [String: Set<PlaybackID>] = [:]
    private static let audioAccessQueue = DispatchQueue(label: "EnhancedAudioSystem.audioAccessQueue")
    
    private static var fadeOutTimers: [PlaybackID: Timer] = [:]
    
    // MARK: - Playback Control
    
    /// Plays an audio file on the specified entity with configurable playback options.
    ///
    /// Loads the audio resource, prepares the playback controller, and begins playback on the entity.
    /// Returns a unique playback identifier that can be used to control or stop the audio later.
    /// Optionally waits for playback completion before invoking the callback.
    @discardableResult
    static func playAudio(
        on entity: Entity,
        resourceName: String,
        volume: Float = 0.0,
        waitForCompletion: Bool = true,
        enableAnalysis: Bool = false,
        isAmbientAudio: Bool = false,
        completion: (() -> Void)? = nil
    ) -> PlaybackID {
        if isAmbientAudio {
            entity.ambientAudio = AmbientAudioComponent()
        }
        
        let playbackID = UUID().uuidString
        let entityID = String(describing: entity.id)
        
        audioAccessQueue.sync {
            playbackToEntity[playbackID] = entityID
            if entityToPlaybacks[entityID] == nil {
                entityToPlaybacks[entityID] = []
            }
            entityToPlaybacks[entityID]?.insert(playbackID)
        }
        
        Task {
            do {
                let audioResource = try await AudioFileResource(
                    named: resourceName,
                    from: "Scenes/AudioScene.usda",
                    in: realityKitContentBundle
                )

                let actualDuration = audioResource.duration
                let durationInSeconds = TimeInterval(actualDuration.components.seconds)
                
                audioAccessQueue.sync {
                    audioResources[playbackID] = (audioResource, durationInSeconds)
                }
                
                let controller = entity.prepareAudio(audioResource)
                audioControllers[playbackID] = controller
                
                if let completion = completion {
                    completionHandlers[playbackID] = completion
                }
                
                if waitForCompletion {
                    await MainActor.run {
                        controller.completionHandler = {
                            cleanupPlayback(playbackID: playbackID)
                            if let completion = completionHandlers.removeValue(forKey: playbackID) {
                                DispatchQueue.main.async {
                                    completion()
                                }
                            }
                        }
                    }
                } else {
                    await MainActor.run {
                        controller.completionHandler = {
                            cleanupPlayback(playbackID: playbackID)
                            if let userCompletion = completionHandlers.removeValue(forKey: playbackID) {
                                userCompletion()
                            }
                        }
                    }
                }
                
                await MainActor.run {
                    controller.gain = Audio.Decibel(volume)
                }
                
                controller.play()
            } catch {
                print(" Error playing audio: \(resourceName), \(error)")
                cleanupPlayback(playbackID: playbackID)
                DispatchQueue.main.async {
                    completion?()
                }
            }
        }
        
        return playbackID
    }
    
    /// Gradually reduces audio volume to silence before stopping playback.
    ///
    /// Smoothly interpolates the gain from current level to -80 dB over the specified duration,
    /// then stops the audio controller and cleans up resources. Uses 60 FPS timer for smooth fading.
    static func fadeOutAndStop(
        playbackID: PlaybackID,
        duration: TimeInterval = 2.0,
        completion: (() -> Void)? = nil
    ) async {
        
        guard let controller = audioControllers[playbackID] else {
            print(" No audio controller found for playbackID: \(playbackID)")
            DispatchQueue.main.async {
                completion?()
            }
            return
        }
        
        let startGain = controller.gain
        let frameRate: TimeInterval = 1.0 / 60.0
        let startTime = Date()
        
        await MainActor.run {
            fadeOutTimers[playbackID]?.invalidate()
            
            fadeOutTimers[playbackID] = Timer.scheduledTimer(withTimeInterval: frameRate, repeats: true) { [startTime, startGain] _ in
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(elapsed / duration, 1.0)
                
                Task { @MainActor in
                    let newGain = Audio.Decibel(startGain - (startGain + 80) * progress)
                    controller.gain = newGain
                    
                    if progress >= 1.0 {
                        fadeOutTimers[playbackID]?.invalidate()
                        fadeOutTimers.removeValue(forKey: playbackID)
                        
                        controller.completionHandler = nil
                        controller.stop()
                        
                        cleanupPlayback(playbackID: playbackID)
                        
                        completion?()
                        
                    }
                }
            }
        }
    }
    
    /// Stops playback for a specific playback identifier.
    ///
    /// Immediately stops the audio if no fade duration is provided, or performs a gradual
    /// fade-out before stopping if a duration is specified.
    static func stopPlayback(
        playbackID: PlaybackID,
        fadeOutDuration: TimeInterval? = nil,
        completion: (() -> Void)? = nil
    ) async {
        
        if let fadeOutDuration = fadeOutDuration {
            await fadeOutAndStop(playbackID: playbackID, duration: fadeOutDuration, completion: completion)
            return
        }
        
        guard let controller = audioControllers[playbackID] else {
            print(" No audio controller found for playbackID: \(playbackID)")
            DispatchQueue.main.async {
                completion?()
            }
            return
        }
        
        await MainActor.run {
            controller.completionHandler = nil
        }
        controller.stop()
        
        cleanupPlayback(playbackID: playbackID)
        
        DispatchQueue.main.async {
            completion?()
        }
    }
    
    /// Stops all audio playback associated with a specific entity.
    ///
    /// Iterates through all active playback sessions for the entity and stops them,
    /// optionally applying a fade-out effect to each.
    static func stopAudio(
        on entity: Entity,
        fadeOutDuration: TimeInterval? = nil,
        completion: (() -> Void)? = nil
    ) async {
        let entityID = String(describing: entity.id)
        
        let playbackIDs = audioAccessQueue.sync {
            entityToPlaybacks[entityID] ?? []
        }
        
        for playbackID in playbackIDs {
            await stopPlayback(playbackID: playbackID, fadeOutDuration: fadeOutDuration)
        }
        
        DispatchQueue.main.async {
            completion?()
        }
    }
    
    /// Immediately stops all active audio playback in the system.
    ///
    /// Cancels all fade-out timers, stops all audio controllers, and clears all tracking state.
    /// Used for global audio cleanup when closing the immersive space or resetting the experience.
    static func stopAllAudio() async {
        
        await MainActor.run {
            for (_, timer) in fadeOutTimers {
                timer.invalidate()
            }
            fadeOutTimers.removeAll()
        }
        
        let controllersToStop = audioAccessQueue.sync {
            Array(audioControllers)
        }
                
        for (_, controller) in controllersToStop {
            await MainActor.run {
                controller.completionHandler = nil
            }
            controller.stop()
        }
        
        audioAccessQueue.sync {
            audioControllers.removeAll()
            audioResources.removeAll()
            completionHandlers.removeAll()
            playbackToEntity.removeAll()
            entityToPlaybacks.removeAll()
        }
        
    }
    
    // MARK: - Query Methods
    
    /// Checks if the specified entity has any active audio playback.
    static func hasActiveAudio(for entity: Entity) -> Bool {
        let entityID = String(describing: entity.id)
        return audioAccessQueue.sync {
            !(entityToPlaybacks[entityID]?.isEmpty ?? true)
        }
    }
    
    /// Returns the number of active audio playback sessions for the entity.
    static func activeAudioCount(for entity: Entity) -> Int {
        let entityID = String(describing: entity.id)
        return audioAccessQueue.sync {
            entityToPlaybacks[entityID]?.count ?? 0
        }
    }
    
    // MARK: - Looping Playback

    /// Plays a looping audio file. When playback completes, it automatically restarts.
    @discardableResult
    static func playLoopingAudio(
        on entity: Entity,
        resourceName: String,
        volume: Float = 0.0,
        isAmbientAudio: Bool = false
    ) -> PlaybackID {
        let playbackID = playAudio(
            on: entity,
            resourceName: resourceName,
            volume: volume,
            waitForCompletion: true,
            isAmbientAudio: isAmbientAudio,
            completion: nil
        )
        
        audioAccessQueue.sync {
            loopingPlaybacks.insert(playbackID)
            targetVolumes[playbackID] = volume
        }
        
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            
            guard let controller = audioControllers[playbackID] else { return }
            
            await MainActor.run {
                controller.completionHandler = {
                    let shouldLoop = audioAccessQueue.sync { loopingPlaybacks.contains(playbackID) }
                    guard shouldLoop else {
                        cleanupPlayback(playbackID: playbackID)
                        return
                    }
                    
                    // Restart playback
                    controller.seek(to: .zero)
                    controller.play()
                }
            }
        }
        
        return playbackID
    }

    // MARK: - Fade Pause / Resume

    /// Fades audio out to silence, then pauses playback (preserving position).
    static func fadeOutAndPause(
        playbackID: PlaybackID,
        duration: TimeInterval = 2.0,
        completion: (() -> Void)? = nil
    ) async {
        guard let controller = audioControllers[playbackID] else {
            DispatchQueue.main.async { completion?() }
            return
        }
        
        let isPaused = audioAccessQueue.sync { pausedPlaybacks.contains(playbackID) }
        guard !isPaused else {
            DispatchQueue.main.async { completion?() }
            return
        }
        
        let startGain = controller.gain
        let startTime = Date()
        let frameRate: TimeInterval = 1.0 / 60.0
        
        await MainActor.run {
            fadeOutTimers[playbackID]?.invalidate()
            
            fadeOutTimers[playbackID] = Timer.scheduledTimer(withTimeInterval: frameRate, repeats: true) { _ in
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(elapsed / duration, 1.0)
                
                Task { @MainActor in
                    let newGain = Audio.Decibel(startGain - (startGain + 80) * progress)
                    controller.gain = newGain
                    
                    if progress >= 1.0 {
                        fadeOutTimers[playbackID]?.invalidate()
                        fadeOutTimers.removeValue(forKey: playbackID)
                        
                        controller.pause()
                        
                        audioAccessQueue.sync {
                            pausedPlaybacks.insert(playbackID)
                        }
                        
                        completion?()
                    }
                }
            }
        }
    }

    /// Resumes paused audio with a fade-in back to its original volume.
    static func fadeInAndResume(
        playbackID: PlaybackID,
        duration: TimeInterval = 2.0,
        completion: (() -> Void)? = nil
    ) async {
        guard let controller = audioControllers[playbackID] else {
            DispatchQueue.main.async { completion?() }
            return
        }
        
        let isPaused = audioAccessQueue.sync { pausedPlaybacks.contains(playbackID) }
        guard isPaused else {
            DispatchQueue.main.async { completion?() }
            return
        }
        
        let targetVolume = audioAccessQueue.sync { targetVolumes[playbackID] ?? 0.0 }
        let targetGain = Audio.Decibel(targetVolume)
        let startGain: Audio.Decibel = -80.0
        let startTime = Date()
        let frameRate: TimeInterval = 1.0 / 60.0
        
        // Start playing at silence, then ramp up
        await MainActor.run {
            controller.gain = startGain
            controller.play()
        }
        
        audioAccessQueue.sync {
            pausedPlaybacks.remove(playbackID)
        }
        
        await MainActor.run {
            fadeOutTimers[playbackID]?.invalidate()
            
            fadeOutTimers[playbackID] = Timer.scheduledTimer(withTimeInterval: frameRate, repeats: true) { _ in
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(elapsed / duration, 1.0)
                
                Task { @MainActor in
                    let newGain = Audio.Decibel(startGain + (targetGain - startGain) * progress)
                    controller.gain = newGain
                    
                    if progress >= 1.0 {
                        fadeOutTimers[playbackID]?.invalidate()
                        fadeOutTimers.removeValue(forKey: playbackID)
                        
                        completion?()
                    }
                }
            }
        }
    }
    
    // MARK: - Resource Management
    
    /// Releases all resources associated with a playback session.
    ///
    /// Removes tracking entries, clears controllers and resources, and invalidates any active fade timers.
    private static func cleanupPlayback(playbackID: PlaybackID) {
        audioAccessQueue.sync {
            if let entityID = playbackToEntity[playbackID] {
                entityToPlaybacks[entityID]?.remove(playbackID)
                if entityToPlaybacks[entityID]?.isEmpty == true {
                    entityToPlaybacks.removeValue(forKey: entityID)
                }
            }
            playbackToEntity.removeValue(forKey: playbackID)
            audioControllers.removeValue(forKey: playbackID)
            audioResources.removeValue(forKey: playbackID)
            
            pausedPlaybacks.remove(playbackID)
            loopingPlaybacks.remove(playbackID)
            targetVolumes.removeValue(forKey: playbackID)

        }
        
        DispatchQueue.main.async {
            fadeOutTimers[playbackID]?.invalidate()
            fadeOutTimers.removeValue(forKey: playbackID)
        }
    }
}
