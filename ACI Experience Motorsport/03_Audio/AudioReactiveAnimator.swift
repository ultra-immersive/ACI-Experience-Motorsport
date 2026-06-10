//
//  AudioReactiveAnimator.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 27/10/25.
//

import Foundation
import RealityKit
import AVFoundation

/// Drives shader material animations synchronized to audio playback amplitude.
///
/// Analyzes audio file amplitude in real-time and  updates shader graph material
/// parameters to create audio-reactive visual effects. Manages concurrent animations across
/// multiple entities with automatic cleanup and smooth value interpolation.
actor AudioReactiveAnimator {
    private var activeAnimations: [String: Task<Void, Never>] = [:]
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    
    // MARK: - Animation Control
    
    /// Starts audio-synchronized shader parameter animation on the specified entities.
    ///
    /// Plays the audio file while continuously sampling its amplitude to drive shader material
    /// parameters with configurable intensity, range, and smoothing. Automatically stops any
    /// existing animations on the same entities before starting the new animation.
    func animateToAudio(
        entities: [Entity],
        audioResourceName: String,
        keyMaterialName: String,
        baseValue: Float = 0.0,
        intensity: Float = 1.0,
        range: Float = 1.0,
        smoothing: Float = 0.7,
        completion: @escaping () -> Void = {}
    ) async {
        let animationID = UUID().uuidString
        
        await stopAnimation(for: entities)
        
        var entityData: [(modelEntity: ModelEntity, material: ShaderGraphMaterial)] = []
        
        for entity in entities {
            
            guard let modelEntity = findModelEntity(in: entity) else {
                continue
            }
            
            
            guard let model = await modelEntity.model else {
                continue
            }
            
            model.materials.enumerated().forEach { i, mat in
            }
            
            guard let material = model.materials.first as? ShaderGraphMaterial else {
                continue
            }
            
            entityData.append((modelEntity, material))
        }
        
        guard !entityData.isEmpty else {

            completion()
            return
        }
        
        let task = Task {
            guard !Task.isCancelled else { return }
            
            await performAudioAnimation(
                entityData: entityData,
                audioResourceName: audioResourceName,
                keyMaterialName: keyMaterialName,
                baseValue: baseValue,
                intensity: intensity,
                range: range,
                smoothing: smoothing,
                animationID: animationID
            )
            
            // Only call completion if this task wasn't cancelled
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                completion()
            }
        }
        
        activeAnimations[animationID] = task
    }
        
    /// Cancels active animations for the specified entities.
    ///
    /// Stops audio playback, cancels animation tasks, and cleans up resources
    /// for animations affecting the given entities.
    func stopAnimation(for entities: [Entity]) async {
        for (id, task) in activeAnimations {
            task.cancel()
            activeAnimations.removeValue(forKey: id)
            audioPlayers[id]?.stop()
            audioPlayers.removeValue(forKey: id)
        }
    }
    
    /// Immediately stops all active animations and audio playback.
    ///
    /// Cancels all animation tasks, stops all audio players, and clears all tracking state.
    func stopAllAnimations() async {
        for task in activeAnimations.values {
            task.cancel()
        }
        for player in audioPlayers.values {
            player.stop()
        }
        activeAnimations.removeAll()
        audioPlayers.removeAll()
    }
    
    // MARK: - Animation Implementation
    
    /// Executes the audio-reactive animation loop.
    ///
    /// Loads and plays the audio file, samples amplitude values, applies smoothing,
    /// and updates shader material parameters on the main actor. Handles cleanup and material
    /// reset after playback completes.
    private func performAudioAnimation(
        entityData: [(modelEntity: ModelEntity, material: ShaderGraphMaterial)],
        audioResourceName: String,
        keyMaterialName: String,
        baseValue: Float,
        intensity: Float,
        range: Float,
        smoothing: Float,
        animationID: String
    ) async {
        guard let audioURL = Bundle.main.url(forResource: audioResourceName, withExtension: "mp3") else {
            print(" Audio file not found: \(audioResourceName)")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: audioURL)
            player.isMeteringEnabled = true
            player.prepareToPlay()
            player.play()
            
            audioPlayers[animationID] = player
            
            var smoothedValue: Float = baseValue
            let updateInterval: TimeInterval = 1.0 / 60.0
            
            while player.isPlaying && !Task.isCancelled {
                player.updateMeters()
                let averagePower = player.averagePower(forChannel: 0)
                let normalizedPower = pow(10.0, averagePower / 20.0)
                let targetValue = baseValue + (normalizedPower * intensity * range)
                smoothedValue = smoothedValue * smoothing + targetValue * (1.0 - smoothing)
                let clampedValue = min(max(smoothedValue, baseValue), baseValue + range)
                
                await MainActor.run {
                    for data in entityData {
                        do {
                            var updatedMaterial = data.material
                            try updatedMaterial.setParameter(name: keyMaterialName, value: .float(clampedValue))
                            data.modelEntity.model?.materials = [updatedMaterial]
                        } catch {
                            print(" Error updating material: \(error)")
                        }
                    }
                }
                
                try? await Task.sleep(for: .milliseconds(Int(updateInterval * 1000)))
            }
            
            if Task.isCancelled {
                player.stop()
            }
            
            audioPlayers.removeValue(forKey: animationID)
            activeAnimations.removeValue(forKey: animationID)
            
            if !Task.isCancelled {
                await MainActor.run {
                    for data in entityData {
                        do {
                            var updatedMaterial = data.material
                            try updatedMaterial.setParameter(name: keyMaterialName, value: .float(baseValue))
                            data.modelEntity.model?.materials = [updatedMaterial]
                        } catch {}
                    }
                }
            }
            
        } catch {
            print("Error loading audio: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Recursively searches for a ModelEntity within the entity hierarchy.
    ///
    /// Returns the first ModelEntity found, either the entity itself or within its children.
    private func findModelEntity(in entity: Entity) -> ModelEntity? {
        if let modelEntity = entity as? ModelEntity {
            return modelEntity
        }
        for child in entity.children {
            if let found = findModelEntity(in: child) {
                return found
            }
        }
        return nil
    }
}
