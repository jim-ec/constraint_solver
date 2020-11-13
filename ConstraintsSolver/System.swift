//
//  Solver.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 13.11.20.
//

import Foundation

struct PositionalConstraint {
    let body: RigidBody
    let positions: (simd_double3, simd_double3)
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
            
            var groundPosition = simd_double3.zero
            var groundOrientation = simd_quatd.identity
            let groundInverseMass = 0.0
            let groundInverseInertia = simd_double3.zero
            let groundTransformInverse = Transform.identity()
            
            for constraint in collisionGroup.generateConstraints() {
                let difference = constraint.positions.1 - constraint.positions.0
                let magnitude = length(difference) - constraint.distance
                
                let position = constraint.positions.0
                let positionRestAttidude = constraint.body.intoRestAttidue(constraint.positions.0)
                let previousPosition = constraint.body.previousOrientation.act(positionRestAttidude) + constraint.body.previousPosition
                let deltaPosition = position - previousPosition
                let tangentialDeltaPosition = deltaPosition - project(deltaPosition, normalize(difference))
                let direction = normalize(difference - tangentialDeltaPosition)
                
                let angularImpulseDual0 = constraint.body.orientation.inverse.act(cross(constraint.positions.0 - constraint.body.position, direction))
                let angularImpulseDual1 = groundTransformInverse.rotate(cross(constraint.positions.1, direction))
                
                let generalizedInverseMass0 = constraint.body.inverseMass + dot(angularImpulseDual0 * constraint.body.inverseInertia, angularImpulseDual0)
                let generalizedInverseMass1 = groundInverseMass + dot(angularImpulseDual1 * groundInverseInertia, angularImpulseDual1)
                
                let timeStepCompliance = constraint.compliance / (subDeltaTime * subDeltaTime)
                let lagrangeMultiplier = magnitude / (generalizedInverseMass0 + generalizedInverseMass1 + timeStepCompliance)
                let impulse = lagrangeMultiplier * direction
                
                let translation0 = impulse * constraint.body.inverseMass
                let translation1 = impulse * groundInverseMass
                
                let rotation0 = 0.5 * simd_quatd(real: 0, imag: cross(constraint.positions.0 - constraint.body.position, impulse)) * constraint.body.orientation
                let rotation1 = 0.5 * simd_quatd(real: 0, imag: cross(constraint.positions.1, impulse)) * groundOrientation
                constraint.body.position += translation0
                constraint.body.orientation = (constraint.body.orientation + rotation0).normalized
                
                groundPosition += translation1
                groundOrientation = (groundOrientation + rotation1).normalized
            }
            
            collisionGroup.deriveVelocities(by: subDeltaTime)
        }
    }
}
