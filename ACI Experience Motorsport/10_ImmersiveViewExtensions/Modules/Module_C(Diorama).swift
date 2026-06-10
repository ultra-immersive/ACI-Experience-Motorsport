//
//  Module_C.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 21/10/25.
//

import Foundation
import RealityKit
import RealityKitContent

extension ImmersiveView {
    
    // MARK: - Module C Start
    
    /// Loads the epoch-appropriate diorama, and reveals it.
    func startModule_C() {
        Task {
            await loadReducedDioramaModel(assetName: appModel.dioramaModel.rawValue)
            try? await Task.sleep(for: .seconds(0.5))
            showDiorama()
        }
    }
    
    /// Fades in the diorama with spatial audio and triggers the epoch-specific RCP notification.
    func showDiorama() {
        if let dioramaHolder = rootEntity.findEntity(named: "Diorama_Holder") {
            EnhancedAudioSystem.playAudio(on: dioramaHolder, resourceName: "/Root/Small_car_appearing_wav")
    
            graduallyChangeOpacity(entity: dioramaHolder, targetOpacity: 1, duration: 4) {
                Task {
                    switch appModel.dioramaModel {
                    case .monza:
                        sendNotificationtToRCP(notificationName: "MonzaBeginPlay")
                    case .valleLunga:
                        sendNotificationtToRCP(notificationName: "BillboardsSequence_Vallelunga")
                    }
                }
            }
        }
    }
    
    // MARK: - Diorama Model Loading
    
    /// Loads the diorama asset (Monza or Vallelunga) and applies epoch-specific outline colors.
    func loadReducedDioramaModel(assetName: String) async {
        if let diorama_Holder = rootEntity.findEntity(named: "Diorama_Holder") {
            if let diorama = try? await Entity(named: "Assets/\(assetName)", in: realityKitContentBundle) {
                setPoutlineColor(inEntity: diorama, forEntity: "groundDiorama")
                diorama_Holder.addChild(diorama)
                if appModel.dioramaModel == .valleLunga {
                    diorama.position.z += 0.3
                }
            }
        }
    }
}
