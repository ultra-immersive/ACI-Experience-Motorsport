//
//  Module_A.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 21/10/25.
//

import Foundation
import RealityKit

extension ImmersiveView {
    
    /// Initializes Module A: hides panel backgrounds, triggers the opening animation, reveals border panels, loads all media, and starts the experience timer.
    func startModule_A() async {
        do {
            for i in 1...10 {
                if let container = rootEntity.findEntity(named: "Image_\(i)") {
                    if container.name == "Image_1" {
                        if let first = container.findEntity(named: "ImageScreen_") {
                            first.components.set(OpacityComponent(opacity: 0.0))
                        }
                    }
                    container.enumerateHierarchy { entity, stop in
                        if entity.name.contains("ImageScreen_") {
                            entity.components.set(OpacityComponent(opacity: 0.0))
                        }
                    }
                }
            }
            
            sendNotificationtToRCP(notificationName: "PanelsAnimation")
                        
            try await Task.sleep(for: .seconds(5))
            
                showMixedMedia()
                
                experienceTimer.setVideoPlaybackChecker { [self] in
                    self.currentTappedVideo != nil
                }

                experienceTimer.onExperienceEnd = {
                    Task {
                        endStartedFromExperienceTimer = true
                        sendNotificationtToRCP(notificationName: "Experience_Completed")
                    }
                }

                experienceTimer.start()
        } catch {
            print("Error in startModule_A: \(error)")
        }
    }
}
