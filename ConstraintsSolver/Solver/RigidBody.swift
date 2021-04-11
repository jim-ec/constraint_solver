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
    var externalForce: Point = .null
    var velocity: Point = .null
    var angularVelocity: Point = .null
    var frame: Frame = .identity
    var pastFrame: Frame = .identity
    
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
        pastFrame = frame
        frame = frame.integrate(by: dt, linearVelocity: velocity, angularVelocity: angularVelocity)
    }
    
    func deriveVelocity(for dt: Double) {
        (velocity, angularVelocity) = frame.derive(for: dt, pastFrame)
    }
    
    /// Applies a linear impulse in a given direction and magnitude at a given location.
    /// Results in changes in both position and quaternion.
    func applyLinearImpulse(_ impulse: Point, at vertex: Point) {
        frame.translate(by: inverseMass * impulse)
        
        let rotation = 0.5 * Quaternion(bivector: (vertex - frame.position).cross(impulse)) * frame.quaternion
        frame.quaternion = frame.quaternion ^+ rotation
    }
    
    /// Computes the position difference of a local point from the past frame to the current frame.
    func delta(_ local: Point) -> Point {
        let pastGlobal = pastFrame.act(local)
        let currentGlobal = frame.act(local)
        return pastGlobal.to(currentGlobal)
    }
}
