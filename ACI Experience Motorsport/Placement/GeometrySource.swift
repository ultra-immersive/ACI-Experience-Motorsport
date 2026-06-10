//
//  GeometrySource.swift
//  ACI Experience Motorsport
//

import Foundation
import RealityKit
import UIKit
import ARKit

/// Utility extensions for reading ARKit geometry buffers and performing spatial math used by the placement system.

extension GeometrySource {
    func asArray<T>(ofType: T.Type) -> [T] {
        assert(MemoryLayout<T>.stride == stride, "Invalid stride \(MemoryLayout<T>.stride); expected \(stride)")
        return (0..<count).map {
            buffer.contents().advanced(by: offset + stride * Int($0)).assumingMemoryBound(to: T.self).pointee
        }
    }
    
    func asSIMD3<T>(ofType: T.Type) -> [SIMD3<T>] {
        asArray(ofType: (T, T, T).self).map { .init($0.0, $0.1, $0.2) }
    }
    
    subscript(_ index: Int32) -> (Float, Float, Float) {
        precondition(format == .float3, "This subscript operator can only be used on GeometrySource instances with format .float3")
        return buffer.contents().advanced(by: offset + (stride * Int(index))).assumingMemoryBound(to: (Float, Float, Float).self).pointee
    }
}

extension GeometryElement {
    subscript(_ index: Int) -> [Int32] {
        precondition(bytesPerIndex == MemoryLayout<Int32>.size,
                     "This subscript operator can only be used on GeometryElement instances with bytesPerIndex == \(MemoryLayout<Int32>.size). This GeometryElement has bytesPerIndex == \(bytesPerIndex)")
        var data = [Int32]()
        data.reserveCapacity(primitive.indexCount)
        for indexOffset in 0 ..< primitive.indexCount {
            data.append(buffer
                .contents()
                .advanced(by: (Int(index) * primitive.indexCount + indexOffset) * MemoryLayout<Int32>.size)
                .assumingMemoryBound(to: Int32.self).pointee)
        }
        return data
    }
    
    func asInt32Array() -> [Int32] {
        var data = [Int32]()
        let totalNumberOfInt32 = count * primitive.indexCount
        data.reserveCapacity(totalNumberOfInt32)
        for indexOffset in 0 ..< totalNumberOfInt32 {
            data.append(buffer.contents().advanced(by: indexOffset * MemoryLayout<Int32>.size).assumingMemoryBound(to: Int32.self).pointee)
        }
        return data
    }
    
    func asUInt16Array() -> [UInt16] {
        asInt32Array().map { UInt16($0) }
    }
    
    public func asUInt32Array() -> [UInt32] {
        asInt32Array().map { UInt32($0) }
    }
}

extension simd_float4x4 {
    init(translation vector: SIMD3<Float>) {
        self.init(SIMD4<Float>(1, 0, 0, 0),
                  SIMD4<Float>(0, 1, 0, 0),
                  SIMD4<Float>(0, 0, 1, 0),
                  SIMD4<Float>(vector.x, vector.y, vector.z, 1))
    }
    
    var translation: SIMD3<Float> {
        get { columns.3.xyz }
        set { self.columns.3 = [newValue.x, newValue.y, newValue.z, 1] }
    }
    
    var rotation: simd_quatf { simd_quatf(rotationMatrix) }
    var xAxis: SIMD3<Float> { columns.0.xyz }
    var yAxis: SIMD3<Float> { columns.1.xyz }
    var zAxis: SIMD3<Float> { columns.2.xyz }
    
    var rotationMatrix: simd_float3x3 {
        matrix_float3x3(xAxis, yAxis, zAxis)
    }
    
    /// Returns a copy with the Y axis aligned to gravity (projected Z onto the horizontal plane).
    var gravityAligned: simd_float4x4 {
        let projectedZAxis: SIMD3<Float> = [zAxis.x, 0.0, zAxis.z]
        let normalizedZAxis = normalize(projectedZAxis)
        let gravityAlignedYAxis: SIMD3<Float> = [0, 1, 0]
        let resultingXAxis = normalize(cross(gravityAlignedYAxis, normalizedZAxis))
        return simd_matrix(
            SIMD4(resultingXAxis.x, resultingXAxis.y, resultingXAxis.z, 0),
            SIMD4(gravityAlignedYAxis.x, gravityAlignedYAxis.y, gravityAlignedYAxis.z, 0),
            SIMD4(normalizedZAxis.x, normalizedZAxis.y, normalizedZAxis.z, 0),
            columns.3
        )
    }
}

extension SIMD4 {
    var xyz: SIMD3<Scalar> { self[SIMD3(0, 1, 2)] }
}

extension SIMD2<Float> {
    /// Returns whether this point lies inside the triangle defined by three vertices using barycentric coordinates.
    func isInsideOf(_ vertex1: SIMD2<Float>, _ vertex2: SIMD2<Float>, _ vertex3: SIMD2<Float>) -> Bool {
        let coords = barycentricCoordinatesInTriangle(vertex1, vertex2, vertex3)
        return coords.x >= 0 && coords.x <= 1 && coords.y >= 0 && coords.y <= 1 && coords.z >= 0 && coords.z <= 1
    }
    
    /// Computes barycentric coordinates of this point relative to a triangle.
    func barycentricCoordinatesInTriangle(_ vertex1: SIMD2<Float>, _ vertex2: SIMD2<Float>, _ vertex3: SIMD2<Float>) -> SIMD3<Float> {
        let v2FromV1 = vertex2 - vertex1
        let v3FromV1 = vertex3 - vertex1
        let selfFromV1 = self - vertex1
        let areaOverallTriangle = cross(v2FromV1, v3FromV1).z
        let areaU = cross(selfFromV1, v3FromV1).z
        let areaV = cross(v2FromV1, selfFromV1).z
        let u = areaU / areaOverallTriangle
        let v = areaV / areaOverallTriangle
        let w = 1.0 - v - u
        return SIMD3<Float>(u, v, w)
    }
}

extension PlaneAnchor {
    static let horizontalCollisionGroup = CollisionGroup(rawValue: 1 << 31)
    static let verticalCollisionGroup = CollisionGroup(rawValue: 1 << 30)
    static let allPlanesCollisionGroup = CollisionGroup(rawValue: horizontalCollisionGroup.rawValue | verticalCollisionGroup.rawValue)
}

extension MeshResource.Contents {
    init(planeGeometry: PlaneAnchor.Geometry) {
        self.init()
        self.instances = [MeshResource.Instance(id: "main", model: "model")]
        var part = MeshResource.Part(id: "part", materialIndex: 0)
        part.positions = MeshBuffers.Positions(planeGeometry.meshVertices.asSIMD3(ofType: Float.self))
        part.triangleIndices = MeshBuffer(planeGeometry.meshFaces.asUInt32Array())
        self.models = [MeshResource.Model(id: "model", parts: [part])]
    }
}
