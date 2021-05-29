//
//  Solver.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 13.11.20.
//

import Foundation


protocol Constraint {
    var measure: Double { get }
    var targetMeasure: Double { get }
    var inverseResistance: Double { get }
    func act(factor: Double)
}


struct PositionalConstraint: Constraint {
    let rigids: (Rigid, Rigid)
    let contacts: (Point, Point)
    let distance: Double
    
    var difference: Point {
        contacts.0.to(contacts.1)
    }

    var direction: Point {
        contacts.0.to(contacts.1).normalize
    }
    
    var measure: Double {
        difference.length
    }
    
    var targetMeasure: Double {
        distance
    }
    
    var inverseResistance: Double {
        let angularImpulseDual: (Point, Point) = (
            rigids.0.frame.quaternion.inverse.act(on: (contacts.0 - rigids.0.frame.position).cross(direction)),
            rigids.1.frame.quaternion.act(on: (contacts.1 - rigids.1.frame.position).cross(direction))
        )
        return rigids.0.inverseMass + rigids.1.inverseMass +
            (rigids.0.inverseInertia .* angularImpulseDual.0).dot(angularImpulseDual.0) +
            (rigids.1.inverseInertia .* angularImpulseDual.1).dot(angularImpulseDual.1)
    }
    
    func act(factor: Double) {
        let impulse = factor * direction
        rigids.0.applyLinearImpulse(impulse, at: contacts.0)
        rigids.1.applyLinearImpulse(-impulse, at: contacts.1)
    }
}
