//
//  Intersector.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 28.10.20.
//

import Foundation

struct Contact {
    let penetration: simd_float3
    let penetratingVertex: simd_float3
}

/// A cube located at the origin, extending in the positive axis directions.
struct Cube {
    let mass: Float
    let sideLength: Float
    let transform: Transform
    
    func restTransform() -> Transform {
        .translation(simd_float3(-sideLength, -sideLength, -sideLength))
    }
    
    func inertiaTensor() -> simd_float3 {
        simd_float3(repeating: 1.0 / 6.0 * mass * sideLength * sideLength)
    }
}

/// Intersects a cube with the plane defined by `z = 0`, returning the penetration vector.
func intersectCubeWithGround(cube: Cube) -> Contact {
    let canonicalVertices: [simd_float3] = [
        cube.sideLength * .zero,
        cube.sideLength * .e1,
        cube.sideLength * .e2,
        cube.sideLength * .e1 + .e2,
        cube.sideLength * .e3,
        cube.sideLength * .e3 + .e1,
        cube.sideLength * .e3 + .e2,
        cube.sideLength * .e3 + .e1 + .e2
    ]
    
    let vertices = canonicalVertices.map(cube.transform.act)
    let deepestVertex = vertices.min { a, b in a.z < b.z }!
    let deepestVertexRestSpace = cube.transform.inverse().then(cube.restTransform()).act(on: deepestVertex)
    
    return Contact(
        penetration: simd_float3(0, 0, deepestVertex.z),
        penetratingVertex: deepestVertexRestSpace
    )
}
