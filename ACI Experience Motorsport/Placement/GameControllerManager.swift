//
//  GameControllerManager.swift
//  ACI Experience Motorsport
//
//

import Foundation
import GameController
import AVFoundation
import CoreHaptics
import Combine
/// A manager class for handling gamepad controller interactions and haptic feedback.
class GameControllerManager: ObservableObject {
    
    static let shared = GameControllerManager()
    
    // MARK: - Published Properties
    
    @Published var controllerConnected: Bool = false
    @Published var controllerName: String = "No Controller"
    
    // MARK: - Button Press Handlers
    
    var onYButtonPress: (() -> Void)?
    var onAButtonPress: (() -> Void)?
    var onBButtonPress: (() -> Void)?
    var onXButtonPress: (() -> Void)?
    var onRightTriggerPress: (() -> Void)?
    var onRightShoulderPress: (() -> Void)?
    
    // MARK: - Thumbstick Movement Handlers
    
    var onLeftThumbstickChanged: ((Float, Float) -> Void)?
    var onRightThumbstickChanged: ((Float, Float) -> Void)?
    
    // MARK: - Private Properties
    
    private var yButtonPressStart: Date?
    private var yButtonPressTimer: Timer?
    private var engineMap = [GCHapticsLocality: CHHapticEngine]()
    
    // MARK: - Initialization and Setup
    
    /// Initializes the `GameControllerManager` instance, sets up observers, and begins controller discovery.
    init() {
        setupObservers()
        registerConnectedControllers()
        startControllerDiscovery()
    }
    
    // MARK: - Controller Setup and Management
    
