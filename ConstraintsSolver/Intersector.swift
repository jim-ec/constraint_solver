//
//  Intersector.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 28.10.20.
//

import Foundation

struct Contact {
    let direction: simd_float3
    let magnitude: Float
    let penetratingVertex: simd_float3
}

/// A cuboid located at the origin, extending in the positive axis directions.
struct Cuboid {
    let mass: Float
    let extent: simd_float3
    let transform: Transform
    
    func restTransform() -> Transform {
        .translation(simd_float3(-extent.x, -extent.y, -extent.z))
    }
    
    func inertiaTensor() -> simd_float3 {
        1.0 / 12.0 * mass * simd_float3(
            extent.y * extent.y + extent.z * extent.z,
            extent.x * extent.x + extent.z * extent.z,
            extent.x * extent.x + extent.y * extent.y
        )
    }
}

/// Intersects a cube with the plane defined by `z = 0`, returning the penetration vector.
func intersectCuboidWithGround(cube: Cuboid) -> Contact? {
    let canonicalVertices: [simd_float3] = [
        simd_float3(0, 0, 0),
        simd_float3(cube.extent.x, 0, 0),
        simd_float3(0, cube.extent.y, 0),
        simd_float3(cube.extent.x, cube.extent.y, 0),
        simd_float3(0, 0, cube.extent.z),
        simd_float3(cube.extent.x, 0, cube.extent.z),
        simd_float3(0, cube.extent.y, cube.extent.z),
        simd_float3(cube.extent.x, cube.extent.y, cube.extent.z)
    ]
    
    let vertices = canonicalVertices.map(cube.transform.act)
    let deepestVertex = vertices.min { a, b in a.z < b.z }!
    
    if deepestVertex.z >= 0 {
        return .none
    }
    
    let deepestVertexRestSpace = cube.transform.inverse().then(cube.restTransform()).act(on: deepestVertex)
    
    return .some(Contact(
        direction: simd_float3(0, 0, -1),
        magnitude: -deepestVertex.z,
        penetratingVertex: deepestVertexRestSpace
    ))
}
