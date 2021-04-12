//
//  Solver.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 13.11.20.
//

import Foundation

struct PositionalConstraint {
    let rigid: Rigid
    let other: Rigid
    let positions: (Point, Point)
    let distance: Double
    let compliance: Double
}

func solve(for constraints: [PositionalConstraint], dt: Double) {
    for constraint in constraints {
        let difference = constraint.positions.1 - constraint.positions.0
        let magnitude = difference.length - constraint.distance
        let direction = difference.normalize
        
        let angularImpulseDual: (Point, Point) = (
            constraint.rigid.frame.quaternion.inverse.act(
                on: (constraint.positions.0 - constraint.rigid.frame.position).cross(direction)
            ),
            constraint.other.frame.quaternion.act(
                on: constraint.positions.1.cross(direction)
            )
        )
        
        let generalizedInverseMass: (Double, Double) = (
            constraint.rigid.inverseMass + (constraint.rigid.inverseInertia .* angularImpulseDual.0).dot(angularImpulseDual.0),
            constraint.other.inverseMass + (constraint.other.inverseInertia .* angularImpulseDual.1).dot(angularImpulseDual.1)
        )
        
        let timeStepCompliance = constraint.compliance / (dt * dt)
        let lagrangeMultiplier = magnitude / (generalizedInverseMass.0 + generalizedInverseMass.1 + timeStepCompliance)
        let impulse = lagrangeMultiplier * direction
        
        constraint.rigid.applyLinearImpulse(impulse, at: constraint.positions.0)
        constraint.other.applyLinearImpulse(impulse, at: constraint.positions.1)
    }
}
