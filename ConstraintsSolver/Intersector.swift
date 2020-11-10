//
//  Intersector.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 28.10.20.
//

import Foundation

struct UnilateralPositionalCorrection {
    var body: Cuboid
    let direction: simd_double3
    let magnitude: Double
    let position: simd_double3
}

extension Double {
    func sqare() -> Double {
        self * self
    }
}

class Cuboid {
    let extent: simd_double3
    let mass: Double
    let inverseMass: Double
    let inertia: simd_double3
    let inverseInertia: simd_double3
    var externalForce: simd_double3
    var velocity: simd_double3
    var angularVelocity: simd_double3
    var previousTransform: Transform
    var transform: Transform
    
    init(mass: Double, extent: simd_double3) {
        self.mass = mass
        self.inverseMass = 1 / mass
        self.extent = extent
        self.velocity = .zero
        self.angularVelocity = .zero
        self.transform = .identity()
        self.previousTransform = .identity()
        self.externalForce = .zero
        self.inertia = 1.0 / 12.0 * mass * simd_double3(
            extent.y * extent.y + extent.z * extent.z,
            extent.x * extent.x + extent.z * extent.z,
            extent.x * extent.x + extent.y * extent.y)
        self.inverseInertia = 1 / inertia
    }
    
    func vertices() -> [simd_double3] {
        let cube: [simd_double3] = [
            .init(-1, -1, -1),
            .init(1, -1, -1),
            .init(-1, 1, -1),
            .init(1, 1, -1),
            .init(-1, -1, 1),
            .init(1, -1, 1),
            .init(-1, 1, 1),
            .init(1, 1, 1)
        ]
        
        let verticesRestSpace = cube.map { v in 0.5 * extent * v }
        return verticesRestSpace.map { v in transform.act(on: v) }
    }
}

/// Intersects a cube with the plane defined by `z = 0`, returning the penetration vector.
func intersectCuboidWithGround(_ cuboid: Cuboid) -> UnilateralPositionalCorrection? {
    let penetratingVertices = cuboid.vertices().filter { v in v.z < 0 }
    
    if penetratingVertices.isEmpty {
        return .none
    }
    
    let deepestVertex = penetratingVertices.average()
    
    return UnilateralPositionalCorrection(
        body: cuboid,
        direction: .e3,
        magnitude: -deepestVertex.z,
        position: deepestVertex - cuboid.transform.act(on: .zero)
    )
}

func solveConstraints(deltaTime: Double, cuboid: Cuboid) {
    let subStepCount = 10
    let subDeltaTime = deltaTime / Double(subStepCount)
    
    for _ in 0..<subStepCount {
        cuboid.previousTransform = cuboid.transform
        
        cuboid.velocity += subDeltaTime * cuboid.externalForce / cuboid.mass
        cuboid.transform.position += subDeltaTime * cuboid.velocity
        
        //        cuboid.angularVelocity += dt *
        cuboid.transform.orientation += subDeltaTime * 0.5 * simd_quatd(real: .zero, imag: cuboid.angularVelocity) * cuboid.transform.orientation
        cuboid.transform.orientation = cuboid.transform.orientation.normalized
        
        if let constraint = intersectCuboidWithGround(cuboid) {
            let angularImpulseDual = cuboid.transform.inverse().rotate(cross(constraint.position, constraint.direction))
            let generalizedInverseMass = constraint.body.inverseMass + dot(angularImpulseDual * constraint.body.inverseInertia, angularImpulseDual)
            
            let impulse = constraint.magnitude / generalizedInverseMass * constraint.direction
            let angularVelocity = simd_quatd(real: 0, imag: cross(constraint.position, impulse))
            
            let translation = impulse / constraint.body.mass
            let rotation = 0.5 * angularVelocity * constraint.body.transform.orientation
            
            constraint.body.transform.position = constraint.body.transform.position + translation
            constraint.body.transform.orientation = (constraint.body.transform.orientation + rotation).normalized
        }
        
        cuboid.velocity = (cuboid.transform.position - cuboid.previousTransform.position) / subDeltaTime
        
        let rotation = cuboid.transform.orientation * cuboid.previousTransform.orientation.inverse
        cuboid.angularVelocity = 2.0 * rotation.imag / subDeltaTime
        if rotation.real < 0 {
            cuboid.angularVelocity = -cuboid.angularVelocity
        }
    }
    
}
