//
//  Solver.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 13.11.20.
//

import Foundation

struct PositionalConstraint {
    let body: RigidBody
    let positions: (double3, double3)
    let distance: Double
    let compliance: Double
}

func solve(for constraints: [PositionalConstraint], dt: Double) {
    var groundPosition = double3.zero
    var groundOrientation = quat.identity
    let groundInverseMass = 0.0
    let groundInverseInertia = double3.zero
    let groundTransformInverse = Transform.identity
    
    for constraint in constraints {
        let difference = constraint.positions.1 - constraint.positions.0
        let magnitude = length(difference) - constraint.distance
        let direction = normalize(difference)
        
        let angularImpulseDual =
            (constraint.body.transform.orientation.inverse.act(cross(constraint.positions.0 - constraint.body.transform.position, direction)),
             groundTransformInverse.rotate(cross(constraint.positions.1, direction)))
        
        let generalizedInverseMass =
            (constraint.body.inverseMass + dot(angularImpulseDual.0 * constraint.body.inverseInertia, angularImpulseDual.0),
             groundInverseMass + dot(angularImpulseDual.1 * groundInverseInertia, angularImpulseDual.1))
        
        let timeStepCompliance = constraint.compliance / (dt * dt)
        let lagrangeMultiplier = magnitude / (generalizedInverseMass.0 + generalizedInverseMass.1 + timeStepCompliance)
        let impulse = lagrangeMultiplier * direction
        
        constraint.body.applyLinearImpulse(impulse, at: constraint.positions.0)
        
        let groundTranslation = impulse * groundInverseMass
        let groundRotation = 0.5 * quat(real: 0, imag: cross(constraint.positions.1, impulse)) * groundOrientation
        groundPosition += groundTranslation
        groundOrientation = (groundOrientation + groundRotation).normalized
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
