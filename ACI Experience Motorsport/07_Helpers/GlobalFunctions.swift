//
//  GlobalFunctions.swift
//
//  Created by Jacques André on 10/10/25.
//

import Foundation
import RealityKit
import SwiftUI

// MARK: - Entity Search

/// Recursively finds the first `ModelEntity` in an entity hierarchy via depth-first traversal.
func findModelEntity(in entity: Entity) -> ModelEntity? {
    if let modelEntity = entity as? ModelEntity {
        return modelEntity
    }
    for child in entity.children {
        if let foundEntity = findModelEntity(in: child) {
            return foundEntity
        }
    }
    return nil
}

// MARK: - Transform Animations

/// Animates an entity's scale to a target value over a given duration using `CADisplayLink`.
func graduallyChangeScale(
    entity: Entity,
    targetScale: SIMD3<Float>,
    duration: TimeInterval,
    completion: (() -> Void)? = nil
) {
    let startScale = entity.scale
    let startTime = CACurrentMediaTime()
    
    var displayLink: CADisplayLink?
    
    displayLink = CADisplayLink(target: BlockOperation {
        let elapsedTime = CACurrentMediaTime() - startTime
        let progress = min(Float(elapsedTime / duration), 1.0)
        
        entity.scale = startScale + (targetScale - startScale) * progress
        
        if progress >= 1.0 {
            displayLink?.invalidate()
            completion?()
        }
    }, selector: #selector(Operation.main))
    displayLink?.add(to: .main, forMode: .default)
}

/// Animates an entity's orientation to a target quaternion over a given duration.
func graduallyChangeOrientation(entity: Entity, targetOrientation: simd_quatf, duration: TimeInterval) {
    let startOrientation = entity.orientation
    let startTime = CACurrentMediaTime()
    
    var displayLink: CADisplayLink?
    
    displayLink = CADisplayLink(target: BlockOperation {
        let elapsedTime = CACurrentMediaTime() - startTime
        let progress = min(Float(elapsedTime / duration), 1.0)
        
        let newOrientation = startOrientation + (targetOrientation - startOrientation) * progress
        
        entity.orientation = newOrientation
        if progress >= 1.0 {
            displayLink?.invalidate()
        }
    }, selector: #selector(Operation.main))
    displayLink?.add(to: .main, forMode: .default)
}

// MARK: - Component Animations

/// Animates an entity's `OpacityComponent` to a target value over a given duration.
func graduallyChangeOpacity(entity: Entity, targetOpacity: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
    guard var opacityComponent = entity.components[OpacityComponent.self] else {
        completion?()
        return
    }
    
    let startOpacity = opacityComponent.opacity
    let startTime = CACurrentMediaTime()
    
    var displayLink: CADisplayLink?
    
    displayLink = CADisplayLink(target: BlockOperation {
        let elapsedTime = CACurrentMediaTime() - startTime
        let progress = min(Float(elapsedTime / duration), 1.0)
        
        let newOpacity = startOpacity + (targetOpacity - startOpacity) * progress
        
        opacityComponent.opacity = newOpacity
        entity.components[OpacityComponent.self] = opacityComponent
        
        if progress >= 1.0 {
            displayLink?.invalidate()
            
            DispatchQueue.main.async {
                completion?()
            }
        }
    }, selector: #selector(Operation.main))
    
    displayLink?.add(to: .main, forMode: .default)
}

/// Animates an entity's `BillboardComponent` blend factor to a target value over a given duration.
func graduallyChangeBillboardBlend(
    entity: Entity,
    targetBlendFactor: Float,
    duration: TimeInterval,
    completion: (() -> Void)? = nil
) {
    guard var billboardComponent = entity.components[BillboardComponent.self] else {
        print("BillboardComponent not found")
        completion?()
        return
    }
    
    let startBlendFactor = billboardComponent.blendFactor
    let startTime = CACurrentMediaTime()
    
    var displayLink: CADisplayLink?
    
    displayLink = CADisplayLink(target: BlockOperation {
        let elapsedTime = CACurrentMediaTime() - startTime
        let progress = min(Float(elapsedTime / duration), 1.0)
        
        let newBlendFactor = startBlendFactor + (targetBlendFactor - startBlendFactor) * progress
        
        billboardComponent.blendFactor = newBlendFactor
        entity.components[BillboardComponent.self] = billboardComponent
        
        if progress >= 1.0 {
            displayLink?.invalidate()
            
            DispatchQueue.main.async {
                completion?()
            }
        }
    }, selector: #selector(Operation.main))
    
    displayLink?.add(to: .main, forMode: .default)
}

// MARK: - Style Manager Animations

/// Animates the `StyleManager` surrounding color effect from one color to another in discrete steps.
func graduallyChangeColorEffect(
  duration: TimeInterval,
  styleManager: StyleManager,
  startColor: SIMD3<Float>,
  targetColor: SIMD3<Float>,
  completion: @escaping () -> Void
) {
  let numberOfSteps = 5
  let stepDuration = duration / Double(numberOfSteps)
  var currentStep = 0
    _ = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
    currentStep += 1
    let progress = Float(currentStep) / Float(numberOfSteps)
    if currentStep >= numberOfSteps {
      timer.invalidate()
      styleManager.currentSourroundingEffect = .colorMultiply(Color(
        red: Double(targetColor.x),
        green: Double(targetColor.y),
        blue: Double(targetColor.z)
      ))
      completion()
      return
    }
    let interpolatedColor = lerpColor(from: startColor, to: targetColor, progress: progress)
    styleManager.currentSourroundingEffect = .colorMultiply(Color(
      red: Double(interpolatedColor.x),
      green: Double(interpolatedColor.y),
      blue: Double(interpolatedColor.z)
    ))
  }
  let interpolatedColor = lerpColor(from: startColor, to: targetColor, progress: 0)
  styleManager.currentSourroundingEffect = .colorMultiply(Color(
    red: Double(interpolatedColor.x),
    green: Double(interpolatedColor.y),
    blue: Double(interpolatedColor.z)
  ))
}

// MARK: - Helper Functions

/// Linearly interpolates between two SIMD3 colors by the given progress (0–1).
func lerpColor(from startColor: SIMD3<Float>, to endColor: SIMD3<Float>, progress: Float) -> SIMD3<Float> {
    return startColor + (endColor - startColor) * progress
}
