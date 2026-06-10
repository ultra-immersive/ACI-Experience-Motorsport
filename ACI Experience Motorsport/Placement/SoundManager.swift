//
//  SoundManager.swift
//  ACI Experience Motorsport
//

import AVFoundation

/// Singleton that manages 3D spatial audio playback via AVAudioEngine for placement feedback sounds.
class SoundManager {
    static let shared = SoundManager()
    
    let audioEngine = AVAudioEngine()
    let environmentNode = AVAudioEnvironmentNode()
    var audioPlayerNodes: [String: AVAudioPlayerNode] = [:]
    var audioFiles: [String: AVAudioFile] = [:]

    init() {
        preloadSound(named: "resetExperienceACI")
        preloadSound(named: "placementSuccessLancia")
        setupAudioEngine()
    }
    
    /// Stops all sounds, clears nodes, restarts the engine, and re-preloads essential sounds.
    func reset() {
        for playerNode in audioPlayerNodes.values {
            if playerNode.isPlaying { playerNode.stop() }
        }
        audioPlayerNodes.removeAll()
        audioFiles.removeAll()
        audioEngine.stop()
        setupAudioEngine()
        preloadSound(named: "resetExperienceACI")
        preloadSound(named: "placementSuccessLancia")
        preloadSound(named: "loadingReset")
        preloadSound(named: "rewind")
    }

    func setupAudioEngine() {
        audioEngine.attach(environmentNode)
        audioEngine.connect(environmentNode, to: audioEngine.mainMixerNode, format: nil)
        audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: nil)
        environmentNode.listenerPosition = AVAudio3DPoint(x: 0.0, y: 0.0, z: 0.0)
        do { try audioEngine.start() } catch { print("Failed to start audio engine: \(error)") }
    }
    
    /// Pre-loads a .wav file from the bundle to avoid latency on first playback.
    func preloadSound(named fileName: String) {
        guard audioFiles[fileName] == nil else { return }
        if let audioFileURL = Bundle.main.url(forResource: fileName, withExtension: "wav") {
            do {
                audioFiles[fileName] = try AVAudioFile(forReading: audioFileURL)
            } catch { print("Error loading sound file: \(error)") }
        }
    }
    
    /// Plays a sound at a specific 3D position in the audio environment.
    func playSound(named fileName: String, at position: AVAudio3DPoint) {
        let audioPlayerNode = AVAudioPlayerNode()
        audioEngine.attach(audioPlayerNode)
        audioEngine.connect(audioPlayerNode, to: environmentNode, format: nil)
        if let audioFile = audioFiles[fileName] {
            audioPlayerNode.scheduleFile(audioFile, at: nil, completionHandler: nil)
        } else {
            preloadSound(named: fileName)
            if let audioFile = audioFiles[fileName] {
                audioPlayerNode.scheduleFile(audioFile, at: nil, completionHandler: nil)
            }
        }
        audioPlayerNode.position = position
        audioPlayerNode.reverbBlend = 1
        audioPlayerNode.volume = 1.0
        audioPlayerNodes[fileName] = audioPlayerNode
        audioPlayerNode.play()
    }
    
    /// Plays a sound at a default ambient position.
    func playAmbientSound(named fileName: String) {
        let ambientPlayerNode = AVAudioPlayerNode()
        audioEngine.attach(ambientPlayerNode)
        audioEngine.connect(ambientPlayerNode, to: environmentNode, format: nil)
        if let audioFile = audioFiles[fileName] {
            ambientPlayerNode.scheduleFile(audioFile, at: nil, completionHandler: nil)
        } else {
            preloadSound(named: fileName)
            if let audioFile = audioFiles[fileName] {
                ambientPlayerNode.scheduleFile(audioFile, at: nil, completionHandler: nil)
            }
        }
        ambientPlayerNode.position = AVAudio3DPoint(x: 20.0, y: -20.0, z: 10.0)
        ambientPlayerNode.volume = 1.0
        audioPlayerNodes[fileName] = ambientPlayerNode
        ambientPlayerNode.play()
    }
    
    /// Plays a directional audio cue from a specific 3D position.
    func playDirectionalCue(named fileName: String, from position: AVAudio3DPoint) {
        let cuePlayerNode = AVAudioPlayerNode()
        audioEngine.attach(cuePlayerNode)
        audioEngine.connect(cuePlayerNode, to: environmentNode, format: nil)
        if let audioFile = audioFiles[fileName] {
            cuePlayerNode.scheduleFile(audioFile, at: nil, completionHandler: nil)
        } else {
            preloadSound(named: fileName)
            if let audioFile = audioFiles[fileName] {
                cuePlayerNode.scheduleFile(audioFile, at: nil, completionHandler: nil)
            }
        }
        cuePlayerNode.position = position
        cuePlayerNode.volume = 1.0
        audioPlayerNodes[fileName] = cuePlayerNode
        cuePlayerNode.play()
    }
    
    func stopSound(named fileName: String) {
        if let playerNode = audioPlayerNodes[fileName], playerNode.isPlaying {
            playerNode.stop()
            audioPlayerNodes[fileName] = nil
        }
    }
    
    func setVolume(for fileName: String, volume: Float) {
        if let playerNode = audioPlayerNodes[fileName] {
            playerNode.volume = max(0.0, min(volume, 1.0))
        }
    }
    
    func updateListenerPosition(x: Float, y: Float, z: Float) {
        environmentNode.listenerPosition = AVAudio3DPoint(x: x, y: y, z: z)
    }
    
    func setOcclusionAndObstruction(occlusion: Float, obstruction: Float) {
        environmentNode.occlusion = occlusion
        environmentNode.obstruction = obstruction
    }
    
    func setGlobalVolume(_ volume: Float) {
        for playerNode in audioPlayerNodes.values {
            playerNode.volume = max(0.0, min(volume, 1.0))
        }
    }
}
