//
//  PlaneAnchorHandler.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 09/03/26.
//

import Foundation
import ARKit
import RealityKit

/// Creates invisible collision entities for each detected AR plane, enabling downward raycasts to find the floor during placement mode.
class PlaneAnchorHandler {

    var rootEntity: Entity
    private var planeEntities: [UUID: Entity] = [:]
    private var planeAnchorsByID: [UUID: PlaneAnchor] = [:]

    var planeAnchors: [PlaneAnchor] {
        Array(planeAnchorsByID.values)
    }

    init(rootEntity: Entity) {
        self.rootEntity = rootEntity
    }

    /// Processes an ARKit plane anchor update: generates a static collision shape for added/updated anchors, removes entities for deleted anchors.
    @MainActor
    func process(_ anchorUpdate: AnchorUpdate<PlaneAnchor>) async {
        let anchor = anchorUpdate.anchor

        if anchorUpdate.event == .removed {
            planeAnchorsByID.removeValue(forKey: anchor.id)
            if let entity = planeEntities.removeValue(forKey: anchor.id) {
                entity.removeFromParent()
            }
            return
        }

        planeAnchorsByID[anchor.id] = anchor

        let entity = Entity()
        entity.name = "Plane_\(anchor.id)"
        entity.setTransformMatrix(anchor.originFromAnchorTransform, relativeTo: nil)

        var shape: ShapeResource?
        do {
            let vertices = anchor.geometry.meshVertices.asSIMD3(ofType: Float.self)
            shape = try await ShapeResource.generateStaticMesh(
                positions: vertices,
                faceIndices: anchor.geometry.meshFaces.asUInt16Array()
            )
        } catch {
            print("PlaneAnchorHandler: Failed to create static mesh – \(error)")
            return
        }

        if let shape {
            let collisionGroup: CollisionGroup = anchor.alignment == .horizontal
                ? PlaneAnchor.horizontalCollisionGroup
                : PlaneAnchor.verticalCollisionGroup

            entity.components.set(CollisionComponent(
                shapes: [shape],
                isStatic: true,
                filter: CollisionFilter(group: collisionGroup, mask: .all)
            ))

            let physics = PhysicsBodyComponent(
                shapes: [shape],
                mass: 0.0,
                material: PhysicsMaterialResource.generate(),
                mode: .static
            )
            entity.components.set(physics)
        }

        let existing = planeEntities[anchor.id]
        planeEntities[anchor.id] = entity
        rootEntity.addChild(entity)
        existing?.removeFromParent()
    }

    /// Removes all plane collision entities from the scene.
    @MainActor
    func removeAll() {
        for (_, entity) in planeEntities {
            entity.removeFromParent()
        }
        planeEntities.removeAll()
        planeAnchorsByID.removeAll()
    }
}
