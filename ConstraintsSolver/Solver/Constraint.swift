//
//  Solver.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 13.11.20.
//

import Foundation


protocol Constraint {
    func solve(compliance: Double)
}


func timeScaledCompliance(_ compliance: Double, dt: Double) -> Double {
    compliance / (dt * dt)
}


/// How much a constraint constributes to the solution in order to converge.
func contribution(currently current: Double, targeting target: Double, inverseResistance: Double, compliance: Double) -> Double {
    let difference = current - target
    let lagrangeFactor = difference / (inverseResistance + compliance)
    return lagrangeFactor
}


struct PositionalConstraint: Constraint {
    let rigids: (Rigid, Rigid)
    let contacts: (Point, Point)
    let distance: Double
    
    func solve(compliance: Double) {
        let difference = contacts.0.to(contacts.1)
        let direction = difference.normalize
        
        let angularImpulseDual: (Point, Point) = (
            rigids.0.frame.quaternion.inverse.act(
                on: (contacts.0 - rigids.0.frame.position).cross(direction)
            ),
            rigids.1.frame.quaternion.act(
                on: (contacts.1 - rigids.1.frame.position).cross(direction)
            )
        )

        let factor = contribution(
            currently: difference.length,
            targeting: distance,
            inverseResistance: rigids.0.inverseMass +
                rigids.1.inverseMass +
                (rigids.0.inverseInertia .* angularImpulseDual.0).dot(angularImpulseDual.0) +
                (rigids.1.inverseInertia .* angularImpulseDual.1).dot(angularImpulseDual.1),
            compliance: compliance)
        
        let impulse = factor * direction

        rigids.0.applyLinearImpulse(impulse, at: contacts.0)
        rigids.1.applyLinearImpulse(-impulse, at: contacts.1)
    }
}
