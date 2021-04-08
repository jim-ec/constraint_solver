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

class CollisionGroup {
    let rigidBody: RigidBody
    
    init(rigidBody: RigidBody) {
        self.rigidBody = rigidBody
    }
    
    func integratePositions(by deltaTime: Double) {
        rigidBody.integratePosition(by: deltaTime)
    }
    
    func generateConstraints() -> [PositionalConstraint] {
        intersectGround(rigidBody)
    }
    
    func deriveVelocities(by deltaTime: Double) {
        rigidBody.deriveVelocity(by: deltaTime)
    }
}

class System {
    var subStepCount: Int = 10
    var collisionGroup: CollisionGroup
    
    init(subStepCount: Int, collisionGroup: CollisionGroup) {
        self.subStepCount = subStepCount
        self.collisionGroup = collisionGroup
    }
    
    func step(by deltaTime: Double) {
        let subDeltaTime = deltaTime / Double(subStepCount)
        
        for _ in 0..<subStepCount {
            collisionGroup.integratePositions(by: subDeltaTime)
            
            var groundPosition = double3.zero
            var groundOrientation = quat.identity
            let groundInverseMass = 0.0
            let groundInverseInertia = double3.zero
            let groundTransformInverse = Transform.identity()
            
            for constraint in collisionGroup.generateConstraints() {
                let difference = constraint.positions.1 - constraint.positions.0
                let magnitude = length(difference) - constraint.distance
                let direction = normalize(difference)
                
                let angularImpulseDual =
                    (constraint.body.orientation.inverse.act(cross(constraint.positions.0 - constraint.body.position, direction)),
                     groundTransformInverse.rotate(cross(constraint.positions.1, direction)))
                
                let generalizedInverseMass =
                    (constraint.body.inverseMass + dot(angularImpulseDual.0 * constraint.body.inverseInertia, angularImpulseDual.0),
                     groundInverseMass + dot(angularImpulseDual.1 * groundInverseInertia, angularImpulseDual.1))
                
                let timeStepCompliance = constraint.compliance / (subDeltaTime * subDeltaTime)
                let lagrangeMultiplier = magnitude / (generalizedInverseMass.0 + generalizedInverseMass.1 + timeStepCompliance)
                let impulse = lagrangeMultiplier * direction
                
                constraint.body.applyLinearImpulse(impulse, at: constraint.positions.0)
                
                let groundTranslation = impulse * groundInverseMass
                let groundRotation = 0.5 * quat(real: 0, imag: cross(constraint.positions.1, impulse)) * groundOrientation
                groundPosition += groundTranslation
                groundOrientation = (groundOrientation + groundRotation).normalized
            }
            
            collisionGroup.deriveVelocities(by: subDeltaTime)
        }
    }
}
