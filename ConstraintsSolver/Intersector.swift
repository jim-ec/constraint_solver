//
//  Intersector.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 28.10.20.
//

import Foundation

struct Contact {
    let penetration: simd_float3
}

/// A cube located at the origin, extending in the positive axis directions.
struct Cube {
    let sideLength: Float
    let transform: Transform
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
    
    let deepestVertex = vertices.reduce(simd_float3(0, 0, .infinity)) { (reduction, vertex) in
        if vertex.z < reduction.z {
            return vertex
        }
        else {
            return reduction
        }
    }
    
    return Contact(penetration: simd_float3(0, 0, deepestVertex.z))
}
