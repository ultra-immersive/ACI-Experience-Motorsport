//
//  VideoUIControls.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 03/09/25.
//

import SwiftUI
import AVFoundation
import RealityKit
import RealityKitContent

///UI View for early exit during 180Video experience
struct VideoUIControls: View {
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    
    @Environment(AppModel.self) var appModel

    @State private var isPlaying: Bool = false
    @State private var hideControlsTimer: Timer?
    @State private var isPressed = false
    
    var body: some View {
        RealityView { content in
            let modelSortGroup = ModelSortGroup(depthPass: .postPass)
            if let entity = try? await Entity(named: "Assets/X_Button", in: realityKitContentBundle) {
                entity.enumerateHierarchy { entity, stop in
                    entity.components.set(HoverEffectComponent(.shader(.default)))
                    entity.components.set(ModelSortGroupComponent(group: modelSortGroup, order: 0))
                    if let modelEntity = findModelEntity(in: entity) {
                        modelEntity.components.set(HoverEffectComponent(.shader(.default)))
                        modelEntity.components.set(InputTargetComponent())
                        modelEntity.components.set(ModelSortGroupComponent(group: modelSortGroup, order: 0))
                    }
                }
                
                let bounds = entity.visualBounds(relativeTo: nil)
                entity.components.set(
                    CollisionComponent(shapes: [.generateBox(size: bounds.extents)])
                )
                entity.components.set(InputTargetComponent())
                entity.scale = [0.4, 0.4, 0.4]
                content.add(entity)
            }
        }
        .gesture(
            TapGesture()
                .targetedToAnyEntity()
                .onEnded { _ in
                    withAnimation(.easeIn(duration: 0.08)) {
                        isPressed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        endVideoAndTriggerCallback()
                        dismiss()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isPressed = false
                        }
                    }
                }
        )
        .scaleEffect(isPressed ? 0.88 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .frame(width: 96, height: 96)
        .onAppear {
            setupPlayerObserver()
        }
        .onDisappear {
            hideControlsTimer?.invalidate()
        }
    }
    
    // MARK: - Control Actions
    
    private func endVideoAndTriggerCallback() {
        appModel.player.pause()
        if let currentVideo = appModel.videoManager.currentVideo {
            appModel.videoManager.onVideoEnd?(currentVideo)
        }
    }
    
    // MARK: - Player Observer
    
    private func setupPlayerObserver() {
        appModel.player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main
        ) { _ in
            isPlaying = appModel.player.rate > 0
        }
    }
    
}
