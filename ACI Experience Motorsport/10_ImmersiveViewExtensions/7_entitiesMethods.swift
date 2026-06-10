//
//  entitiesExtension.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 13/10/25.
//

import Foundation
import RealityKit
import Combine
import RealityKitContent
import SwiftUI

extension ImmersiveView {
    
    // MARK: - Reverse Animation
    
    /// Plays an animation in reverse by generating a new AnimationResource with negative speed.
    ///
    /// Stops existing animations, modifies animation definition with negative speed and no repeat,
    /// generates reversed animation resource, plays from end to start, and subscribes to completion
    /// events. Returns playback controller for external control. Used for module teardown animations.
    @discardableResult
    func playAnimationReverse(
        entity: Entity,
        name: String? = nil,
        index: Int? = nil,
        speed: Float = 1.0,
        completion: (() -> Void)? = nil
    ) -> AnimationPlaybackController? {
        let resource: AnimationResource?
        if let name = name {
            resource = entity.availableAnimations.first(where: { $0.name == name })
        } else if let idx = index, idx >= 0, idx < entity.availableAnimations.count {
            resource = entity.availableAnimations[idx]
        } else {
            resource = entity.availableAnimations.first
        }
        
        guard let animationResource = resource else {
            print(" No animation resource found")
            return nil
        }
        
        entity.stopAllAnimations(recursive: true)
        
        var reversedDefinition = animationResource.definition
        reversedDefinition.speed = -abs(speed)
        reversedDefinition.repeatMode = .none
        
        do {
            let reversedAnimation = try AnimationResource.generate(with: reversedDefinition)
            
            let controller = entity.playAnimation(
                reversedAnimation,
                transitionDuration: 0,
                startsPaused: false
            )
            
            print(" Playing reverse animation with definition speed: \(reversedDefinition.speed)")
            
            if let scene = entity.scene, let completion = completion {
                var token: AnyCancellable? = nil
                token = scene.subscribe(to: AnimationEvents.PlaybackCompleted.self, on: entity) { event in
                    if event.playbackController == controller {
                        completion()
                        token?.cancel()
                    }
                } as? AnyCancellable
            }
            
            return controller
            
        } catch {
            print(" Failed to generate reversed animation: \(error)")
            return nil
        }
    }
    
    // MARK: - Blend Shape Animation
    
    /// Animates blend shape weights using CADisplayLink for smooth 60fps interpolation.
    ///
    /// Retrieves current weights, validates array sizes, creates display link for frame-by-frame
    /// updates, linearly interpolates between start and target weights, updates component each frame,
    /// and triggers completion on main thread when progress reaches 1.0. Essential for smooth
    /// morph target animations.
    func animateBlendShapeWeights(
        entity: Entity,
        blendWeightsIndex: Int,
        targetWeights: [Float],
        duration: TimeInterval,
        completion: (() -> Void)? = nil
    ) {
        guard var component = entity.components[BlendShapeWeightsComponent.self] else {
            print("BlendShapeWeightsComponent not found")
            completion?()
            return
        }
        
        let startWeights = Array(component.weightSet[blendWeightsIndex].weights)
        guard startWeights.count == targetWeights.count else {
            print("Mismatched weight array sizes")
            completion?()
            return
        }
        
        let startTime = CACurrentMediaTime()
        var displayLink: CADisplayLink?
        
        displayLink = CADisplayLink(target: BlockOperation {
            let elapsedTime = CACurrentMediaTime() - startTime
            let progress = min(Float(elapsedTime / duration), 1.0)
            
            var updatedWeights: [Float] = []
            for i in 0..<startWeights.count {
                let newWeight = startWeights[i] + (targetWeights[i] - startWeights[i]) * progress
                updatedWeights.append(newWeight)
            }
            
            component.weightSet[blendWeightsIndex].weights = BlendShapeWeights(updatedWeights)
            entity.components[BlendShapeWeightsComponent.self] = component
            
            if progress >= 1.0 {
                displayLink?.invalidate()
                DispatchQueue.main.async {
                    completion?()
                }
            }
        }, selector: #selector(Operation.main))
        
        displayLink?.add(to: .main, forMode: .default)
    }
    
    /// Recursively finds an entity with a ModelComponent in the hierarchy.
    func findModelComponentEntity(entity: Entity) -> Entity? {
        if entity.components.has(ModelComponent.self) {
            return entity
        }
        for child in entity.children {
            if let foundEntity = findModelComponentEntity(entity: child) {
                return foundEntity
            }
        }
        return nil
    }
    
    /// Sets up BlendShapeWeightsComponent on an entity using its ModelComponent mesh.
    func setupBlendShapeWeightsComponent(for entity: Entity) {
        guard let modelComponentEntity = findModelComponentEntity(entity: entity),
              let modelComponent = modelComponentEntity.components[ModelComponent.self]
        else {
            return
        }
        
        let blendShapeWeightsMapping = BlendShapeWeightsMapping(meshResource: modelComponent.mesh)
        entity.components.set(BlendShapeWeightsComponent(weightsMapping: blendShapeWeightsMapping))
    }
}

// MARK: - Entity Spawning and Animation

extension ImmersiveView {
    
