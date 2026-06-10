import SwiftUI
import RealityKit
import RealityKitContent

extension Notification.Name {
    static let skipCurrentVideo = Notification.Name("skipCurrentVideo")
}

/// 3D "X" button that posts a ``skipCurrentVideo`` notification when tapped, used to skip the currently playing video.
struct SkipVideoUI: View {
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
                entity.scale = [0.5, 0.5, 0.5]
                entity.orientation = simd_quatf(angle: -.pi / 6, axis: [1, 0, 0])
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
                        NotificationCenter.default.post(name: .skipCurrentVideo, object: nil)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isPressed = false
                        }
                    }
                }
        )
        .scaleEffect(isPressed ? 0.88 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .frame(width: 96, height: 96)
    }
}
