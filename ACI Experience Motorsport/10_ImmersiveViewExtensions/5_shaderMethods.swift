//
//  shaderAnimationFunctions.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 10/10/25.
//

import Foundation
import RealityKit
import Combine


extension ImmersiveView {
    
    // MARK: - Single Entity Shader Animation
    
    /// Animates a shader parameter on a single entity to a target value.
    ///
    /// Convenience wrapper that delegates to handlePopValueChangeMultipleEntities with
    /// a single-element array. Used for animating individual material properties like
    /// "Pop" effect values with smooth interpolation over specified duration.
    func handlePopValueChange(
        entity: Entity,
        targetValue: Float,
        duration: TimeInterval,
        keyMaterialName: String,
        completion: @escaping () -> Void
    ) {
        handlePopValueChangeMultipleEntities(
            entities: [entity],
            targetValue: targetValue,
            duration: duration,
            keyMaterialName: keyMaterialName,
            completion: completion
        )
    }
    
    // MARK: - Multiple Entity Shader Animation
    
    /// Animates the same shader parameter on multiple entities simultaneously.
    ///
    /// Finds ModelEntity and ShaderGraphMaterial in each entity, retrieves initial values,
    /// creates 60fps timer for smooth interpolation, updates all entities synchronously
    /// each frame with linear interpolation from initial to target value, and triggers
    /// completion callback when animation finishes. Stores timer in timers dictionary
    /// with UUID key for proper cleanup.
    func handlePopValueChangeMultipleEntities(
        entities: [Entity],
        targetValue: Float,
        duration: TimeInterval,
        keyMaterialName: String,
        completion: @escaping () -> Void
    ) {
        var animationData: [(modelEntity: ModelEntity, material: ShaderGraphMaterial, initialValue: Float)] = []
        
        for entity in entities {
            guard let modelEntity = findModelEntity(in: entity) else {
                print("Warning: No ModelEntity found in entity: \(entity.name)")
                continue
            }
            
            guard let mat = modelEntity.model?.materials.first as? ShaderGraphMaterial else {
                print("Warning: No ShaderGraphMaterial found in ModelEntity: \(modelEntity.name)")
                continue
            }
            
            var initialValue: Float = 0.0
            if case let .float(value)? = mat.getParameter(name: keyMaterialName) {
                initialValue = value
            }
            
            animationData.append((modelEntity: modelEntity, material: mat, initialValue: initialValue))
        }
        
        guard !animationData.isEmpty else {
            print("Error: No valid entities found for animation")
            completion()
            return
        }
        
        let frameRate: TimeInterval = 1.0 / 60.0
        let totalFrames = Int(duration / frameRate)
        var currentFrame = 0
        
        let randomTimerKey = UUID().uuidString
        timers[randomTimerKey]?.invalidate()
        timers[randomTimerKey] = Timer.scheduledTimer(withTimeInterval: frameRate, repeats: true) { timer in
            currentFrame += 1
            let progress = Float(currentFrame) / Float(totalFrames)
            
            for data in animationData {
                let popValue = data.initialValue + (targetValue - data.initialValue) * progress
                
                do {
                    var updatedMaterial = data.material
                    try updatedMaterial.setParameter(name: keyMaterialName, value: .float(popValue))
                    data.modelEntity.model?.materials = [updatedMaterial]
                } catch {
                    print("Error setting material value for: \(data.modelEntity.name), parameter: \(keyMaterialName) --- \(error)")
                }
            }
            
            if currentFrame >= totalFrames {
                timer.invalidate()
                timers.removeValue(forKey: randomTimerKey)
                completion()
            }
        }
    }
    
    // MARK: - Multi-Parameter Animation
    
    /// Configuration for a single shader parameter animation.
    ///
    /// Stores parameter name, target value, and initial value for multi-parameter
    /// animation sequences where multiple shader properties animate simultaneously.
    struct ParameterAnimation {
        let name: String
        let targetValue: Float
        var initialValue: Float = 0.0
    }
    
    /// Animates multiple shader parameters on a single entity simultaneously.
    ///
    /// Finds ModelEntity and ShaderGraphMaterial, retrieves initial values for all
    /// parameters, creates 60fps timer, updates all parameters synchronously each frame
    /// with linear interpolation, and triggers completion when animation finishes.
    /// Useful for coordinated multi-property transitions like fade+scale+rotation effects.
    func handlePopValueChangeMultipleParameters(
        entity: Entity,
        parameters: [ParameterAnimation],
        duration: TimeInterval,
        completion: @escaping () -> Void
    ) {
        guard let modelEntity = findModelEntity(in: entity) else {
            print("Error: No ModelEntity found in the provided entity")
            completion()
            return
        }
        
        guard let mat = modelEntity.model?.materials.first as? ShaderGraphMaterial else {
            print("Error: No ShaderGraphMaterial found in ModelEntity")
            completion()
            return
        }
        
        var parameterData = parameters
        for i in 0..<parameterData.count {
            if case let .float(value)? = mat.getParameter(name: parameterData[i].name) {
                parameterData[i].initialValue = value
            }
        }
        
        let frameRate: TimeInterval = 1.0 / 60.0
        let totalFrames = Int(duration / frameRate)
        var currentFrame = 0
        
        let randomTimerKey = UUID().uuidString
        timers[randomTimerKey]?.invalidate()
        timers[randomTimerKey] = Timer.scheduledTimer(withTimeInterval: frameRate, repeats: true) { timer in
            currentFrame += 1
            let progress = Float(currentFrame) / Float(totalFrames)
            
            do {
                var updatedMaterial = mat
                
                for paramData in parameterData {
                    let currentValue = paramData.initialValue + (paramData.targetValue - paramData.initialValue) * progress
                    try updatedMaterial.setParameter(name: paramData.name, value: .float(currentValue))
                }
                
                modelEntity.model?.materials = [updatedMaterial]
            } catch {
                print("Error setting material values: \(error)")
            }
            
            if currentFrame >= totalFrames {
                timer.invalidate()
                timers.removeValue(forKey: randomTimerKey)
                completion()
            }
        }
    }
    
    // MARK: - Material Loading
    
    /// Loads a ShaderGraphMaterial by name from a bundle resource.
    ///
    /// Asynchronously loads the specified shader graph material from the bundle resource
    /// using RealityKit's ShaderGraphMaterial initializer. Used for dynamically loading
    /// materials for runtime material swapping or effect application.
    func getShaderGraphMaterial(named name: String, from resource: String, inBundle bundle: Bundle) async throws -> ShaderGraphMaterial {
        let material = try await ShaderGraphMaterial(named: name, from: resource, in: bundle)
        return material
    }
    
}
