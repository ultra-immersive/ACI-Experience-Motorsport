import Foundation
import RealityKit
import RealityKitContent
import SwiftUI
import AVFoundation
import AVKit
import BigAssets

extension ImmersiveView {
    
    func startExperience() {
        handTrackingViewModel.pause()
        if let guideGear = rootEntity.findEntity(named: "GuideGearModel") {
            if let guideSphere = rootEntity.findEntity(named: "GuideSphere") {
                Task {
                    
                    handlePopValueChange(entity: guideGear, targetValue: 0, duration: 1, keyMaterialName: "Floating", completion:  {
                        
                    })
                    handlePopValueChange(entity: guideSphere, targetValue: 0, duration: 1, keyMaterialName: "Floating", completion:  {
                        
                    })
                    
                    if let sphereAci = rootEntity.findEntity(named: "sphereAci") {
                        sphereAci.name = "DebugX"
                        handlePopValueChange(entity: sphereAci, targetValue: 1, duration: 3, keyMaterialName: "Pop", completion: {
                            sphereAci.components.set(CollisionComponent(shapes: [.generateBox(size: [0.5,0.5,0.5])]))
                            sphereAci.components.set(InputTargetComponent())
                        })
                    }
                    
                    try? await Task.sleep(for: .seconds(3))
                    
                    EnhancedAudioSystem.playAudio(on: guideGear, resourceName: "/Root/GuideToWireframe_wav")
                    guideSphere.enumerateHierarchy { entity, stop in
                        setupBlendShapeWeightsComponent(for: entity)
                        animateBlendShapeWeights(entity: entity, blendWeightsIndex: 0, targetWeights: [1], duration: 2) {
                            
                        }
                    }
                    
                    handlePopValueChange(entity: guideSphere, targetValue: 1, duration: 2, keyMaterialName: "Exit", completion: {
                        
                    })
                    
                    if let playbackID = conversationalBackgroundPlaybackID {
                        await EnhancedAudioSystem.fadeOutAndStop(
                            playbackID: playbackID,
                            duration: 2.0
                        ) {
                        }
                    }
                    graduallyChangeColorEffect(
                        duration: 1.5,
                        styleManager: self.styleManager,
                        startColor: [1, 1, 1],
                        targetColor: [0.3, 0.3, 0.3],
                        completion: {}
                    )
                    
                    sendNotificationtToRCP(notificationName: "Module_A_Start")

                }
            }
        }
    }
    
    
    func handleNotification(notificationName: String, entity: Entity) async   {
        
        switch notificationName {
        case .start_Preparation:
            if isDebugMode {
                Task {
                    loadMixedMedia()
                }
            }
            
            
        case.opacityGuideIn:
            if let guide = rootEntity.findEntity(named: "Guide") {
                originalGuideTransform = guide.transform
                if let outlineTatuus = rootEntity.findEntity(named: "guideOutlineTatuus") {
                    originalOutlineTatuusTransform = outlineTatuus.transform
                }
                
                graduallyChangeOpacity(entity: guide, targetOpacity: 1, duration: 0.5, completion: {
                    if let ringAci = guide.findEntity(named: "ringAci") {
                        graduallyChangeOpacity(entity: ringAci, targetOpacity: 0.5, duration: 0.5)
                    }
                })
                if let textTouchToStart = rootEntity.findEntity(named: "TouchToStart") {
                    textTouchToStart.position.y -= 0.1
                    textTouchToStart.position.z -= 0.1
                    graduallyChangeOpacity(entity: textTouchToStart, targetOpacity: 1, duration: 1.2, completion: {
                    })
                }
            }
            
            if let opennningTitleHolder = rootEntity.findEntity(named: "Title_Holder") {
                if let title = try? await Entity(named: "Assets/A_OpenningTitle", in: realityKitContentBundle) {
                    title.name = "Title"
                    opennningTitleHolder.addChild(title)
                    opennningTitleHolder.position.z += 0.5
                    graduallyChangeOpacity(entity: opennningTitleHolder, targetOpacity: 1, duration: 1.2)
                }
            }
            
        case.audio_PopSphere:
            
            if let title = rootEntity.findEntity(named: "Title") {
                handlePopValueChange(entity: title, targetValue: 0, duration: 2, keyMaterialName: "TransitionAmount", completion:  {
                    title.removeFromParent()
                })
            }
            
            if let guide = rootEntity.findEntity(named: "Guide") {
                EnhancedAudioSystem.playAudio(on: guide, resourceName: "/Root/touchLogo_wav")
                if let sphereAci = guide.findEntity(named: "sphereAci") {
                    handlePopValueChange(entity: sphereAci, targetValue: 0, duration: 2, keyMaterialName: "Pop", completion:  {
                        sphereAci.components.remove(CollisionComponent.self)
                        //   sphereAci.removeFromParent()
                    })
                }
                
                
                
                Task {
                    if let circleAci = guide.findEntity(named: "circleAci") {
                        handlePopValueChange(entity: circleAci, targetValue: 1, duration: 2.5, keyMaterialName: "Animation", completion: {
                        })
                    }
                    if let textAci = guide.findEntity(named: "textAci") {
                        handlePopValueChange(entity: textAci, targetValue: 1, duration: 2.5, keyMaterialName: "Animation", completion: {
                        })
                    }
                    
                    if let ringAci = guide.findEntity(named: "ringAci") {
                        graduallyChangeOpacity(entity: ringAci, targetOpacity: 0, duration: 2.5)
                    }
                    
                    try? await Task.sleep(for: .seconds(2.0))
                    
                    if let audioSource = rootEntity.children.first {
                        conversationalBackgroundPlaybackID = EnhancedAudioSystem.playAudio(
                            on: audioSource,
                            resourceName: "/Root/Intro_bg_drone_wav",
                            volume: -10
                        )
                    }
                    
                    if let circleAci = guide.findEntity(named: "circleAci") {
                        circleAci.enumerateHierarchy { entity, stop in
                            setupBlendShapeWeightsComponent(for: entity)
                            animateBlendShapeWeights(entity: entity, blendWeightsIndex: 0, targetWeights: [1], duration: 1) {
                            }
                        }
                    }
                                        
                    if let a_LogoAci = guide.findEntity(named: "ringAci") {
                        a_LogoAci.components.set(OpacityComponent(opacity: 1.0))
                        graduallyChangeOpacity(entity: a_LogoAci, targetOpacity: 0, duration: 1)
                    }
                    
                    if let a_LogoAci = guide.findEntity(named: "textAci") {
                        a_LogoAci.components.set(OpacityComponent(opacity: 1.0))
                        graduallyChangeOpacity(entity: a_LogoAci, targetOpacity: 0, duration: 1)
                    }
                    
                    if let a_LogoAci = guide.findEntity(named: "circleAci") {
                        a_LogoAci.components.set(OpacityComponent(opacity: 1.0))
                        graduallyChangeOpacity(entity: a_LogoAci, targetOpacity: 0, duration: 1)
                    }
                    
                    
                    
                    if let guideGear = guide.findEntity(named: "GuideGearModel") {
                        handlePopValueChange(entity: guideGear, targetValue: 1, duration: 1.0, keyMaterialName: "Ring", completion: {
                            if let guideSphere = guide.findEntity(named: "GuideSphere") {
                                graduallyChangeOpacity(entity: guideSphere, targetOpacity: 1, duration: 1)
                            }
                            
                            handlePopValueChange(entity: guideGear, targetValue: 1, duration: 1.0, keyMaterialName: "Floating", completion: {
                                
                            })
                            if let guideSphere = guide.findEntity(named: "GuideSphere") {
                                handlePopValueChange(entity: guideSphere, targetValue: 1, duration: 1.0, keyMaterialName: "Floating", completion: {
                                    
                                })
                            }
                        })
                    }
                }
            }
            
            
            
        case.opacityTouchStartOut:
            if let textTouchToStart = rootEntity.findEntity(named: "TouchToStart") {
                graduallyChangeOpacity(entity: textTouchToStart, targetOpacity: 0, duration: 1.2, completion: {
                    textTouchToStart.removeFromParent()
                })
            }
            
            
            
        case .startGuideMovement:
            await startConversationalExperience()
            
            
            
            
            
            
            
            
            //MARK: - MODULE A
            
        case .startModule_A:
            await startModule_A()
            
        case.opacityPanelsIn:
            
            if let panels = rootEntity.findEntity(named: "AllRows") {
                graduallyChangeOpacity(entity: panels, targetOpacity: 1, duration: 6, completion: {
                })
            }
            
        case .endModule_B:
            
            if let playbackID = experienceBackgroundPlaybackID {
                Task {
                    await EnhancedAudioSystem.fadeInAndResume(playbackID: playbackID, duration: 2.0)
                    {
                    }
                }
            }
            handTrackingViewModel.pause()
            if let carHolder = rootEntity.findEntity(named: isFullScaleCarsActive ? "CarModel_Holder" : "ReducedCarModel_Holder") {
                if let platform = rootEntity.findEntity(named: "ME_FloatingPlane") {
                    carHolder.components.set(OpacityComponent(opacity: 1.0))
                    graduallyChangeOpacity(entity: carHolder, targetOpacity: 0, duration: 1) {
                        Task {
                            handlePopValueChange(entity: platform, targetValue: 0, duration: 1, keyMaterialName: "Pop", completion: {
                                if let tatusPBR = rootEntity.findEntity(named: "TatusPBR") {
                                    tatusPBR.removeFromParent()
                                }
                                carHolder.enumerateHierarchy { entity, stop in
                                    if entity.name != "CarModel_Holder" && entity.name != "ReducedCarModel_Holder" {
                                        entity.removeFromParent()
                                    }
                                }
                                platform.removeFromParent()
                            })
                        }
                    }
                }
            }
            
            
            try? await Task.sleep(for: .seconds(1.5))
            graduallyChangeColorEffect(
                duration: 1.5,
                styleManager: self.styleManager,
                startColor: [0.3, 0.3, 0.3],
                targetColor: [0.8, 0.8, 0.8],
                completion: {}
            )
            
            if let panels = rootEntity.findEntity(named: "AllRows") {
                graduallyChangeOpacity(entity: panels, targetOpacity: 1, duration: 0.5, completion: {
                    experienceTimer.moduleDidEnd(.B)
                    self.currentTappedVideo = nil
                    self.activeModuleRunCount -= 1
                    self.checkExperienceCompletion()
                })
            }
            if let guide = rootEntity.findEntity(named: "Guide") {
                graduallyChangeOpacity(entity: guide, targetOpacity: 1.0, duration: 2)
            }
            
            
            
        case .endModule_C:
            if let playbackID = experienceBackgroundPlaybackID {
                Task {
                    await EnhancedAudioSystem.fadeInAndResume(playbackID: playbackID, duration: 2.0)
                    {
                    }
                }
            }
            handTrackingViewModel.pause()
            
            
            if let diorama = rootEntity.findEntity(named: "Diorama_Holder") {
                graduallyChangeOpacity(entity: diorama, targetOpacity: 0, duration: 1, completion: {
                    diorama.enumerateHierarchy { entity, stop in
                        if entity.name != "Diorama_Holder" {
                            entity.removeFromParent()
                        }
                    }
                })
            }
            
            
            
            try? await Task.sleep(for: .seconds(1.5))
            
            if let allRows = rootEntity.findEntity(named: "AllRows") {
                graduallyChangeOpacity(entity: allRows, targetOpacity: 1, duration: 0.5) {
                    
                    self.currentTappedVideo = nil
                    experienceTimer.moduleDidEnd(.C)
                    self.activeModuleRunCount -= 1
                    self.checkExperienceCompletion()
                }
            }
            if let guide = rootEntity.findEntity(named: "Guide") {
                graduallyChangeOpacity(entity: guide, targetOpacity: 1, duration: 2)
            }
            
            
            
            
            //MARK: - MODULE B
            
        case .startModule_B:
            experienceTimer.moduleDidStart(.B)
            if let playbackID = experienceBackgroundPlaybackID {
                Task {
                    await EnhancedAudioSystem.fadeOutAndPause(playbackID: playbackID, duration: 2.0)
                }
            }
            
            if let panels = rootEntity.findEntity(named: "AllRows") {
                graduallyChangeOpacity(entity: panels, targetOpacity: 0, duration: 0.5, completion: {
                    startModule_B()
                })
            }
            
            
            
            
            //MARK: - Material Switch & animation
            
        case .show_Tatuus:
            if let light = rootEntity.findEntity(named: "SpotLight") {
                light.isEnabled = false
            }
            
            var tatuusEntities: [Entity] = []
            
            if let tatuusEntity = rootEntity.findEntity(named: "M_TatuusT421") {
                tatuusEntity.enumerateHierarchy { entity, stop in
                    if entity.name.contains("_ME_") {
                        tatuusEntities.append(entity)
                    }
                }
            }
            if let car = rootEntity.findEntity(named: isFullScaleCarsActive ? "CarModel_Holder" : "ReducedCarModel_Holder") {
                EnhancedAudioSystem.playAudio(on: car, resourceName: "/Root/Small_car_appearing_wav")
                if let shadowCatcher = car.findEntity(named: "A_ShadowCatcher") {
                    if isFullScaleCarsActive == true {
                        graduallyChangeOpacity(entity: shadowCatcher, targetOpacity: 1, duration: 5)
                    } else {
                        shadowCatcher.removeFromParent()
                    }
                }
            }
            graduallyChangeColorEffect(
                duration: 1.5,
                styleManager: self.styleManager,
                startColor: [0.8, 0.8, 0.8],
                targetColor: [0.3, 0.3, 0.3],
                completion: {}
            )
            
            handlePopValueChangeMultipleEntities(entities: tatuusEntities, targetValue: 1.0, duration: 5, keyMaterialName: "TransitionAmount", completion: {
                tatuusEntities.removeAll()
            })
            try? await Task.sleep(for: .seconds(5))
            if let light = rootEntity.findEntity(named: "SpotLight") {
                light.isEnabled = true
            }
            animateSpotLight(
                named: "SpotLight",
                to: 5000,
                duration: 2,
                easing: .linear
            )
            
        case .switch_Tatuus_phy:
            Task {
                try? await Task.sleep(for: .seconds(1))
                if let tatuusEntity = rootEntity.findEntity(named: "M_TatuusT421") {
                    tatuusEntity.enumerateHierarchy { tatusEntity, stop in
                        if tatusEntity.name == "Z_ME_Covers" {
                            if let tatusPBR = rootEntity.findEntity(named: "TatusPBR") {
                                if let pbrEntity = tatusPBR.findEntity(named: "Swatch_MI_PHY_Covers") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            
                                            if let tatusModelEntity = findModelEntity(in: tatusEntity) {
                                                tatusModelEntity.model!.materials = [pbrMaterial]
                                            }
                                            
                                            
                                        }
                                    }
                                }
                            }
                        }
                        
                        if tatusEntity.name == "B_ME_CarBody02" {
                            if let tatusPBR = rootEntity.findEntity(named: "TatusPBR") {
                                if let pbrEntity = tatusPBR.findEntity(named: "Swatch_MI_PHY_CarBody02") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            
                                            if let tatusModelEntity = findModelEntity(in: tatusEntity) {
                                                tatusModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if tatusEntity.name == "A_ME_CarBody01" {
                            if let tatusPBR = rootEntity.findEntity(named: "TatusPBR") {
                                if let pbrEntity = tatusPBR.findEntity(named: "Swatch_MI_PHY_CarBody01") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let tatusModelEntity = findModelEntity(in: tatusEntity) {
                                                tatusModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if tatusEntity.name == "E_ME_Transparent" {
                            if let tatusPBR = rootEntity.findEntity(named: "TatusPBR") {
                                if let pbrEntity = tatusPBR.findEntity(named: "Swatch_MI_PHY_Transparent") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let tatusModelEntity = findModelEntity(in: tatusEntity) {
                                                tatusModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if tatusEntity.name == "C_ME_MediumSized" {
                            if let tatusPBR = rootEntity.findEntity(named: "TatusPBR") {
                                if let pbrEntity = tatusPBR.findEntity(named: "Swatch_MI_PHY_MediumSized") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let tatusModelEntity = findModelEntity(in: tatusEntity) {
                                                tatusModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if tatusEntity.name == "D_ME_SmallParts" {
                            if let tatusPBR = rootEntity.findEntity(named: "TatusPBR") {
                                if let pbrEntity = tatusPBR.findEntity(named: "Swatch_MI_PHY_SmallParts") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let tatusModelEntity = findModelEntity(in: tatusEntity) {
                                                tatusModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
        case.remove_AlfaRomeo_phy:
            if let alfaRomeoPBR = rootEntity.findEntity(named: "AlfaRomeoPBR") {
                alfaRomeoPBR.removeFromParent()
            }
            
        case .switch_Tatuus_tra:
            Task {
                if let tatuusEntity = rootEntity.findEntity(named: "M_TatuusT421") {
                    tatuusEntity.enumerateHierarchy { entity, stop in
                        if entity.name.contains("_ME_") {
                            if entity.name == "Z_ME_Covers" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_Covers", from: "Assets/A_Tatuus", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "B_ME_CarBody02" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_Carbody02", from: "Assets/A_Tatuus", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "A_ME_CarBody01" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_Carbody01", from: "Assets/A_Tatuus", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "E_ME_Transparent" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_Transparent", from: "Assets/A_Tatuus", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "C_ME_MediumSized" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_Tra_MediumSized", from: "Assets/A_Tatuus", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "D_ME_SmallParts" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_Tra_SmallParts", from: "Assets/A_Tatuus", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
        case .hide_Tatuus:
            Task {
                
                animateSpotLight(
                    named: "SpotLight",
                    to: 0,
                    duration: 2,
                    easing: .linear
                )
                if let spotLightEntity = rootEntity.findEntity(named: "SpotLight") {
                    spotLightEntity.isEnabled = false
                }
                
                
                if let billboardOpacity = rootEntity.findEntity(named: "BillboardOpacity") {
                    graduallyChangeOpacity(entity: billboardOpacity, targetOpacity: 0, duration: 1) {
                    }
                    
                    var tatuusEntities: [Entity] = []
                    
                    if let tatuusEntity = rootEntity.findEntity(named: "M_TatuusT421") {
                        tatuusEntity.enumerateHierarchy { entity, stop in
                            
                            if entity.name == "A_ME_CarBody01" {
                                tatuusEntities.append(entity)
                            }
                            
                            if entity.name == "B_ME_CarBody02" {
                                tatuusEntities.append(entity)
                            }
                            
                            if entity.name == "C_ME_MediumSized" {
                                tatuusEntities.append(entity)
                            }
                            
                            if entity.name == "D_ME_SmallParts" {
                                tatuusEntities.append(entity)
                            }
                            
                            if entity.name == "E_ME_Transparent" {
                                tatuusEntities.append(entity)
                            }
                            
                            if entity.name == "Z_ME_Covers" {
                                tatuusEntities.append(entity)
                            }
                        }
                        
                        if let car = rootEntity.findEntity(named: isFullScaleCarsActive ? "CarModel_Holder" : "ReducedCarModel_Holder") {
                            EnhancedAudioSystem.playAudio(on: car, resourceName: "/Root/Small_car_appearing_wav")
                            if let shadowCatcher = car.findEntity(named: "A_ShadowCatcher") {
                                if isFullScaleCarsActive == true {
                                    graduallyChangeOpacity(entity: shadowCatcher, targetOpacity: 0, duration: 5)
                                } else {
                                    shadowCatcher.removeFromParent()
                                }
                            }
                            
                        }
                        
                        
                        handlePopValueChangeMultipleEntities(entities: tatuusEntities, targetValue: 0, duration: 5, keyMaterialName: "TransitionAmount", completion: {
                            tatuusEntities.removeAll()
                        })
                    }
                }
            }
            
            
            //MARK: - AlfaRomeo
            
        case .show_AlfaRomeo:
            Task {
                var alfaRomeoEntities: [Entity] = []
                
                if let alfaRomeoEntity = rootEntity.findEntity(named: "M_AlfaRomeoP3") {
                    alfaRomeoEntity.enumerateHierarchy { entity, stop in
                        if entity.name.contains("_ME_") {
                            alfaRomeoEntities.append(entity)
                        }
                    }
                }
                if let car = rootEntity.findEntity(named: isFullScaleCarsActive ? "CarModel_Holder" : "ReducedCarModel_Holder") {
                    EnhancedAudioSystem.playAudio(on: car, resourceName: "/Root/Small_car_appearing_wav")
                    if let shadowCatcher = car.findEntity(named: "A_ShadowCatcher") {
                        if isFullScaleCarsActive == true {
                            graduallyChangeOpacity(entity: shadowCatcher, targetOpacity: 1, duration: 5)
                        } else {
                            shadowCatcher.removeFromParent()
                        }
                    }
                    
                }
                graduallyChangeColorEffect(
                    duration: 1.5,
                    styleManager: self.styleManager,
                    startColor: [0.8, 0.8, 0.8],
                    targetColor: [0.3, 0.3, 0.3],
                    completion: {}
                )
                
                handlePopValueChangeMultipleEntities(entities: alfaRomeoEntities, targetValue: 1.0, duration: 5, keyMaterialName: "TransitionAmount", completion: {
                    alfaRomeoEntities.removeAll()
                })
                
                try? await Task.sleep(for: .seconds(5))
                animateSpotLight(
                    named: "SpotLight",
                    to: 5000,
                    duration: 2,
                    easing: .linear
                )
            }
            
        case .switch_AlfaRomeo_phy:
            Task {
                try? await Task.sleep(for: .seconds(1))
                if let alfaRomeoEntity = rootEntity.findEntity(named: "M_AlfaRomeoP3") {
                    alfaRomeoEntity.enumerateHierarchy { alfaRomeoEntity, stop in
                        
                        if alfaRomeoEntity.name == "A_ME_CarBody" {
                            if let alfaRomeoPBR = rootEntity.findEntity(named: "AlfaRomeoPBR") {
                                if let pbrEntity = alfaRomeoPBR.findEntity(named: "Swatch_MI_PHY_CarBody") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            
                                            if let alfaRomeoModelEntity = findModelEntity(in: alfaRomeoEntity) {
                                                alfaRomeoModelEntity.model!.materials = [pbrMaterial]
                                                alfaRomeoModelEntity.components.set(GroundingShadowComponent(castsShadow: true ,receivesShadow: true, fadeBehaviorNearPhysicalObjects: .constant))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if alfaRomeoEntity.name == "B_ME_NonMetal" {
                            if let alfaRomeoPBR = rootEntity.findEntity(named: "AlfaRomeoPBR") {
                                if let pbrEntity = alfaRomeoPBR.findEntity(named: "Swatch_MI_PHY_NonMetal") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            
                                            if let alfaRomeoModelEntity = findModelEntity(in: alfaRomeoEntity) {
                                                alfaRomeoModelEntity.model!.materials = [pbrMaterial]
                                                alfaRomeoModelEntity.components.set(GroundingShadowComponent(castsShadow: true ,receivesShadow: true, fadeBehaviorNearPhysicalObjects: .constant))
                                                
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if alfaRomeoEntity.name == "C_ME_Transparent" {
                            if let alfaRomeoPBR = rootEntity.findEntity(named: "AlfaRomeoPBR") {
                                if let pbrEntity = alfaRomeoPBR.findEntity(named: "Swatch_MI_PHY_Transparent") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let alfaRomeoModelEntity = findModelEntity(in: alfaRomeoEntity) {
                                                alfaRomeoModelEntity.model!.materials = [pbrMaterial]
                                                alfaRomeoModelEntity.components.set(GroundingShadowComponent(castsShadow: true ,receivesShadow: true, fadeBehaviorNearPhysicalObjects: .constant))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if alfaRomeoEntity.name == "D_ME_Metal" {
                            if let alfaRomeoPBR = rootEntity.findEntity(named: "AlfaRomeoPBR") {
                                if let pbrEntity = alfaRomeoPBR.findEntity(named: "Swatch_MI_PHY_Metal") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let alfaRomeoModelEntity = findModelEntity(in: alfaRomeoEntity) {
                                                alfaRomeoModelEntity.model!.materials = [pbrMaterial]
                                                alfaRomeoModelEntity.components.set(GroundingShadowComponent(castsShadow: true ,receivesShadow: true, fadeBehaviorNearPhysicalObjects: .constant))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if alfaRomeoEntity.name == "E_ME_Screws" {
                            if let alfaRomeoPBR = rootEntity.findEntity(named: "AlfaRomeoPBR") {
                                if let pbrEntity = alfaRomeoPBR.findEntity(named: "Swatch_MI_PHY_Screws") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            
                                            if let alfaRomeoModelEntity = findModelEntity(in: alfaRomeoEntity) {
                                                alfaRomeoModelEntity.model!.materials = [pbrMaterial]
                                                alfaRomeoModelEntity.components.set(GroundingShadowComponent(castsShadow: true ,receivesShadow: true, fadeBehaviorNearPhysicalObjects: .constant))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if alfaRomeoEntity.name == "Z_ME_Cover" {
                            if let alfaRomeoPBR = rootEntity.findEntity(named: "AlfaRomeoPBR") {
                                if let pbrEntity = alfaRomeoPBR.findEntity(named: "Swatch_MI_PHY_Cover") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            
                                            if let alfaRomeoModelEntity = findModelEntity(in: alfaRomeoEntity) {
                                                alfaRomeoModelEntity.model!.materials = [pbrMaterial]
                                                alfaRomeoModelEntity.components.set(GroundingShadowComponent(castsShadow: true ,receivesShadow: true, fadeBehaviorNearPhysicalObjects: .constant))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                    }
                }
            }
            
        case.remove_AlfaRomeo_phy:
            if let alfaRomeoPBR = rootEntity.findEntity(named: "AlfaRomeoPBR") {
                alfaRomeoPBR.removeFromParent()
            }
            
        case .switch_AlfaRomeo_tra:
            Task {
                if let alfaRomeoEntity = rootEntity.findEntity(named: "M_AlfaRomeoP3") {
                    alfaRomeoEntity.enumerateHierarchy { entity, stop in
                        if entity.name.contains("_ME_") {
                            
                            if entity.name == "A_ME_CarBody" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_A_CarBody", from: "Assets/A_AlfaRomeo", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                        modelEnity.components.set(GroundingShadowComponent(castsShadow: true ,receivesShadow: true, fadeBehaviorNearPhysicalObjects: .constant))
                                    }
                                }
                            }
                            
                            if entity.name == "B_ME_NonMetal" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_B_NonMetal", from: "Assets/A_AlfaRomeo", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                        modelEnity.components.set(GroundingShadowComponent(castsShadow: true ,receivesShadow: true, fadeBehaviorNearPhysicalObjects: .constant))
                                    }
                                }
                            }
                            
                            if entity.name == "C_ME_Transparent" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_C_Transparent", from: "Assets/A_AlfaRomeo", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                        modelEnity.components.set(GroundingShadowComponent(castsShadow: true ,receivesShadow: true, fadeBehaviorNearPhysicalObjects: .constant))
                                    }
                                }
                            }
                            
                            if entity.name == "D_ME_Metal" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_D_Metal", from: "Assets/A_AlfaRomeo", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                        modelEnity.components.set(GroundingShadowComponent(castsShadow: true ,receivesShadow: true, fadeBehaviorNearPhysicalObjects: .constant))
                                    }
                                }
                            }
                            
                            if entity.name == "E_ME_Screws" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_E_Screws", from: "Assets/A_AlfaRomeo", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                        modelEnity.components.set(GroundingShadowComponent(castsShadow: true ,receivesShadow: true, fadeBehaviorNearPhysicalObjects: .constant))
                                    }
                                }
                            }
                            
                            if entity.name == "Z_ME_Cover" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_Z_Cover", from: "Assets/A_AlfaRomeo", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                        modelEnity.components.set(GroundingShadowComponent(castsShadow: true ,receivesShadow: true, fadeBehaviorNearPhysicalObjects: .constant))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
        case .hide_AlfaRomeo:
            Task {
                animateSpotLight(
                    named: "SpotLight",
                    to: 0,
                    duration: 2,
                    easing: .linear
                )
                
                
                var alfaRomeoEntities: [Entity] = []
                
                if let alfaRomeoEntity = rootEntity.findEntity(named: "M_AlfaRomeoP3") {
                    alfaRomeoEntity.enumerateHierarchy { entity, stop in
                        
                        if entity.name == "A_ME_CarBody" {
                            alfaRomeoEntities.append(entity)
                        }
                        
                        if entity.name == "B_ME_NonMetal" {
                            alfaRomeoEntities.append(entity)
                        }
                        
                        if entity.name == "C_ME_Transparent" {
                            alfaRomeoEntities.append(entity)
                        }
                        
                        if entity.name == "D_ME_Metal" {
                            alfaRomeoEntities.append(entity)
                        }
                        
                        if entity.name == "E_ME_Screws" {
                            alfaRomeoEntities.append(entity)
                        }
                        
                        if entity.name == "Z_ME_Cover" {
                            alfaRomeoEntities.append(entity)
                        }
                    }
                    try? await Task.sleep(for: .seconds(1))
                    
                    if let car = rootEntity.findEntity(named: isFullScaleCarsActive ? "CarModel_Holder" : "ReducedCarModel_Holder") {
                        EnhancedAudioSystem.playAudio(on: car, resourceName: "/Root/Small_car_appearing_wav")
                        if let shadowCatcher = car.findEntity(named: "A_ShadowCatcher") {
                            if isFullScaleCarsActive == true {
                                graduallyChangeOpacity(entity: shadowCatcher, targetOpacity: 0, duration: 5)
                            } else {
                                shadowCatcher.removeFromParent()
                            }
                        }
                        
                    }
                    
                    handlePopValueChangeMultipleEntities(entities: alfaRomeoEntities, targetValue: 0, duration: 5, keyMaterialName: "TransitionAmount", completion: {
                        alfaRomeoEntities.removeAll()
                    })
                }
            }
            
            
            //MARK: - Ferrari375
            
        case .show_Ferrari375:
            Task {
                // Collect Ferrari entities
                var ferrariEntities: [Entity] = []
                
                rootEntity.findEntity(named: "M_Ferrari375plus")?.enumerateHierarchy { entity, _ in
                    if entity.name.contains("_ME_") {
                        ferrariEntities.append(entity)
                    }
                }
                
                // Play audio
                if let car = rootEntity.findEntity(named: isFullScaleCarsActive ? "CarModel_Holder" : "ReducedCarModel_Holder") {
                    EnhancedAudioSystem.playAudio(on: car, resourceName: "/Root/Small_car_appearing_wav")
                    if let shadowCatcher = car.findEntity(named: "A_ShadowCatcher") {
                        if isFullScaleCarsActive == true {
                            graduallyChangeOpacity(entity: shadowCatcher, targetOpacity: 1, duration: 5)
                        } else {
                            shadowCatcher.removeFromParent()
                        }
                    }
                }
                graduallyChangeColorEffect(
                    duration: 1.5,
                    styleManager: self.styleManager,
                    startColor: [0.8, 0.8, 0.8],
                    targetColor: [0.3, 0.3, 0.3],
                    completion: {}
                )
                
                // Animate materials
                handlePopValueChangeMultipleEntities(
                    entities: ferrariEntities,
                    targetValue: 1.0,
                    duration: 5,
                    keyMaterialName: "TransitionAmount"
                ) {
                    ferrariEntities.removeAll()
                }
                
                
                try? await Task.sleep(for: .seconds(5))
                
                animateSpotLight(
                    named: "SpotLight",
                    to: 5000,
                    duration: 2,
                    easing: .linear
                )
            }
            
            
        case .switch_Ferrari375_phy:
            Task {
                try? await Task.sleep(for: .seconds(1))
                if let ferrariEntity = rootEntity.findEntity(named: "M_Ferrari375plus") {
                    ferrariEntity.enumerateHierarchy { ferrariEntity, stop in
                        
                        if ferrariEntity.name == "A_ME_CarBody1" {
                            if let ferrariPBR = rootEntity.findEntity(named: "Ferrari375PBR") {
                                if let pbrEntity = ferrariPBR.findEntity(named: "Swatch_MI_PHY_CarBody1") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            
                                            if let ferrariModelEntity = findModelEntity(in: ferrariEntity) {
                                                ferrariModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if ferrariEntity.name == "A_ME_CarBody2" {
                            if let ferrariPBR = rootEntity.findEntity(named: "Ferrari375PBR") {
                                if let pbrEntity = ferrariPBR.findEntity(named: "Swatch_MI_PHY_CarBody2") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let ferrariModelEntity = findModelEntity(in: ferrariEntity) {
                                                ferrariModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if ferrariEntity.name == "C_ME_NewWheelsBack_001" {
                            if let ferrariPBR = rootEntity.findEntity(named: "Ferrari375PBR") {
                                if let pbrEntity = ferrariPBR.findEntity(named: "Swatch_MI_PHY_Wheels") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let ferrariModelEntity = findModelEntity(in: ferrariEntity) {
                                                ferrariModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if ferrariEntity.name == "D_ME_Common" {
                            if let ferrariPBR = rootEntity.findEntity(named: "Ferrari375PBR") {
                                if let pbrEntity = ferrariPBR.findEntity(named: "Swatch_MI_PHY_Common") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let ferrariModelEntity = findModelEntity(in: ferrariEntity) {
                                                ferrariModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if ferrariEntity.name == "E_ME_Transparent" {
                            if let ferrariPBR = rootEntity.findEntity(named: "Ferrari375PBR") {
                                if let pbrEntity = ferrariPBR.findEntity(named: "Swatch_MI_PHY_Transparent") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let ferrariModelEntity = findModelEntity(in: ferrariEntity) {
                                                ferrariModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if ferrariEntity.name == "Z_ME_Covers" {
                            if let ferrariPBR = rootEntity.findEntity(named: "Ferrari375PBR") {
                                if let pbrEntity = ferrariPBR.findEntity(named: "Swatch_MI_PHY_Covers") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let ferrariModelEntity = findModelEntity(in: ferrariEntity) {
                                                ferrariModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                    }
                }
            }
            
        case.remove_Ferrari375_phy:
            if let ferrariPBR = rootEntity.findEntity(named: "Ferrari375PBR") {
                ferrariPBR.removeFromParent()
            }
            
        case .switch_Ferrari375_tra:
            Task {
                if let alfaRomeoEntity = rootEntity.findEntity(named: "M_Ferrari375plus") {
                    alfaRomeoEntity.enumerateHierarchy { entity, stop in
                        if entity.name.contains("_ME_") {
                            
                            if entity.name == "A_ME_CarBody1" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_A_CarBody1", from: "Assets/A_Ferrari_02", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "B_ME_CarBody1" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_B_CarBody2", from: "Assets/A_Ferrari_02", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "C_ME_NewWheelsBack_001" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_C_Wheels", from: "Assets/A_Ferrari_02", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "D_ME_Common" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_D_Common", from: "Assets/A_Ferrari_02", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "E_ME_Transparent" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_E_Transparent", from: "Assets/A_Ferrari_02", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "Z_ME_Covers" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_Z_Covers", from: "Assets/A_Ferrari_02", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
        case .hide_Ferrari375:
            Task {
                animateSpotLight(
                    named: "SpotLight",
                    to: 0,
                    duration: 2,
                    easing: .linear
                )
                
                
                var ferrariEntities: [Entity] = []
                
                if let ferrariEntity = rootEntity.findEntity(named: "M_Ferrari375plus") {
                    ferrariEntity.enumerateHierarchy { entity, stop in
                        
                        if entity.name == "A_ME_CarBody1" {
                            ferrariEntities.append(entity)
                        }
                        
                        if entity.name == "B_ME_CarBody2" {
                            ferrariEntities.append(entity)
                        }
                        
                        if entity.name == "C_ME_NewWheelsBack_001" {
                            ferrariEntities.append(entity)
                        }
                        
                        if entity.name == "D_ME_Common" {
                            ferrariEntities.append(entity)
                        }
                        
                        if entity.name == "E_ME_Transparent" {
                            ferrariEntities.append(entity)
                        }
                        
                        if entity.name == "Z_ME_Covers" {
                            ferrariEntities.append(entity)
                        }
                    }
                    try? await Task.sleep(for: .seconds(1))
                    
                    
                    
                    if let car = rootEntity.findEntity(named: isFullScaleCarsActive ? "CarModel_Holder" : "ReducedCarModel_Holder") {
                        EnhancedAudioSystem.playAudio(on: car, resourceName: "/Root/Small_car_appearing_wav")
                        if let shadowCatcher = car.findEntity(named: "A_ShadowCatcher") {
                            if isFullScaleCarsActive == true {
                                graduallyChangeOpacity(entity: shadowCatcher, targetOpacity: 0, duration: 5)
                            } else {
                                shadowCatcher.removeFromParent()
                            }
                        }
                    }
                    
                    handlePopValueChangeMultipleEntities(entities: ferrariEntities, targetValue: 0, duration: 5, keyMaterialName: "TransitionAmount", completion: {
                        ferrariEntities.removeAll()
                    })
                }
            }
            
            
            
            //MARK: - LanciaStratos
            
        case .show_LanciaStratos:
            Task {
                var lanciaStratosEntities: [Entity] = []
                
                if let lanciaStratosEntity = rootEntity.findEntity(named: "M_LanciaStratos") {
                    lanciaStratosEntity.enumerateHierarchy { entity, stop in
                        if entity.name.contains("_ME_") {
                            lanciaStratosEntities.append(entity)
                        }
                    }
                }
                if let car = rootEntity.findEntity(named: isFullScaleCarsActive ? "CarModel_Holder" : "ReducedCarModel_Holder") {
                    EnhancedAudioSystem.playAudio(on: car, resourceName: "/Root/Small_car_appearing_wav")
                    if let shadowCatcher = car.findEntity(named: "A_ShadowCatcher") {
                        if isFullScaleCarsActive == true {
                            graduallyChangeOpacity(entity: shadowCatcher, targetOpacity: 1, duration: 5)
                        } else {
                            shadowCatcher.removeFromParent()
                        }
                    }
                }
                
                graduallyChangeColorEffect(
                    duration: 1.5,
                    styleManager: self.styleManager,
                    startColor: [0.8, 0.8, 0.8],
                    targetColor: [0.3, 0.3, 0.3],
                    completion: {}
                )
                
                handlePopValueChangeMultipleEntities(entities: lanciaStratosEntities, targetValue: 1.0, duration: 5, keyMaterialName: "TransitionAmount", completion: {
                    lanciaStratosEntities.removeAll()
                })
                
                try? await Task.sleep(for: .seconds(5))
                
                animateSpotLight(
                    named: "SpotLight",
                    to: 5000,
                    duration: 2,
                    easing: .linear
                )
            }
            
        case .switch_LanciaStratos_phy:
            Task {
                try? await Task.sleep(for: .seconds(1))
                if let lanciaStratosEntity = rootEntity.findEntity(named: "M_LanciaStratos") {
                    lanciaStratosEntity.enumerateHierarchy { lanciaStratosEntity, stop in
                        
                        if lanciaStratosEntity.name == "A_ME_CarBodyFront" {
                            if let lanciaStratosPBR = rootEntity.findEntity(named: "LanciaStratosPBR") {
                                if let pbrEntity = lanciaStratosPBR.findEntity(named: "Swatch_MI_PHY_CarBodyFront") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let lanciaStratosModelEntity = findModelEntity(in: lanciaStratosEntity) {
                                                lanciaStratosModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if lanciaStratosEntity.name == "A_ME_CarBodyBack" {
                            if let lanciaStratosPBR = rootEntity.findEntity(named: "LanciaStratosPBR") {
                                if let pbrEntity = lanciaStratosPBR.findEntity(named: "Swatch_MI_PHY_CarBodyBack") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let lanciaStratosModelEntity = findModelEntity(in: lanciaStratosEntity) {
                                                lanciaStratosModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if lanciaStratosEntity.name == "B_ME_BacklightsGlass" {
                            if let lanciaStratosPBR = rootEntity.findEntity(named: "LanciaStratosPBR") {
                                if let pbrEntity = lanciaStratosPBR.findEntity(named: "Swatch_MI_PHY_BlackLightsGlass") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let lanciaStratosModelEntity = findModelEntity(in: lanciaStratosEntity) {
                                                lanciaStratosModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if lanciaStratosEntity.name == "C_ME_BackWheels" {
                            if let lanciaStratosPBR = rootEntity.findEntity(named: "LanciaStratosPBR") {
                                if let pbrEntity = lanciaStratosPBR.findEntity(named: "Swatch_MI_PHY_BackWheels") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let lanciaStratosModelEntity = findModelEntity(in: lanciaStratosEntity) {
                                                lanciaStratosModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if lanciaStratosEntity.name == "D_ME_Seatbelt1" {
                            if let lanciaStratosPBR = rootEntity.findEntity(named: "LanciaStratosPBR") {
                                if let pbrEntity = lanciaStratosPBR.findEntity(named: "Swatch_MI_PHY_SeatBelt") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let lanciaStratosModelEntity = findModelEntity(in: lanciaStratosEntity) {
                                                lanciaStratosModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if lanciaStratosEntity.name == "E_ME_AccessoriesFuel" {
                            if let lanciaStratosPBR = rootEntity.findEntity(named: "LanciaStratosPBR") {
                                if let pbrEntity = lanciaStratosPBR.findEntity(named: "Swatch_MI_PHY_AcessoriesFuel") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let lanciaStratosModelEntity = findModelEntity(in: lanciaStratosEntity) {
                                                lanciaStratosModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if lanciaStratosEntity.name == "Z_ME_CarBottom" {
                            if let lanciaStratosPBR = rootEntity.findEntity(named: "LanciaStratosPBR") {
                                if let pbrEntity = lanciaStratosPBR.findEntity(named: "Swatch_MI_PHY_CarBottom") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let lanciaStratosModelEntity = findModelEntity(in: lanciaStratosEntity) {
                                                lanciaStratosModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
        case.remove_LanciaStratos_phy:
            if let lanciaStratosPBR = rootEntity.findEntity(named: "LanciaStratosPBR") {
                lanciaStratosPBR.removeFromParent()
            }
            
        case.switch_LanciaStratos_tra:
            Task {
                if let lanciaStratosEntity = rootEntity.findEntity(named: "M_LanciaStratos") {
                    lanciaStratosEntity.enumerateHierarchy { entity, stop in
                        if entity.name.contains("_ME_") {
                            
                            if entity.name == "A_ME_CarBodyFront" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_A_CarBodyFront", from: "Assets/A_LanciaStratos", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "A_ME_CarBodyBack" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_A_CarBodyBack", from: "Assets/A_LanciaStratos", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "B_ME_BacklightsGlass" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_B_BlackLightsGlass", from: "Assets/A_LanciaStratos", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "C_ME_BackWheels" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_C_BackWheels", from: "Assets/A_LanciaStratos", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "D_ME_Seatbelt1" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_D_SeatBelt", from: "Assets/A_LanciaStratos", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "E_ME_AccessoriesFuel" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_E_AcessoriesFuel", from: "Assets/A_LanciaStratos", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "Z_ME_CarBottom" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_Z_CarBottom", from: "Assets/A_LanciaStratos", inBundle: realityKitContentBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
        case .hide_LanciaStratos:
            Task {
                animateSpotLight(
                    named: "SpotLight",
                    to: 0,
                    duration: 2,
                    easing: .linear
                )
                
                var lanciaStratosEntities: [Entity] = []
                
                if let lanciaStratosEntity = rootEntity.findEntity(named: "M_LanciaStratos") {
                    lanciaStratosEntity.enumerateHierarchy { entity, stop in
                        
                        if entity.name == "A_ME_CarBodyFront" {
                            lanciaStratosEntities.append(entity)
                        }
                        
                        if entity.name == "A_ME_CarBodyBack" {
                            lanciaStratosEntities.append(entity)
                        }
                        
                        if entity.name == "B_ME_BacklightsGlass" {
                            lanciaStratosEntities.append(entity)
                        }
                        
                        if entity.name == "C_ME_BackWheels" {
                            lanciaStratosEntities.append(entity)
                        }
                        
                        if entity.name == "D_ME_Seatbelt1" {
                            lanciaStratosEntities.append(entity)
                        }
                        
                        if entity.name == "E_ME_AccessoriesFuel" {
                            lanciaStratosEntities.append(entity)
                        }
                        
                        if entity.name == "Z_ME_CarBottom" {
                            lanciaStratosEntities.append(entity)
                        }
                        
                    }
                    try? await Task.sleep(for: .seconds(1))
                    
                    
                    if let car = rootEntity.findEntity(named: isFullScaleCarsActive ? "CarModel_Holder" : "ReducedCarModel_Holder") {
                        EnhancedAudioSystem.playAudio(on: car, resourceName: "/Root/Small_car_appearing_wav")
                        if let shadowCatcher = car.findEntity(named: "A_ShadowCatcher") {
                            if isFullScaleCarsActive == true {
                                graduallyChangeOpacity(entity: shadowCatcher, targetOpacity: 0, duration: 5)
                            } else {
                                shadowCatcher.removeFromParent()
                            }
                        }
                    }
                    
                    
                    handlePopValueChangeMultipleEntities(entities: lanciaStratosEntities, targetValue: 0, duration: 5, keyMaterialName: "TransitionAmount", completion: {
                        lanciaStratosEntity.enumerateHierarchy { entity, stop in
                            entity.removeFromParent()
                        }
                        lanciaStratosEntities.removeAll()
                    })
                }
            }
            
            
            
            
            
            
            //MARK: - Audios Tatuus
            
        case.audio_Tatuus_01:
            if let playbackID = experienceBackgroundPlaybackID {
                Task {
                    await EnhancedAudioSystem.fadeOutAndPause(playbackID: playbackID, duration: 2.0)
                }
            }
            
            if let voiceAlfaRomeo = rootEntity.findEntity(named: "VoiceAudioSource_A_Tatuus") {
                EnhancedAudioSystem.playAudio(on: voiceAlfaRomeo, resourceName: "/Root/Billboards_Tatuus/EP03_PAN08_Voice_Tatuus_mp3")
            }
            if !isFullScaleCarsActive {
                
                if let musicAlfaRomeo = rootEntity.findEntity(named: "MusicAudioSource_A_Tatuus_1") {
                    EnhancedAudioSystem.playAudio(on: musicAlfaRomeo, resourceName: "/Root/Billboards_Tatuus/EP03_PAN08_Music_Tatuus_wav", volume: -5,isAmbientAudio: false)
                }
            } else {
                if let musicAlfaRomeo = rootEntity.findEntity(named: "MusicAudioSource_A_Tatuus_2") {
                    EnhancedAudioSystem.playAudio(on: musicAlfaRomeo, resourceName: "/Root/Billboards_Tatuus/EP03_PAN08_Music_Tatuus_wav", volume: -5,isAmbientAudio: false)
                }
                if let musicAlfaRomeo = rootEntity.findEntity(named: "MusicAudioSource_A_Tatuus_3") {
                    EnhancedAudioSystem.playAudio(on: musicAlfaRomeo, resourceName: "/Root/Billboards_Tatuus/EP03_PAN08_Music_Tatuus_wav", volume: -5,isAmbientAudio: false)
                }
            }
            
            
            // Setup YAxisBillboards for the Info Baloons
            if let billboard01 = rootEntity.findEntity(named: "A_Billboard_01") {
                if let billboard = billboard01.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard02 = rootEntity.findEntity(named: "A_Billboard_02") {
                if let billboard = billboard02.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard03 = rootEntity.findEntity(named: "A_Billboard_03") {
                if let billboard = billboard03.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard04 = rootEntity.findEntity(named: "A_Billboard_04") {
                if let billboard = billboard04.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard05 = rootEntity.findEntity(named: "A_Billboard_05") {
                if let billboard = billboard05.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            
        case.billboard_Tatuus_01:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_01") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_Tatuus_02:
            if let billboard = rootEntity.findEntity(named: "A_Billboard_02") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_Tatuus_03:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_03") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_Tatuus_04:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_04") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_Tatuus_05:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_05") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
                        
            
            
        case .show_DeltaIntegrale:
            var deltaIntegraleEntities: [Entity] = []
            
            if let deltaIntegraleEntity = rootEntity.findEntity(named: "M_DeltaIntegrale") {
                deltaIntegraleEntity.enumerateHierarchy { entity, stop in
                    if entity.name.contains("_ME_") {
                        deltaIntegraleEntities.append(entity)
                    }
                }
            }
            if let car = rootEntity.findEntity(named: "CarModel_Holder") {
                EnhancedAudioSystem.playAudio(on: car, resourceName: "/Root/Small_car_appearing_wav")
                if let shadowCatcher = car.findEntity(named: "A_ShadowCatcher") {
                    if isFullScaleCarsActive == true {
                        graduallyChangeOpacity(entity: shadowCatcher, targetOpacity: 1, duration: 5)
                    } else {
                        shadowCatcher.removeFromParent()
                    }
                }
            }
            graduallyChangeColorEffect(
                duration: 1.5,
                styleManager: self.styleManager,
                startColor: [0.8, 0.8, 0.8],
                targetColor: [0.3, 0.3, 0.3],
                completion: {}
            )
            
            handlePopValueChangeMultipleEntities(entities: deltaIntegraleEntities, targetValue: 1.0, duration: 5, keyMaterialName: "TransitionAmount", completion: {
                deltaIntegraleEntities.removeAll()
            })
            
            try? await Task.sleep(for: .seconds(5))
            animateSpotLight(
                named: "SpotLight",
                to: 5000,
                duration: 2,
                easing: .linear
            )
            
        case .switch_DeltaIntegrale_phy:
            Task {
                try? await Task.sleep(for: .seconds(1))
                if let deltaIntegraleEntity = rootEntity.findEntity(named: "M_DeltaIntegrale") {
                    deltaIntegraleEntity.enumerateHierarchy { deltaIntegraleEntity, stop in
                        
                        if deltaIntegraleEntity.name == "_01_ME_CarBody1" {
                            if let deltaIntegralePBR = rootEntity.findEntity(named: "DeltaIntegralePBR") {
                                if let pbrEntity = deltaIntegralePBR.findEntity(named: "Swatch_MI_PHY_Carbody1") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let deltaIntegraleModelEntity = findModelEntity(in: deltaIntegraleEntity) {
                                                deltaIntegraleModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if deltaIntegraleEntity.name == "_02_ME_CarBody2" {
                            if let deltaIntegralePBR = rootEntity.findEntity(named: "DeltaIntegralePBR") {
                                if let pbrEntity = deltaIntegralePBR.findEntity(named: "Swatch_MI_PHY_Carbody2") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let deltaIntegraleModelEntity = findModelEntity(in: deltaIntegraleEntity) {
                                                deltaIntegraleModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if deltaIntegraleEntity.name == "_03_ME_CarBody3" {
                            if let deltaIntegralePBR = rootEntity.findEntity(named: "DeltaIntegralePBR") {
                                if let pbrEntity = deltaIntegralePBR.findEntity(named: "Swatch_MI_PHY_Carbody3") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let deltaIntegraleModelEntity = findModelEntity(in: deltaIntegraleEntity) {
                                                deltaIntegraleModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if deltaIntegraleEntity.name == "_04_ME_Dashboard" {
                            if let deltaIntegralePBR = rootEntity.findEntity(named: "DeltaIntegralePBR") {
                                if let pbrEntity = deltaIntegralePBR.findEntity(named: "Swatch_MI_PHY_Dashboard") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let deltaIntegraleModelEntity = findModelEntity(in: deltaIntegraleEntity) {
                                                deltaIntegraleModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if deltaIntegraleEntity.name == "_05_ME_Interiors1" {
                            if let deltaIntegralePBR = rootEntity.findEntity(named: "DeltaIntegralePBR") {
                                if let pbrEntity = deltaIntegralePBR.findEntity(named: "Swatch_MI_PHY_Interiors1") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let deltaIntegraleModelEntity = findModelEntity(in: deltaIntegraleEntity) {
                                                deltaIntegraleModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if deltaIntegraleEntity.name == "_06_ME_Interiors2" {
                            if let deltaIntegralePBR = rootEntity.findEntity(named: "DeltaIntegralePBR") {
                                if let pbrEntity = deltaIntegralePBR.findEntity(named: "Swatch_MI_PHY_Interiors2") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let deltaIntegraleModelEntity = findModelEntity(in: deltaIntegraleEntity) {
                                                deltaIntegraleModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if deltaIntegraleEntity.name == "_07_ME_Transparent" {
                            if let deltaIntegralePBR = rootEntity.findEntity(named: "DeltaIntegralePBR") {
                                if let pbrEntity = deltaIntegralePBR.findEntity(named: "Swatch_MI_PHY_Transparent") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let deltaIntegraleModelEntity = findModelEntity(in: deltaIntegraleEntity) {
                                                deltaIntegraleModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if deltaIntegraleEntity.name == "_08_ME_ExternalPieces" {
                            if let deltaIntegralePBR = rootEntity.findEntity(named: "DeltaIntegralePBR") {
                                if let pbrEntity = deltaIntegralePBR.findEntity(named: "Swatch_MI_PHY_ExternalPieces") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let deltaIntegraleModelEntity = findModelEntity(in: deltaIntegraleEntity) {
                                                deltaIntegraleModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if deltaIntegraleEntity.name == "_09_ME_Graphics" {
                            if let deltaIntegralePBR = rootEntity.findEntity(named: "DeltaIntegralePBR") {
                                if let pbrEntity = deltaIntegralePBR.findEntity(named: "Swatch_MI_PHY_Graphics") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let deltaIntegraleModelEntity = findModelEntity(in: deltaIntegraleEntity) {
                                                deltaIntegraleModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if deltaIntegraleEntity.name == "_10_ME_CarBottomAndCovers" {
                            if let deltaIntegralePBR = rootEntity.findEntity(named: "DeltaIntegralePBR") {
                                if let pbrEntity = deltaIntegralePBR.findEntity(named: "Swatch_MI_PHY_CarBottomAndCovers") {
                                    if let pbrModelEntity = findModelEntity(in: pbrEntity) {
                                        if let pbrMaterial = pbrModelEntity.model?.materials.first {
                                            if let deltaIntegraleModelEntity = findModelEntity(in: deltaIntegraleEntity) {
                                                deltaIntegraleModelEntity.model!.materials = [pbrMaterial]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
        case.remove_DeltaIntegrale_phy:
            if let deltaIntegralePBR = rootEntity.findEntity(named: "DeltaIntegralePBR") {
                deltaIntegralePBR.removeFromParent()
            }
            
        case.switch_DeltaIntegrale_tra:
            Task {
                if let deltaIntegraleEntity = rootEntity.findEntity(named: "M_DeltaIntegrale") {
                    deltaIntegraleEntity.enumerateHierarchy { entity, stop in
                        if entity.name.contains("_ME_") {
                            
                            if entity.name == "_01_ME_CarBody1" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_A_Carbody1", from: "BulkImport/A_DeltaIntegrale", inBundle: BigAssets.bigAssetsBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "_02_ME_CarBody2" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_B_Carbody2", from: "BulkImport/A_DeltaIntegrale", inBundle: BigAssets.bigAssetsBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "_03_ME_CarBody3" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_C_Carbody3", from: "BulkImport/A_DeltaIntegrale", inBundle: BigAssets.bigAssetsBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "_04_ME_Dashboard" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_D_Dashboard", from: "BulkImport/A_DeltaIntegrale", inBundle: BigAssets.bigAssetsBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "_05_ME_Interiors1" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_E_Interiors1", from: "BulkImport/A_DeltaIntegrale", inBundle: BigAssets.bigAssetsBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "_06_ME_Interiors2" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_F_Interiors2", from: "BulkImport/A_DeltaIntegrale", inBundle: BigAssets.bigAssetsBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "_07_ME_Transparent" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_G_Transparent", from: "BulkImport/A_DeltaIntegrale", inBundle: BigAssets.bigAssetsBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "_08_ME_ExternalPieces" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_H_ExternalPieces", from: "BulkImport/A_DeltaIntegrale", inBundle: BigAssets.bigAssetsBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "_09_ME_Graphics" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_J_Graphics", from: "BulkImport/A_DeltaIntegrale", inBundle: BigAssets.bigAssetsBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                            
                            if entity.name == "_10_ME_CarBottomAndCovers" {
                                if let modelEnity = findModelEntity(in: entity) {
                                    Task {
                                        var material = try? await getShaderGraphMaterial(named: "/Root/Materials/M_Transition/MI_TRA_Z_CarBottomAndCovers", from: "BulkImport/A_DeltaIntegrale", inBundle: BigAssets.bigAssetsBundle)
                                        try? material?.setParameter(name: "TransitionAmount", value: .float(1))
                                        modelEnity.model?.materials = [material!]
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
        case .hide_DeltaIntegrale:
            Task {
                
                var deltaIntegraleEntities: [Entity] = []
                animateSpotLight(
                    named: "SpotLight",
                    to: 0,
                    duration: 2,
                    easing: .linear
                )
                
                if let deltaIntegraleEntity = rootEntity.findEntity(named: "M_DeltaIntegrale") {
                    deltaIntegraleEntity.enumerateHierarchy { entity, stop in
                        
                        if entity.name == "_01_ME_CarBody1" {
                            deltaIntegraleEntities.append(entity)
                        }
                        
                        if entity.name == "_02_ME_CarBody2" {
                            deltaIntegraleEntities.append(entity)
                        }
                        
                        if entity.name == "_03_ME_CarBody3" {
                            deltaIntegraleEntities.append(entity)
                        }
                        
                        if entity.name == "_04_ME_Dashboard" {
                            deltaIntegraleEntities.append(entity)
                        }
                        
                        if entity.name == "_05_ME_Interiors1" {
                            deltaIntegraleEntities.append(entity)
                        }
                        
                        if entity.name == "_06_ME_Interiors2" {
                            deltaIntegraleEntities.append(entity)
                        }
                        
                        if entity.name == "_07_ME_Transparent" {
                            deltaIntegraleEntities.append(entity)
                        }
                        
                        if entity.name == "_08_ME_ExternalPieces" {
                            deltaIntegraleEntities.append(entity)
                        }
                        
                        if entity.name == "_09_ME_Graphics" {
                            deltaIntegraleEntities.append(entity)
                        }
                        
                        if entity.name == "_10_ME_CarBottomAndCovers" {
                            deltaIntegraleEntities.append(entity)
                        }
                        
                    }
                    try? await Task.sleep(for: .seconds(3))
                    
                    if let car = rootEntity.findEntity(named: isFullScaleCarsActive ? "CarModel_Holder" : "ReducedCarModel_Holder") {
                        EnhancedAudioSystem.playAudio(on: car, resourceName: "/Root/Small_car_appearing_wav")
                        if let shadowCatcher = car.findEntity(named: "A_ShadowCatcher") {
                            if isFullScaleCarsActive == true {
                                graduallyChangeOpacity(entity: shadowCatcher, targetOpacity: 0, duration: 5)
                            } else {
                                shadowCatcher.removeFromParent()
                            }
                        }
                        
                    }
                    
                    
                    handlePopValueChangeMultipleEntities(entities: deltaIntegraleEntities, targetValue: 0, duration: 5, keyMaterialName: "TransitionAmount", completion: {
                        deltaIntegraleEntities.removeAll()
                    })
                }
            }
            
            
            
            
            
            
            
            
            
            
            //MARK: - MODULE C
            
        case .startModule_C:
            experienceTimer.moduleDidStart(.C)
            if let playbackID = experienceBackgroundPlaybackID {
                Task {
                    await EnhancedAudioSystem.fadeOutAndPause(playbackID: playbackID, duration: 2.0)
                }
            }
            if let panels = rootEntity.findEntity(named: "AllRows") {
                graduallyChangeOpacity(entity: panels, targetOpacity: 0, duration: 0.5, completion: {
                    startModule_C()
                })
            }
            
            
            
            
        case.spinTatuus:
            if let holderTatuus = rootEntity.findEntity(named: "TestRotation") {
                let degrees: Float = 360
                let radians = degrees * .pi / 180
                graduallyChangeOrientation(entity: holderTatuus, targetOrientation: simd_quatf(angle: radians, axis: [0, 1, 0]), duration: 20)
            }
            
            //MARK: - Audios Diorama
            
        case.audio_Diorama_01:
            
            if let playbackID = experienceBackgroundPlaybackID {
                Task {
                    await EnhancedAudioSystem.fadeOutAndPause(playbackID: playbackID, duration: 2.0)
                }
            }
            
            if let musicAudioSource_A_Monza_Diorama = rootEntity.findEntity(named: "MusicAudioSource_A_Diorama") {
                EnhancedAudioSystem.playAudio(on: musicAudioSource_A_Monza_Diorama, resourceName: "/Root/Billboards_VallelungaDiorama/EP03_PAN09_Voice_Vallelunga_Diorama_wav", isAmbientAudio: false)
            }
            
            if let voiceAudioSource_A_Monza_Diorama = rootEntity.findEntity(named: "VoiceAudioSource_A_Diorama") {
                EnhancedAudioSystem.playAudio(on: voiceAudioSource_A_Monza_Diorama, resourceName: "/Root/Billboards_VallelungaDiorama/EP03_PAN09_Music_Vallelunga_Diorama_wav")
            }
            
            
            if let diorama = rootEntity.findEntity(named: "M_Vallelunga") {
                EnhancedAudioSystem.playAudio(on: diorama, resourceName: "/Root/Billboards_Diorama/Horizon_954_mp3")
            }
            
            // Setup YAxisBillboards for the Info Baloons
            if let billboardA = rootEntity.findEntity(named: "A_Billboard_A") {
                if let billboard = billboardA.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboardB = rootEntity.findEntity(named: "A_Billboard_B") {
                if let billboard = billboardB.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            if let billboardC = rootEntity.findEntity(named: "A_Billboard_C") {
                if let billboard = billboardC.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            if let billboardD = rootEntity.findEntity(named: "A_Billboard_D") {
                if let billboard = billboardD.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            if let billboardE = rootEntity.findEntity(named: "A_Billboard_E") {
                if let billboard = billboardE.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            if let billboardF = rootEntity.findEntity(named: "A_Billboard_F") {
                if let billboard = billboardF.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            
            //MARK: - Vallelunga Diorama Notifications
            
        case.billboard_Diorama_01:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_A") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let island = rootEntity.findEntity(named: "HZone_02") {
                graduallyChangeOpacity(entity: island, targetOpacity: 1, duration: 0.75, completion: {
                    graduallyChangeOpacity(entity: island, targetOpacity: 0, duration: 0.5, completion: {
                        graduallyChangeOpacity(entity: island, targetOpacity: 1, duration: 0.75, completion: {
                            graduallyChangeOpacity(entity: island, targetOpacity: 0, duration: 0.5, completion: {
                            })
                        })
                    })
                })
            }
            
            if let sara = rootEntity.findEntity(named: "Sara") {
                handlePopValueChange(entity: sara, targetValue: 1.0, duration: 1.0, keyMaterialName: "HighlightAnim", completion: {
                    handlePopValueChange(entity: sara, targetValue: 0.0, duration: 0.75, keyMaterialName: "HighlightAnim", completion: {
                        handlePopValueChange(entity: sara, targetValue: 0.0, duration: 1.0, keyMaterialName: "HighlightAnim", completion: {
                            handlePopValueChange(entity: sara, targetValue: 0.0, duration: 0.75, keyMaterialName: "HighlightAnim", completion: {
                            })
                        })
                    })
                })
            }
            
            
            
            
        case.billboard_Diorama_02:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_B") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            
            if let congress = rootEntity.findEntity(named: "Congress") {
                handlePopValueChange(entity: congress, targetValue: 1.0, duration: 1.0, keyMaterialName: "HighlightAnim", completion: {
                    handlePopValueChange(entity: congress, targetValue: 0.0, duration: 0.75, keyMaterialName: "HighlightAnim", completion: {
                        handlePopValueChange(entity: congress, targetValue: 0.0, duration: 1.0, keyMaterialName: "HighlightAnim", completion: {
                            handlePopValueChange(entity: congress, targetValue: 0.0, duration: 0.75, keyMaterialName: "HighlightAnim", completion: {
                            })
                        })
                    })
                })
            }
            
        case.billboard_Diorama_03:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_C") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            //            if let highlight = rootEntity.findEntity(named: "groundDiorama") {
            //                handlePopValueChange(entity: highlight, targetValue: 3, duration: 1.0, keyMaterialName: "Highlight_ID", completion: {
            //                })
            //            }
            
            if let island = rootEntity.findEntity(named: "HZone_01") {
                graduallyChangeOpacity(entity: island, targetOpacity: 1, duration: 0.75, completion: {
                    graduallyChangeOpacity(entity: island, targetOpacity: 0, duration: 0.5, completion: {
                        graduallyChangeOpacity(entity: island, targetOpacity: 1, duration: 0.75, completion: {
                            graduallyChangeOpacity(entity: island, targetOpacity: 0, duration: 0.5, completion: {
                            })
                        })
                    })
                })
            }
            
        case.billboard_Diorama_04:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_D") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let island = rootEntity.findEntity(named: "HZone_03") {
                graduallyChangeOpacity(entity: island, targetOpacity: 1, duration: 0.75, completion: {
                    graduallyChangeOpacity(entity: island, targetOpacity: 0, duration: 0.5, completion: {
                        graduallyChangeOpacity(entity: island, targetOpacity: 1, duration: 0.75, completion: {
                            graduallyChangeOpacity(entity: island, targetOpacity: 0, duration: 0.5, completion: {
                            })
                        })
                    })
                })
            }
            
        case.billboard_Diorama_05:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_E") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let island = rootEntity.findEntity(named: "HZone_03") {
                graduallyChangeOpacity(entity: island, targetOpacity: 1, duration: 0.75, completion: {
                    graduallyChangeOpacity(entity: island, targetOpacity: 0, duration: 0.5, completion: {
                        graduallyChangeOpacity(entity: island, targetOpacity: 1, duration: 0.75, completion: {
                            graduallyChangeOpacity(entity: island, targetOpacity: 0, duration: 0.5, completion: {
                            })
                        })
                    })
                })
            }
            
        case.billboard_Diorama_06:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_F") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let island = rootEntity.findEntity(named: "HZone_03") {
                graduallyChangeOpacity(entity: island, targetOpacity: 1, duration: 0.75, completion: {
                    graduallyChangeOpacity(entity: island, targetOpacity: 0, duration: 0.5, completion: {
                        graduallyChangeOpacity(entity: island, targetOpacity: 1, duration: 0.75, completion: {
                            graduallyChangeOpacity(entity: island, targetOpacity: 0, duration: 0.5, completion: {
                            })
                        })
                    })
                })
            }
            
        case.title_VallelungaDiorama_0:
            
            if let title = rootEntity.findEntity(named: "AutodromoDiVallelunga") {
                graduallyChangeOpacity(entity: title, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: title, resourceName: "/Root/PanelAppearing_wav")
            }
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 1, duration: 2, completion: {
                })
            }
            
        case.removeTitle_VallelungaDiorama_0:
            
            if let title = rootEntity.findEntity(named: "AutodromoDiVallelunga") {
                graduallyChangeOpacity(entity: title, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: title, resourceName: "/Root/PanelAppearing_wav")
            }
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 0, duration: 2, completion: {
                })
            }
            
        case.title_VallelungaDiorama_1:
            
            if let title = rootEntity.findEntity(named: "OltreIlCircuito") {
                graduallyChangeOpacity(entity: title, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: title, resourceName: "/Root/PanelAppearing_wav")
            }
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 1, duration: 2, completion: {
                })
            }
            
        case.removeTitle_VallelungaDiorama_1:
            
            if let title = rootEntity.findEntity(named: "OltreIlCircuito") {
                graduallyChangeOpacity(entity: title, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: title, resourceName: "/Root/PanelAppearing_wav")
            }
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 0, duration: 2, completion: {
                })
            }
            
        case.title_VallelungaDiorama_2:
            
            if let title = rootEntity.findEntity(named: "UnEcosistemaDellaGuida") {
                graduallyChangeOpacity(entity: title, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: title, resourceName: "/Root/PanelAppearing_wav")
            }
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 1, duration: 2, completion: {
                })
            }
            
        case.removeTitle_VallelungaDiorama_2:
            
            if let title = rootEntity.findEntity(named: "UnEcosistemaDellaGuida") {
                graduallyChangeOpacity(entity: title, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: title, resourceName: "/Root/PanelAppearing_wav")
            }
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 0, duration: 2, completion: {
                })
            }
            
        case.title_VallelungaDiorama_3:
            
            if let title = rootEntity.findEntity(named: "EventiECultura") {
                graduallyChangeOpacity(entity: title, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: title, resourceName: "/Root/PanelAppearing_wav")
            }
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 1, duration: 2, completion: {
                })
            }
            
        case.removeTitle_VallelungaDiorama_3:
            
            if let title = rootEntity.findEntity(named: "EventiECultura") {
                graduallyChangeOpacity(entity: title, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: title, resourceName: "/Root/PanelAppearing_wav")
            }
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 0, duration: 2, completion: {
                })
            }
            
        case.title_VallelungaDiorama_4:
            
            if let title = rootEntity.findEntity(named: "TestESperimentazione") {
                graduallyChangeOpacity(entity: title, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: title, resourceName: "/Root/PanelAppearing_wav")
            }
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 1, duration: 2, completion: {
                })
            }
            
        case.removeTitle_VallelungaDiorama_4:
            
            if let title = rootEntity.findEntity(named: "TestESperimentazione") {
                graduallyChangeOpacity(entity: title, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: title, resourceName: "/Root/PanelAppearing_wav")
            }
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 0, duration: 2, completion: {
                })
            }
            
        case.title_VallelungaDiorama_5:
            
            if let title = rootEntity.findEntity(named: "TracceDelPassato") {
                graduallyChangeOpacity(entity: title, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: title, resourceName: "/Root/PanelAppearing_wav")
            }
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 1, duration: 2, completion: {
                })
            }
            
        case.removeTitle_VallelungaDiorama_5:
            
            if let title = rootEntity.findEntity(named: "TracceDelPassato") {
                graduallyChangeOpacity(entity: title, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: title, resourceName: "/Root/PanelAppearing_wav")
            }
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 0, duration: 2, completion: {
                })
            }
            
        case.title_VallelungaDiorama_6:
            
            if let title = rootEntity.findEntity(named: "FormazioneRally") {
                graduallyChangeOpacity(entity: title, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: title, resourceName: "/Root/PanelAppearing_wav")
            }
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 1, duration: 2, completion: {
                })
            }
            
        case.removeTitle_VallelungaDiorama_6:
            
            if let title = rootEntity.findEntity(named: "FormazioneRally") {
                graduallyChangeOpacity(entity: title, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: title, resourceName: "/Root/PanelAppearing_wav")
            }
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 0, duration: 2, completion: {
                })
            }
            
            //MARK: - Audios AlfaRomeo
            
        case.audio_AlfaRomeo_01:
            if let playbackID = experienceBackgroundPlaybackID {
                Task {
                    await EnhancedAudioSystem.fadeOutAndPause(playbackID: playbackID, duration: 2.0)
                }
            }
            
            if let voiceAlfaRomeo = rootEntity.findEntity(named: "VoiceAudioSource_A_AlfaRomeo") {
                EnhancedAudioSystem.playAudio(on: voiceAlfaRomeo, resourceName: "/Root/Billboards_AlfaRomeoP3/EP01_PAN09_Voice_Alfa_Romeo_P3_mp3")
            }
            
            if !isFullScaleCarsActive {
                
                if let musicAlfaRomeo = rootEntity.findEntity(named: "MusicAudioSource_A_AlfaRomeo_1") {
                    EnhancedAudioSystem.playAudio(on: musicAlfaRomeo, resourceName: "/Root/Billboards_AlfaRomeoP3/EP01_PAN09_Music_Alfa_Romeo_P3_mp3", volume: -5,isAmbientAudio: false)
                }
            } else {
                if let musicAlfaRomeo = rootEntity.findEntity(named: "MusicAudioSource_A_AlfaRomeo_2") {
                    EnhancedAudioSystem.playAudio(on: musicAlfaRomeo, resourceName: "/Root/Billboards_AlfaRomeoP3/EP01_PAN09_Music_Alfa_Romeo_P3_mp3", volume: -5,isAmbientAudio: false)
                }
                if let musicAlfaRomeo = rootEntity.findEntity(named: "MusicAudioSource_A_AlfaRomeo_3") {
                    EnhancedAudioSystem.playAudio(on: musicAlfaRomeo, resourceName: "/Root/Billboards_AlfaRomeoP3/EP01_PAN09_Music_Alfa_Romeo_P3_mp3", volume: -5,isAmbientAudio: false)
                }
                
            }
            
            // Setup YAxisBillboards for the Info Baloons
            if let billboard01 = rootEntity.findEntity(named: "A_Billboard_01") {
                if let billboard = billboard01.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard02 = rootEntity.findEntity(named: "A_Billboard_02") {
                if let billboard = billboard02.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard03 = rootEntity.findEntity(named: "A_Billboard_03") {
                if let billboard = billboard03.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard04 = rootEntity.findEntity(named: "A_Billboard_04") {
                if let billboard = billboard04.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard05 = rootEntity.findEntity(named: "A_Billboard_05") {
                if let billboard = billboard05.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
        case.billboard_AlfaRomeo_01:
            if let billboard = rootEntity.findEntity(named: "A_Billboard_01") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_AlfaRomeo_02:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_02") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_AlfaRomeo_03:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_03") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_AlfaRomeo_04:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_04") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_AlfaRomeo_05:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_05") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            //MARK: - Audios Ferrari375
            
        case.audio_Ferrari375_01:
            if let playbackID = experienceBackgroundPlaybackID {
                Task {
                    await EnhancedAudioSystem.fadeOutAndPause(playbackID: playbackID, duration: 2.0)
                }
            }
            
            if let voiceFerrari = rootEntity.findEntity(named: "VoiceAudioSource_A_Ferrari") {
                EnhancedAudioSystem.playAudio(on: voiceFerrari, resourceName: "/Root/Billboards_Ferrari375/EP01_PAN08_Voice_Ferrari_375__mp3")
            }
            if !isFullScaleCarsActive {
                if let musicFerrari = rootEntity.findEntity(named: "MusicAudioSource_Ferrari_1") {
                    EnhancedAudioSystem.playAudio(on: musicFerrari, resourceName: "/Root/Billboards_Ferrari375/EP01_PAN08_Music_Ferrari_375__mp3" ,volume: -5, isAmbientAudio: false)
                }
            } else {
                if let musicFerrari = rootEntity.findEntity(named: "MusicAudioSource_Ferrari_2") {
                    EnhancedAudioSystem.playAudio(on: musicFerrari, resourceName: "/Root/Billboards_Ferrari375/EP01_PAN08_Music_Ferrari_375__mp3" ,volume: -5, isAmbientAudio: false)
                }
                if let musicFerrari = rootEntity.findEntity(named: "MusicAudioSource_Ferrari_3") {
                    EnhancedAudioSystem.playAudio(on: musicFerrari, resourceName: "/Root/Billboards_Ferrari375/EP01_PAN08_Music_Ferrari_375__mp3" ,volume: -5, isAmbientAudio: false)
                }
                
                
            }
            
            // Setup YAxisBillboards for the Info Baloons
            if let billboard01 = rootEntity.findEntity(named: "A_Billboard_01") {
                if let billboard = billboard01.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard02 = rootEntity.findEntity(named: "A_Billboard_02") {
                if let billboard = billboard02.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard03 = rootEntity.findEntity(named: "A_Billboard_03") {
                if let billboard = billboard03.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard04 = rootEntity.findEntity(named: "A_Billboard_04") {
                if let billboard = billboard04.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard05 = rootEntity.findEntity(named: "A_Billboard_05") {
                if let billboard = billboard05.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            
            
        case.billboard_Ferrari375_02:
            if let billboard = rootEntity.findEntity(named: "A_Billboard_02") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_Ferrari375_03:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_03") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_Ferrari375_04:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_04") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_Ferrari375_05:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_05") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_Ferrari375_01:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_01") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            
            
            // MARK: MONZA Cases
            
        case.audio_MonzaDiorama_01:
            if let playbackID = experienceBackgroundPlaybackID {
                Task {
                    await EnhancedAudioSystem.fadeOutAndPause(playbackID: playbackID, duration: 2.0)
                }
            }
            
            if let musicAudioSource_A_Monza_Diorama = rootEntity.findEntity(named: "MusicAudioSource_A_Monza_Diorama") {
                EnhancedAudioSystem.playAudio(on: musicAudioSource_A_Monza_Diorama, resourceName: "/Root/Billboards_MonzaDiorama/EP01_PAN10_Music_Monza_Diorama_wav", isAmbientAudio: false)
            }
            
            if let voiceAudioSource_A_Monza_Diorama = rootEntity.findEntity(named: "VoiceAudioSource_A_Monza_Diorama") {
                EnhancedAudioSystem.playAudio(on: voiceAudioSource_A_Monza_Diorama, resourceName: "/Root/Billboards_MonzaDiorama/EP01_PAN10_Voice_Monza_Diorama_wav")
            }
            
            // Setup YAxisBillboards for the Info Baloons
            if let billboardB2A = rootEntity.findEntity(named: "A_Billboard_B2A") {
                if let billboard = billboardB2A.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboardB2B = rootEntity.findEntity(named: "A_Billboard_B2B") {
                if let billboard = billboardB2B.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            
        case.billboard_MonzaDiorama_B0:
            
            if let billboard = rootEntity.findEntity(named: "AutodromoDiMonzaIlTempioDellaVelocita") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 1, duration: 2, completion: {
                })
            }
            
        case.hideMainCircuit:
            
            if let mainCircuit = rootEntity.findEntity(named: "MainCircuit") {
                graduallyChangeOpacity(entity: mainCircuit, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: mainCircuit, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.removeBillboard_MonzaDiorama_B0:
            
            if let billboard = rootEntity.findEntity(named: "AutodromoDiMonzaIlTempioDellaVelocita") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 0, duration: 2, completion: {
                })
            }
            
        case.locator_1922:
            
            if let locator = rootEntity.findEntity(named: "A_LocatorGroup_1922") {
                graduallyChangeOpacity(entity: locator, targetOpacity: 1, duration: 1, completion: {
                })
                EnhancedAudioSystem.playAudio(on: locator, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_MonzaDiorama_B1:
            
            if let billboard = rootEntity.findEntity(named: "IlCircuitoOriginario") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 1, duration: 2, completion: {
                })
            }
            
        case.billboard_MonzaDiorama_B2A:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_B2A") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case .highlight_Circuit:
            
            if let circuit = rootEntity.findEntity(named: "M_MonzaCircuit_Shapekeys") {
                handlePopValueChange(entity: circuit, targetValue: 1.0, duration: 1.0, keyMaterialName: "HighlightEffect", completion: {
                    handlePopValueChange(entity: circuit, targetValue: 0.0, duration: 1.0, keyMaterialName: "HighlightEffect", completion: {
                    })
                })
            }
            
            
            
        case.billboard_MonzaDiorama_B2B:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_B2B") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case .highlight_Oval:
            
            if let circuit = rootEntity.findEntity(named: "BankedOval") {
                handlePopValueChange(entity: circuit, targetValue: 1.0, duration: 1.0, keyMaterialName: "HighlightEffect", completion: {
                    handlePopValueChange(entity: circuit, targetValue: 0.0, duration: 1.0, keyMaterialName: "HighlightEffect", completion: {
                    })
                })
            }
            
        case.removeBillboard_MonzaDiorama_B12:
            
            if let billboard = rootEntity.findEntity(named: "IlCircuitoOriginario") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_B2A") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_B2B") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 0, duration: 2, completion: {
                })
            }
            
        case.removeLocator_MonzaDiorama_1922:
            
            if let locator = rootEntity.findEntity(named: "A_LocatorGroup_1922") {
                graduallyChangeOpacity(entity: locator, targetOpacity: 0, duration: 1, completion: {
                })
                EnhancedAudioSystem.playAudio(on: locator, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_MonzaDiorama_B3:
            
            if let billboard = rootEntity.findEntity(named: "LaConfigurazioneIbrida") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 1, duration: 2, completion: {
                })
            }
            
        case.locator_Florio:
            
            if let locator = rootEntity.findEntity(named: "A_LocatorGroup_Florio") {
                graduallyChangeOpacity(entity: locator, targetOpacity: 1, duration: 1, completion: {
                })
                EnhancedAudioSystem.playAudio(on: locator, resourceName: "/Root/PanelAppearing_wav")
            }
            
            
        case.removeBillboard_MonzaDiorama_B3:
            
            if let billboard = rootEntity.findEntity(named: "LaConfigurazioneIbrida") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 0, duration: 2, completion: {
                })
            }
            
        case.removeLocator_MonzaDiorama_Florio:
            
            if let billboard = rootEntity.findEntity(named: "A_LocatorGroup_Florio") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_MonzaDiorama_B4:
            
            if let billboard = rootEntity.findEntity(named: "TracciatoVedano") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 1, duration: 2, completion: {
                })
            }
            
        case.removeBillboard_MonzaDiorama_B4:
            
            if let billboard = rootEntity.findEntity(named: "TracciatoVedano") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 0, duration: 2, completion: {
                })
            }
            
        case.billboard_MonzaDiorama_B5:
            
            if let billboard = rootEntity.findEntity(named: "IlRitornoDellaVelocita") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 1, duration: 2, completion: {
                })
            }
            
        case.removeBillboard_MonzaDiorama_B5:
            
            if let billboard = rootEntity.findEntity(named: "IlRitornoDellaVelocita") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 0, duration: 2, completion: {
                })
            }
            
        case.locator_Parabolica:
            
            if let locator = rootEntity.findEntity(named: "A_Locator_Parabolica") {
                graduallyChangeOpacity(entity: locator, targetOpacity: 1, duration: 1, completion: {
                })
                EnhancedAudioSystem.playAudio(on: locator, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.removeLocator_MonzaDiorama_Parabolica:
            
            if let locator = rootEntity.findEntity(named: "A_Locator_Parabolica") {
                graduallyChangeOpacity(entity: locator, targetOpacity: 0, duration: 1, completion: {
                })
                EnhancedAudioSystem.playAudio(on: locator, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_MonzaDiorama_B6:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_B6") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 1, duration: 2, completion: {
                })
            }
            
        case.removeBillboard_MonzaDiorama_B6:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_B6") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 0, duration: 2, completion: {
                })
            }
            
        case.locator_Chicane:
            
            if let locator = rootEntity.findEntity(named: "A_Locator_Chicane") {
                graduallyChangeOpacity(entity: locator, targetOpacity: 1, duration: 1, completion: {
                })
                EnhancedAudioSystem.playAudio(on: locator, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.removeLocator_MonzaDiorama_Chicane:
            
            if let locator = rootEntity.findEntity(named: "A_Locator_Chicane") {
                graduallyChangeOpacity(entity: locator, targetOpacity: 0, duration: 1, completion: {
                })
                EnhancedAudioSystem.playAudio(on: locator, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_MonzaDiorama_B7:
            
            if let billboard = rootEntity.findEntity(named: "AsettoModerno") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 1, duration: 2, completion: {
                })
            }
            
        case.removeBillboard_MonzaDiorama_B7:
            
            if let billboard = rootEntity.findEntity(named: "AsettoModerno") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 0, duration: 2, completion: {
                })
            }
            
        case.locator_Rettifilo:
            
            if let locator = rootEntity.findEntity(named: "A_Locator_Rettifilo") {
                graduallyChangeOpacity(entity: locator, targetOpacity: 1, duration: 1, completion: {
                })
                EnhancedAudioSystem.playAudio(on: locator, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.locator_Roggia:
            
            if let locator = rootEntity.findEntity(named: "A_Locator_Roggia") {
                graduallyChangeOpacity(entity: locator, targetOpacity: 1, duration: 1, completion: {
                })
                EnhancedAudioSystem.playAudio(on: locator, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.locator_Ascari:
            
            if let locator = rootEntity.findEntity(named: "A_Locator_Ascari") {
                graduallyChangeOpacity(entity: locator, targetOpacity: 1, duration: 1, completion: {
                })
                EnhancedAudioSystem.playAudio(on: locator, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.removeLocator_MonzaDiorama_N56:
            
            if let locator1 = rootEntity.findEntity(named: "A_Locator_Rettifilo") {
                graduallyChangeOpacity(entity: locator1, targetOpacity: 0, duration: 1, completion: {
                })
                EnhancedAudioSystem.playAudio(on: locator1, resourceName: "/Root/PanelAppearing_wav")
            }
            if let locator2 = rootEntity.findEntity(named: "A_Locator_Roggia") {
                graduallyChangeOpacity(entity: locator2, targetOpacity: 0, duration: 1, completion: {
                })
                EnhancedAudioSystem.playAudio(on: locator2, resourceName: "/Root/PanelAppearing_wav")
            }
            if let locator3 = rootEntity.findEntity(named: "A_Locator_Ascari") {
                graduallyChangeOpacity(entity: locator3, targetOpacity: 0, duration: 1, completion: {
                })
                EnhancedAudioSystem.playAudio(on: locator3, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_MonzaDiorama_B8:
            
            if let billboard = rootEntity.findEntity(named: "AffinamentoDellaSicurezza") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 1, duration: 2, completion: {
                })
            }
            
        case.removeBillboard_MonzaDiorama_B8:
            
            if let billboard = rootEntity.findEntity(named: "AffinamentoDellaSicurezza") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 0, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 0, duration: 2, completion: {
                })
            }
            
        case.locator_CurveModified:
            
            if let locator = rootEntity.findEntity(named: "A_LocatorGroup_CurveModified") {
                graduallyChangeOpacity(entity: locator, targetOpacity: 1, duration: 1, completion: {
                })
                EnhancedAudioSystem.playAudio(on: locator, resourceName: "/Root/PanelAppearing_wav")
            }
            
            
            
            
        case.billboard_MonzaDiorama_B9:
            
            if let billboard = rootEntity.findEntity(named: "IlCircuitoAttuale") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            if let frame = rootEntity.findEntity(named: "TitleFrame") {
                graduallyChangeOpacity(entity: frame, targetOpacity: 1, duration: 2, completion: {
                })
            }
            
        case.locators_Current:
            
            if let locator = rootEntity.findEntity(named: "A_LocatorGroup_Current") {
                graduallyChangeOpacity(entity: locator, targetOpacity: 1, duration: 1, completion: {
                })
                EnhancedAudioSystem.playAudio(on: locator, resourceName: "/Root/PanelAppearing_wav")
            }
            
            
            
        case.spawnShapeKeyMonza:
            if let animatedCircuitHolder = rootEntity.findEntity(named: "AnimatedCircuit_Holder") {
                if let monzaCircuit = try? await Entity(named: "Assets/A_MonzaCircuit_Shapekeys", in: realityKitContentBundle) {
                    monzaCircuit.name = "A_MonzaCircuit_Shapekeys"
                    animatedCircuitHolder.addChild(monzaCircuit)
                    graduallyChangeOpacity(entity: animatedCircuitHolder, targetOpacity: 1, duration: 2.0)
                }
            }
            
        case.reduceOpacityMonza:
            if let monzaRoot = rootEntity.findEntity(named: "M_Monza_Diorama") {
                graduallyChangeOpacity(entity: monzaRoot, targetOpacity: 0.75, duration: 2.0)
                
            }
            
            
            
        case.reduceOpacityBankedOval:
            if let bankedOvalRoot = rootEntity.findEntity(named: "BankedOval") {
                graduallyChangeOpacity(entity: bankedOvalRoot, targetOpacity: 0.5, duration: 2.0) {
                }
                
            }
            
        case.hideOpacityBankedOval:
            if let bankedOvalRoot = rootEntity.findEntity(named: "BankedOval") {
                graduallyChangeOpacity(entity: bankedOvalRoot, targetOpacity: 0.0, duration: 2.0) {
                }
                
            }
            
        case.increaseOpacityBankedOval:
            if let bankedOvalRoot = rootEntity.findEntity(named: "BankedOval") {
                graduallyChangeOpacity(entity: bankedOvalRoot, targetOpacity: 1, duration: 2.0)
            }
            
            
            
        case.animateTo95_99:
            
            if let monzaDiorama = rootEntity.findEntity(named: "M_MonzaCircuit_Shapekeys") {
                monzaDiorama.enumerateHierarchy { entity, stop in
                    setupBlendShapeWeightsComponent(for: entity)
                    
                    animateBlendShapeWeights(
                        entity: entity,
                        blendWeightsIndex: 0,
                        targetWeights: [1, 0, 0, 0, 0, 0, 0],
                        duration: 2  // Very short duration
                    ){
                        
                    }
                }
            }
            
        case.animateTo76_94:
            
            if let monzaDiorama = rootEntity.findEntity(named: "M_MonzaCircuit_Shapekeys") {
                monzaDiorama.enumerateHierarchy { entity, stop in
                    animateBlendShapeWeights(
                        entity: entity,
                        blendWeightsIndex: 0,
                        targetWeights: [0, 1, 0, 0, 0, 0, 0],
                        duration: 2  // Very short duration
                    ){}
                }
            }
            
        case.animateTo72_75:
            
            if let monzaDiorama = rootEntity.findEntity(named: "M_MonzaCircuit_Shapekeys") {
                monzaDiorama.enumerateHierarchy { entity, stop in
                    animateBlendShapeWeights(
                        entity: entity,
                        blendWeightsIndex: 0,
                        targetWeights: [0, 0, 1, 0, 0, 0, 0],
                        duration: 2  // Very short duration
                    ){}
                }
            }
            
        case.animateTo57_71:
            
            if let monzaDiorama = rootEntity.findEntity(named: "M_MonzaCircuit_Shapekeys") {
                monzaDiorama.enumerateHierarchy { entity, stop in
                    animateBlendShapeWeights(
                        entity: entity,
                        blendWeightsIndex: 0,
                        targetWeights: [0, 0, 0, 1, 0, 0, 0],
                        duration: 2  // Very short duration
                    ){print("ShapeKey animation complete: animateTo57_71")}
                }
            }
            
        case.animateTo37_50:
            
            if let monzaDiorama = rootEntity.findEntity(named: "M_MonzaCircuit_Shapekeys") {
                monzaDiorama.enumerateHierarchy { entity, stop in
                    animateBlendShapeWeights(
                        entity: entity,
                        blendWeightsIndex: 0,
                        targetWeights: [0, 0, 0, 0, 1, 0, 0],
                        duration: 2  // Very short duration
                    ){}
                }
            }
            
        case.animateTo35_37Florio:
            
            if let monzaDiorama = rootEntity.findEntity(named: "M_MonzaCircuit_Shapekeys") {
                monzaDiorama.enumerateHierarchy { entity, stop in
                    animateBlendShapeWeights(
                        entity: entity,
                        blendWeightsIndex: 0,
                        targetWeights: [0, 0, 0, 0, 0, 1, 0],
                        duration: 2  // Very short duration
                    ){}
                }
            }
            
        case.animateTo1922:
            
            if let monzaDiorama = rootEntity.findEntity(named: "M_MonzaCircuit_Shapekeys") {
                monzaDiorama.enumerateHierarchy { entity, stop in
                    animateBlendShapeWeights(
                        entity: entity,
                        blendWeightsIndex: 0,
                        targetWeights: [0, 0, 0, 0, 0, 0, 1],
                        duration: 2  // Very short duration
                    ){}
                }
            }
            
        case.animateToReset:
            
            if let monzaDiorama = rootEntity.findEntity(named: "M_MonzaCircuit_Shapekeys") {
                monzaDiorama.enumerateHierarchy { entity, stop in
                    animateBlendShapeWeights(
                        entity: entity,
                        blendWeightsIndex: 0,
                        targetWeights: [0, 0, 0, 0, 0, 0, 0],
                        duration: 2  // Very short duration
                    ){}
                }
            }
            
            
            
        case.showMonzaDiorama:
            if let monzaRoot = rootEntity.findEntity(named: "M_Monza_Diorama") {
                graduallyChangeOpacity(entity: monzaRoot, targetOpacity: 1.0, duration: 2.0)
                
            }
            
            
            
            
            
            
            //MARK: - Audios Stratos
            
            
            
        case.audio_Stratos_01:
            if let playbackID = experienceBackgroundPlaybackID {
                Task {
                    await EnhancedAudioSystem.fadeOutAndPause(playbackID: playbackID, duration: 2.0)
                }
            }
            
            if let voiceAlfaRomeo = rootEntity.findEntity(named: "VoiceAudioSource_A_LanciaStratos") {
                EnhancedAudioSystem.playAudio(on: voiceAlfaRomeo, resourceName: "/Root/Billboards_Stratos/EP02_PAN08_Voice_Lancia_Stratos_mp3")
            }
            if !isFullScaleCarsActive {
                if let musicAlfaRomeo = rootEntity.findEntity(named: "MusicAudioSource_A_LanciaStratos_1") {
                    EnhancedAudioSystem.playAudio(on: musicAlfaRomeo, resourceName: "/Root/Billboards_Stratos/EP02_PAN08_Music_Lancia_Stratos_mp3", volume: -5,isAmbientAudio: false)
                }
            } else {
                if let musicAlfaRomeo = rootEntity.findEntity(named: "MusicAudioSource_A_LanciaStratos_2") {
                    EnhancedAudioSystem.playAudio(on: musicAlfaRomeo, resourceName: "/Root/Billboards_Stratos/EP02_PAN08_Music_Lancia_Stratos_mp3", volume: -5,isAmbientAudio: false)
                }
                if let musicAlfaRomeo = rootEntity.findEntity(named: "MusicAudioSource_A_LanciaStratos_3") {
                    EnhancedAudioSystem.playAudio(on: musicAlfaRomeo, resourceName: "/Root/Billboards_Stratos/EP02_PAN08_Music_Lancia_Stratos_mp3", volume: -5,isAmbientAudio: false)
                }
                
            }
            // Setup YAxisBillboards for the Info Baloons
            if let billboard01 = rootEntity.findEntity(named: "A_Billboard_01") {
                if let billboard = billboard01.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard02 = rootEntity.findEntity(named: "A_Billboard_02") {
                if let billboard = billboard02.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard03 = rootEntity.findEntity(named: "A_Billboard_03") {
                if let billboard = billboard03.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard04 = rootEntity.findEntity(named: "A_Billboard_04") {
                if let billboard = billboard04.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard05 = rootEntity.findEntity(named: "A_Billboard_05") {
                if let billboard = billboard05.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard06 = rootEntity.findEntity(named: "A_Billboard_06") {
                if let billboard = billboard06.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            
            
            
        case.billboard_Stratos_01:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_01") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_Stratos_02:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_02") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_Stratos_03:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_03") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_Stratos_04:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_04") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_Stratos_05:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_05") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_Stratos_06:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_06") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            
            //MARK: - Audios Delta Integrale
            
        case.audio_DeltaIntegrale_01:
            if let playbackID = experienceBackgroundPlaybackID {
                Task {
                    await EnhancedAudioSystem.fadeOutAndPause(playbackID: playbackID, duration: 2.0)
                }
            }
            
            if let voiceAlfaRomeo = rootEntity.findEntity(named: "VoiceAudioSource_A_DeltaIntegrale") {
                EnhancedAudioSystem.playAudio(on: voiceAlfaRomeo, resourceName: "/Root/Billboards_DeltaIntegrale/EP02_PAN09_Voice_Lancia_Delta_mp3")
            }
            
            if !isFullScaleCarsActive {
                if let musicAlfaRomeo = rootEntity.findEntity(named: "MusicAudioSource_A_DeltaIntegrale_1") {
                    EnhancedAudioSystem.playAudio(on: musicAlfaRomeo, resourceName: "/Root/Billboards_DeltaIntegrale/EP02_PAN09_Music_Lancia_Delta_mp3", volume: 5,isAmbientAudio: false)
                }
            } else {
                if let musicAlfaRomeo = rootEntity.findEntity(named: "MusicAudioSource_A_DeltaIntegrale_2") {
                    EnhancedAudioSystem.playAudio(on: musicAlfaRomeo, resourceName: "/Root/Billboards_DeltaIntegrale/EP02_PAN09_Music_Lancia_Delta_mp3", volume: 5,isAmbientAudio: false)
                }
                if let musicAlfaRomeo = rootEntity.findEntity(named: "MusicAudioSource_A_DeltaIntegrale_3") {
                    EnhancedAudioSystem.playAudio(on: musicAlfaRomeo, resourceName: "/Root/Billboards_DeltaIntegrale/EP02_PAN09_Music_Lancia_Delta_mp3", volume: 5,isAmbientAudio: false)
                }
            }
            
            
            // Setup YAxisBillboards for the Info Baloons
            if let billboard01 = rootEntity.findEntity(named: "A_Billboard_01") {
                if let billboard = billboard01.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard02 = rootEntity.findEntity(named: "A_Billboard_02") {
                if let billboard = billboard02.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard03 = rootEntity.findEntity(named: "A_Billboard_03") {
                if let billboard = billboard03.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard04 = rootEntity.findEntity(named: "A_Billboard_04") {
                if let billboard = billboard04.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard05 = rootEntity.findEntity(named: "A_Billboard_05") {
                if let billboard = billboard05.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            if let billboard06 = rootEntity.findEntity(named: "A_Billboard_06") {
                if let billboard = billboard06.findEntity(named: "Transform_Billboard") {
                    billboard.components.set(YAxisBillboardComponent(isEnabled: true))
                }
            }
            
            
            
            
        case.billboard_DeltaIntegrale_01:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_01") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_DeltaIntegrale_02:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_02") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_DeltaIntegrale_03:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_03") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_DeltaIntegrale_04:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_04") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_DeltaIntegrale_05:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_05") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
        case.billboard_DeltaIntegrale_06:
            
            if let billboard = rootEntity.findEntity(named: "A_Billboard_06") {
                graduallyChangeOpacity(entity: billboard, targetOpacity: 1, duration: 2, completion: {
                })
                EnhancedAudioSystem.playAudio(on: billboard, resourceName: "/Root/PanelAppearing_wav")
            }
            
            
            
            
            
            //MARK: - MODULE D
            
        case .startModule_D:
            experienceTimer.moduleDidStart(.D)
            
            
        case.hideMainScene:
            if let mainSceneRoot = rootEntity.findEntity(named: "GeneralOpacity") {
                graduallyChangeOpacity(entity: mainSceneRoot, targetOpacity: 0, duration: 1, completion: {
                })
            }
            
            
        case .restartExperience:
                
                if let guideSphere = rootEntity.findEntity(named: "GuideSphere") {
                    guideSphere.enumerateHierarchy { entity, stop in
                        setupBlendShapeWeightsComponent(for: entity)
                        animateBlendShapeWeights(entity: entity, blendWeightsIndex: 0, targetWeights: [0], duration: 2) {
                        }
                    }
                    
                    handlePopValueChange(entity: guideSphere, targetValue: 0, duration: 2, keyMaterialName: "Exit", completion: {
                    })
                    
                }
                
                if let sphereAci = rootEntity.findEntity(named: "DebugX") {
                    handlePopValueChange(entity: sphereAci, targetValue: 0, duration: 3, keyMaterialName: "Pop", completion: {
                        sphereAci.removeFromParent()
                    })
                }
                
                Task {
                    
                    if let driverTouchStart = rootEntity.findEntity(named: "driverTouchStart") {
                        animateEntity(entity: driverTouchStart, index: 3, speed: 1)
                    }
                    
                    try? await Task.sleep(for: .seconds(3))
                    
                    if let guideSphere = rootEntity.findEntity(named: "GuideSphere"), let guideGear = rootEntity.findEntity(named: "GuideGearModel") {
                        var AudioFarewellForEpoch: String = ""
                        
                        if endStartedFromExperienceTimer {
                            AudioFarewellForEpoch = "Forced_Farewell"
                        } else {
                            switch appModel.selectedEpoch {
                            case .laCorsaComeSfida:
                                AudioFarewellForEpoch = "EP01_Farewell"
                            case .tecnicaPassioneGenio:
                                AudioFarewellForEpoch = "EP02_Farewell"
                            case .laFormazionePiloti:
                                AudioFarewellForEpoch = "EP03_Farewell"
                            default:
                                break
                            }
                        }
                        
                        await audioAnimator.animateToAudio(
                            entities: [guideGear, guideSphere],
                            audioResourceName: AudioFarewellForEpoch,
                            keyMaterialName: "Animation",
                            baseValue: 0.0,
                            intensity: 2.0,
                            range: 1,
                            smoothing: 0.85
                        ) {
                            Task {
                                //    await restartImmersiveView()
                                finalTransitionLogo()
                            }
                        }
                    }
                    
                }
            
            
        case .voiceOverEnded_A_AlfaRomeo:
            if let billboardsOpacity = rootEntity.findEntity(named: "BillboardsOpacity") {
                graduallyChangeOpacity(entity: billboardsOpacity, targetOpacity: 0, duration: 2)
            }
            activateEngine(carAssetName: "A_AlfaRomeo")
            
        case .voiceOverEnded_A_AlfaRomeo_FullSize:
            if let billboardsOpacity = rootEntity.findEntity(named: "BillboardsOpacity") {
                graduallyChangeOpacity(entity: billboardsOpacity, targetOpacity: 0, duration: 2)
            }
            activateEngine(carAssetName: "A_AlfaRomeo")
            
            
            
        case .voiceOverEnded_A_Ferrari:
            if let billboardsOpacity = rootEntity.findEntity(named: "BillboardsOpacity") {
                graduallyChangeOpacity(entity: billboardsOpacity, targetOpacity: 0, duration: 2)
            }
            activateEngine(carAssetName: "A_Ferrari")
            
        case .voiceOverEnded_A_Ferrari_FullSize:
            if let billboardsOpacity = rootEntity.findEntity(named: "BillboardsOpacity") {
                graduallyChangeOpacity(entity: billboardsOpacity, targetOpacity: 0, duration: 2)
            }
            activateEngine(carAssetName: "A_Ferrari")
            
            
            
        case .voiceOverEnded_A_Tatuus:
            if let billboardsOpacity = rootEntity.findEntity(named: "BillboardOpacity") {
                graduallyChangeOpacity(entity: billboardsOpacity, targetOpacity: 0, duration: 2)
            }
            activateEngine(carAssetName: "A_Tatuus")
            
        case .voiceOverEnded_A_Tatuus_FullSize:
            if let billboardsOpacity = rootEntity.findEntity(named: "BillboardOpacity") {
                graduallyChangeOpacity(entity: billboardsOpacity, targetOpacity: 0, duration: 2)
            }
            activateEngine(carAssetName: "A_Tatuus")
            
            
            
        case .voiceOverEnded_A_LanciaStratos:
            if let billboardsOpacity = rootEntity.findEntity(named: "BillboardsOpacity") {
                graduallyChangeOpacity(entity: billboardsOpacity, targetOpacity: 0, duration: 2)
            }
            activateEngine(carAssetName: "A_LanciaStratos")
            
        case .voiceOverEnded_A_LanciaStratos_FullSize:
            if let billboardsOpacity = rootEntity.findEntity(named: "BillboardsOpacity") {
                graduallyChangeOpacity(entity: billboardsOpacity, targetOpacity: 0, duration: 2)
            }
            activateEngine(carAssetName: "A_LanciaStratos")
            rootEntity.enumerateHierarchy { entity, stop in
                if entity.name.contains("A_Billboard") {
                    graduallyChangeOpacity(entity: entity, targetOpacity: 0, duration: 2)
                }
            }
            
        case .voiceOverEnded_A_DeltaIntegrale:
            if let billboardsOpacity = rootEntity.findEntity(named: "BillboardsOpacity") {
                graduallyChangeOpacity(entity: billboardsOpacity, targetOpacity: 0, duration: 2)
            }
            activateEngine(carAssetName: "A_DeltaIntegrale")
            rootEntity.enumerateHierarchy { entity, stop in
                if entity.name.contains("A_Billboard") {
                    graduallyChangeOpacity(entity: entity, targetOpacity: 0, duration: 2)
                }
            }
            
        case .voiceOverEnded_A_DeltaIntegrale_FullSize:
            if let billboardsOpacity = rootEntity.findEntity(named: "BillboardsOpacity") {
                graduallyChangeOpacity(entity: billboardsOpacity, targetOpacity: 0, duration: 2)
            }
            activateEngine(carAssetName: "A_DeltaIntegrale")
            rootEntity.enumerateHierarchy { entity, stop in
                if entity.name.contains("A_Billboard") {
                    graduallyChangeOpacity(entity: entity, targetOpacity: 0, duration: 2)
                }
            }
            
        case .remove_Tatuus_phy:
            if let tatuusPBR = rootEntity.findEntity(named: "TatusPBR") {
                tatuusPBR.removeFromParent()
            }
            
        default:
            return
        }
    }
    
    func finalTransitionLogo() {
        if let guide = rootEntity.findEntity(named: "Guide") {
            
            Task {
                if let guideSphere = guide.findEntity(named: "GuideSphere") {
                    graduallyChangeOpacity(entity: guideSphere, targetOpacity: 0, duration: 1)
                }
                
                
                if let circleAci = guide.findEntity(named: "circleAci") {
                    
                    handlePopValueChange(entity: circleAci, targetValue: 0, duration: 2.5, keyMaterialName: "Animation", completion: {
                        graduallyChangeOpacity(entity: circleAci, targetOpacity: 1, duration: 1)
                    })
                }
                if let textAci = guide.findEntity(named: "textAci") {
                    graduallyChangeOpacity(entity: textAci, targetOpacity: 1, duration: 1)
                    handlePopValueChange(entity: textAci, targetValue: 0, duration: 2.5, keyMaterialName: "Animation", completion: {
                    })
                }
                
                if let ringAci = guide.findEntity(named: "ringAci") {
                    graduallyChangeOpacity(entity: ringAci, targetOpacity: 1, duration: 2.5)
                }
                
                if let guideGear = guide.findEntity(named: "GuideGearModel") {
                    handlePopValueChange(entity: guideGear, targetValue: 0, duration: 2, keyMaterialName: "Floating", completion: {
                        
                    })
                }
                
                try? await Task.sleep(for: .seconds(2.0))
                EnhancedAudioSystem.playAudio(on: guide, resourceName: "/Root/GuideToWireframe_wav")
                
                if let circleAci = guide.findEntity(named: "circleAci") {
                    circleAci.enumerateHierarchy { entity, stop in
                        setupBlendShapeWeightsComponent(for: entity)
                        animateBlendShapeWeights(entity: entity, blendWeightsIndex: 0, targetWeights: [0], duration: 1) {
                            
                        }
                    }
                }
                
                if let a_LogoAci = guide.findEntity(named: "A_LogoAci") {
                    graduallyChangeOpacity(entity: a_LogoAci, targetOpacity: 1, duration: 1)
                }
                
                
                if let guideGear = guide.findEntity(named: "GuideGearModel") {
                    handlePopValueChange(entity: guideGear, targetValue: 0, duration: 1.0, keyMaterialName: "Ring", completion: {
                        if let guideSphere = guide.findEntity(named: "GuideSphere") {
                            graduallyChangeOpacity(entity: guideSphere, targetOpacity: 0, duration: 1)
                        }
                        
                        handlePopValueChange(entity: guideGear, targetValue: 0, duration: 0.3, keyMaterialName: "Floating", completion: {
                            
                        })
                        if let guideSphere = guide.findEntity(named: "GuideSphere") {
                            handlePopValueChange(entity: guideSphere, targetValue: 0, duration: 1.0, keyMaterialName: "Floating", completion: {
                                Task {
                                    try? await Task.sleep(for: .seconds(3))
                                    graduallyChangeOpacity(entity: guide, targetOpacity: 0, duration: 3) {
                                        Task {
                                            await restartImmersiveView()
                                        }
                                    }
                                }
                            })
                        }
                    })
                }
            }
        }
    }
    
    
    func activateEngine(carAssetName: String) {
        handTrackingViewModel.resume()
        if !isFullScaleCarsActive {
            stopCarHolderSpin(easeOutDuration: 2.0, returnToHome: true) {
            }
        }
        
        if let soundAsset = rootEntity.findEntity(named: "A_SoundIcon_\(carAssetName)") {
            graduallyChangeOpacity(entity: soundAsset, targetOpacity: 1, duration: 5)
            EnhancedAudioSystem.playAudio(on: soundAsset, resourceName: "/Root/ActivationPanel_wav")
            
            if let engine = rootEntity.findEntity(named: "Engine_\(carAssetName)") {
                engine.isEnabled = true
                
                // Particles
                if let particles = engine.findEntity(named: "Particle") {
                    var particleComponent = particles.components[ParticleEmitterComponent.self]
                    particles.components.remove(ParticleEmitterComponent.self)
                    particleComponent?.isEmitting = true
                    particles.components.set(particleComponent!)
                }
                
                
                // Subscribe to collision dynamically
                if let content = self.content {
                    _ = content.subscribe(to: CollisionEvents.Began.self, on: engine) { collisionEvent in
                        let (entityA, entityB) = (collisionEvent.entityA.name, collisionEvent.entityB.name)
                        
                        let engineName = "Engine_\(carAssetName)"
                        if entityA == "hand" || entityB == "hand" {
                            if !canInteractWithSphere(identifier: engineName) { return }
                            setSphereOnCooldown(identifier: engineName)
                            handleEngineTouched(carAssetName: carAssetName, engine: engine, soundAsset: soundAsset)
                        }
                    }
                }
            }
        }
    }
    
    func handleEngineTouched(carAssetName: String, engine: Entity, soundAsset: Entity) {
        if isFullScaleCarsActive {
            
            graduallyChangeOpacity(entity: soundAsset, targetOpacity: 0, duration: 3)
            
            if let particles = engine.findEntity(named: "Particle") {
                var particleComponent = particles.components[ParticleEmitterComponent.self]
                particles.components.remove(ParticleEmitterComponent.self)
                particleComponent?.isEmitting = false
                particles.components.set(particleComponent!)
            }
            
            EnhancedAudioSystem.playAudio(on: engine, resourceName: "/Root/EngineSounds/EngineSound_\(carAssetName)_wav",volume: 50, waitForCompletion: true) {
                
                
                // Quick check: is the user already seated in the safe zone?
                Task { @MainActor in
                    let alreadySeated = await safeZoneManager.quickCheck(duration: 2.0)
                    
                    if alreadySeated {
                        sendNotificationtToRCP(notificationName: "End_\(carAssetName)")
                    } else {
                        if let voiceAudioSource = rootEntity.findEntity(named: "VoiceAudioSource_\(carAssetName)") {
                            EnhancedAudioSystem.playAudio(on: voiceAudioSource, resourceName: "/Root/Sit_Down_Request_mp3")
                        }
                        safeZoneManager.requestReturn {
                            sendNotificationtToRCP(notificationName: "End_\(carAssetName)")
                        }
                    }
                }
            }
            
        } else {
            // Reduced-scale path — unchanged
            graduallyChangeOpacity(entity: soundAsset, targetOpacity: 0, duration: 3)
            
            if let particles = engine.findEntity(named: "Particle") {
                var particleComponent = particles.components[ParticleEmitterComponent.self]
                particles.components.remove(ParticleEmitterComponent.self)
                particleComponent?.isEmitting = false
                particles.components.set(particleComponent!)
            }
            EnhancedAudioSystem.playAudio(on: engine, resourceName: "/Root/EngineSounds/EngineSound_\(carAssetName)_wav",volume: 20.0, waitForCompletion: true) {
                sendNotificationtToRCP(notificationName: "End_\(carAssetName)")
            }
        }
    }
}
//MARK: Notifications

private extension String {
    
    static let start_Preparation = "Start_Preparation"
    static let spawnAndShowImages = "SpawnAndLoadImages"
    static let removeStartSphere = "RemoveStartSphere"
    static let startGuideMovement = "StartGuideMovement"
    static let showGuideGear = "ShowGuideGear"
    
    
    static let startModule_A = "StartModule_A"
    static let startModule_B = "StartModule_B"
    static let startModule_C = "StartModule_C"
    static let startModule_D = "StartModule_D"
    
    static let endModule_B = "EndModule_B"
    static let endModule_C = "EndModule_C"
    
    static let audio_PopSphere = "audio_PopSphere"
    static let opacityGuideIn = "opacityGuideIn"
    static let opacityTouchStartIn = "opacityTouchStartIn"
    static let opacityTouchStartOut = "opacityTouchStartOut"
    static let opacityGearIn = "opacityGearIn"
    
    static let opacityPanelsIn = "opacityPanelsIn"
    
    static let spinTatuus = "spinTatuus"
    
    static let show_DeltaIntegrale = "Show_DeltaIntegrale"
    static let switch_DeltaIntegrale_phy = "SwitchDeltaIntegralePhy"
    static let remove_DeltaIntegrale_phy = "RemoveDeltaIntegralePhy"
    static let switch_DeltaIntegrale_tra = "SwitchDeltaIntegraleTra"
    static let hide_DeltaIntegrale = "Hide_DeltaIntegrale"
    
    static let show_Tatuus = "show_Tatuus"
    static let switch_Tatuus_phy = "SwitchTatuusPhy"
    static let remove_Tatuus_phy = "RemoveTatuusPhy"
    static let switch_Tatuus_tra = "SwitchTatuusTra"
    static let hide_Tatuus = "hide_Tatuus"
    
    static let show_AlfaRomeo = "Show_AlfaRomeo"
    static let switch_AlfaRomeo_phy = "SwitchAlfaRomeoPhy"
    static let remove_AlfaRomeo_phy = "RemoveAlfaRomeoPhy"
    static let switch_AlfaRomeo_tra = "SwitchAlfaRomeoTra"
    static let hide_AlfaRomeo = "Hide_AlfaRomeo"
    
    static let show_Ferrari375 = "Show_Ferrari375"
    static let switch_Ferrari375_phy = "SwitchFerrari375Phy"
    static let remove_Ferrari375_phy = "RemoveFerrari375Phy"
    static let switch_Ferrari375_tra = "SwitchFerrari375Tra"
    static let hide_Ferrari375 = "Hide_Ferrari375"
    
    static let show_LanciaStratos = "Show_LanciaStratos"
    static let switch_LanciaStratos_phy = "SwitchLanciaStratosPhy"
    static let remove_LanciaStratos_phy = "RemoveLanciaStratos"
    static let switch_LanciaStratos_tra = "SwitchLanciaStratosTra"
    static let hide_LanciaStratos = "Hide_LanciaStratos"
    
    static let audio_Tatuus_01 = "audio_Tatuus_01"
    
    static let billboard_Tatuus_01 = "billboard_Tatuus_01"
    static let billboard_Tatuus_02 = "billboard_Tatuus_02"
    static let billboard_Tatuus_03 = "billboard_Tatuus_03"
    static let billboard_Tatuus_04 = "billboard_Tatuus_04"
    static let billboard_Tatuus_05 = "billboard_Tatuus_05"
    
    
    static let audio_Diorama_01 = "audio_Diorama_01"
    
    static let billboard_Diorama_01 = "billboard_Diorama_01"
    static let billboard_Diorama_02 = "billboard_Diorama_02"
    static let billboard_Diorama_03 = "billboard_Diorama_03"
    static let billboard_Diorama_04 = "billboard_Diorama_04"
    static let billboard_Diorama_05 = "billboard_Diorama_05"
    static let billboard_Diorama_06 = "billboard_Diorama_06"
    
    static let title_VallelungaDiorama_0 = "title_VallelungaDiorama_0"
    static let title_VallelungaDiorama_1 = "title_VallelungaDiorama_1"
    static let title_VallelungaDiorama_2 = "title_VallelungaDiorama_2"
    static let title_VallelungaDiorama_3 = "title_VallelungaDiorama_3"
    static let title_VallelungaDiorama_4 = "title_VallelungaDiorama_4"
    static let title_VallelungaDiorama_5 = "title_VallelungaDiorama_5"
    static let title_VallelungaDiorama_6 = "title_VallelungaDiorama_6"
    static let removeTitle_VallelungaDiorama_0 = "removeTitle_VallelungaDiorama_0"
    static let removeTitle_VallelungaDiorama_1 = "removeTitle_VallelungaDiorama_1"
    static let removeTitle_VallelungaDiorama_2 = "removeTitle_VallelungaDiorama_2"
    static let removeTitle_VallelungaDiorama_3 = "removeTitle_VallelungaDiorama_3"
    static let removeTitle_VallelungaDiorama_4 = "removeTitle_VallelungaDiorama_4"
    static let removeTitle_VallelungaDiorama_5 = "removeTitle_VallelungaDiorama_5"
    static let removeTitle_VallelungaDiorama_6 = "removeTitle_VallelungaDiorama_6"
    
    static let audio_AlfaRomeo_01 = "audio_AlfaRomeo_01"
    static let audio_AlfaRomeo_02 = "audio_AlfaRomeo_02"
    static let audio_AlfaRomeo_03 = "audio_AlfaRomeo_03"
    static let audio_AlfaRomeo_04 = "audio_AlfaRomeo_04"
    
    static let billboard_AlfaRomeo_01 = "billboard_AlfaRomeo_01"
    static let billboard_AlfaRomeo_02 = "billboard_AlfaRomeo_02"
    static let billboard_AlfaRomeo_03 = "billboard_AlfaRomeo_03"
    static let billboard_AlfaRomeo_04 = "billboard_AlfaRomeo_04"
    static let billboard_AlfaRomeo_05 = "billboard_AlfaRomeo_05"
    
    static let audio_Ferrari375_01 = "audio_Ferrari375_01"
    
    static let billboard_Ferrari375_01 = "billboard_Ferrari375_01"
    static let billboard_Ferrari375_02 = "billboard_Ferrari375_02"
    static let billboard_Ferrari375_03 = "billboard_Ferrari375_03"
    static let billboard_Ferrari375_04 = "billboard_Ferrari375_04"
    static let billboard_Ferrari375_05 = "billboard_Ferrari375_05"
    
    static let audio_MonzaDiorama_01 = "audio_MonzaDiorama_01"
    
    static let billboard_MonzaDiorama_B0 = "billboard_MonzaDiorama_B0"
    static let hideMainCircuit = "hideMainCircuit"
    static let removeBillboard_MonzaDiorama_B0 = "removeBillboard_MonzaDiorama_B0"
    static let locator_1922 = "locator_1922"
    static let removeLocator_MonzaDiorama_1922 = "removeLocator_MonzaDiorama_1922"
    static let billboard_MonzaDiorama_B1 = "billboard_MonzaDiorama_B1"
    static let billboard_MonzaDiorama_B2A = "billboard_MonzaDiorama_B2A"
    static let highlight_Circuit = "highlight_Circuit"
    static let billboard_MonzaDiorama_B2B = "billboard_MonzaDiorama_B2B"
    static let highlight_Oval = "highlight_Oval"
    static let removeBillboard_MonzaDiorama_B12 = "removeBillboard_MonzaDiorama_B12"
    static let billboard_MonzaDiorama_B3 = "billboard_MonzaDiorama_B3"
    static let locator_Florio = "locator_Florio"
    static let removeBillboard_MonzaDiorama_B3 = "removeBillboard_MonzaDiorama_B3"
    static let removeLocator_MonzaDiorama_Florio = "removeLocator_MonzaDiorama_Florio"
    static let billboard_MonzaDiorama_B4 = "billboard_MonzaDiorama_B4"
    static let removeBillboard_MonzaDiorama_B4 = "removeBillboard_MonzaDiorama_B4"
    static let billboard_MonzaDiorama_B5 = "billboard_MonzaDiorama_B5"
    static let removeBillboard_MonzaDiorama_B5 = "removeBillboard_MonzaDiorama_B5"
    static let locator_Parabolica = "locator_Parabolica"
    static let removeLocator_MonzaDiorama_Parabolica = "removeLocator_MonzaDiorama_Parabolica"
    static let billboard_MonzaDiorama_B6 = "billboard_MonzaDiorama_B6"
    static let removeBillboard_MonzaDiorama_B6 = "removeBillboard_MonzaDiorama_B6"
    static let locator_Chicane = "locator_Chicane"
    static let removeLocator_MonzaDiorama_Chicane = "removeLocator_MonzaDiorama_Chicane"
    static let billboard_MonzaDiorama_B7 = "billboard_MonzaDiorama_B7"
    static let removeBillboard_MonzaDiorama_B7 = "removeBillboard_MonzaDiorama_B7"
    static let locator_Rettifilo = "locator_Rettifilo"
    static let locator_Roggia = "locator_Roggia"
    static let locator_Ascari = "locator_Ascari"
    static let removeLocator_MonzaDiorama_N56 = "removeLocator_MonzaDiorama_N56"
    static let billboard_MonzaDiorama_B8 = "billboard_MonzaDiorama_B8"
    static let removeBillboard_MonzaDiorama_B8 = "removeBillboard_MonzaDiorama_B8"
    static let billboard_MonzaDiorama_B9 = "billboard_MonzaDiorama_B9"
    static let locator_CurveModified = "locator_CurveModified"
    static let locators_Current = "locators_Current"
    
    
    
    static let hideLocatorsMonza = "HideLocatorsMonza"
    static let spawnShapeKeyMonza = "SpawnShapeKeyMonza"
    static let reduceOpacityMonza = "ReduceOpacityMonza"
    static let reduceOpacityBankedOval = "reduceOpacityBankedOval"
    static let hideOpacityBankedOval = "hideOpacityBankedOval"
    static let increaseOpacityBankedOval = "increaseOpacityBankedOval"
    static let elevateMonzaCircuit = "ElevateMonzaCircuit"
    static let animateTo95_99 = "AnimateTo95_99"
    static let animateTo76_94 = "AnimateTo76_94"
    static let animateTo72_75 = "AnimateTo72_75"
    static let animateTo57_71 = "AnimateTo57_71"
    static let animateTo37_50 = "AnimateTo37_50"
    static let animateTo35_37Florio = "AnimateTo35_37Florio"
    static let animateTo1922 = "AnimateTo1922"
    static let animateToReset = "AnimateToReset"
    static let hideAnimatedCircuit = "HideAnimatedCircuit"
    static let showMonzaDiorama = "ShowMonzaDiorama"
    static let removeAnimatedCircuit = "RemoveAnimatedCircuit"
    
    
    static let audio_Stratos_01 = "audio_LanciaStratos_01"
    
    static let billboard_Stratos_01 = "billboard_LanciaStratos_01"
    static let billboard_Stratos_02 = "billboard_LanciaStratos_02"
    static let billboard_Stratos_03 = "billboard_LanciaStratos_03"
    static let billboard_Stratos_04 = "billboard_LanciaStratos_04"
    static let billboard_Stratos_05 = "billboard_LanciaStratos_05"
    static let billboard_Stratos_06 = "billboard_LanciaStratos_06"
    
    
    static let audio_DeltaIntegrale_01 = "audio_DeltaIntegrale_01"
    
    static let billboard_DeltaIntegrale_01 = "billboard_DeltaIntegrale_01"
    static let billboard_DeltaIntegrale_02 = "billboard_DeltaIntegrale_02"
    static let billboard_DeltaIntegrale_03 = "billboard_DeltaIntegrale_03"
    static let billboard_DeltaIntegrale_04 = "billboard_DeltaIntegrale_04"
    static let billboard_DeltaIntegrale_05 = "billboard_DeltaIntegrale_05"
    static let billboard_DeltaIntegrale_06 = "billboard_DeltaIntegrale_06"
    
    static let activateEngine = "ActivateEngine"
    
    
    
    
    
    
    
    
    
    static let hideMainScene = "hideMainScene"
    
    
    static let restartExperience = "RestartExperience"
    
    static let voiceOverEnded_A_AlfaRomeo = "VoiceOverEnded_A_AlfaRomeo"
    static let voiceOverEnded_A_AlfaRomeo_FullSize = "VoiceOverEnded_A_AlfaRomeo_FullSize"
    
    static let voiceOverEnded_A_Ferrari = "VoiceOverEnded_A_Ferrari"
    static let voiceOverEnded_A_Ferrari_FullSize = "VoiceOverEnded_A_Ferrari_FullSize"
    
    static let voiceOverEnded_A_LanciaStratos = "VoiceOverEnded_A_LanciaStratos"
    static let voiceOverEnded_A_LanciaStratos_FullSize = "VoiceOverEnded_A_LanciaStratos_FullSize"
    
    static let voiceOverEnded_A_Tatuus = "VoiceOverEnded_A_Tatuus"
    static let voiceOverEnded_A_Tatuus_FullSize = "VoiceOverEnded_A_Tatuus_FullSize"
    
    static let voiceOverEnded_A_DeltaIntegrale = "VoiceOverEnded_A_DeltaIntegrale"
    
    static let voiceOverEnded_A_DeltaIntegrale_FullSize = "VoiceOverEnded_A_DeltaIntegrale_FullSize"
    
    
    
}




