//
//  ConversationalGuide.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 14/11/25.
//

import Foundation
import RealityKit
import Combine
import SwiftUI

/// Drives the pre-experience AI conversation that determines the user's preferred epoch.
///
/// Plays a welcome question via audio-reactive guide animations, records the user's
/// voice response, classifies it into an epoch with ``EpochDetectionService``, and
/// triggers the experience launch once the conversation completes.
@MainActor
class ConversationalGuide: ObservableObject {
    private var conversationTask: Task<Void, Never>?
    private(set) var isCancelled = false

    @Published var currentStep: QuestionStep = .epoch
    @Published var isListening = false
    @Published var isProcessing = false
    
    private let audioAnimator: AudioReactiveAnimator
    private let voiceInput: Recorder
    private let autoStopDetector: AutoStopDetector
    private let appModel: AppModel
    
    var onConversationComplete: (() -> Void)?
    var onEpochDetected: (() async -> Void)?
    var onRecordingStart: (() async -> Void)?
    var onThinkingStart: (() async -> Void)?
    
    private let epochService = EpochDetectionService()
    let rootEntity: Entity
    var isDebugMode: Bool

    init(
        audioAnimator: AudioReactiveAnimator,
        voiceInput: Recorder,
        autoStopDetector: AutoStopDetector,
        appModel: AppModel,
        rootEntity: Entity,
        isDebugMode: Bool
    ) {
        self.audioAnimator = audioAnimator
        self.voiceInput = voiceInput
        self.autoStopDetector = autoStopDetector
        self.appModel = appModel
        self.rootEntity = rootEntity
        self.isDebugMode = isDebugMode
    }
    
    // MARK: - Cancellation
    
    /// Cancels the entire conversational flow — stops recording, audio animations, and pending tasks.
    func cancel() {
        isCancelled = true
        conversationTask?.cancel()
        conversationTask = nil
        autoStopDetector.stop()
        
        Task {
            await audioAnimator.stopAllAnimations()
        }
        
        if voiceInput.isRecording {
            Task.detached { [voiceInput] in
                try? await voiceInput.toggleRecording()
            }
        }
        isListening = false
        isProcessing = false
    }
    
    // MARK: - Conversation Flow
    
    /// Begins the conversation. In debug mode, skips directly to the finish step.
    func startConversation(
        guideGear: Entity,
        guideSphere: Entity,
        driverAnimation: Entity
    ) async {
        isCancelled = false
        if isDebugMode {
            await finishConversation(guideGear: guideGear, guideSphere: guideSphere, driverAnimation: driverAnimation)
        } else {
            currentStep = .epoch
            await askCurrentQuestion(guideGear: guideGear, guideSphere: guideSphere, driverAnimation: driverAnimation)
        }
    }
    
    /// Plays the question audio with guide animations, then starts listening for the user's answer.
    private func askCurrentQuestion(
        guideGear: Entity,
        guideSphere: Entity,
        driverAnimation: Entity
    ) async {
        guard !isCancelled, !Task.isCancelled else { return }
        
        let audioFileName = audioFileForStep(currentStep)
        
        let preWarmTask = Task {
            await preWarmRecorder()
        }
        
        await audioAnimator.animateToAudio(
            entities: [guideGear, guideSphere],
            audioResourceName: audioFileName,
            keyMaterialName: "Animation",
            baseValue: 0.0,
            intensity: 2.0,
            range: 1,
            smoothing: 0.85
        ) {
            Task {
                guard !self.isCancelled else { return }
                await preWarmTask.value
                await self.listenForAnswer(guideGear: guideGear, guideSphere: guideSphere, driverAnimation: driverAnimation)
            }
        }
    }
    
    /// Records voice input and auto-stops when the user finishes speaking.
    private func listenForAnswer(
        guideGear: Entity,
        guideSphere: Entity,
        driverAnimation: Entity
    ) async {
        guard !isCancelled, !Task.isCancelled else { return }
        isListening = true
        
        if let onRecordingStart {
            await onRecordingStart()
        }
        
        do {
            try await voiceInput.startRecordingFast()
            
            autoStopDetector.startMonitoring(
                transcriber: voiceInput.transcriber
            ) { [weak self] in
                guard let self, !self.isCancelled else { return }
                if self.voiceInput.isRecording {
                    if let onThinkingStart = self.onThinkingStart {
                        await onThinkingStart()
                    }
                    
                    guard !self.isCancelled else { return }
                    try? await self.voiceInput.toggleRecording()
                    await self.processAnswer(
                        guideGear: guideGear,
                        guideSphere: guideSphere,
                        driverAnimation: driverAnimation
                    )
                }
            }
        } catch {
            print("Recording error: \(error)")
            isListening = false
        }
    }
    
    /// Sends the transcribed text to ``EpochDetectionService`` and updates the app model with the result.
    private func processAnswer(
        guideGear: Entity,
        guideSphere: Entity,
        driverAnimation: Entity
    ) async {
        guard !isCancelled, !Task.isCancelled else { return }
        isListening = false
        isProcessing = true
        
        let finalText = String(voiceInput.transcriber.finalizedTranscript.characters)
        print("Processing answer for \(currentStep): \(finalText)")
        
        do {
            let epoch = try await epochService.detectEpoch(from: finalText)
            
            guard !isCancelled, !Task.isCancelled else {
                isProcessing = false
                return
            }
            
            appModel.updateEpoch(with: epoch)
            print("Epoch detected: \(epoch.epoch) (confidence: \(epoch.confidence))")
            
            if let onEpochDetected = onEpochDetected {
                await onEpochDetected()
            }
            
            voiceInput.transcriber.reset()
            isProcessing = false
            
            await finishConversation(guideGear: guideGear, guideSphere: guideSphere, driverAnimation: driverAnimation)
            
        } catch {
            print("Error processing answer: \(error)")
            isProcessing = false
        }
    }
    
