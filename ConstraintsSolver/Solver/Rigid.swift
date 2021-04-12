//
//  Rigid.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 13.11.20.
//

import Foundation

class Rigid {
    let collider: Collider
    let inverseMass: Double
    let inverseInertia: Point
    var externalForce: Point = .null
    var velocity: Point = .null
    var angularVelocity: Point = .null
    var frame: Frame = .identity
    var pastFrame: Frame = .identity
    
    init(collider: Collider, mass: Double?) {
        if let mass = mass {
            self.inverseMass = 1 / mass
            let extent = Point(1)
            let inertia = 1 / 12 * mass * Point(
                extent.y * extent.y + extent.z * extent.z,
                extent.x * extent.x + extent.z * extent.z,
                extent.x * extent.x + extent.y * extent.y)
            self.inverseInertia = Point(1 / inertia.x, 1 / inertia.y, 1 / inertia.z)
        }
        else {
            self.inverseMass = 0
            self.inverseInertia = .null
        }
        self.collider = collider
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
        
        let rotation = 0.5 * Quaternion(bivector: inverseInertia .* (vertex - frame.position).cross(impulse)) * frame.quaternion
        frame.quaternion = frame.quaternion ^+ rotation
    }
    
    /// Computes the position difference of a global point in the current frame from the same point in the past frame.
    func delta(global: Point) -> Point {
        let local = frame.inverse.act(global)
        let pastGlobal = pastFrame.act(local)
        return pastGlobal.to(global)
    }
}
