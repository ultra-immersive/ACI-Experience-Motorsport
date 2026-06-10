//
//  SpokenWordTranscriber.swift
//
//  Created by Jacques André on 29/07/25.
//

import Foundation
import Speech
import SwiftUI
import FoundationModels

/// Performs real-time speech-to-text transcription using Apple's Speech framework.
///
/// Manages the complete transcription pipeline including audio format conversion, speech analysis,
/// and result streaming. Produces both volatile (in-progress) and finalized transcript results
/// with support for Italian locale and progressive transcription mode.
@Observable
@MainActor
final class SpokenWordTranscriber {
    private var inputSequence: AsyncStream<AnalyzerInput>?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var recognizerTask: Task<(), any Error>?

    var analyzerFormat: AVAudioFormat?

    let converter = BufferConverter()

    var volatileTranscript: AttributedString = ""
    var finalizedTranscript: AttributedString = ""

    static let locale = Locale(
        components: .init(languageCode: .italian, script: nil, languageRegion: .italy))
    
    static let fallbackLocales = [
        Locale(components: .init(languageCode: .italian, script: nil, languageRegion: .italy)),
        Locale(components: .init(languageCode: .italian, script: nil, languageRegion: .italy)),
        Locale.current
    ]

    init() {
        print(
            "[Transcriber DEBUG]: Initializing SpokenWordTranscriber with locale: \(SpokenWordTranscriber.locale.identifier)"
        )
    }
    
    // MARK: - Setup and Configuration
    
    /// Initializes the speech recognition pipeline for a new transcription session.
    ///
    /// Creates the transcriber with progressive transcription settings, configures the speech analyzer,
    /// determines the optimal audio format, and starts a task to continuously process recognition results.
    func setUpTranscriber() async throws {
        await cleanup()
        
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputSequence = stream
        self.inputBuilder = continuation
        
        transcriber = SpeechTranscriber(
            locale: SpokenWordTranscriber.locale,
            preset: .progressiveTranscription
        )
        
        guard let transcriber else {
            throw TranscriptionError.failedToSetupRecognitionStream
        }
        
        // Ensure the on-device model is present before proceeding
        try await ensureModel(transcriber: transcriber, locale: SpokenWordTranscriber.locale)
        
        analyzer = SpeechAnalyzer(modules: [transcriber])

        self.analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [
            transcriber
        ])

        guard analyzerFormat != nil else {
            print("[Transcriber DEBUG]: ERROR - No compatible audio format found")
            throw TranscriptionError.invalidAudioDataType
        }

        recognizerTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                var resultCount = 0
                for try await case let result in transcriber.results {
                    try Task.checkCancellation()
                    
                    resultCount += 1
                    let text = result.text
                    
                    await MainActor.run {
                        if result.isFinal {
                            self.finalizedTranscript += text
                            self.volatileTranscript = ""
                        } else {
                            self.volatileTranscript = text
                            self.volatileTranscript.foregroundColor = .purple.opacity(0.5)
                        }
                    }
                }
            } catch {
                if error is CancellationError {
                } else {
                    print(
                        "[Transcriber DEBUG]: ERROR - Speech recognition failed: \(error.localizedDescription)"
                    )
                }
            }
        }

        do {
            guard let inputSequence = inputSequence else {
                throw TranscriptionError.failedToSetupRecognitionStream
            }
            try await analyzer?.start(inputSequence: inputSequence)
        } catch {
            print(
                "[Transcriber DEBUG]: ERROR - Failed to start SpeechAnalyzer: \(error.localizedDescription)"
            )
            throw error
        }
    }

    // MARK: - Audio Streaming
    
    
    @MainActor
    func ensureModel(transcriber: SpeechTranscriber, locale: Locale) async throws {
        // Check if locale is supported at all
        guard await SpeechTranscriber.supportedLocales.contains(where: {
            $0.identifier(.bcp47) == locale.identifier(.bcp47)
        }) else {
            throw TranscriptionError.localeNotSupported
        }
        
        // Check if model is already installed
        if await SpeechTranscriber.installedLocales.contains(where: {
            $0.identifier(.bcp47) == locale.identifier(.bcp47)
        }) {
            print("[Transcriber] Italian model already installed")
            return
        }
        
        // Download it
        print("[Transcriber] Italian model not installed — downloading...")
        try await downloadIfNeeded(for: transcriber)
    }

    private func downloadIfNeeded(for module: SpeechTranscriber) async throws {
        if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            // downloader.progress is a Foundation Progress you can observe
            try await downloader.downloadAndInstall()
            print("[Transcriber] Model download complete")
        }
    }
    
    /// Streams an audio buffer to the transcription pipeline.
    ///
    /// Converts the buffer to the required format and feeds it to the speech analyzer
    /// for processing and recognition.
    func streamAudioToTranscriber(_ buffer: AVAudioPCMBuffer) async throws {
        guard let analyzerFormat else {
            throw TranscriptionError.invalidAudioDataType
        }

        guard let inputBuilder = inputBuilder else {
            throw TranscriptionError.failedToSetupRecognitionStream
        }

        let converted = try self.converter.convertBuffer(buffer, to: analyzerFormat)
        let input = AnalyzerInput(buffer: converted)
        inputBuilder.yield(input)
    }

    // MARK: - Session Management
    
    /// Completes the transcription session and processes remaining audio.
    ///
    /// Finishes the input stream, allows the analyzer to process all pending audio,
    /// and cancels the recognition task to produce final results.
    public func finishTranscribing() async throws {
        inputBuilder?.finish()
        
        if let analyzer = analyzer {
            do {
                try await analyzer.finalizeAndFinishThroughEndOfInput()
            } catch {
            }
        }
        
        recognizerTask?.cancel()
        recognizerTask = nil
    }

    /// Clears transcript results for a new recording session.
    ///
    /// Resets both volatile and finalized transcript text without tearing down
    /// the transcription pipeline.
    public func reset() {
        volatileTranscript = ""
        finalizedTranscript = ""
    }
    
    /// Releases all transcription resources including analyzer and recognition tasks.
    ///
    /// Performs complete cleanup of the speech recognition pipeline to prepare
    /// for a fresh setup.
    private func cleanup() async {
        recognizerTask?.cancel()
        recognizerTask = nil
        
        inputBuilder?.finish()
        inputBuilder = nil
        inputSequence = nil
        
        if let analyzer = analyzer {
            await analyzer.cancelAndFinishNow()
        }
        
        analyzer = nil
        transcriber = nil
        analyzerFormat = nil
    }
}

// MARK: - Supporting Types

/// Errors that can occur during speech transcription operations.
public enum TranscriptionError: Error {
    case couldNotDownloadModel
    case failedToSetupRecognitionStream
    case invalidAudioDataType
    case localeNotSupported
    case noInternetForModelDownload
    case audioFilePathNotFound

    var descriptionString: String {
        switch self {
        case .couldNotDownloadModel:
            return "Could not download the model."
        case .failedToSetupRecognitionStream:
            return "Could not set up the speech recognition stream."
        case .invalidAudioDataType:
            return "Unsupported audio format."
        case .localeNotSupported:
            return "This locale is not yet supported by SpeechAnalyzer."
        case .noInternetForModelDownload:
            return "The model could not be downloaded because the user is not connected to internet."
        case .audioFilePathNotFound:
            return "Couldn't write audio to file."
        }
    }
}

/// Wraps audio buffer and timing information for sendable audio streaming.
public struct AudioData: @unchecked Sendable {
    var buffer: AVAudioPCMBuffer
    var time: AVAudioTime
}

// MARK: - Authorization

extension Recorder {
    /// Checks and requests microphone access permission.
    ///
    /// Returns immediately if already authorized, otherwise prompts the user
    /// for microphone access and returns the result.
    nonisolated func isAuthorized() async -> Bool {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
            return true
        }

        return await AVCaptureDevice.requestAccess(for: .audio)
    }
}
