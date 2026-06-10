//
//  Recorder.swift
//
//  Created by Jacques André on 29/07/25.
//
import AVFoundation
import Foundation
import SwiftUI
import SwiftData

/// Manages audio recording sessions with real-time speech transcription.
///
/// Coordinates microphone input capture, audio file writing, and streaming audio buffers
/// to the speech transcriber. Uses separate audio engines for recording and playback to prevent
/// conflicts, and provides both standard and fast-start recording modes for optimized performance.
@Observable
class Recorder {
    private var outputContinuation: AsyncStream<AudioData>.Continuation?
    
    private let recordingEngine: AVAudioEngine
    private let playbackEngine: AVAudioEngine
    
    let transcriber: SpokenWordTranscriber
    private var audioFile: AVAudioFile?
    
    private let url: URL
    var isRecording = false
    private var recordingTask: Task<Void, Error>?
    
    init(transcriber: SpokenWordTranscriber) {
        self.recordingEngine = AVAudioEngine()
        self.playbackEngine = AVAudioEngine()
        self.transcriber = transcriber
        self.url = FileManager.default.temporaryDirectory
            .appending(component: UUID().uuidString)
            .appendingPathExtension("wav")
    }
    
    // MARK: - Recording Control
    
    /// Toggles between recording and stopped states.
    ///
    /// Starts a new recording session if currently stopped, or stops the active session if recording.
    func toggleRecording() async throws {
        if isRecording {
            await stopRecording()
        } else {
            try await startRecording()
        }
    }
    
    /// Starts a new recording session with full initialization.
    ///
    /// Checks microphone authorization, configures the audio session, sets up the transcriber,
    /// and begins streaming audio buffers for real-time transcription.
    private func startRecording() async throws {
        print("DEBUG [Recorder]: Starting recording session")
        
        guard !isRecording else {
            print("DEBUG [Recorder]: Already recording, ignoring start request")
            return
        }
        
        guard await isAuthorized() else {
            print("DEBUG [Recorder]: Recording authorization failed")
            throw TranscriptionError.failedToSetupRecognitionStream
        }
        
        do {
            try setUpAudioSession()
            print("DEBUG [Recorder]: Audio session setup completed")
        } catch {
            print("DEBUG [Recorder]: Audio session setup failed: \(error)")
            throw error
        }
        
        transcriber.reset()
        
        do {
            try await transcriber.setUpTranscriber()
            print("DEBUG [Recorder]: Transcriber setup completed")
        } catch {
            print("DEBUG [Recorder]: Transcriber setup failed: \(error)")
            throw error
        }
        
        isRecording = true
        
        recordingTask = Task {
            do {
                let audioStreamSequence = try await audioStream()
                for await audioData in audioStreamSequence {
                    try Task.checkCancellation()
                    try await self.transcriber.streamAudioToTranscriber(audioData.buffer)
                }
            } catch {
                print("DEBUG [Recorder]: Audio streaming error: \(error)")
                if !(error is CancellationError) {
                    throw error
                }
            }
        }
        
        print("DEBUG [Recorder]: Recording started successfully")
    }
    
    /// Starts recording immediately using pre-initialized audio session and transcriber.
    ///
    /// Skips authorization checks and setup steps for minimal latency when the recorder
    /// has been pre-warmed by prior configuration calls.
    func startRecordingFast() async throws {
        guard !isRecording else {
            return
        }
        
        isRecording = true
        
        recordingTask = Task {
            do {
                let audioStreamSequence = try await audioStream()
                for await audioData in audioStreamSequence {
                    try Task.checkCancellation()
                    try await self.transcriber.streamAudioToTranscriber(audioData.buffer)
                }
            } catch {
                if !(error is CancellationError) {
                    throw error
                }
            }
        }
    }

    /// Configures the audio session for simultaneous recording and playback.
    ///
    /// Sets up the shared audio session with play-and-record category optimized for spoken audio,
    /// routing output to the device speaker by default.
    func setUpAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    /// Stops the active recording session and finalizes transcription.
    ///
    /// Cancels the recording task, stops the audio engine, removes audio taps, and completes
    /// the transcription process to generate final text results.
    private func stopRecording() async {
        isRecording = false
        
        recordingTask?.cancel()
        recordingTask = nil
        
        if recordingEngine.isRunning {
            recordingEngine.stop()
        }
        
        recordingEngine.inputNode.removeTap(onBus: 0)
        
        outputContinuation?.finish()
        outputContinuation = nil
        
        do {
            try await transcriber.finishTranscribing()
        } catch {
        }
    }
    
    /// Temporarily pauses audio capture without stopping the recording session.
    func pauseRecording() {
        recordingEngine.pause()
    }
    
    /// Resumes a paused recording session.
    func resumeRecording() throws {
        try recordingEngine.start()
    }
    
    // MARK: - Audio Pipeline
    
    /// Creates an async stream of audio buffers from the microphone input.
    ///
    /// Configures the recording engine, installs an audio tap to capture buffers, and returns
    /// an async stream that yields audio data for processing by consumers.
    private func audioStream() async throws -> AsyncStream<AudioData> {
        try setupRecordingEngine()
        
        recordingEngine.inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: nil
        ) { [weak self] (buffer, time) in
            guard let self else { return }
            
            guard self.isRecording else { return }
            
            self.writeBufferToDisk(buffer: buffer)
            let audioData = AudioData(buffer: buffer, time: time)
            self.outputContinuation?.yield(audioData)
        }
        
        recordingEngine.prepare()
        try recordingEngine.start()
        print("DEBUG [Recorder]: Recording engine started successfully")
        
        return AsyncStream(AudioData.self, bufferingPolicy: .unbounded) { continuation in
            self.outputContinuation = continuation
            
            continuation.onTermination = { @Sendable _ in
                print("DEBUG [Recorder]: Audio stream terminated")
            }
        }
    }
    
    /// Prepares the recording engine for audio capture.
    ///
    /// Stops any existing recording, removes audio taps, and resets the engine to a clean state
    /// before starting a new recording session.
    private func setupRecordingEngine() throws {
        if recordingEngine.isRunning {
            recordingEngine.stop()
        }
        
        recordingEngine.inputNode.removeTap(onBus: 0)
        recordingEngine.reset()
        
        _ = recordingEngine.inputNode.outputFormat(forBus: 0)
    }
    
    /// Writes an audio buffer to the on-disk audio file.
    private func writeBufferToDisk(buffer: AVAudioPCMBuffer) {
        guard let audioFile = audioFile else { return }
        
        do {
            try audioFile.write(from: buffer)
        } catch {
        }
    }
    
    deinit {
        if recordingEngine.isRunning {
            recordingEngine.stop()
        }
        recordingEngine.inputNode.removeTap(onBus: 0)
        
        if playbackEngine.isRunning {
            playbackEngine.stop()
        }
    }
}

