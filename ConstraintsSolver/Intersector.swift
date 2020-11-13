//
//  Intersector.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 28.10.20.
//

import Foundation

func intersectGround(_ rigidBody: RigidBody) -> [PositionalConstraint] {
    rigidBody.vertices().filter { vertex in vertex.z < 0 }.map { position in
        let targetPosition = simd_double3(position.x, position.y, 0)
        let difference = targetPosition - position
        
        let deltaPosition = position - rigidBody.intoPreviousAttidue(position)
        let deltaTangentialPosition = deltaPosition - project(deltaPosition, difference)
        
        return PositionalConstraint(
            body: rigidBody,
            positions: (position, targetPosition - deltaTangentialPosition),
            distance: 0,
            compliance: 0.0000001
        )
    }
}
