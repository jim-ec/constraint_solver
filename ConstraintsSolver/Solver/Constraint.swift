//
//  Solver.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 13.11.20.
//

import Foundation

protocol Constraint {
    func solve(dt: Double)
}

struct PositionalConstraint: Constraint {
    let rigids: (Rigid, Rigid)
    let positions: (Point, Point)
    let distance: Double
    let compliance: Double
    
    func solve(dt: Double) {
        let difference = positions.1 - positions.0
        let magnitude = difference.length - distance
        let direction = difference.normalize
        
        let angularImpulseDual: (Point, Point) = (
            rigids.0.frame.quaternion.inverse.act(
                on: (positions.0 - rigids.0.frame.position).cross(direction)
            ),
            rigids.1.frame.quaternion.act(
                on: (positions.1 - rigids.1.frame.position).cross(direction)
            )
        )
        
        let generalizedInverseMass: (Double, Double) = (
            rigids.0.inverseMass + (rigids.0.inverseInertia .* angularImpulseDual.0).dot(angularImpulseDual.0),
            rigids.1.inverseMass + (rigids.1.inverseInertia .* angularImpulseDual.1).dot(angularImpulseDual.1)
        )
        
        let timeStepCompliance = compliance / (dt * dt)
        let lagrangeMultiplier = magnitude / (generalizedInverseMass.0 + generalizedInverseMass.1 + timeStepCompliance)
        let impulse = lagrangeMultiplier * direction
        
        rigids.0.applyLinearImpulse(impulse, at: positions.0)
        rigids.1.applyLinearImpulse(impulse, at: positions.1)
    }
}
