//
//  Solver.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 13.11.20.
//

import Foundation

struct PositionalConstraint {
    let rigids: (Rigid, Rigid)
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
            constraint.rigids.0.frame.quaternion.inverse.act(
                on: (constraint.positions.0 - constraint.rigids.0.frame.position).cross(direction)
            ),
            constraint.rigids.1.frame.quaternion.act(
                on: constraint.positions.1.cross(direction)
            )
        )
        
        let generalizedInverseMass: (Double, Double) = (
            constraint.rigids.0.inverseMass + (constraint.rigids.0.inverseInertia .* angularImpulseDual.0).dot(angularImpulseDual.0),
            constraint.rigids.1.inverseMass + (constraint.rigids.1.inverseInertia .* angularImpulseDual.1).dot(angularImpulseDual.1)
        )
        
        let timeStepCompliance = constraint.compliance / (dt * dt)
        let lagrangeMultiplier = magnitude / (generalizedInverseMass.0 + generalizedInverseMass.1 + timeStepCompliance)
        let impulse = lagrangeMultiplier * direction
        
        constraint.rigids.0.applyLinearImpulse(impulse, at: constraint.positions.0)
        constraint.rigids.1.applyLinearImpulse(impulse, at: constraint.positions.1)
    }
}
