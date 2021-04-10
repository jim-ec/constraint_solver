//
//  RigidBody.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 13.11.20.
//

import Foundation

class RigidBody {
    let inverseMass: Double
    let inverseInertia: simd_double3
    var externalForce: Position = .null
    var velocity: Position = .null
    var angularVelocity: simd_double3 = .zero
    var space: Space = .identity
    var pastSpace: Space = .identity
    
    init(mass: Double?) {
        if let mass = mass {
            self.inverseMass = 1 / mass
            let extent = simd_double3(repeating: 1)
            let inertia = 1.0 / 12.0 * mass * simd_double3(
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
        velocity = velocity + dt * inverseMass * externalForce
        
        pastSpace = space
        space = space.integrate(by: dt, linearVelocity: velocity, angularVelocity: angularVelocity)
    }
    
    func deriveVelocity(for dt: Double) {
        (velocity, angularVelocity) = space.derive(for: dt, pastSpace)
    }
    
    /// Applies a linear impulse in a given direction and magnitude at a given location.
    /// Results in changes in both position and orientation.
    func applyLinearImpulse(_ impulse: Position, at vertex: Position) {
        space.translate(by: inverseMass * impulse)
        
        let rotation = 0.5 * simd_quatd(real: 0, imag: (vertex - space.position).cross(impulse).p) * space.orientation.q
        space.orientation.q = (space.orientation.q + rotation).normalized
    }
    
    func toLocal(_ x: Position) -> Position {
        space.enter(x)
    }
    
    func toGlobal(_ x: Position) -> Position {
        space.leave(x)
    }
    
    /// Computes the position of the given global space vertex in the past configuration.
    func delta(_ x: Position) -> Position {
        let global = space.enter(x)
        return pastSpace.leave(global)
    }
}
