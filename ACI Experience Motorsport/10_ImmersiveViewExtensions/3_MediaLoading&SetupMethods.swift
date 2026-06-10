//
//  3_MediaLoading&SetupFunctions.swift
//

import RealityKit
@preconcurrency import AVKit
import RealityKitContent

/// Media loading pipeline: filters videos for the current epoch, assigns them to panel slots,
/// loads each as a spatial `VideoPlayerComponent`, and builds the title/hover/overlay UI per slot.
extension ImmersiveView {
    
    // MARK: - Properties
    
    static var isGeneratingMedia = false
    static var videoSlotAssignments: [UUID: Int] = [:]

    // MARK: - Public Interface
    
    /// Entry point — filters videos for the current epoch and loads them into panel slots.
    func loadMixedMedia() {
        Task {
            await generateMixedMediaWithTargetSlots(
                onEntity: rootEntity,
                scale: [0.78, 0.78, 0.78],
                epoch: appModel.selectedEpoch,
                availableModules: appModel.availableModules
            )
        }
    }
    
    // MARK: - Media Generation Pipeline
        
    /// Filters epoch/module-compatible videos, assigns them to slots, loads each with an AVPlayer, and populates slot titles.
    private func generateMixedMediaWithTargetSlots(
        onEntity entity: Entity,
        scale: SIMD3<Float>,
        epoch: Epoch,
        availableModules: [ModuleType]
    ) async {
        guard !Self.isGeneratingMedia else {
            print("Media generation already in progress")
            return
        }
        
        Self.isGeneratingMedia = true
        defer { Self.isGeneratingMedia = false }

        let videosToLoad = MediaLibrary.videos.filter { video in
            video.isAvailable(for: epoch) &&
            (video.modules.isEmpty || availableModules.contains(where: { video.modules.contains($0) }))
        }
        clearAllMedia(from: entity)
        
        let (videoSlotMap, _) = assignSlotsToVideos(videosToLoad)
        Self.videoSlotAssignments = videoSlotMap
        
        for video in videosToLoad {
            guard let assignedSlot = videoSlotMap[video.id] else { continue }
            
            let _ = await loadVideo(
                into: entity,
                videoConfig: video,
                assignedSlot: assignedSlot,
                scale: scale
            )
            
            try? await Task.sleep(for: .milliseconds(400))
        }
        
        for video in videosToLoad {
            guard let assignedSlot = videoSlotMap[video.id],
                  !video.title.isEmpty else { continue }
            slotTitles[assignedSlot] = video.title
        }

        seekAllVideosToPreview()
    }
    
    /// Returns the epoch-specific border color as a `UIColor`.
    func epochBorderColor() -> UIColor {
        switch appModel.selectedEpoch {
        case .laCorsaComeSfida:      return UIColor(red: 0xFE/255, green: 0x59/255, blue: 0x58/255, alpha: 1)
        case .tecnicaPassioneGenio:  return UIColor(red: 0xFF/255, green: 0xFF/255, blue: 0x8B/255, alpha: 1)
        case .laFormazionePiloti:    return UIColor(red: 0x07/255, green: 0xB1/255, blue: 0xFF/255, alpha: 1)
        default:                     return UIColor(red: 0x07/255, green: 0xB1/255, blue: 0xFF/255, alpha: 1)
        }
    }
    
    /// Returns the epoch-specific border color as an integer ID for shader parameters.
    func epochBorderColorID() -> Int {
        switch appModel.selectedEpoch {
        case .laCorsaComeSfida:      return 0
        case .tecnicaPassioneGenio:  return 1
        case .laFormazionePiloti:    return 2
        default:                     return 0
        }
    }
    
    // MARK: - Multi-line Text Wrapping

