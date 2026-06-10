//
//  ExperienceTimer.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 03/03/26.
//

import Foundation

/// Countdown timer that controls the overall experience duration.
///
/// Once expired, waits for any active video playback or module timeline
/// to finish before firing the experience-end callback.
@MainActor
@Observable
class ExperienceTimer {
    
    // MARK: - Configuration
    
    var duration: TimeInterval = 15 * 60
    
    // MARK: - State
    
    private(set) var isRunning = false
    private(set) var isExpired = false
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var activeModules: Set<ModuleType> = []
            
    var isActivityInProgress: Bool {
        let videoPlaying = videoPlaybackChecker?() ?? false
        let modulesActive = !activeModules.isEmpty
        return videoPlaying || modulesActive
    }
    
    // MARK: - Callbacks
    
    var onExperienceEnd: (() -> Void)?
    var onTimerExpired: (() -> Void)?
    
    // MARK: - Private
    
    private var timer: Timer?
    private var activityCheckTimer: Timer?
    private var videoPlaybackChecker: (() -> Bool)?
    
    // MARK: - Setup
    
    /// Registers a closure that returns whether a video is currently playing.
    func setVideoPlaybackChecker(_ checker: @escaping () -> Bool) {
        self.videoPlaybackChecker = checker
    }
    
    // MARK: - Module Tracking
    
    /// Marks a module timeline as active, preventing experience-end until it finishes.
    func moduleDidStart(_ module: ModuleType) {
        activeModules.insert(module)
    }
    
    /// Marks a module timeline as finished. Triggers experience-end check if the timer has already expired.
    func moduleDidEnd(_ module: ModuleType) {
        activeModules.remove(module)
        if isExpired {
            checkAndEndIfReady()
        }
    }
    
    // MARK: - Control
    
    /// Resets and starts the countdown.
    func start() {
        guard !isRunning else { return }
        reset()
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    /// Stops the countdown without resetting elapsed time.
    func stop() {
        invalidateTimers()
        isRunning = false
    }
    
    /// Stops the countdown and resets all state.
    func reset() {
        invalidateTimers()
        isRunning = false
        isExpired = false
        elapsedTime = 0
        activeModules.removeAll()
    }
    
    // MARK: - Tick
    
    private func tick() {
        guard isRunning else { return }
        
        elapsedTime += 1.0
        
        if elapsedTime >= duration && !isExpired {
            isExpired = true
            timer?.invalidate()
            timer = nil
            onTimerExpired?()
            checkAndEndIfReady()
        }
    }
    
    // MARK: - Activity-Aware End
    
    /// Fires `onExperienceEnd` if no activity is in progress, otherwise polls every 0.5s until clear.
    private func checkAndEndIfReady() {
        guard isExpired else { return }
        
        if !isActivityInProgress {
            invalidateTimers()
            onExperienceEnd?()
            return
        }
        
        guard activityCheckTimer == nil else { return }
        
        activityCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if !self.isActivityInProgress {
                    self.activityCheckTimer?.invalidate()
                    self.activityCheckTimer = nil
                    self.onExperienceEnd?()
                }
            }
        }
    }
    
    // MARK: - Cleanup
    
    private func invalidateTimers() {
        timer?.invalidate()
        timer = nil
        activityCheckTimer?.invalidate()
        activityCheckTimer = nil
    }
    
    /// Stops the timer, resets all state, and releases callbacks.
    func cleanup() {
        invalidateTimers()
        isRunning = false
        isExpired = false
        elapsedTime = 0
        activeModules.removeAll()
        onExperienceEnd = nil
        onTimerExpired = nil
        videoPlaybackChecker = nil
    }
}
