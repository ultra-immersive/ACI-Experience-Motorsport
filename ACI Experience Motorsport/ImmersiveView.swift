//
//  ImmersiveView.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 16/10/25.
//

@preconcurrency import SwiftUI
import RealityKit
import RealityKitContent
import AVFoundation

/// Central coordinator for the immersive ACI Motorsport experience.
///
/// Sets up the RealityKit scene, hand tracking, collision detection, and the conversational
/// AI guide. Handles tap-to-play video interactions, module transitions (B/C/D), scene phase
/// lifecycle, and experience completion tracking.
struct ImmersiveView: View {
    @State var endStartedFromExperienceTimer = false
    @State var moduleDDidEnd = false
    @State var turntableSpinner = TurntableSpinner()
    @State var activeModuleRunCount: Int = 0
    @State var conversationalBackgroundPlaybackID: EnhancedAudioSystem.PlaybackID?
    @State var experienceBackgroundPlaybackID: EnhancedAudioSystem.PlaybackID?
    
    @State var isClosingExperience: Bool = false
    let topGroupID = HoverEffectComponent.GroupID()

    var placementManager: ScenePlacementManager?
    @State var placementVisualization = PlacementVisualization()
    @EnvironmentObject var gameControllerManager: GameControllerManager
    
    @State var experienceTimer = ExperienceTimer()
    @State var watchedVideoIDs: Set<UUID> = []
    @State var safeZoneManager = SafeZoneManager()
    @State var slotTitles: [Int: String] = [:]
    @State var videoTitleEntities: [Int: Entity] = [:]
    
    var isFullScaleCarsActive: Bool
    @State var currentTappedVideo: (player: AVPlayer, entity: Entity, config: VideoConfig)?
    @State var isVideoAnimating: Bool = false

    // MARK: - Environment & Configuration
    
    @Environment(AppModel.self) var appModel
    @Environment(\.realityKitScene) var scene
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var styleManager: StyleManager
    
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    @Environment(Recorder.self) var voiceInput
    
    // MARK: - State Properties
    
    @State var content: RealityViewContent?
    @StateObject var handTrackingViewModel = HandTrackingViewModel()
    @State var sphereCooldowns: [String: Date] = [:]
    let cooldownDuration: TimeInterval = 6
    
    @State var rootEntity: Entity = Entity()
    @State var scenePhaseTracking: ScenePhase = .active
    @State var timers: [String: Timer] = [:]
    @State var isCleaningUp = false
    @State var hasBeenCleaned = false
    
    @State var audioAnimator = AudioReactiveAnimator()
    @StateObject var autoStopDetector = AutoStopDetector()
    @StateObject var voiceLevelMonitor = VoiceLevelMonitor()
    
    // MARK: - Conversational AI State
    
    @State private var currentStep: QuestionStep = .epoch
    @State private var userInput: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var errorMessage: String? = nil
    
    @State private var epochService = EpochDetectionService()
    @State var conversationalGuide: ConversationalGuide?
    
    // MARK: - Transform State
    
    @State var originalGuideTransform: Transform?
    @State var originalOutlineTatuusTransform: Transform?
    
    // MARK: - Debug Configuration
    
    var isDebugMode: Bool
    
    // MARK: - Audio Playback Tracking
    
    @State var moduleB_AudioPlaybackID: String?
    @State var moduleC_AudioPlaybackID: String?
    
    // MARK: - Skip Video Feature
    
    @State var skipVideoUIEntity = Entity()
    var skipVideoEnabled: Bool
    
    // MARK: - Notification Publishers
    
    private let notificationTrigger = NotificationCenter.default.publisher(for: Notification.Name("RealityKit.NotificationTrigger"))
    private let skipVideoNotification = NotificationCenter.default.publisher(for: .skipCurrentVideo)
    
    private let voiceLevelSphereTimerKey = "voiceLevelSphereTimerKey"
    private let voiceLevelGearTimerKey = "voiceLevelGearTimerKey"
    
    // MARK: - View Body
    
