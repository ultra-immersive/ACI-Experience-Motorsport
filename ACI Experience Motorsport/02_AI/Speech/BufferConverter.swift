//
//  BufferConverter.swift
//
//  Created by Jacques André on 29/07/25.
//

@preconcurrency import AVFoundation
import Foundation
import os

/// Converts audio buffers between different PCM formats with automatic sample rate conversion.
///
/// Provides efficient audio format conversion using `AVAudioConverter`, handling sample rate
/// adjustments and format transformations required for audio processing pipelines. Maintains
/// converter state for reuse across multiple conversions to the same target format.
class BufferConverter {
    enum Error: Swift.Error {
        case failedToCreateConverter
        case failedToCreateConversionBuffer
        case conversionFailed(NSError?)
    }

    private var converter: AVAudioConverter?
    
    // MARK: - Conversion
    
    /// Converts an audio buffer to a different PCM format.
    ///
    /// Creates or reuses an `AVAudioConverter` to transform the input buffer to the target format,
    /// automatically calculating the appropriate output buffer size based on sample rate ratios.
    /// Returns the original buffer unchanged if formats already match.
    func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws
        -> AVAudioPCMBuffer
    {
        let inputFormat = buffer.format
        guard inputFormat != format else {
            return buffer
        }

        if converter == nil || converter?.outputFormat != format {
            converter = AVAudioConverter(from: inputFormat, to: format)
            converter?.primeMethod = .none
        }

        guard let converter else {
            throw Error.failedToCreateConverter
        }

        let sampleRateRatio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
        let scaledInputFrameLength = Double(buffer.frameLength) * sampleRateRatio
        let frameCapacity = AVAudioFrameCount(scaledInputFrameLength.rounded(.up))
        guard
            let conversionBuffer = AVAudioPCMBuffer(
                pcmFormat: converter.outputFormat, frameCapacity: frameCapacity)
        else {
            throw Error.failedToCreateConversionBuffer
        }

        var nsError: NSError?
        let bufferProcessedLock = OSAllocatedUnfairLock(initialState: false)

        let status = converter.convert(to: conversionBuffer, error: &nsError) {
            packetCount, inputStatusPointer in
            let wasProcessed = bufferProcessedLock.withLock { bufferProcessed in
                let wasProcessed = bufferProcessed
                bufferProcessed = true
                return wasProcessed
            }
            inputStatusPointer.pointee = wasProcessed ? .noDataNow : .haveData
            return wasProcessed ? nil : buffer
        }

        guard status != .error else {
            throw Error.conversionFailed(nsError)
        }

        return conversionBuffer
    }
}
