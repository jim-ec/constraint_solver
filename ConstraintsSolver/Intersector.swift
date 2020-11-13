//
//  Intersector.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 28.10.20.
//

import Foundation

func intersectGround(_ rigidBody: RigidBody) -> [PositionalConstraint] {
    rigidBody.vertices().filter { vertex in vertex.z < 0 }.map { vertex in
        PositionalConstraint(
            body: rigidBody,
            positions: (vertex, simd_double3(vertex.x, vertex.y, 0)),
            distance: 0,
            compliance: 0.0000001
        )
    }
}