    var body: some View {
        RealityView { content, attachments in
            self.content = content
            
            content.add(handTrackingViewModel.setupContentEntity())
            setupEntityCollisions(content: content)
            
#if targetEnvironment(simulator)
#else
            if isFullScaleCarsActive, placementManager != nil {
                await setupPlacement(content: content, attachments: attachments)
            }
#endif
            
            await initialSetup()
            
            for i in 1...10 {
                if let titleEntity = attachments.entity(for: "VideoTitle_\(i)") {
                    titleEntity.name = "VideoTitle_\(i)"
                    videoTitleEntities[i] = titleEntity
                }
            }
            
            if skipVideoEnabled {
                if let skipVideoUI = attachments.entity(for: "SkipVideoUI") {
                    skipVideoUI.name = "SkipVideoUI"
                    self.skipVideoUIEntity = skipVideoUI
                }
            }
        }
        attachments: {
            Attachment(id: "SkipVideoUI") {
                SkipVideoUI()
            }
                        
            if isFullScaleCarsActive {
                Attachment(id: "PlacementConfirm") {
                    PlacementConfirmUI(
                        surfaceFound: placementManager?.planeToProjectOnFound ?? false,
                        controllerName: gameControllerManager.controllerName,
                        controllerConnected: gameControllerManager.controllerConnected
                    )
                }
            }
        }
        .task {
            #if !targetEnvironment(simulator)
            await safeZoneManager.startTracking()
            YAxisBillboardRuntime.setCameraTransformProvider {
                safeZoneManager.currentDeviceTransform()
            }
            #endif
        }
        .task {
#if !targetEnvironment(simulator)
            await handTrackingViewModel.beginSession()
#endif
        }
        .task {
#if !targetEnvironment(simulator)
            await handTrackingViewModel.processHandsUpdates()
#endif
        }
        .onReceive(skipVideoNotification) { _ in
            if currentTappedVideo != nil {
                skipCurrentTappedVideo()
            }
        }
        .onDisappear {
            YAxisBillboardRuntime.setCameraTransformProvider(nil)
        }
        .task {
            if let pm = placementManager { await pm.processDeviceAnchorUpdates() }
        }
        .task {
            if let pm = placementManager { await pm.processWorldAnchorUpdates() }
        }
        .task {
            if let pm = placementManager { await pm.processPlaneDetectionUpdates() }
        }
        .task {
            if isFullScaleCarsActive, placementManager?.isPlacingMode == true {
                await placementVisualization.processReconstructionUpdates()
            }
        }
        .onAppear {
            setupStaffControllerBindings()
            
            conversationalGuide = ConversationalGuide(
                audioAnimator: audioAnimator,
                voiceInput: voiceInput,
                autoStopDetector: autoStopDetector,
                appModel: appModel,
                rootEntity: rootEntity,
                isDebugMode: isDebugMode
            )
            
            conversationalGuide?.onConversationComplete = { [] in
                guard !self.isCleaningUp else { return }
                Task { self.startExperience() }
            }
            
            conversationalGuide?.onRecordingStart = { [] in
                guard !self.isCleaningUp else { return }
                voiceLevelMonitor.startMonitoring()
                EnhancedAudioSystem.playAudio(on: rootEntity, resourceName: "/Root/AI/Listening_start_wav")
                if let guideSphere = rootEntity.findEntity(named: "GuideSphere") {
                    handlePopValueChange(entity: guideSphere, targetValue: 1, duration: 0.5, keyMaterialName: "Listening", completion: {
                        startVoiceLevelSphereAnimation(entity: guideSphere)
                    })
                    if let guideGear = rootEntity.findEntity(named: "GuideGearModel") {
                        handlePopValueChange(entity: guideGear, targetValue: 1, duration: 0.5, keyMaterialName: "Listening", completion: {
                            startVoiceLevelGearAnimation(entity: guideGear)
                        })
                    }
                }
            }
            
            conversationalGuide?.onEpochDetected = { [] in
                guard !self.isCleaningUp else { return }
                self.loadMixedMedia()
            }
            
            conversationalGuide?.onThinkingStart = { [] in
                guard !self.isCleaningUp else { return }
                voiceLevelMonitor.stopMonitoring()
                EnhancedAudioSystem.playAudio(on: rootEntity, resourceName: "/Root/AI/Thinking_wav")
                if let guideSphere = rootEntity.findEntity(named: "GuideSphere") {
                    Task {
                        stopVoiceLevelSphereAnimation(entity: guideSphere)
                        try? await Task.sleep(for: .seconds(0.5))
                        handlePopValueChange(entity: guideSphere, targetValue: 0, duration: 0.5, keyMaterialName: "Listening", completion: {
                        })
                    }
                    if let guideGear = rootEntity.findEntity(named: "GuideGearModel") {
                        Task {
                            stopVoiceLevelGearAnimation(entity: guideGear)
                            try? await Task.sleep(for: .seconds(0.1))
                            handlePopValueChange(entity: guideGear, targetValue: 1, duration: 0.5, keyMaterialName: "Thinking", completion: {
                                
                            })
                            try? await Task.sleep(for: .seconds(0.5))
                            handlePopValueChange(entity: guideGear, targetValue: 0, duration: 0.5, keyMaterialName: "Listening", completion: {
                            })
                           try? await Task.sleep(for: .seconds(2))
                            handlePopValueChange(entity: guideGear, targetValue: 0, duration: 0.5, keyMaterialName: "Thinking", completion: {
                                
                            })
                        }
                    }
                }
            }
        }
        .onReceive(notificationTrigger) { output in
            guard let entity = output.userInfo?["RealityKit.NotificationTrigger.SourceEntity"] as? Entity,
                  let notificationName = output.userInfo?["RealityKit.NotificationTrigger.Identifier"] as? String else { return }
            Task { @MainActor in
                await handleNotification(notificationName: notificationName, entity: entity)
            }
        }
        .onChange(of: scenePhase, initial: false) { (oldValue, newValue) in
            handleScenePhase(oldValue: oldValue, newValue: newValue)
        }
#if targetEnvironment(simulator)
        .gesture(TapGesture()
            .targetedToAnyEntity()
            .onEnded({ tap in
                if tap.entity.name == "sphereAci" {
                    sendNotificationtToRCP(notificationName: "StartSphere_Touched")
                }
                if tap.entity.name.starts(with: "Video_") {
                    playTappedVideo(entity: tap.entity)
                }
                if tap.entity.name == "DebugX" {
                    Task { @MainActor in
                        tap.entity.components.remove(InputTargetComponent.self)
                        await stopCurrentVideoAndClose()
                    }
                }
            }))
#else
        .gesture(TapGesture()
            .targetedToAnyEntity()
            .onEnded({ tap in
                if tap.entity.name.starts(with: "Video_") {
                    playTappedVideo(entity: tap.entity)
                }
                if tap.entity.name == "DebugX" {
                    Task { @MainActor in
                        tap.entity.components.remove(InputTargetComponent.self)
                        await stopCurrentVideoAndClose()
                    }
                }
            }))
#endif
    }
    