    /// Sets up observers for controller connection and disconnection notifications.
    private func setupObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(controllerDidConnect(_:)),
                                               name: .GCControllerDidConnect,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(controllerDidDisconnect(_:)),
                                               name: .GCControllerDidDisconnect,
                                               object: nil)
    }
    
    /// Registers any currently connected controllers.
    private func registerConnectedControllers() {
        for controller in GCController.controllers() {
            registerGameController(controller)
        }
    }
    
    /// Starts wireless controller discovery to allow dynamic connection of game controllers.
    private func startControllerDiscovery() {
        GCController.startWirelessControllerDiscovery {
        }
    }
    
    // MARK: - Controller Connection and Disconnection Handling
    
    /// Called when a controller connects. Registers the connected controller.
    @objc private func controllerDidConnect(_ notification: Notification) {
        if let controller = notification.object as? GCController {
            print("Controller did connect: \(controller.vendorName ?? "Unknown")")
            registerGameController(controller)
        }
    }
    
    /// Called when a controller disconnects. Updates the state accordingly.
    @objc private func controllerDidDisconnect(_ notification: Notification) {
        if let controller = notification.object as? GCController {
            controllerConnected = false
            controllerName = "No Controller"
            engineMap.removeAll()
            print("Controller disconnected: \(controller.vendorName ?? "Unknown")")
        }
    }
    
    /// Registers a game controller by checking if it has a supported profile (extended or micro gamepad).
    private func registerGameController(_ controller: GCController) {
        controllerConnected = true
        controllerName = controller.productCategory
        
        if let gamepad = controller.extendedGamepad {
            setupExtendedGamepad(gamepad)
            createHapticEngine(for: controller)
        } else if let microGamepad = controller.microGamepad {
            setupMicroGamepad(microGamepad)
        } else {
            print("No supported gamepad profile found.")
        }
    }
    
    // MARK: - Haptic Engine Management
    
    /// Creates a haptic engine for the specified controller.
    /// - Parameter controller: The `GCController` to create a haptic engine for.
    private func createHapticEngine(for controller: GCController) {
        guard let engine = controller.haptics?.createEngine(withLocality: .default) else {
            print("Failed to create haptic engine for controller.")
            return
        }
        
        engine.stoppedHandler = { reason in
            print("Haptic engine stopped: \(reason)")
        }
        
        engine.resetHandler = {
            print("Haptic engine reset, restarting...")
            do {
                try engine.start()
            } catch {
                print("Failed to restart haptic engine: \(error)")
            }
        }
        
        engineMap[GCHapticsLocality.default] = engine
    }
    
    /// Plays a haptic pattern file with the given filename.
    /// - Parameters:
    ///   - filename: The name of the haptic pattern file (without extension).
    ///   - locality: The locality where the haptic engine is applied (default is `.default`).
    func playHapticsFile(named filename: String, locality: GCHapticsLocality = .default) {
        guard let engine = engineMap[locality],
              let url = Bundle.main.url(forResource: filename, withExtension: "ahap") else {
            print("Haptic file or engine not found.")
            return
        }
        
        do {
            try engine.start()
            try engine.playPattern(from: url)
        } catch {
            print("Error playing haptic pattern: \(error)")
        }
    }
    
    /// Stops the haptic feedback for a given locality.
    /// - Parameter locality: The locality where haptic feedback should be stopped (default is `.default`).
    func stopHaptics(for locality: GCHapticsLocality = .default) {
        guard let engine = engineMap[locality] else {
            print("No haptic engine available for locality \(locality).")
            return
        }
        
        engine.stop()
    }
    
    // MARK: - Extended Gamepad Setup
    
    /// Configures the extended gamepad and its button handlers.
    private func setupExtendedGamepad(_ gamepad: GCExtendedGamepad) {
        
        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.startYButtonPressTimer()
            } else {
                self?.stopYButtonPressTimer()
            }
        }
        
        gamepad.rightTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.playHapticsFile(named: "Placement")
                self?.onRightTriggerPress?()
            }
        }
        
        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.onRightShoulderPress?()
            }
        }
         
    }
    
    // MARK: - Micro Gamepad Setup
    
    /// Configures the micro gamepad and its button handlers.
    private func setupMicroGamepad(_ gamepad: GCMicroGamepad) {
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.onAButtonPress?() }
        }
        
        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.onXButtonPress?() }
        }
    }
    
    // MARK: - Y Button Timer Logic
    
    /// Starts the timer for the Y button press and triggers actions if held for more than 2 seconds.
    private func startYButtonPressTimer() {
        yButtonPressStart = Date()
        SoundManager.shared.playAmbientSound(named: "loadingReset")
        
        yButtonPressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.yButtonPressStart else {
                self?.stopYButtonPressTimer()
                return
            }
            
            self.playHapticsFile(named: "Hit")
            let elapsed = Date().timeIntervalSince(startTime)
            
            if elapsed >= 2 {
                self.onYButtonPress?()
                self.stopYButtonPressTimer()
                self.playHapticsFile(named: "Delete")
            }
        }
    }
    
    /// Stops the Y button press timer.
    private func stopYButtonPressTimer() {
        yButtonPressStart = nil
        yButtonPressTimer?.invalidate()
        yButtonPressTimer = nil
        SoundManager.shared.stopSound(named: "loadingReset")
    }
    
    // MARK: - Right Shoulder Button Timer Logic
    
    /// Starts the timer for the right shoulder button press.
    private func startRightShoulderButtonPressTimer() {
        yButtonPressStart = Date()
        
        yButtonPressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.yButtonPressStart else {
                self?.stopYButtonPressTimer()
                return
            }
            
            self.playHapticsFile(named: "Hit")
            let elapsed = Date().timeIntervalSince(startTime)
            
            if elapsed >= 2 {
                self.onRightShoulderPress?()
                self.stopYButtonPressTimer()
            }
        }
    }
    
    /// Stops the right shoulder button press timer.
    private func stopRightShouldButtonPressTimer() {
        yButtonPressStart = nil
        yButtonPressTimer?.invalidate()
        yButtonPressTimer = nil
        SoundManager.shared.stopSound(named: "rewind")
    }
    
    // MARK: - Reset Logic
    
    /// Resets the `GameControllerManager` by stopping controller discovery and resetting state.
    func resetGameControllerManager() {
        // Stop wireless controller discovery and remove observers
        GCController.stopWirelessControllerDiscovery()
        NotificationCenter.default.removeObserver(self)
        
        // Reset State
        controllerConnected = false
        controllerName = "No Controller"
        engineMap.removeAll()
        
        // Re-register connected controllers
        setupObservers()
        registerConnectedControllers()
        startControllerDiscovery()
    }
}
