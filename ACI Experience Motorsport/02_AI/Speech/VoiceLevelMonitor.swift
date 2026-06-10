//
//  VoiceLevelMonitor.swift
//
//  Created by Jacques André on 29/07/25.
//


import AVFoundation
import Combine
import Accelerate
import SwiftUI

/// Monitors real-time microphone input levels for voice-reactive animations.
///
/// Captures audio from the device microphone, calculates RMS power levels, and publishes
/// normalized voice intensity values (0.0-1.0) suitable for driving shader parameters
/// Uses asymmetric smoothing to create natural rise and fall animations.
@MainActor
class VoiceLevelMonitor: ObservableObject {
    @Published var voiceLevel: CGFloat = 0.0
    
    private let engine = AVAudioEngine()
    private var lastSmoothedLevel: CGFloat = 0.0
    
    private let silenceThreshold: Float = -50.0
    private let maxThreshold: Float = -20.0
    private let smoothingFactor: CGFloat = 0.5
    
    // MARK: - Monitoring Control
    
    /// Begins capturing and processing microphone input.
    ///
    /// Installs an audio tap on the input node to continuously analyze voice levels
    /// and publish normalized values through the `voiceLevel` property.
    func startMonitoring() {
        let inputNode = engine.inputNode
        _ = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 512, format: nil) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            
            var rms: Float = 0
            vDSP_measqv(channelData, 1, &rms, vDSP_Length(frameCount))
            let avgPower = 10 * log10(rms + 1e-10)
            
            let normalized: Float
            if avgPower < self.silenceThreshold {
                normalized = 0
            } else {
                let range = self.maxThreshold - self.silenceThreshold
                normalized = min(1.0, max(0, (avgPower - self.silenceThreshold) / range))
            }
            
            Task { @MainActor in
                self.smoothToLevel(CGFloat(normalized))
            }
        }
        
        do {
            try engine.start()
        } catch {
            print(" Voice monitor failed: \(error)")
        }
    }
    
    /// Stops microphone monitoring and resets voice level to zero.
    ///
    /// Removes the audio tap, stops the audio engine, and clears all accumulated state.
    func stopMonitoring() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        voiceLevel = 0
        lastSmoothedLevel = 0
    }
    
    // MARK: - Signal Processing
    
    /// Applies asymmetric smoothing to create natural voice animation curves.
    ///
    /// Uses faster rise time and slower fall time to produce visually appealing
    /// reactions to speech while avoiding jittery motion.
    private func smoothToLevel(_ newLevel: CGFloat) {
        let factor = newLevel > lastSmoothedLevel ? 0.7 : 0.4
        lastSmoothedLevel = (factor * newLevel) + (1 - factor) * lastSmoothedLevel
        voiceLevel = lastSmoothedLevel
    }
}

