import RealityKit
import simd

/// Component that marks an entity for Y-axis billboard rotation toward the camera.
struct YAxisBillboardComponent: Component {
    var isEnabled: Bool = true
}

/// Manages registration and camera tracking for the Y-axis billboard system.
@MainActor
enum YAxisBillboardRuntime {
    private static var cameraTransformProvider: (() -> simd_float4x4?)?
    private static var hasRegistered = false

    /// Registers the component and system with RealityKit.
    static func register() {
        guard !hasRegistered else { return }
        YAxisBillboardComponent.registerComponent()
        YAxisBillboardSystem.registerSystem()
        hasRegistered = true
    }

    /// Sets the closure used to retrieve the current camera transform from ARKit.
    static func setCameraTransformProvider(_ provider: (() -> simd_float4x4?)?) {
        cameraTransformProvider = provider
    }

    static func enable(on entity: Entity) {
        entity.components.set(YAxisBillboardComponent())
    }

    static func disable(on entity: Entity) {
        entity.components.remove(YAxisBillboardComponent.self)
    }

    static func currentCameraTransform() -> simd_float4x4? {
        cameraTransformProvider?()
    }
}

/// Per-frame system that rotates entities with ``YAxisBillboardComponent`` to face the camera on the Y axis.
final class YAxisBillboardSystem: System {
    private static let query = EntityQuery(where: .has(YAxisBillboardComponent.self))

    required init(scene: Scene) {}

    @MainActor
    func update(context: SceneUpdateContext) {
        guard let cameraTransform = YAxisBillboardRuntime.currentCameraTransform() else {
            return
        }

        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let component = entity.components[YAxisBillboardComponent.self], component.isEnabled else {
                continue
            }

            rotateEntityOnYAxis(entity, toward: cameraPosition)
        }
    }

    /// Computes the yaw angle from the entity to the camera and applies it as a world-space Y rotation.
    @MainActor
    private func rotateEntityOnYAxis(_ entity: Entity, toward cameraPosition: SIMD3<Float>) {
        let entityPosition = entity.position(relativeTo: nil)
        var flattenedDirection = cameraPosition - entityPosition
        flattenedDirection.y = 0

        guard simd_length_squared(flattenedDirection) > 0.0001 else {
            return
        }

        flattenedDirection = simd_normalize(flattenedDirection)
        let yaw = atan2(flattenedDirection.x, flattenedDirection.z)

        let worldRotation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        entity.setOrientation(worldRotation, relativeTo: nil)
    }
}
