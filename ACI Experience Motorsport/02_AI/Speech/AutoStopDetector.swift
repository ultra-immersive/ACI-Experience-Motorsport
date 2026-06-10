//
//  AutoStopDetector.swift
//
//  Created by Jacques André on 04/08/25.
//

import SwiftUI
import Combine

/// Automatically detects when to stop voice recording based on silence and duration thresholds.
///
/// Monitors transcription activity in real-time to  end recording sessions when the user
/// stops speaking, while preventing premature cutoffs and enforcing maximum duration limits.
@MainActor
class AutoStopDetector: ObservableObject {
    @Published var shouldStop = false
    
    private var monitoringTask: Task<Void, Never>?
    private var recordingStartTime: Date?
    private var lastSignificantUpdate: Date?
    private var lastTranscriptLength = 0
    
    private let maxRecordingDuration: TimeInterval = 8.0
    private let silenceThreshold: TimeInterval = 4.0
    private let minimumRecordingTime: TimeInterval = 2.0
    
    // MARK: - Monitoring Control
    
    /// Begins monitoring the transcriber for automatic stop conditions.
    ///
    /// checks transcript activity and recording duration, triggering the provided
    /// callback when silence is detected or maximum recording time is reached.
    func startMonitoring(
        transcriber: SpokenWordTranscriber,
        onStop: @escaping () async -> Void
    ) {
        recordingStartTime = Date()
        lastSignificantUpdate = Date()
        lastTranscriptLength = 0
        shouldStop = false
        
        monitoringTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(300))
                
                guard let startTime = recordingStartTime else { continue }
                let elapsed = Date().timeIntervalSince(startTime)
                
                let fullTranscript = transcriber.finalizedTranscript + transcriber.volatileTranscript
                let currentLength = fullTranscript.characters.count
                
                if currentLength > lastTranscriptLength {
                    lastSignificantUpdate = Date()
                    lastTranscriptLength = currentLength
                }
                
                if shouldStopRecording(elapsed: elapsed, transcriptLength: currentLength) {
                    shouldStop = true
                    await onStop()
                    break
                }
            }
        }
    }
    
    /// Stops the monitoring task and resets all tracking state.
    func stop() {
        monitoringTask?.cancel()
        monitoringTask = nil
        recordingStartTime = nil
        lastSignificantUpdate = nil
        lastTranscriptLength = 0
        shouldStop = false
    }
    
    // MARK: - Detection Logic
    
    /// Determines whether recording should stop based on duration and silence criteria.
    ///
    /// Enforces maximum recording duration, prevents premature stops before minimum time,
    /// and detects sustained silence after the user has spoken.
    private func shouldStopRecording(elapsed: TimeInterval, transcriptLength: Int) -> Bool {
        if elapsed >= maxRecordingDuration {
            return true
        }
        
        if elapsed < minimumRecordingTime {
            return false
        }
        
        if let lastUpdate = lastSignificantUpdate,
           transcriptLength > 0,
           Date().timeIntervalSince(lastUpdate) > silenceThreshold {
            return true
        }
        
        return false
    }
}
