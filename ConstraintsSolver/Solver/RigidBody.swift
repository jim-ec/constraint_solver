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
    var externalForce: double3
    var velocity: double3
    var angularVelocity: double3
    var transform: Transform
    var previousTransform: Transform
    
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
        
        self.externalForce = .zero
        self.velocity = .zero
        self.angularVelocity = .zero
        self.transform = .identity
        self.previousTransform = .identity
    }
    
    func integratePosition(by dt: Double) {
        velocity += dt * externalForce * inverseMass
        
        previousTransform = transform
        transform = transform.integrate(by: dt, linear: velocity, angular: angularVelocity)
    }
    
    func deriveVelocity(for dt: Double) {
        (velocity, angularVelocity) = transform.derive(by: dt, previousTransform)
    }
    
    /// Applies a linear impulse in a given direction and magnitude at a given location.
    /// Results in changes in both position and orientation.
    func applyLinearImpulse(_ impulse: double3, at vertex: double3) {
        transform.position += impulse * inverseMass
        
        let rotation = 0.5 * quat(real: 0, imag: cross(vertex - transform.position, impulse)) * transform.orientation
        transform.orientation = (transform.orientation + rotation).normalized
    }
    
    func toLocal(_ x: double3) -> double3 {
        transform.inverse().act(on: x)
    }
    
    func toGlobal(_ x: double3) -> double3 {
        transform.act(on: x)
    }
    
    func fromGlobalToPreviousGlobal(_ x: double3) -> double3 {
        previousTransform.act(on: toLocal(x))
    }
}
