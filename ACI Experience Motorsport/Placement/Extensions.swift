//
//  Extensions.swift
//  ACI Experience Motorsport
//
//

import Foundation
import RealityKit

// MARK: - SIMD3 Extensions

extension SIMD3 where Scalar == Float {
    func normalized() -> SIMD3<Float> {
        let length = sqrt(x * x + y * y + z * z)
        return length > 0 ? self / length : SIMD3<Float>(0, 0, 0)
    }
}


// MARK: - simd_float4x4 Extensions

extension simd_float4x4 {
    var upper3x3: simd_float3x3 {
        return simd_float3x3(columns.0.float3, columns.1.float3, columns.2.float3)
    }
}

// MARK: - simd_float4 Extensions

extension simd_float4 {
    var float3: simd_float3 {
        return simd_float3(x, y, z)
    }
}