    /// Plays an animation with comprehensive control options including reverse playback.
    ///
    /// Finds animation by name or index, handles looping (forever or count-based), supports
    /// reverse playback with negative speed and end-to-start positioning, manages transition
    /// duration and start timing, subscribes to completion events (with special handling for
    /// reverse using timer-based checking), and returns playback controller. Essential for
    /// coordinated animation sequences.
    @discardableResult
    func animateEntity(
        entity: Entity,
        name: String? = nil,
        index: Int? = nil,
        loopCount: Int? = nil,
        loopForever: Bool = false,
        speed: Float = 1.0,
        reverse: Bool = false,
        transitionDuration: TimeInterval = 0.2,
        startsPaused: Bool = false,
        startTimeOffset: TimeInterval = 0,
        completion: (() -> Void)? = nil
    ) -> AnimationPlaybackController? {
        let resource: AnimationResource?
        if let name = name {
            resource = entity.availableAnimations.first(where: { $0.name == name })
        } else if let idx = index, idx >= 0, idx < entity.availableAnimations.count {
          //  print("Animation index count: \(entity.availableAnimations.count )")
            resource = entity.availableAnimations[idx]
        } else {
            resource = entity.availableAnimations.first
        }
        
        guard var anim = resource else {
            print(" No animation resource found on \(entity.name) with name \(String(describing: name)).")
            return nil
        }
        
        if loopForever {
            if reverse {
                print(" Reverse looping not directly supported. Playing once in reverse.")
            } else {
                anim = anim.repeat()
            }
        } else if let loopCount = loopCount, loopCount > 1 {
            if reverse {
                print(" Reverse looping not directly supported. Playing once in reverse.")
            } else {
                anim = anim.repeat(count: loopCount)
            }
        }
        
        entity.stopAllAnimations()
        
        let controller = entity.playAnimation(
            anim,
            transitionDuration: reverse ? 0 : transitionDuration,
            startsPaused: true
        )
        
        if reverse {
            controller.speed = -abs(speed)
            let duration = anim.definition.duration
            
            if let loopCount = loopCount, loopCount > 1 {
                controller.time = duration * Double(loopCount)
            } else {
                controller.time = duration
            }
            
        } else {
            controller.speed = abs(speed)
            controller.time = 0
        }
        
        if !startsPaused {
            if startTimeOffset > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + startTimeOffset) {
                    controller.resume()
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    controller.resume()
                }
            }
        }
        
        if let scene = entity.scene, let completion = completion {
            var token: AnyCancellable? = nil
            
            if reverse {
                let checkInterval = 0.1
                var timer: Timer?
                
                timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { _ in
                    if controller.time <= 0.01 || !controller.isPlaying {
                        completion()
                        timer?.invalidate()
                        timer = nil
                    }
                }
                
                token = scene.subscribe(to: AnimationEvents.PlaybackCompleted.self, on: entity) { event in
                    if event.playbackController == controller {
                        completion()
                        timer?.invalidate()
                        token?.cancel()
                    }
                } as? AnyCancellable
            } else {
                token = scene.subscribe(to: AnimationEvents.PlaybackCompleted.self, on: entity) { event in
                    if event.playbackController == controller {
                        completion()
                        token?.cancel()
                    }
                } as? AnyCancellable
            }
        }
                
        return controller
    }
    
    // MARK: - SpotLight Animation
    
    /// Gradually animates a SpotLight's intensity with easing curve support.
    ///
    /// Retrieves current intensity, calculates delta, creates task-based 60fps animation loop,
    /// applies easing function to progress, updates component each frame, and ensures exact
    /// target value on completion. Supports linear, ease-in, ease-out, and ease-in-out curves.
    @MainActor
    func animateSpotLightIntensity(
        entity lightEntity: Entity,
        to targetIntensity: Float,
        duration: Double,
        easing: LightEasing = .linear,
        completion: (() -> Void)? = nil
    ) {
        guard var spotlightComponent = lightEntity.components[SpotLightComponent.self] else {
            print(" No SpotLightComponent found on entity: \(lightEntity.name)")
            completion?()
            return
        }
            spotlightComponent.attenuationRadius = 10
        
        let startIntensity = spotlightComponent.intensity
        let intensityDelta = targetIntensity - startIntensity
        
        guard abs(intensityDelta) > 0.001 else {
            completion?()
            return
        }
        
        let startTime = Date()
        let frameRate: Double = 1.0 / 60.0
        
        Task {
            while true {
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(elapsed / duration, 1.0)
                let easedProgress = easing.apply(Float(progress))
                
                let newIntensity = startIntensity + (intensityDelta * easedProgress)
                spotlightComponent.intensity = newIntensity
                lightEntity.components.set(spotlightComponent)
                
                if progress >= 1.0 {
                    spotlightComponent.intensity = targetIntensity
                    lightEntity.components.set(spotlightComponent)
                    completion?()
                    break
                }
                
                try? await Task.sleep(for: .seconds(frameRate))
            }
        }
    }
    
    /// Easing curve options for light intensity animations.
    enum LightEasing {
        case linear
        case easeIn
        case easeOut
        case easeInOut
        
        func apply(_ t: Float) -> Float {
            switch self {
            case .linear:
                return t
            case .easeIn:
                return t * t
            case .easeOut:
                return 1 - (1 - t) * (1 - t)
            case .easeInOut:
                return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            }
        }
    }
    
    /// Convenience method to animate a spotlight by name with easing.
    @MainActor
    func animateSpotLight(
        named name: String,
        to targetIntensity: Float,
        duration: Double,
        easing: LightEasing = .easeInOut,
        completion: (() -> Void)? = nil
    ) {
        guard let lightEntity = rootEntity.findEntity(named: name) else {
            print(" Light entity '\(name)' not found")
            completion?()
            return
        }
        lightEntity.position.y += 1.5
        
        animateSpotLightIntensity(
            entity: lightEntity,
            to: targetIntensity,
            duration: duration,
            easing: easing,
            completion: completion
        )
    }
}
