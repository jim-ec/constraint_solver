//
//  Solver.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 13.11.20.
//

import Foundation

struct PositionalConstraint {
    let rigid: Rigid
    let positions: (Point, Point)
    let distance: Double
    let compliance: Double
}

func solve(for constraints: [PositionalConstraint], dt: Double) {
    var groundPosition = Point.null
    var groundOrientation = Quaternion.identity
    let groundInverseMass = 0.0
    let groundInverseInertia = simd_double3.zero
    let groundSpaceInverse = Frame.identity
    
    for constraint in constraints {
        let difference = constraint.positions.1 - constraint.positions.0
        let magnitude = difference.length - constraint.distance
        let direction = difference.normalize
        
        let angularImpulseDual: (Point, Point) = (
            constraint.rigid.frame.quaternion.inverse.act(
                on: (constraint.positions.0 - constraint.rigid.frame.position).cross(direction)
            ),
            groundSpaceInverse.quaternion.act(
                on: constraint.positions.1.cross(direction)
            )
        )
        
        let generalizedInverseMass: (Double, Double) = (
            constraint.rigid.inverseMass + (constraint.rigid.inverseInertia .* angularImpulseDual.0).dot(angularImpulseDual.0),
            groundInverseMass + (groundInverseInertia .* angularImpulseDual.1).dot(angularImpulseDual.1)
        )
        
        let timeStepCompliance = constraint.compliance / (dt * dt)
        let lagrangeMultiplier = magnitude / (generalizedInverseMass.0 + generalizedInverseMass.1 + timeStepCompliance)
        let impulse = lagrangeMultiplier * direction
        
        constraint.rigid.applyLinearImpulse(impulse, at: constraint.positions.0)
        
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
    
    func integrate(_ rigids: [Rigid], by dt: Double) {
        let subdt = dt / Double(subStepCount)
        
        for _ in 0 ..< subStepCount {
            for rigid in rigids {
                rigid.integrateAttitude(by: subdt)
                let constraints = generateConstraints(for: rigid)
                solve(for: constraints, dt: subdt)
                rigid.deriveVelocity(for: subdt)
            }
        }
    }
    
    func generateConstraints(for rigid: Rigid) -> [PositionalConstraint] {
        switch rigid.collider {
        case let .box(box):
            return box.intersectWithGround(attachedTo: rigid)
        case .plane(_):
            return []
        }
    }
}
