//
//  RigidBody.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 13.11.20.
//

import Foundation

class RigidBody {
    let inverseMass: Double
    let inverseInertia: double3
    var externalForce: double3 = .zero
    var velocity: double3 = .zero
    var angularVelocity: double3 = .zero
    var space: Space = .identity
    var pastSpace: Space = .identity
    
    init(mass: Double?) {
        if let mass = mass {
            self.inverseMass = 1 / mass
            let extent = simd_double3(repeating: 1)
            let inertia = 1.0 / 12.0 * mass * double3(
                extent.y * extent.y + extent.z * extent.z,
                extent.x * extent.x + extent.z * extent.z,
                extent.x * extent.x + extent.y * extent.y)
            self.inverseInertia = 1 / inertia
        }
        else {
            self.inverseMass = 0
            self.inverseInertia = .zero
        }
    }
    
    func integrateAttitude(by dt: Double) {
        velocity += dt * externalForce * inverseMass
        
        pastSpace = space
        space = space.integrate(by: dt, linearVelocity: velocity, angularVelocity: angularVelocity)
    }
    
    func deriveVelocity(for dt: Double) {
        (velocity, angularVelocity) = space.derive(for: dt, pastSpace)
    }
    
    /// Applies a linear impulse in a given direction and magnitude at a given location.
    /// Results in changes in both position and orientation.
    func applyLinearImpulse(_ impulse: double3, at vertex: double3) {
        space.translate(by: inverseMass * impulse)
        
        let rotation = 0.5 * quat(real: 0, imag: cross(vertex - space.position.p, impulse)) * space.orientation.q
        space.orientation.q = (space.orientation.q + rotation).normalized
    }
    
    func toLocal(_ x: double3) -> double3 {
        space.enter(Position(x)).p
    }
    
    func toGlobal(_ x: double3) -> double3 {
        space.leave(Position(x)).p
    }
    
    func fromGlobalToPreviousGlobal(_ x: double3) -> double3 {
        let global = space.enter(Position(x))
        return pastSpace.leave(global).p
    }
}
