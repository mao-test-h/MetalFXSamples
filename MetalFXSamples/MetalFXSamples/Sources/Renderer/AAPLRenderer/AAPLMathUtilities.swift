/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file provides functions to make common 3D matrices.
*/

import simd

/// Provides a rotation matrix using the SIMD library.
func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let cosTheta = cosf(radians)
    let sinTheta = sinf(radians)
    let oneMinusCosTheta = 1 - cosTheta

    let m11 = cosTheta + unitAxis.x * unitAxis.x * oneMinusCosTheta
    let m21 = unitAxis.y * unitAxis.x * oneMinusCosTheta + unitAxis.z * sinTheta
    let m31 = unitAxis.z * unitAxis.x * oneMinusCosTheta - unitAxis.y * sinTheta
    let m12 = unitAxis.x * unitAxis.y * oneMinusCosTheta - unitAxis.z * sinTheta
    let m22 = cosTheta + unitAxis.y * unitAxis.y * oneMinusCosTheta
    let m32 = unitAxis.z * unitAxis.y * oneMinusCosTheta + unitAxis.x * sinTheta
    let m13 = unitAxis.x * unitAxis.z * oneMinusCosTheta + unitAxis.y * sinTheta
    let m23 = unitAxis.y * unitAxis.z * oneMinusCosTheta - unitAxis.x * sinTheta
    let m33 = cosTheta + unitAxis.z * unitAxis.z * oneMinusCosTheta

    return matrix_float4x4.init(columns: (SIMD4<Float>(m11, m21, m31, 0),
                                          SIMD4<Float>(m12, m22, m32, 0),
                                          SIMD4<Float>(m13, m23, m33, 0),
                                          SIMD4<Float>(0, 0, 0, 1)))
}

/// Provides a translation matrix using the SIMD library.
func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns: (vector_float4(1, 0, 0, 0),
                                          vector_float4(0, 1, 0, 0),
                                          vector_float4(0, 0, 1, 0),
                                          vector_float4(translationX, translationY, translationZ, 1)))
}

/// Provides a right-hand perspective matrix using the SIMD library.
func matrix_perspective_right_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let yScale = 1 / tanf(fovy * 0.5)
    let xScale = yScale / aspectRatio
    let zScale = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns: (vector_float4(xScale, 0, 0, 0),
                                          vector_float4(0, yScale, 0, 0),
                                          vector_float4(0, 0, zScale, -1),
                                          vector_float4(0, 0, zScale * nearZ, 0)))
}

func normalMatrixFromFloat4x4(_ matrix: simd_float4x4) -> simd_float3x3 {
    let column0: simd_float3 = simd_float3(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z)
    let column1: simd_float3 = simd_float3(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z)
    let column2: simd_float3 = simd_float3(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z)
    var normalMatrix: simd_float3x3 = simd_float3x3(column0, column1, column2)
    normalMatrix = simd_inverse(simd_transpose(normalMatrix))
    return normalMatrix
}

/// Uses the Halton sequence generator for random numbers.
///
/// This provides a good convergence rate for TAA, although it doesn't seem completely random.
func halton(index: UInt32, base: UInt32) -> Float {
    var result: Float = 0.0
    var fractional: Float = 1.0
    var currentIndex: UInt32 = index
    while currentIndex > 0 {
        fractional /= Float(base)
        result += fractional * Float(currentIndex % base)
        currentIndex /= base
    }
    return result
}
