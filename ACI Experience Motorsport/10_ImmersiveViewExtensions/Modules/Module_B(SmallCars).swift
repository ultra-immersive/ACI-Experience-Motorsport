//
//  Module_B.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 21/10/25.
//

import Foundation
import RealityKit
import RealityKitContent
import BigAssets

extension ImmersiveView {
    
    // MARK: - Module B Start
    
    /// Loads the epoch-appropriate car model, starts the turntable spin, reveals the floating plane, and triggers the RCP billboard sequence.
    func startModule_B() {
        Task {
            let car = appModel.currentReducedCarModel
            await loadReducedCarModel(assetName: car.rawValue)
            
            try? await Task.sleep(for: .seconds(0.5))
            if isFullScaleCarsActive == false {
                startCarHolderSpin(rpm: 0.8)
            }
            
            if let floatingPlane = rootEntity.findEntity(named: "M_FloatingPlane") {
                EnhancedAudioSystem.playAudio(on: floatingPlane, resourceName: "/Root/Space_appearing_wav")
                if let ME_FloatingPlane = floatingPlane.findEntity(named: "ME_FloatingPlane") {
                    
                    handlePopValueChange(entity: ME_FloatingPlane, targetValue: isFullScaleCarsActive ? 0.0 : 1, duration: 1, keyMaterialName: "Pop", completion: {
                        
                        if let carHolder = rootEntity.findEntity(named: isFullScaleCarsActive ? "CarModel_Holder" : "ReducedCarModel_Holder") {
                            carHolder.enumerateHierarchy { entity, stop in
                                entity.components.set(GroundingShadowComponent(castsShadow: true ,receivesShadow: true, fadeBehaviorNearPhysicalObjects: .constant))
                                if let modelEntity = findModelEntity(in: entity) {
                                    modelEntity.components.set(GroundingShadowComponent(castsShadow: true ,receivesShadow: true, fadeBehaviorNearPhysicalObjects: .constant))
                                }
                            }

                            graduallyChangeOpacity(entity: carHolder, targetOpacity: 1, duration: 0.1) {
                                carHolder.components.remove(OpacityComponent.self)
                                if isFullScaleCarsActive {
                                    sendNotificationtToRCP(notificationName: "Begin_\(appModel.currentReducedCarModel.rawValue)_FullSize")
                                } else {
                                    sendNotificationtToRCP(notificationName: "Begin_\(appModel.currentReducedCarModel.rawValue)")
                                }
                            }
                        }
                    })
                }
            }
        }
    }
    
    /// Starts continuous Y-axis rotation on the reduced car model holder.
    func startCarHolderSpin(rpm: Float = 3.0, easeInDuration: TimeInterval = 1.5) {
        guard let holder = rootEntity.findEntity(named: "ReducedCarModel_Holder") else {
            print("ReducedCarModel_Holder not found for spin")
            return
        }
        turntableSpinner.start(entity: holder, rpm: rpm, easeInDuration: easeInDuration)
    }

    /// Stops the car holder rotation with optional ease-out and return to home orientation.
    func stopCarHolderSpin(
        easeOutDuration: TimeInterval = 1.5,
        returnToHome: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        if returnToHome {
            turntableSpinner.stopAtHome(duration: easeOutDuration, completion: completion)
        } else {
            turntableSpinner.stop(easeOutDuration: easeOutDuration, completion: completion)
        }
    }
    
    // MARK: - Car Model Loading
    