    /// Plays the epoch-specific response audio and fires ``onConversationComplete`` when done.
    private func finishConversation(
        guideGear: Entity,
        guideSphere: Entity,
        driverAnimation: Entity
    ) async {
        guard !isCancelled, !Task.isCancelled else { return }
                
        
        var launchAudio: String = ""
        
        switch appModel.selectedEpoch {
        case .laCorsaComeSfida:
            launchAudio = "EP01_Response"
        case .tecnicaPassioneGenio:
            launchAudio = "EP02_Response"
        case .laFormazionePiloti:
            launchAudio = "EP03_Response"
        default:
            break
        }
        
        guard !isCancelled else { return }
        Task {
            try? await Task.sleep(for: .seconds(1))
            animateEntity(entity: driverAnimation, index: 4) {
            }
            
            await audioAnimator.animateToAudio(
                entities: [guideGear, guideSphere],
                audioResourceName: launchAudio,
                keyMaterialName: "Animation",
                baseValue: 0.0,
                intensity: 2.0,
                range: 1,
                smoothing: 0.85
            ) {
                guard !self.isCancelled else { return }
                self.onConversationComplete?()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Returns a randomized welcome question audio filename for the given step.
    private func audioFileForStep(_ step: QuestionStep) -> String {
        let idForEpoch = Int.random(in: 1...3)
        switch step {
        case .epoch:
            return "Welcome_Question_0\(idForEpoch)"
        }
    }
    
    /// Pre-warms the audio session and transcriber so recording starts without delay.
    private func preWarmRecorder() async {
        do {
            try voiceInput.setUpAudioSession()
        } catch {
            print("Pre-warm audio session failed: \(error)")
        }
        
        voiceInput.transcriber.reset()
        do {
            try await voiceInput.transcriber.setUpTranscriber()
        } catch {
            print("Pre-warm transcriber failed: \(error)")
        }
    }
    
    /// Plays a RealityKit animation on an entity by name or index, with optional looping, reverse, and completion callback.
    @discardableResult
    func animateEntity(
        entity: Entity,
        name: String? = nil,
        index: Int? = nil,
        loopCount: Int? = nil,
        loopForever: Bool = false,
        speed: Float = 1.0,
        reverse: Bool = false,
        transitionDuration: TimeInterval = 0.2,
        startsPaused: Bool = false,
        startTimeOffset: TimeInterval = 0,
        completion: (() -> Void)? = nil
    ) -> AnimationPlaybackController? {
        let resource: AnimationResource?
        if let name = name {
            resource = entity.availableAnimations.first(where: { $0.name == name })
        } else if let idx = index, idx >= 0, idx < entity.availableAnimations.count {
            resource = entity.availableAnimations[idx]
        } else {
            resource = entity.availableAnimations.first
        }
        
        guard var anim = resource else {
            print("No animation resource found on \(entity.name) with name \(String(describing: name)).")
            return nil
        }
        
        if loopForever {
            if reverse {
                print("Reverse looping not directly supported. Playing once in reverse.")
            } else {
                anim = anim.repeat()
            }
        } else if let loopCount = loopCount, loopCount > 1 {
            if reverse {
                print("Reverse looping not directly supported. Playing once in reverse.")
            } else {
                anim = anim.repeat(count: loopCount)
            }
        }
        
        entity.stopAllAnimations()
        
        let controller = entity.playAnimation(
            anim,
            transitionDuration: reverse ? 0 : transitionDuration,
            startsPaused: true
        )
        
        if reverse {
            controller.speed = -abs(speed)
            let duration = anim.definition.duration
            
            if let loopCount = loopCount, loopCount > 1 {
                controller.time = duration * Double(loopCount)
            } else {
                controller.time = duration
            }
        } else {
            controller.speed = abs(speed)
            controller.time = 0
        }
        
        if !startsPaused {
            if startTimeOffset > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + startTimeOffset) {
                    controller.resume()
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    controller.resume()
                }
            }
        }
        
        if let scene = entity.scene, let completion = completion {
            var token: AnyCancellable? = nil
            
            if reverse {
                let checkInterval = 0.1
                var timer: Timer?
                
                timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { _ in
                    if controller.time <= 0.01 || !controller.isPlaying {
                        completion()
                        timer?.invalidate()
                        timer = nil
                    }
                }
                
                token = scene.subscribe(to: AnimationEvents.PlaybackCompleted.self, on: entity) { event in
                    if event.playbackController == controller {
                        completion()
                        timer?.invalidate()
                        token?.cancel()
                    }
                } as? AnyCancellable
            } else {
                token = scene.subscribe(to: AnimationEvents.PlaybackCompleted.self, on: entity) { event in
                    if event.playbackController == controller {
                        completion()
                        token?.cancel()
                    }
                } as? AnyCancellable
            }
        }
        
        return controller
    }
}
