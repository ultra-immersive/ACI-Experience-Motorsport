//
//  PlacementVisualization.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 09/03/26.
//

import ARKit
import RealityKit
import UIKit

/// Renders wireframe meshes of detected real-world surfaces during placement mode to help staff understand the tracked environment.
@MainActor
@Observable
class PlacementVisualization {

    private let session = ARKitSession()
    var sceneReconstruction = SceneReconstructionProvider()
    let contentEntity = Entity()
    private var meshEntities: [UUID: ModelEntity] = [:]

    /// Starts the scene reconstruction provider.
    func beginSession() async {
        do {
            try await session.run([sceneReconstruction])
        } catch {
            print("PlacementViz: Failed to start – \(error)")
        }
    }

    func stopSession() async {
        session.stop()
    }

    /// Creates a fresh provider and restarts the session.
    func reset() async {
        sceneReconstruction = SceneReconstructionProvider(modes: [.classification])
        await beginSession()
    }

    /// Continuously processes scene reconstruction anchor updates — call from a `.task` modifier.
    func processReconstructionUpdates() async {
        for await update in sceneReconstruction.anchorUpdates {
            let meshAnchor = update.anchor

            switch update.event {
            case .added:
                guard meshEntities[meshAnchor.id] == nil else { continue }
                do {
                    let entity = try await generateMeshEntity(from: meshAnchor.geometry)
                    entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
                    entity.name = "reconMesh_\(meshAnchor.id)"
                    meshEntities[meshAnchor.id] = entity
                } catch {
                    print("PlacementViz: mesh generation failed – \(error)")
                }

            case .updated:
                meshEntities[meshAnchor.id]?.transform =
                    Transform(matrix: meshAnchor.originFromAnchorTransform)

            case .removed:
                meshEntities[meshAnchor.id]?.removeFromParent()
                meshEntities.removeValue(forKey: meshAnchor.id)
            }
        }
    }

    /// Removes all wireframe mesh entities from the scene.
    func removeAllMeshes() {
        contentEntity.children.forEach { $0.removeFromParent() }
        meshEntities.removeAll()
    }

    /// Generates a wireframe `ModelEntity` from a mesh anchor's geometry.
    private func generateMeshEntity(from geometry: MeshAnchor.Geometry) async throws -> ModelEntity {
        var desc = MeshDescriptor()

        let positions = geometry.vertices.asSIMD3(ofType: Float.self)
        desc.positions = .init(positions)

        let normals = geometry.normals.asSIMD3(ofType: Float.self)
        desc.normals = .init(normals)

        desc.primitives = .polygons(
            (0..<geometry.faces.count).map { _ in UInt8(3) },
            (0..<geometry.faces.count * 3).map {
                geometry.faces.buffer.contents()
                    .advanced(by: $0 * geometry.faces.bytesPerIndex)
                    .assumingMemoryBound(to: UInt32.self).pointee
            }
        )

        let mesh = try MeshResource.generate(from: [desc])

        var material = SimpleMaterial(color: .white.withAlphaComponent(0.6), isMetallic: false)
        material.triangleFillMode = .lines

        return ModelEntity(mesh: mesh, materials: [material])
    }
}
