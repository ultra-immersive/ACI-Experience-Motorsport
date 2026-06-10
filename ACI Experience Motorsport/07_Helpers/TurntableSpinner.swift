//
// TurntableSpinner.swift
// ACI Experience Motorsport
//
// Created by Jacques André on 01/04/26.
//


import Foundation
import RealityKit

@MainActor
@Observable
class TurntableSpinner {
  private var baseOrientation: simd_quatf = .init(ix: 0, iy: 0, iz: 0, r: 1)

  private(set) var isActive = false

  // MARK: - Private State

  private var timer: Timer?
  private weak var entity: Entity?

  private var currentVelocity: Float = 0
  private var targetVelocity: Float = 0
  private var timeConstant: Float = 0.5
  private var angle: Float = 0

  private var stopCompletion: (() -> Void)?

  private var isAnimatingHome = false
  private var homeStartAngle: Float = 0
  private var homeEndAngle: Float = 0
  private var homeDuration: Float = 0
  private var homeElapsed: Float = 0

  func start(entity: Entity, rpm: Float = 3.0, easeInDuration: TimeInterval = 1.5) {
    teardown()

    self.entity = entity
    self.baseOrientation = entity.orientation
    self.targetVelocity = rpm * (.pi * 2.0) / 60.0
    self.timeConstant = max(Float(easeInDuration) / 3.0, 0.01)
    self.currentVelocity = 0
    self.angle = 0
    self.isActive = true
    self.isAnimatingHome = false

    let interval: TimeInterval = 1.0 / 60.0
    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.tick(Float(interval)) }
    }
  }

  // MARK: - Stop (immediate ease-out, stops wherever it lands)

  func stop(easeOutDuration: TimeInterval = 1.5, completion: (() -> Void)? = nil) {
    guard isActive, !isAnimatingHome else {
      completion?()
      return
    }

    targetVelocity = 0
    timeConstant = max(Float(easeOutDuration) / 3.0, 0.01)
    stopCompletion = completion
  }

  func stopAtHome(
    duration: TimeInterval = 2.0,
    minimumArc: Float = .pi / 2,
    completion: (() -> Void)? = nil
  ) {
    guard isActive, !isAnimatingHome else {
      completion?()
      return
    }

    let twoPi: Float = .pi * 2.0

     var normalized = angle.truncatingRemainder(dividingBy: twoPi)
    if normalized < 0 { normalized += twoPi }

     var remaining = twoPi - normalized

     if remaining < minimumArc {
      remaining += twoPi
    }

    homeStartAngle = angle
    homeEndAngle = angle + remaining
    homeDuration = max(Float(duration), 0.01)
    homeElapsed = 0
    isAnimatingHome = true
    stopCompletion = completion

    // Kill velocity-driven mode
    targetVelocity = 0
    currentVelocity = 0
  }

  // MARK: - Tick

  private func tick(_ dt: Float) {
    guard let entity else { teardown(); return }

    if isAnimatingHome {
      tickHome(dt: dt, entity: entity)
    } else {
      tickVelocity(dt: dt, entity: entity)
    }
  }

  /// Velocity-driven tick with exponential smoothing.
  private func tickVelocity(dt: Float, entity: Entity) {
    let alpha = 1.0 - exp(-dt / timeConstant)
    currentVelocity += (targetVelocity - currentVelocity) * alpha

    if targetVelocity == 0 && abs(currentVelocity) < 0.005 {
      currentVelocity = 0
      let callback = stopCompletion
      teardown()
      callback?()
      return
    }

    angle += currentVelocity * dt
    angle = angle.truncatingRemainder(dividingBy: .pi * 2.0)

    let spin = simd_quatf(angle: angle, axis: [0, 1, 0])
    entity.orientation = spin * baseOrientation
  }

  private func tickHome(dt: Float, entity: Entity) {
    homeElapsed += dt

    let t = min(homeElapsed / homeDuration, 1.0)
    let eased = 1.0 - pow(1.0 - t, 3)

    angle = homeStartAngle + (homeEndAngle - homeStartAngle) * eased

    let spin = simd_quatf(angle: angle, axis: [0, 1, 0])
    entity.orientation = spin * baseOrientation

    if t >= 1.0 {
      entity.orientation = baseOrientation
      let callback = stopCompletion
      teardown()
      callback?()
    }
  }

  // MARK: - Teardown

  /// Immediate cleanup with no deceleration. Safe to call multiple times.
  func teardown() {
    timer?.invalidate()
    timer = nil
    entity = nil
    isActive = false
    currentVelocity = 0
    targetVelocity = 0
    isAnimatingHome = false
    homeElapsed = 0
    stopCompletion = nil
    baseOrientation = .init(ix: 0, iy: 0, iz: 0, r: 1)
  }
}