    /// Loads the 3D car asset and its PBR material set for the current epoch's car model.
    func loadReducedCarModel(assetName: String) async {
        if let reducedCarModel_Holder = rootEntity.findEntity(named: isFullScaleCarsActive ? "CarModel_Holder" : "ReducedCarModel_Holder") {
            if appModel.currentReducedCarModel == .deltaIntegrale {
                if let reducedCar = try? await Entity(named: "BulkImport/A_DeltaIntegrale", in: BigAssets.bigAssetsBundle) {
                    setPoutlineColor(inEntity: reducedCar, forEntity: "FloatingPlane")
                    reducedCar.enumerateHierarchy { entity, stop in
                        entity.components.set(GroundingShadowComponent(castsShadow: true ,receivesShadow: true))
                        if let modelEntity = findModelEntity(in: entity) {
                            modelEntity.components.set(GroundingShadowComponent(castsShadow: true ,receivesShadow: true, fadeBehaviorNearPhysicalObjects: .constant))
                        }
                    }
                    
                    if let light = reducedCar.findEntity(named: "SpotLight") {
                        if let spotlightComponent = light.components[SpotLightComponent.self] {
                            var newSpotLightComponent = spotlightComponent
                            newSpotLightComponent.intensity = 0.0
                            light.components.set(newSpotLightComponent)
                        }
                    }
                    
                    reducedCarModel_Holder.addChild(reducedCar)
                    
                    if let deltaIntegralePBR = try? await Entity(named: "BulkImport/A_DeltaIntegrale_references/MS_PHY_DeltaIntegrale.usda", in: BigAssets.bigAssetsBundle) {
                        deltaIntegralePBR.name = "DeltaIntegralePBR"
                        deltaIntegralePBR.position.y = 300
                        rootEntity.addChild(deltaIntegralePBR)
                    }
                }

            } else {
                if let reducedCar = try? await Entity(named: "Assets/\(assetName)", in: realityKitContentBundle) {
                    setPoutlineColor(inEntity: reducedCar, forEntity: "FloatingPlane")
                    reducedCar.enumerateHierarchy { entity, stop in
                        entity.components.set(GroundingShadowComponent(castsShadow: true ,receivesShadow: true))
                        if let modelEntity = findModelEntity(in: entity) {
                            modelEntity.components.set(GroundingShadowComponent(castsShadow: true ,receivesShadow: true, fadeBehaviorNearPhysicalObjects: .constant))
                        }
                    }
                    
                    if let light = reducedCar.findEntity(named: "SpotLight") {
                        if let spotlightComponent = light.components[SpotLightComponent.self] {
                            var newSpotLightComponent = spotlightComponent
                            newSpotLightComponent.intensity = 0.0
                            light.components.set(newSpotLightComponent)
                        }
                    }
                    
                    reducedCarModel_Holder.addChild(reducedCar)
                    
                    switch appModel.currentReducedCarModel {
                    case .tatuus:
                        if let tatusPBR = try? await Entity(named: "Materials/MaterialSets/Tatuus/MS_PHY_Tatuus.usda", in: realityKitContentBundle) {
                            tatusPBR.name = "TatusPBR"
                            tatusPBR.position.y = 300
                            rootEntity.addChild(tatusPBR)
                        }
                    case .alfaRomeo:
                        if let alfaRomeoPBR = try? await Entity(named: "Materials/MaterialSets/AlfaRomeoP3/MS_PHY_AlfaRomeoP3.usda", in: realityKitContentBundle) {
                            alfaRomeoPBR.name = "AlfaRomeoPBR"
                            alfaRomeoPBR.position.y = 300
                            rootEntity.addChild(alfaRomeoPBR)
                        }
                    case .lanciaStratos:
                        if let lanciaStratosPBR = try? await Entity(named: "Materials/MaterialSets/LanciaStratos/MS_PHY_LanciaStratos.usda", in: realityKitContentBundle) {
                            lanciaStratosPBR.name = "LanciaStratosPBR"
                            lanciaStratosPBR.position.y = 300
                            rootEntity.addChild(lanciaStratosPBR)
                        }
                    case .ferrari375:
                        if let ferrari375PBR = try? await Entity(named: "Materials/MaterialSets/Ferrari375/MS_PHY_Ferrari375plus.usda", in: realityKitContentBundle) {
                            ferrari375PBR.name = "Ferrari375PBR"
                            ferrari375PBR.position.y = 300
                            rootEntity.addChild(ferrari375PBR)
                        }
                    case .deltaIntegrale:
                        print("")
                    }
                }
            }
        }
    }
    
    // MARK: - Material Configuration
    
    /// Applies the epoch-specific outline color to the specified entity.
    func setPoutlineColor(inEntity: Entity, forEntity: String) {
        if let pOutline = inEntity.findEntity(named: forEntity) {
            var targetToUse: Int32 = 0
            
            switch appModel.selectedEpoch {
            case .laCorsaComeSfida:
                targetToUse = 0
            case .tecnicaPassioneGenio:
                targetToUse = 1
            case .laFormazionePiloti:
                targetToUse = 2
            default:
                targetToUse = 0
            }
            
            pOutline.enumerateHierarchy { entity, stop in
                if let modelEntity = findModelEntity(in: entity) {
                    if let material = modelEntity.model?.materials.first as? ShaderGraphMaterial {
                        do {
                            var newMaterial = material
                            try newMaterial.setParameter(name: "ID", value: .int(targetToUse))
                            modelEntity.model?.materials = [newMaterial]
                        } catch {
                        }
                    }
                }
            }
        }
    }
}