    /// Checks whether all non-introductory videos have been watched and no modules are running, then triggers experience completion.
    @MainActor
    func checkExperienceCompletion() {
        let watchableVideoIDs = Set(Self.videoSlotAssignments.keys.filter { id in
            guard let config = MediaLibrary.videos.first(where: { $0.id == id }) else { return false }
            return !config.isIntroductory
        })
        
        let allVideosWatched = watchableVideoIDs.isSubset(of: watchedVideoIDs)
        let noModulesRunning = activeModuleRunCount == 0
        
        guard allVideosWatched && noModulesRunning else { return }
        
        sendNotificationtToRCP(notificationName: "Experience_Completed")
    }
    
    // MARK: - Conversational Experience
    
    /// Locates the guide entities, plays the driver animation, and starts the AI conversation flow.
    func startConversationalExperience() async {
        guard var guideGear = rootEntity.findEntity(named: "GuideGearModel"),
              let guideSphere = rootEntity.findEntity(named: "GuideSphere"),
              let guide = conversationalGuide,
              let driverAnimation = rootEntity.findEntity(named: "driverTouchStart")
        else { return }
        guideGear = guideGear.parent!
        if let driverTouchStart = rootEntity.findEntity(named: "driverTouchStart") {
            animateEntity(entity: driverTouchStart) {
                Task {
                    await guide.startConversation(
                        guideGear: guideGear,
                        guideSphere: guideSphere,
                        driverAnimation: driverAnimation
                    )
                }
            }
        }
    }
    
