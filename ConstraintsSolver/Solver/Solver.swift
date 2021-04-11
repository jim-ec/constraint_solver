//
//  Solver.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 13.11.20.
//

import Foundation

struct PositionalConstraint {
    let body: RigidBody
    let positions: (Point, Point)
    let distance: Double
    let compliance: Double
}

func solve(for constraints: [PositionalConstraint], dt: Double) {
    var groundPosition = Point.null
    var groundOrientation = Quaternion.identity
    let groundInverseMass = 0.0
    let groundInverseInertia = simd_double3.zero
    let groundSpaceInverse = Space.identity
    
    for constraint in constraints {
        let difference = constraint.positions.1 - constraint.positions.0
        let magnitude = difference.length - constraint.distance
        let direction = difference.normalize
        
        let angularImpulseDual: (Point, Point) = (
            constraint.body.space.quaternion.inverse.act(
                on: (constraint.positions.0 - constraint.body.space.position).cross(direction)
            ),
            groundSpaceInverse.quaternion.act(
                on: constraint.positions.1.cross(direction)
            )
        )
        
        let generalizedInverseMass: (Double, Double) = (
            constraint.body.inverseMass + (constraint.body.inverseInertia .* angularImpulseDual.0).dot(angularImpulseDual.0),
            groundInverseMass + (groundInverseInertia .* angularImpulseDual.1).dot(angularImpulseDual.1)
        )
        
        let timeStepCompliance = constraint.compliance / (dt * dt)
        let lagrangeMultiplier = magnitude / (generalizedInverseMass.0 + generalizedInverseMass.1 + timeStepCompliance)
        let impulse = lagrangeMultiplier * direction
        
        constraint.body.applyLinearImpulse(impulse, at: constraint.positions.0)
        
        let groundTranslation = groundInverseMass * impulse
        let groundRotation = 0.5 * Quaternion(bivector: constraint.positions.1.cross(impulse)) * groundOrientation
        groundPosition = groundPosition + groundTranslation
        groundOrientation = groundOrientation ^+ groundRotation
    }
}

class SubStepIntegrator {
    let subStepCount: Int
    
    init(subStepCount: Int) {
        self.subStepCount = subStepCount
    }
    
    func integrate(_ colliders: [Collider], by dt: Double) {
        let sdt = dt / Double(subStepCount)
        
        for _ in 0..<subStepCount {
            for collider in colliders {
                collider.rigidBody.integrateAttitude(by: sdt)
                let constraints = collider.intersectWithGround()
                solve(for: constraints, dt: sdt)
                collider.rigidBody.deriveVelocity(for: sdt)
            }
        }
    }
}