    /// Breaks a string into lines at word boundaries, each up to `maxCharactersPerLine` characters.
    func wordWrapText(_ text: String, maxCharactersPerLine: Int = 18) -> String {
        let words = text.split(separator: " ")
        var lines: [String] = []
        var currentLine = ""
        
        for word in words {
            let candidate = currentLine.isEmpty ? String(word) : "\(currentLine) \(word)"
            
            if candidate.count > maxCharactersPerLine && !currentLine.isEmpty {
                lines.append(currentLine)
                currentLine = String(word)
            } else {
                currentLine = candidate
            }
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        return lines.joined(separator: "\n")
    }

    /// Builds and attaches 3D title text, hover overlay to each occupied video slot.
    @MainActor
    func attachTitleEntitiesToSlots() {
        for (slot, _) in slotTitles {
            guard let title = slotTitles[slot], !title.isEmpty,
                  let slotEntity = rootEntity.findEntity(named: "Image_\(slot)"),
                  let screen = findEntityContaining("ImageScreen", in: slotEntity),
                  let videoEntity = screen.children.first(where: { $0.name.starts(with: "Video") }) else {
                continue
            }
            
            let slotGroupID = HoverEffectComponent.GroupID()
            let slotSortGroup = ModelSortGroup(depthPass: .postPass)
            
            Task {
                var hoverMaterial: ShaderGraphMaterial?
                var maskHoverMaterial: ShaderGraphMaterial?
                
                if let materialScene = try? await Entity(named: "HoverEffectComponentScene", in: realityKitContentBundle) {
                    materialScene.enumerateHierarchy { entity, _ in
                        if let model = entity as? ModelEntity,
                           let mat = model.model?.materials.first as? ShaderGraphMaterial {
                            hoverMaterial = mat
                        }
                    }
                }
                
                if let materialScene = try? await Entity(named: "Assets/HoverMask", in: realityKitContentBundle) {
                    materialScene.enumerateHierarchy { entity, _ in
                        if let model = entity as? ModelEntity,
                           let mat = model.model?.materials.first as? ShaderGraphMaterial {
                            maskHoverMaterial = mat
                        }
                    }
                }
                
                guard var material = hoverMaterial else { return }
                guard let maskMat = maskHoverMaterial else { return }
                
                let wrappedTitle = wordWrapText(title, maxCharactersPerLine: 20)
                var textString = AttributedString(wrappedTitle)
                textString.font = MeshResource.Font(name: "Inter-Black", size: 10)

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                paragraphStyle.lineHeightMultiple = 0.9
                let centerAttributes = AttributeContainer([.paragraphStyle: paragraphStyle])
                textString.mergeAttributes(centerAttributes)
                
                var extrusionOptions = MeshResource.ShapeExtrusionOptions()
                extrusionOptions.extrusionMethod = .linear(depth: 0.001)
                extrusionOptions.materialAssignment = .init(
                    front: 0, back: 0, extrusion: 1,
                    frontChamfer: 1, backChamfer: 1
                )
                extrusionOptions.chamferRadius = 0.045

                let textMesh = try await MeshResource(extruding: textString, extrusionOptions: extrusionOptions)
                
                var material2 = material
                do { try material.setParameter(name: "Color", value: .color(.white)) } catch {}
                do { try material2.setParameter(name: "Color", value: .color(.black)) } catch {}
                
                let textEntity = ModelEntity(mesh: textMesh, materials: [material, material2])
                textEntity.name = "TitleText_\(slot)"
                
                let textBounds = textEntity.visualBounds(relativeTo: textEntity)
                textEntity.position = -textBounds.center
                textEntity.position.z += 0.015
                
                let containerEntity = Entity()
                containerEntity.name = "TitleContainer_\(slot)"
                containerEntity.addChild(textEntity)
                textEntity.name = "TextEntity__\(slot)"
                setDrawOrder(on: textEntity, group: slotSortGroup, order: 1)

                var videoHover = HoverEffectComponent(.shader(
                    HoverEffectComponent.ShaderHoverEffectInputs(fadeInDuration: 0.5, fadeOutDuration: 0.3)
                ))
                videoHover.hoverEffect.groupID = slotGroupID
                videoEntity.components.set(videoHover)
                
                if videoEntity.components[ModelComponent.self] != nil {
                    videoEntity.components.set(ModelSortGroupComponent(group: slotSortGroup, order: 0))
                }
                
                
                // Mask overlay
                var overlayEntity = ModelEntity(mesh: .generatePlane(width: 1.7, height: 0.9), materials: [maskMat])
                if let loadedEntity = try? await Entity(named: "Geometry/fillPanel", in: realityKitContentBundle) {
                    if let modelEntity = findModelEntity(in: loadedEntity) {
                        overlayEntity = modelEntity
                        modelEntity.model?.materials = [maskMat]
                    }
                }
                overlayEntity.name = "HoverOverlay_\(slot)"
                overlayEntity.orientation = simd_quatf(angle: .pi / 2, axis: [-1, 0, 0])

                var overlayHover = HoverEffectComponent(.shader(.default))
                overlayHover.hoverEffect.groupID = slotGroupID
                overlayEntity.components.set(overlayHover)
                
                overlayEntity.position = [0, 0, 0.00001]
                videoEntity.addChild(overlayEntity)
                let parentScale: Float = 0.765
                overlayEntity.scale = SIMD3<Float>(1.0 / parentScale, 1.0 / parentScale, 1.015 / parentScale)
                overlayEntity.components.set(ModelSortGroupComponent(group: slotSortGroup, order: 2))
                
                var containerHover = HoverEffectComponent(.shader(
                    HoverEffectComponent.ShaderHoverEffectInputs(fadeInDuration: 0.5, fadeOutDuration: 0.3)
                ))
                containerHover.hoverEffect.groupID = slotGroupID
                containerEntity.components.set(containerHover)
                setDrawOrder(on: overlayEntity, group: slotSortGroup, order: 2)

                containerEntity.enumerateHierarchy { entity, stop in
                    var childHover = HoverEffectComponent(.shader(
                        HoverEffectComponent.ShaderHoverEffectInputs(fadeInDuration: 0.5, fadeOutDuration: 0.3)
                    ))
                    childHover.hoverEffect.groupID = slotGroupID
                    entity.components.set(childHover)
                }
                
                videoEntity.addChild(containerEntity)
                containerEntity.setPosition([0, 0, 0.07], relativeTo: videoEntity)
            }
        }
    }

    /// Applies a `ModelSortGroupComponent` to every entity in the hierarchy that has a `ModelComponent`.
    func setDrawOrder(on entity: Entity, group: ModelSortGroup, order: Int32) {
        entity.enumerateHierarchy { child, _ in
            if child.components[ModelComponent.self] != nil {
                child.components.set(ModelSortGroupComponent(group: group, order: order))
            }
        }
    }
    
    // MARK: - Slot Assignment
    
    /// Distributes videos across the 10 panel slots: intro videos get fixed slots, then module intros, standard videos, and remaining previews fill the rest randomly.
    private func assignSlotsToVideos(_ videos: [VideoConfig]) -> ([UUID: Int], Set<Int>) {
        var slotMap: [UUID: Int] = [:]
        var usedSlots: Set<Int> = []
        
        let introVideos = videos.filter { $0.isIntroductory }
        for video in introVideos {
            let fixedSlot = video.targetSlot ?? 10
            slotMap[video.id] = fixedSlot
            usedSlots.insert(fixedSlot)
        }
        
        let nextModuleIntros = videos.filter { $0.isNextModuleIntro }
        var availableSlots = Set(1...10).subtracting(usedSlots)
        var prioritySlots = Array(availableSlots).shuffled()
        
        for video in nextModuleIntros {
            if let fixed = video.targetSlot, !usedSlots.contains(fixed) {
                slotMap[video.id] = fixed
                usedSlots.insert(fixed)
                prioritySlots.removeAll { $0 == fixed }
            } else {
                guard !prioritySlots.isEmpty else { break }
                let assignedSlot = prioritySlots.removeFirst()
                slotMap[video.id] = assignedSlot
                usedSlots.insert(assignedSlot)
            }
        }
        
        let standardVideos = videos.filter { $0.isStandard }.shuffled()
        availableSlots = Set(1...10).subtracting(usedSlots)
        var remainingSlots = Array(availableSlots).shuffled()
        
        for video in standardVideos {
            if let fixed = video.targetSlot, !usedSlots.contains(fixed) {
                slotMap[video.id] = fixed
                usedSlots.insert(fixed)
                remainingSlots.removeAll { $0 == fixed }
            } else {
                guard !remainingSlots.isEmpty else { break }
                let assignedSlot = remainingSlots.removeFirst()
                slotMap[video.id] = assignedSlot
                usedSlots.insert(assignedSlot)
            }
        }
        
        let previewOnlyVideos = videos.filter { $0.isStandard && !slotMap.keys.contains($0.id) }.shuffled()
        availableSlots = Set(1...10).subtracting(usedSlots)
        var previewSlots = Array(availableSlots).shuffled()

        for video in previewOnlyVideos {
            if let fixed = video.targetSlot, !usedSlots.contains(fixed) {
                slotMap[video.id] = fixed
                usedSlots.insert(fixed)
                previewSlots.removeAll { $0 == fixed }
            } else {
                guard !previewSlots.isEmpty else { break }
                let assignedSlot = previewSlots.removeFirst()
                slotMap[video.id] = assignedSlot
                usedSlots.insert(assignedSlot)
            }
        }
        return (slotMap, usedSlots)
    }
    
    // MARK: - Video Loading
    
    /// Creates an AVPlayer for a video, wraps it in a spatial stereo `VideoPlayerComponent`, and adds it to the target slot's ImageScreen entity.
    @MainActor
    private func loadVideo(
        into entity: Entity,
        videoConfig: VideoConfig,
        assignedSlot: Int,
        scale: SIMD3<Float>
    ) async -> Bool {
        guard let slotEntity = entity.findEntity(named: "Image_\(assignedSlot)") else {
            print("Slot entity 'Image_\(assignedSlot)' not found in scene")
            return false
        }
        
        guard let transform = findEntityContaining("ImageScreen", in: slotEntity) else {
            return false
        }
        
        if !transform.children.isEmpty {
            transform.children.forEach {
                if !$0.name.contains("borderPanel") && !$0.name.contains("BorderPanel") && !$0.name.contains("ImageScreen_") {
                    $0.removeFromParent()
                }
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        guard let url = Bundle.main.url(
            forResource: videoConfig.fileName,
            withExtension: videoConfig.fileExtension
        ) else {
            print("Video file not found: \(videoConfig.fileName).\(videoConfig.fileExtension)")
            return false
        }
        
        let player = AVPlayer(url: url)
        let videoEntity = Entity()
        let previewTime = CMTime(seconds: videoConfig.previewTime, preferredTimescale: 600)

        videoEntity.name = "Video_SEQ_\(videoConfig.fileName)_\(videoConfig.id.uuidString)"

        do {
            var videoComponent = VideoPlayerComponent(avPlayer: player)
            videoComponent.desiredSpatialVideoMode = .spatial
            videoComponent.desiredImmersiveViewingMode = .portal
            videoComponent.desiredViewingMode = .stereo
            
            videoEntity.components.set(videoComponent)
            videoEntity.scale = scale
            videoEntity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            videoEntity.components.set(InputTargetComponent())
            videoEntity.components.set(CollisionComponent(shapes: [.generateBox(size: [1.7, 0.9, 0.1])]))
            
            transform.addChild(videoEntity)
            
            await player.seek(to: previewTime, toleranceBefore: .zero, toleranceAfter: .zero)
            player.pause()
            
            if transform.children.count > 1 {
                let latest = videoEntity
                transform.children.forEach {
                    if $0 !== latest {
                        if !$0.name.contains("borderPanel") && !$0.name.contains("BorderPanel") && !$0.name.contains("ImageScreen_") {
                            $0.removeFromParent()
                        }
                    }
                }
            }
            
            guard transform.children.contains(where: { $0.name == videoEntity.name }) else {
                print("Failed to verify video was added to slot \(assignedSlot)")
                return false
            }
            return true
        }
    }
    
    /// Seeks every loaded video back to its configured preview frame.
    @MainActor
    func seekAllVideosToPreview() {
        for i in 1...10 {
            guard let slotEntity = rootEntity.findEntity(named: "Image_\(i)"),
                  let screen = findEntityContaining("ImageScreen", in: slotEntity) else {
                continue
            }
            
            for child in screen.children {
                guard child.name.starts(with: "Video_"),
                      let videoComponent = child.components[VideoPlayerComponent.self],
                      let player = videoComponent.avPlayer else {
                    continue
                }
                
                let entityName = child.name
                for config in MediaLibrary.videos {
                    if entityName.contains(config.fileName) {
                        let previewTime = CMTime(seconds: config.previewTime, preferredTimescale: 600)
                        player.seek(to: previewTime)
                        break
                    }
                }
            }
        }
    }
    
    /// Recursively finds the first child entity whose name contains the given substring.
    func findEntityContaining(_ substring: String, in entity: Entity) -> Entity? {
        if entity.name.contains(substring) {
            return entity
        }
        for child in entity.children {
            if let found = findEntityContaining(substring, in: child) {
                return found
            }
        }
        return nil
    }
    
    // MARK: - Cleanup
    
    /// Removes all video entities from panel slots while preserving border panels and screen geometry.
    @MainActor
    func clearAllMedia(from entity: Entity) {
        var clearedCount = 0
        Self.videoSlotAssignments.removeAll()
        
        for i in 1...10 {
            if let slotEntity = entity.findEntity(named: "Image_\(i)"),
               let transform = findEntityContaining("ImageScreen", in: slotEntity) {
                let childCount = transform.children.count
                if childCount > 0 {
                    transform.children.forEach {
                        if !$0.name.contains("borderPanel") && !$0.name.contains("BorderPanel") && !$0.name.contains("ImageScreen_") {
                            $0.removeFromParent()
                        }
                    }
                    clearedCount += childCount
                }
            }
        }
    }
    
    /// Discovers populated slots, fades them in, then auto-plays the epoch introductory video.
    @MainActor
    func showMixedMedia() {
        Task {
            let mediaContainers = discoverMediaContainers()
            guard !mediaContainers.isEmpty else {
                print("No media containers found to show")
                return
            }
            var shuffledContainers = mediaContainers
            shuffledContainers.shuffle()
            await revealMediaItems(shuffledContainers)
            await playIntroductoryVideo()
        }
    }
    
    /// Locates the epoch intro video entity, plays it in full spatial mode, then transitions to free-browse mode with panel opening animation.
    @MainActor
    func playIntroductoryVideo() async {
        let epoch = appModel.selectedEpoch
        
        guard let introConfig = MediaLibrary.introductoryVideo(for: .A1, epoch: epoch) else {
            print("No introductory video found for epoch \(epoch.displayName)")
            return
        }
        
        guard let assignedSlot = Self.videoSlotAssignments[introConfig.id] else {
            print("No slot assigned for intro video \(introConfig.fileName)")
            return
        }
        
        guard let slotEntity = rootEntity.findEntity(named: "Image_\(assignedSlot)"),
              let screen = findEntityContaining("ImageScreen", in: slotEntity) else {
            print("Could not find slot entity for intro video")
            return
        }
        
        guard let videoEntity = screen.children.first(where: {
            $0.name.contains(introConfig.id.uuidString)
        }) else {
            print("Could not find intro video entity in slot \(assignedSlot)")
            return
        }
        
        guard let videoComponent = videoEntity.components[VideoPlayerComponent.self],
              let player = videoComponent.avPlayer else {
            print("No AVPlayer on intro video entity")
            return
        }
        
        isVideoAnimating = true
        currentTappedVideo = (player: player, entity: videoEntity, config: introConfig)
        
        if let titleContainer = videoEntity.findEntity(named: "TitleContainer_\(assignedSlot)") {
            titleContainer.removeFromParent()
        }
        
        await player.seek(to: .zero)
        handleINTROVideoStart(entity: videoEntity, config: introConfig)
        
        if let borderPanel = videoEntity.findEntity(named: "borderPanel") {
            borderPanel.components.set(OpacityComponent(opacity: 0.0))
        }
        
        player.play()
        
        var earlyTransitionDidFire = false
        
        var boundaryObserver: Any?
        if let triggerTime = introConfig.endTime {
            let boundaryTime = CMTime(seconds: triggerTime, preferredTimescale: 600)
            
            boundaryObserver = player.addBoundaryTimeObserver(
                forTimes: [NSValue(time: boundaryTime)],
                queue: .main
            ) { [weak player] in
                guard let player else { return }
                
                if let obs = boundaryObserver {
                    player.removeTimeObserver(obs)
                    boundaryObserver = nil
                }
                
                Task { @MainActor in
                    earlyTransitionDidFire = true
                    
                    if var videoComp = videoEntity.components[VideoPlayerComponent.self] {
                        videoComp.desiredImmersiveViewingMode = .portal
                        videoComp.desiredSpatialVideoMode = .spatial
                        videoComp.desiredViewingMode = .stereo
                        videoComp.isPassthroughTintingEnabled = false
                        videoEntity.components[VideoPlayerComponent.self] = videoComp
                    }
                    
                    if let panels = self.rootEntity.findEntity(named: "panels10_Idle") {
                        panels.enumerateHierarchy { entity, stop in
                            if entity.name.contains("ImageScreen") {
                                graduallyChangeScale(entity: entity, targetScale: [1,1,1], duration: 2)
                            }
                        }
                        EnhancedAudioSystem.playAudio(on: panels, resourceName: "/Root/OpeningPanels_wav")
                        self.animateEntity(entity: panels, name: "Opening", speed: 1, startsPaused: false, startTimeOffset: 0.0) {
                            Task {
                                if !isDebugMode {
                                    graduallyChangeColorEffect(
                                                                     duration: 1.5,
                                                                     styleManager: self.styleManager,
                                                                     startColor: [0.3, 0.3, 0.3],
                                                                     targetColor: [0.8, 0.8, 0.8],
                                                                     completion: {}
                                                                 )
                                    self.attachTitleEntitiesToSlots()
                                }
                                try? await Task.sleep(for: .seconds(2))
                                self.isVideoAnimating = false
                                self.watchedVideoIDs.insert(introConfig.id)
                                
                                await self.addWatchedOverlay(
                                    to: videoEntity,
                                    slot: assignedSlot,
                                    title: introConfig.title
                                )
                                
                                if let titleContainer = videoEntity.findEntity(named: "TitleContainer_\(assignedSlot)") {
                                    titleContainer.removeFromParent()
                                }
                                
                                self.currentTappedVideo = nil
                            }
                            
                            if let entity = rootEntity.children.first {
                                experienceBackgroundPlaybackID = EnhancedAudioSystem.playLoopingAudio(
                                    on: entity,
                                    resourceName: "/Root/Epoch_bg_all_wav",
                                    volume: -10
                                )
                            }
                        }
                    }
                }
            }
        }
        
        if isDebugMode == false {
            await withCheckedContinuation { continuation in
                var observer: NSObjectProtocol?
                observer = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: player.currentItem,
                    queue: .main
                ) { _ in
                    if let observer { NotificationCenter.default.removeObserver(observer) }
                    if let obs = boundaryObserver {
                        player.removeTimeObserver(obs)
                        boundaryObserver = nil
                    }
                    Task { @MainActor in
                        let videoComponent = videoEntity.components[VideoPlayerComponent.self]!
                        let player = videoComponent.avPlayer
                        let entityName = videoEntity.name
                        for config in MediaLibrary.videos {
                            if entityName.contains(config.fileName) {
                                let previewTime = CMTime(seconds: config.previewTime, preferredTimescale: 600)
                                player!.seek(to: previewTime)
                                break
                            }
                        }
                        continuation.resume()
                    }
                }
            }
        }

        if isDebugMode {
            await withCheckedContinuation { continuation in
                var observer: NSObjectProtocol?
                observer = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: player.currentItem,
                    queue: .main
                ) { _ in
                    if let observer { NotificationCenter.default.removeObserver(observer) }
                    if let obs = boundaryObserver {
                        player.removeTimeObserver(obs)
                        boundaryObserver = nil
                    }
                    Task { @MainActor in
                        player.pause()
                        self.isVideoAnimating = true
                        
                        if self.skipVideoEnabled == true {
                            if let skipEntity = videoEntity.findEntity(named: "SkipVideoUI") {
                                skipEntity.removeFromParent()
                            }
                        }
                        
                        if !earlyTransitionDidFire {
                            self.handleINTROVideoEnd(entity: videoEntity, config: introConfig)
                            if let panels = self.rootEntity.findEntity(named: "panels10_Idle") {
                                panels.enumerateHierarchy { entity, stop in
                                    if entity.name.contains("ImageScreen") {
                                        graduallyChangeScale(entity: entity, targetScale: [1,1,1], duration: 2)
                                    }
                                }
                                EnhancedAudioSystem.playAudio(on: panels, resourceName: "/Root/OpeningPanels_wav")
                                self.animateEntity(entity: panels, name: "Opening", speed: 1, startsPaused: false, startTimeOffset: 0.0) {
                                    if let entity = rootEntity.children.first {
                                        experienceBackgroundPlaybackID = EnhancedAudioSystem.playLoopingAudio(
                                            on: entity,
                                            resourceName: "/Root/Epoch_bg_all_wav",
                                            volume: -10
                                        )
                                    }
                                }
                            }
                            try? await Task.sleep(for: .seconds(4.0))
                        } else {
                            if var videoComp = videoEntity.components[VideoPlayerComponent.self] {
                                videoComp.desiredImmersiveViewingMode = .portal
                                videoComp.desiredSpatialVideoMode = .spatial
                                videoComp.desiredViewingMode = .stereo
                                videoComp.isPassthroughTintingEnabled = false
                                videoEntity.components[VideoPlayerComponent.self] = videoComp
                            }
                        }
                        
                        self.isVideoAnimating = false
                        self.watchedVideoIDs.insert(introConfig.id)
                        self.seekAllVideosToPreview()
                        graduallyChangeColorEffect(
                                                         duration: 1.5,
                                                         styleManager: self.styleManager,
                                                         startColor: [0.3, 0.3, 0.3],
                                                         targetColor: [0.8, 0.8, 0.8],
                                                         completion: {}
                                                     )
                        self.attachTitleEntitiesToSlots()
                        
                        try? await Task.sleep(for: .seconds(2))
                        await self.addWatchedOverlay(
                            to: videoEntity,
                            slot: assignedSlot,
                            title: introConfig.title
                        )
                        
                        if let titleContainer = videoEntity.findEntity(named: "TitleContainer_\(assignedSlot)") {
                            titleContainer.removeFromParent()
                        }
                        
                        self.currentTappedVideo = nil
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    // MARK: - Video Start/End Handlers
    
    /// Builds a slot-specific `AnimationConfig`, waits for the delay, then runs the forward panel animation with optional spatial transition.
    func handleVideoStart(entity: Entity, config: VideoConfig) {
        Task {
            guard let assignedSlot = Self.videoSlotAssignments[config.id] else {
                print("No assigned slot found for \(config.fileName)")
                return
            }
            
            let animConfig: AnimationConfig
            if let existingConfig = config.animationConfig {
                animConfig = AnimationConfig(
                    panelAnimationName: String(format: "Activation_%02d", assignedSlot),
                    useSpatialTransition: existingConfig.useSpatialTransition,
                    delayBeforeAnimation: existingConfig.delayBeforeAnimation,
                    mediaShouldMoveForward: existingConfig.mediaShouldMoveForward,
                    mediaShouldMoveBackward: existingConfig.mediaShouldMoveBackward
                )
            } else {
                animConfig = AnimationConfig(
                    panelAnimationName: String(format: "Activation_%02d", assignedSlot),
                    useSpatialTransition: false,
                    delayBeforeAnimation: config.isIntroductory ? 0.0 : 3.0,
                    mediaShouldMoveForward: true,
                    mediaShouldMoveBackward: true
                )
            }
            
            if animConfig.delayBeforeAnimation > 0 {
                try await Task.sleep(for: .seconds(animConfig.delayBeforeAnimation))
            }
            
            if animConfig.mediaShouldMoveForward {
                moveMediaForward(
                    entity: entity,
                    animationName: animConfig.panelAnimationName,
                    spatialTransition: animConfig.useSpatialTransition,
                    videoConfig: config
                )
            }
        }
    }
    
    /// Switches the intro video entity to full spatial immersive mode and plays the activation audio.
    func handleINTROVideoStart(entity: Entity, config: VideoConfig) {
        Task {
            guard let _ = Self.videoSlotAssignments[config.id] else {
                print("No assigned slot found for \(config.fileName)")
                return
            }
            moveINTROMediaForward(entity: entity, animationName: "", spatialTransition: true)
        }
    }
    
    /// Transitions the intro video to full immersive mode with activation audio and optional skip UI.
    func moveINTROMediaForward(entity: Entity, animationName: String, spatialTransition: Bool) {
        Task {
            if let panels = rootEntity.findEntity(named: "panels10_Idle") {
                EnhancedAudioSystem.playAudio(on: panels, resourceName: "/Root/ActivationPanel_wav")
            }
            
            if var videoComp = entity.components[VideoPlayerComponent.self] {
                let position = entity.position
                videoComp.desiredImmersiveViewingMode = .full
                videoComp.desiredSpatialVideoMode = .spatial
                videoComp.desiredViewingMode = .stereo
                videoComp.isPassthroughTintingEnabled = false
                entity.components[VideoPlayerComponent.self] = videoComp
                entity.position = position
            }

            if skipVideoEnabled == true && isDebugMode {
                try await Task.sleep(for: .seconds(3))
                entity.addChild(skipVideoUIEntity)
                skipVideoUIEntity.setPosition([0,-0.8,0.6], relativeTo: entity)
            }
        }
    }

    /// Runs the backward panel animation, restores portal mode if needed, and seeks all videos to preview.
    func handleVideoEnd(entity: Entity, config: VideoConfig) {
        Task {
            guard let assignedSlot = Self.videoSlotAssignments[config.id] else {
                print("No assigned slot found for \(config.fileName)")
                return
            }
            
            let animConfig: AnimationConfig
            if let existingConfig = config.animationConfig {
                animConfig = AnimationConfig(
                    panelAnimationName: String(format: "Activation_%02d", assignedSlot),
                    useSpatialTransition: existingConfig.useSpatialTransition,
                    delayBeforeAnimation: existingConfig.delayBeforeAnimation,
                    mediaShouldMoveForward: existingConfig.mediaShouldMoveForward,
                    mediaShouldMoveBackward: existingConfig.mediaShouldMoveBackward
                )
            } else {
                animConfig = AnimationConfig(
                    panelAnimationName: String(format: "Activation_%02d", assignedSlot),
                    useSpatialTransition: false,
                    delayBeforeAnimation: config.isIntroductory ? 0.0 : 3.0,
                    mediaShouldMoveForward: true,
                    mediaShouldMoveBackward: true
                )
            }
            
            if animConfig.mediaShouldMoveBackward {
                moveMediaBack(
                    entity: entity,
                    animationName: animConfig.panelAnimationName,
                    spatialTransition: animConfig.useSpatialTransition
                )
            }
            seekAllVideosToPreview()
        }
    }
    
    /// Switches the intro video back to portal mode and seeks all videos to preview.
    func handleINTROVideoEnd(entity: Entity, config: VideoConfig) {
        Task {
            guard let _ = Self.videoSlotAssignments[config.id] else {
                print("No assigned slot found for \(config.fileName)")
                return
            }
            Task {
                if var videoComp = entity.components[VideoPlayerComponent.self] {
                    videoComp.desiredImmersiveViewingMode = .portal
                    videoComp.desiredSpatialVideoMode = .spatial
                    videoComp.desiredViewingMode = .stereo
                    videoComp.isPassthroughTintingEnabled = false
                    entity.components[VideoPlayerComponent.self] = videoComp
                }
                seekAllVideosToPreview()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    /// Plays the forward panel activation animation, hides other slots if spatial, and switches to full immersive mode.
    func moveMediaForward(entity: Entity, animationName: String, spatialTransition: Bool, videoConfig: VideoConfig) {
        Task {
            if let panels = rootEntity.findEntity(named: "panels10_Idle") {
                EnhancedAudioSystem.playAudio(on: panels, resourceName: "/Root/ActivationPanel_wav")
                animateEntity(entity: panels, name: animationName, speed: 1.0, transitionDuration: 0.5, startsPaused: false, startTimeOffset: 0.0) {}
            }
            disableHoverOverlay(on: entity)
            if spatialTransition {
                try await Task.sleep(for: .seconds(3))
                hideNonPlayingSlots(except: entity)
                if var videoComp = entity.components[VideoPlayerComponent.self] {
                    let position = entity.position
                    videoComp.desiredImmersiveViewingMode = .full
                    videoComp.desiredSpatialVideoMode = .spatial
                    videoComp.desiredViewingMode = .stereo
                    videoComp.isPassthroughTintingEnabled = false
                    entity.components[VideoPlayerComponent.self] = videoComp
                    entity.position = position
                }
            }
            if skipVideoEnabled == true && videoConfig.introducesModule != .D {
                try await Task.sleep(for: .seconds(3))
                entity.addChild(skipVideoUIEntity)
                skipVideoUIEntity.setPosition([0,-0.8,0.5], relativeTo: entity)
            }
        }
    }
    
    /// Plays the reverse panel deactivation animation, restores portal mode if spatial, and re-enables input on all slots.
    func moveMediaBack(entity: Entity, animationName: String, spatialTransition: Bool) {
        Task {
            if skipVideoEnabled == true {
                if let entity = entity.findEntity(named: "SkipVideoUI") {
                    entity.removeFromParent()
                }
            }
            
            if spatialTransition {
                showAllSlots()
                if var videoComp = entity.components[VideoPlayerComponent.self] {
                    videoComp.desiredImmersiveViewingMode = .portal
                    videoComp.desiredSpatialVideoMode = .spatial
                    videoComp.desiredViewingMode = .stereo
                    videoComp.isPassthroughTintingEnabled = false
                    entity.components[VideoPlayerComponent.self] = videoComp
                }
                try await Task.sleep(for: .seconds(2))
                if let panels = rootEntity.findEntity(named: "panels10_Idle") {
                    EnhancedAudioSystem.playAudio(on: panels, resourceName: "/Root/DeactivationPanel_wav")
                    playAnimationReverse(entity: panels, name: animationName)
                    try await Task.sleep(for: .seconds(3.29))
                    restoreHoverOverlay(on: entity)
                }
            } else {
                if let panels = rootEntity.findEntity(named: "panels10_Idle") {
                    EnhancedAudioSystem.playAudio(on: panels, resourceName: "/Root/DeactivationPanel_wav")
                    playAnimationReverse(entity: panels, name: animationName)
                    try await Task.sleep(for: .seconds(3.29))
                }
            }
        }
    }
    

    // MARK: - Helper Methods

    /// Returns all slot containers (Image_1…Image_10) that have video content loaded.
    private func discoverMediaContainers() -> [(container: Entity, hasVideo: Bool)] {
        var containers: [(container: Entity, hasVideo: Bool)] = []
        for i in 1...10 {
            if let container = rootEntity.findEntity(named: "Image_\(i)"),
               let screen = findEntityContaining("ImageScreen", in: container),
               !screen.children.isEmpty {
                let hasVideo = screen.children.contains { $0.name.starts(with: "Video") }
                containers.append((container: container, hasVideo: hasVideo))
            }
        }
        return containers
    }
    
    /// Fades in all slot containers with a 2-second opacity animation.
    private func revealMediaItems(_ containers: [(container: Entity, hasVideo: Bool)]) async {
        seekAllVideosToPreview()
        for i in 1...10 {
            if let container = rootEntity.findEntity(named: "Image_\(i)") {
                container.enumerateHierarchy { entity, stop in
                    graduallyChangeOpacity(entity: entity, targetOpacity: 1, duration: 2) {
                        container.enumerateHierarchy { entity, stop in }
                    }
                }
            }
        }
    }
}