    // MARK: - Voice Level Animation
    
    /// Stops the 60fps voice-level timer on the sphere and resets its shader animation parameter.
    @MainActor
    func stopVoiceLevelSphereAnimation(entity: Entity) {
        timers[voiceLevelSphereTimerKey]?.invalidate()
        timers.removeValue(forKey: voiceLevelSphereTimerKey)
        guard let modelEntity = findModelEntity(in: entity),
              var material = modelEntity.model?.materials.first as? ShaderGraphMaterial else { return }
        do {
            try material.setParameter(name: "Animation", value: .float(0.0))
            modelEntity.model?.materials = [material]
        } catch {}
    }
    
    /// Stops the 60fps voice-level timer on the gear and resets its shader animation parameter.
    @MainActor
    func stopVoiceLevelGearAnimation(entity: Entity) {
        timers[voiceLevelGearTimerKey]?.invalidate()
        timers.removeValue(forKey: voiceLevelGearTimerKey)
        guard let modelEntity = findModelEntity(in: entity),
              var material = modelEntity.model?.materials.first as? ShaderGraphMaterial else { return }
        do {
            try material.setParameter(name: "Animation", value: .float(0.0))
            modelEntity.model?.materials = [material]
        } catch {}
    }
    
    /// Drives the sphere's shader "Animation" parameter at 60fps from the voice level monitor with smoothing.
    @MainActor
    func startVoiceLevelSphereAnimation(entity: Entity) {
        timers[voiceLevelSphereTimerKey]?.invalidate()
        guard let modelEntity = findModelEntity(in: entity),
              let material = modelEntity.model?.materials.first as? ShaderGraphMaterial else { return }
        
        let baseValue: Float = 0.0
        let intensity: Float = 1.2
        let smoothing: Float = 0.6
        var smoothedValue: Float = baseValue
        var cachedMaterial = material
        
        timers[voiceLevelSphereTimerKey] = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            Task { @MainActor in
                let currentLevel = Float(self.voiceLevelMonitor.voiceLevel)
                let poweredLevel = pow(currentLevel, 0.8)
                let targetValue = baseValue + (poweredLevel * intensity)
                smoothedValue = smoothedValue * smoothing + targetValue * (1.0 - smoothing)
                let clampedValue = min(max(smoothedValue, 0.0), 1.0)
                do {
                    try cachedMaterial.setParameter(name: "Animation", value: .float(clampedValue))
                    modelEntity.model?.materials = [cachedMaterial]
                } catch {}
            }
        }
    }
    
    /// Drives the gear's shader "Animation" parameter at 60fps from the voice level monitor with smoothing.
    @MainActor
    func startVoiceLevelGearAnimation(entity: Entity) {
        timers[voiceLevelGearTimerKey]?.invalidate()
        guard let modelEntity = findModelEntity(in: entity),
              let material = modelEntity.model?.materials.first as? ShaderGraphMaterial else { return }
        
        let baseValue: Float = 0.0
        let intensity: Float = 1.2
        let smoothing: Float = 0.6
        var smoothedValue: Float = baseValue
        var cachedMaterial = material
        
        timers[voiceLevelGearTimerKey] = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            Task { @MainActor in
                let currentLevel = Float(self.voiceLevelMonitor.voiceLevel)
                let poweredLevel = pow(currentLevel, 0.8)
                let targetValue = baseValue + (poweredLevel * intensity)
                smoothedValue = smoothedValue * smoothing + targetValue * (1.0 - smoothing)
                let clampedValue = min(max(smoothedValue, 0.0), 1.0)
                do {
                    try cachedMaterial.setParameter(name: "Animation", value: .float(clampedValue))
                    modelEntity.model?.materials = [cachedMaterial]
                } catch {}
            }
        }
    }
    
    // MARK: - Window & Space Management
    
    func closeImmersiveSpace() async { await dismissImmersiveSpace() }
    func showWindow(id: String) { openWindow(id: id) }
    func closeWindow(id: String) { dismissWindow(id: id) }
}


