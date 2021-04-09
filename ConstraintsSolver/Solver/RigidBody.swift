//
//  RigidBody.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 13.11.20.
//

import Foundation

class RigidBody {
    let mass: Double
    let inverseMass: Double
    let inertia: double3
    let inverseInertia: double3
    var externalForce: double3
    var velocity: double3
    var angularVelocity: double3
    var position: double3
    var orientation: quat
    var previousPosition: double3
    var previousOrientation: quat
    
    init(mass: Double) {
        self.mass = mass
        self.inverseMass = 1 / mass
        self.velocity = .zero
        self.angularVelocity = .zero
        self.position = .zero
        self.orientation = .identity
        self.previousPosition = position
        self.previousOrientation = orientation
        self.externalForce = .zero
        let extent = simd_double3(repeating: 1)
        self.inertia = 1.0 / 12.0 * mass * double3(
            extent.y * extent.y + extent.z * extent.z,
            extent.x * extent.x + extent.z * extent.z,
            extent.x * extent.x + extent.y * extent.y)
        self.inverseInertia = 1 / inertia
    }
    
    func integratePosition(by dt: Double) {
        previousPosition = position
        previousOrientation = orientation
        
        velocity += dt * externalForce / mass
        position += dt * velocity
        
        orientation += dt * 0.5 * quat(real: .zero, imag: angularVelocity) * orientation
        orientation = orientation.normalized
    }
    
    func deriveVelocity(for dt: Double) {
        velocity = (position - previousPosition) / dt
        
        let rotation = orientation * previousOrientation.inverse
        angularVelocity = 2.0 * rotation.imag / dt
        if rotation.real < 0 {
            angularVelocity = -angularVelocity
        }
    }
    
    /// Applies a linear impulse in a given direction and magnitude at a given location.
    /// Results in changes in both position and orientation.
    func applyLinearImpulse(_ impulse: double3, at vertex: double3) {
        position += impulse * inverseMass
        
        let rotation = 0.5 * quat(real: 0, imag: cross(vertex - position, impulse)) * orientation
        orientation = (orientation + rotation).normalized
    }
    
    func toLocal(_ x: double3) -> double3 {
        orientation.inverse.act(x - position)
    }
    
    func toGlobal(_ x: double3) -> double3 {
        orientation.act(x) + position
    }
    
    /// Computes where the given vertex in the current attitude would be in the previous one.
    func intoPreviousAttidue(_ x: double3) -> double3 {
        previousOrientation.act(toLocal(x)) + previousPosition
    }
}