extension ImmersiveView {
    
    /// Handles a tap on a video panel: validates safety checks, plays the video with forward/backward panel animations, and triggers module transitions for nextModuleIntro videos.
    func playTappedVideo(entity: Entity) {
        Task { @MainActor in
            if isCleaningUp { return }
            if isVideoAnimating { return }
            if currentTappedVideo != nil { return }
            
            let components = entity.name.components(separatedBy: "_")
            guard let uuidString = components.last,
                  let videoUUID = UUID(uuidString: uuidString) else { return }
            guard let videoConfig = MediaLibrary.videos.first(where: { $0.id == videoUUID }) else { return }
            guard Self.videoSlotAssignments[videoConfig.id] != nil else { return }
            guard let videoComponent = entity.components[VideoPlayerComponent.self],
                  let player = videoComponent.avPlayer else { return }
            if player.timeControlStatus == .playing { return }
            if watchedVideoIDs.contains(videoConfig.id) { return }
            
            graduallyChangeScale(entity: entity, targetScale: [0.85,0.85,0.85], duration: 0.3) {
                graduallyChangeScale(entity: entity, targetScale: [0.78,0.78,0.78], duration: 0.3) {}
            }
            
            isVideoAnimating = true
            currentTappedVideo = (player: player, entity: entity, config: videoConfig)
            
            if let assignedSlot = Self.videoSlotAssignments[videoConfig.id],
               let titleContainer = entity.findEntity(named: "TitleContainer_\(assignedSlot)") {
                titleContainer.removeFromParent()
            }
            player.seek(to: .zero)
            handleVideoStart(entity: entity, config: videoConfig)
            
            let totalDelay = videoConfig.animationConfig?.delayBeforeAnimation ?? 3.0
            Task {
                try? await Task.sleep(for: .seconds(totalDelay + 1.0))
                self.isVideoAnimating = false
            }
            
            if videoConfig.isNextModuleIntro, let moduleToStart = videoConfig.introducesModule {
                if let guide = rootEntity.findEntity(named: "Guide") {
                    guide.components.set(OpacityComponent(opacity: 1.0))
                    graduallyChangeOpacity(entity: guide, targetOpacity: 0, duration: 1)
                }
                if moduleToStart != .D {
                    Task {
                        if let carModel = videoConfig.introducesCarModel { appModel.activeReducedCarModel = carModel }
                        if let dioramaModel = videoConfig.introducesDioramaModel { appModel.activeDioramaModel = dioramaModel }
                        
                        self.isVideoAnimating = true
                        self.handleVideoEnd(entity: entity, config: videoConfig)
                        
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1.0))
                            self.isVideoAnimating = false
                            self.watchedVideoIDs.insert(videoConfig.id)
                            await self.startModuleAfterIntro(module: moduleToStart)
                            try? await Task.sleep(for: .seconds(5))
                            if let assignedSlot = Self.videoSlotAssignments[videoConfig.id] {
                                await self.addWatchedOverlay(to: entity, slot: assignedSlot, title: videoConfig.title)
                            }
                        }
                    }
                } else {
                    // Module D — crossfade path
                    if let playbackID = experienceBackgroundPlaybackID {
                        Task { await EnhancedAudioSystem.fadeOutAndPause(playbackID: playbackID, duration: 2.0) {} }
                    }
                    
                    player.play()
                    
                    var crossfadeObserver: Any?
                    var crossfadeFired = false
                    
                    if let triggerTime = videoConfig.crossfadeTriggerTime {
                        let boundaryTime = CMTime(seconds: triggerTime, preferredTimescale: 600)
                        let fadeDuration = videoConfig.crossfadeDuration
                        
                        crossfadeObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: boundaryTime)], queue: .main) { [weak player] in
                            guard let player else { return }
                            if let obs = crossfadeObserver { player.removeTimeObserver(obs); crossfadeObserver = nil }
                            Task { @MainActor in
                                guard !crossfadeFired else { return }
                                crossfadeFired = true
                                self.activeModuleRunCount += 1
                                self.performModuleDCrossfade(introEntity: entity, introConfig: videoConfig, crossfadeDuration: fadeDuration, vrResourceName: "IntroEP02-PAN10_VR180_HDR_MV-HEVC")
                            }
                        }
                    }
                    
                    var observer: NSObjectProtocol?
                    observer = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                        if let obs = crossfadeObserver { player.removeTimeObserver(obs); crossfadeObserver = nil }
                        Task { @MainActor in
                            self.isVideoAnimating = false
                            self.watchedVideoIDs.insert(videoConfig.id)
                            if let assignedSlot = Self.videoSlotAssignments[videoConfig.id] {
                                await self.addWatchedOverlay(to: entity, slot: assignedSlot, title: videoConfig.title)
                            }
                            self.currentTappedVideo = nil
                            if let observer = observer { NotificationCenter.default.removeObserver(observer) }
                        }
                    }
                }
            } else {
                // Standard video playback
                graduallyChangeColorEffect(duration: 1.5, styleManager: self.styleManager, startColor: [0.8, 0.8, 0.8], targetColor: [0.2, 0.2, 0.2], completion: {})
                if let playbackID = experienceBackgroundPlaybackID {
                    Task { await EnhancedAudioSystem.fadeOutAndPause(playbackID: playbackID, duration: 2.0) {} }
                }
                player.play()
                
                var observer: NSObjectProtocol?
                observer = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                    self.isVideoAnimating = true
                    self.handleVideoEnd(entity: entity, config: videoConfig)
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(4.0))
                        self.isVideoAnimating = false
                        self.watchedVideoIDs.insert(videoConfig.id)
                        if let assignedSlot = Self.videoSlotAssignments[videoConfig.id] {
                            await self.addWatchedOverlay(to: entity, slot: assignedSlot, title: videoConfig.title)
                        }
                        self.checkExperienceCompletion()
                        if videoConfig.isNextModuleIntro, let moduleToStart = videoConfig.introducesModule {
                            if let carModel = videoConfig.introducesCarModel { appModel.activeReducedCarModel = carModel }
                            if let dioramaModel = videoConfig.introducesDioramaModel { appModel.activeDioramaModel = dioramaModel }
                            await self.startModuleAfterIntro(module: moduleToStart)
                        } else {
                            self.currentTappedVideo = nil
                        }
                        if let playbackID = experienceBackgroundPlaybackID {
                            Task { await EnhancedAudioSystem.fadeInAndResume(playbackID: playbackID, duration: 2.0) {} }
                        }
                        graduallyChangeColorEffect(duration: 1.5, styleManager: self.styleManager, startColor: [0.2, 0.2, 0.2], targetColor: [0.8, 0.8, 0.8], completion: {})
                        if let observer = observer { NotificationCenter.default.removeObserver(observer) }
                    }
                }
            }
        }
    }
    
    /// Builds and attaches a "watched" overlay (eye icon + title) to a video entity after playback completes.
    @MainActor
    func addWatchedOverlay(to videoEntity: Entity, slot: Int, title: String) async {
        var modelSortGroup = ModelSortGroup(depthPass: .postPass)
        videoEntity.enumerateHierarchy { entity, stop in
            if entity.name.contains("TextEntity__") {
                if let existingSortComponent = entity.components[ModelSortGroupComponent.self] {
                    modelSortGroup = existingSortComponent.group
                }
            }
        }
        
        if let existingOverlay = videoEntity.findEntity(named: "HoverOverlay_\(slot)") {
            if let modelEntity = findModelEntity(in: existingOverlay),
               var mat = modelEntity.model?.materials.first as? ShaderGraphMaterial {
                do {
                    try mat.setParameter(name: "Selection", value: .float(0.85))
                    modelEntity.model?.materials = [mat]
                } catch {}
            }
            setDrawOrder(on: existingOverlay, group: modelSortGroup, order: 2)
        }
        
        if let existingContainer = videoEntity.findEntity(named: "TitleContainer_\(slot)") {
            existingContainer.removeFromParent()
        }
        
        var hoverMaterial: ShaderGraphMaterial?
        if let materialScene = try? await Entity(named: "HoverEffectComponentScene", in: realityKitContentBundle) {
            materialScene.enumerateHierarchy { entity, _ in
                if let model = entity as? ModelEntity,
                   let mat = model.model?.materials.first as? ShaderGraphMaterial {
                    hoverMaterial = mat
                }
            }
        }
        guard var material = hoverMaterial else { return }
        
        var material2 = material
        do { try material.setParameter(name: "Color", value: .color(.white)) } catch {}
        do { try material2.setParameter(name: "Color", value: .color(.black)) } catch {}
        
        let wrappedTitle = wordWrapText(title, maxCharactersPerLine: 20)
        var titleString = AttributedString(wrappedTitle)
        titleString.font = MeshResource.Font(name: "Inter-Black", size: 5)
        let titleParagraphStyle = NSMutableParagraphStyle()
        titleParagraphStyle.alignment = .center
        titleParagraphStyle.lineHeightMultiple = 0.9
        titleString.mergeAttributes(AttributeContainer([.paragraphStyle: titleParagraphStyle]))
        
        var titleExtrusionOptions = MeshResource.ShapeExtrusionOptions()
        titleExtrusionOptions.extrusionMethod = .linear(depth: 0.001)
        titleExtrusionOptions.materialAssignment = .init(front: 0, back: 0, extrusion: 1, frontChamfer: 1, backChamfer: 1)
        titleExtrusionOptions.chamferRadius = 0.045
        
        guard let titleMesh = try? await MeshResource(extruding: titleString, extrusionOptions: titleExtrusionOptions) else { return }
        
        let titleEntity = ModelEntity(mesh: titleMesh, materials: [material, material2])
        titleEntity.name = "WatchedTitle_\(slot)"
        let titleBounds = titleEntity.visualBounds(relativeTo: titleEntity)
        titleEntity.position = -titleBounds.center
        titleEntity.position.z += 0.01
        
        let containerEntity = Entity()
        containerEntity.name = "WatchedContainer_\(slot)"
        
        if let eyeIcon = try? await Entity(named: "Assets/A_EyeIcon", in: realityKitContentBundle) {
            eyeIcon.enumerateHierarchy { child, _ in
                if let model = child as? ModelEntity {
                    var iconMat = material
                    try? iconMat.setParameter(name: "Color", value: .color(.white))
                    model.model?.materials = [iconMat]
                }
            }
            let iconScale: Float = 1.0
            eyeIcon.scale = [iconScale, iconScale, iconScale]
            eyeIcon.position.z = 0.01
            setDrawOrder(on: eyeIcon, group: modelSortGroup, order: 1)
            let iconWrapper = Entity()
            iconWrapper.addChild(eyeIcon)
            iconWrapper.position.y = 0.0
            containerEntity.addChild(iconWrapper)
        }
        
        let titleWrapper = Entity()
        titleWrapper.addChild(titleEntity)
        titleWrapper.position.y = -0.2
        containerEntity.addChild(titleWrapper)
        
        setDrawOrder(on: titleEntity, group: modelSortGroup, order: 1)
        
        let containerBounds = containerEntity.visualBounds(relativeTo: containerEntity)
        let fitScale = min(1.4 / containerBounds.extents.x, 0.7 / containerBounds.extents.y, 1.0)
        containerEntity.scale = SIMD3<Float>(repeating: fitScale)
        
        if let existingHover = videoEntity.components[HoverEffectComponent.self] {
            let groupID = existingHover.hoverEffect.groupID
            var containerHover = HoverEffectComponent(.shader(HoverEffectComponent.ShaderHoverEffectInputs(fadeInDuration: 0.5, fadeOutDuration: 0.3)))
            containerHover.hoverEffect.groupID = groupID
            containerEntity.components.set(containerHover)
            containerEntity.enumerateHierarchy { entity, stop in
                var childHover = HoverEffectComponent(.shader(HoverEffectComponent.ShaderHoverEffectInputs(fadeInDuration: 0.5, fadeOutDuration: 0.3)))
                childHover.hoverEffect.groupID = groupID
                entity.components.set(childHover)
            }
        }
        
        videoEntity.addChild(containerEntity)
        containerEntity.setPosition([0, 0, 0.07], relativeTo: videoEntity)
    }

    /// Seeks the currently playing tapped video to its end, triggering the completion observer.
    @MainActor
    func skipCurrentTappedVideo() {
        guard let tappedVideo = currentTappedVideo else { return }
        guard tappedVideo.player.timeControlStatus == .playing else {
            currentTappedVideo = nil
            return
        }
        tappedVideo.player.seek(to: tappedVideo.player.currentItem?.duration ?? .zero)
    }
    
    /// Increments the active module count and sends the appropriate RCP start notification for the given module.
    private func startModuleAfterIntro(module: ModuleType) async {
        activeModuleRunCount += 1
        switch module {
        case .A1: break
        case .B:     sendNotificationtToRCP(notificationName: "Module_B_Start")
        case .C:     sendNotificationtToRCP(notificationName: "Module_C_Start")
        case .D:     experienceTimer.moduleDidStart(.D)
        }
    }

    /// Stops the current video, runs its backward animation, and triggers the experience completion notification.
    @MainActor
    func stopCurrentVideoAndClose() async {
        guard !isClosingExperience else { return }
        isClosingExperience = true
        
        if let tappedVideo = currentTappedVideo {
            isVideoAnimating = true
            tappedVideo.player.pause()
            handleVideoEnd(entity: tappedVideo.entity, config: tappedVideo.config)
            try? await Task.sleep(for: .seconds(4.0))
            isVideoAnimating = false
            watchedVideoIDs.insert(tappedVideo.config.id)
            currentTappedVideo = nil
        }
        sendNotificationtToRCP(notificationName: "Experience_Completed")
    }
    
    // MARK: - Slot Visibility for Spatial Transitions

    /// Hides all panel slots except the one containing the active video entity.
    @MainActor
    func hideNonPlayingSlots(except activeEntity: Entity) {
        for i in 1...10 {
            guard let container = rootEntity.findEntity(named: "Image_\(i)") else { continue }
            var isActive = false
            var current: Entity? = activeEntity
            while let parent = current?.parent {
                if parent === container { isActive = true; break }
                current = parent
            }
            if !isActive {
                container.components.set(OpacityComponent(opacity: 0.0))
            }
        }
    }

    /// Restores all panel slots to full visibility.
    @MainActor
    func showAllSlots() {
        for i in 1...10 {
            guard let container = rootEntity.findEntity(named: "Image_\(i)") else { continue }
            container.components.set(OpacityComponent(opacity: 1.0))
        }
    }
    
    // MARK: - Hover Overlay Parameter Control

    /// Zeros the hover overlay shader parameters for clean full-screen video playback.
    @MainActor
    func disableHoverOverlay(on videoEntity: Entity) {
        guard let overlay = videoEntity.children.first(where: { $0.name.hasPrefix("HoverOverlay_") }),
              let modelEntity = findModelEntity(in: overlay),
              var mat = modelEntity.model?.materials.first as? ShaderGraphMaterial else { return }
        do {
            try mat.setParameter(name: "Min", value: .float(0))
            try mat.setParameter(name: "Max", value: .float(0))
            try mat.setParameter(name: "Selection", value: .float(0))
            modelEntity.model?.materials = [mat]
        } catch {}
    }

    /// Restores the hover overlay shader parameters after returning from full-screen playback.
    @MainActor
    func restoreHoverOverlay(on videoEntity: Entity) {
        guard let overlay = videoEntity.children.first(where: { $0.name.hasPrefix("HoverOverlay_") }),
              let modelEntity = findModelEntity(in: overlay),
              var mat = modelEntity.model?.materials.first as? ShaderGraphMaterial else { return }
        do {
            try mat.setParameter(name: "Min", value: .float(0.3))
            try mat.setParameter(name: "Max", value: .float(0.5))
            modelEntity.model?.materials = [mat]
        } catch {}
    }
}
