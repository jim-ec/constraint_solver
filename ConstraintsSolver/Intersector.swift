//
//  Intersector.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 28.10.20.
//

import Foundation

struct UnilateralPositionalCorrection {
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
    var position: simd_double3
    var orientation: simd_quatd
    
    init(mass: Double, extent: simd_double3) {
        self.mass = mass
        self.inverseMass = 1 / mass
        self.extent = extent
        self.velocity = .zero
        self.angularVelocity = .zero
        self.position = .zero
        self.orientation = .identity
        self.externalForce = .zero
        self.inertia = 1.0 / 12.0 * mass * simd_double3(
            extent.y * extent.y + extent.z * extent.z,
            extent.x * extent.x + extent.z * extent.z,
            extent.x * extent.x + extent.y * extent.y)
        self.inverseInertia = 1 / inertia
    }
    
    func transform() -> Transform {
        Transform(position: position, orientation: orientation)
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
        return verticesRestSpace.map { v in transform().act(on: v) }
    }
}

/// Intersects a cube with the plane defined by `z = 0`, returning the penetration vector.
func intersectCuboidWithGround(_ cuboid: Cuboid) -> UnilateralPositionalCorrection? {
    let penetratingVertices = cuboid.vertices().filter { v in v.z < 0 }
    
    if penetratingVertices.isEmpty {
        return .none
    }
    
    let deepestVertex = penetratingVertices.reduce(simd_double3.zero, +) / Double(penetratingVertices.count)
    
    return UnilateralPositionalCorrection(
        direction: .e3,
        magnitude: -deepestVertex.z,
        position: deepestVertex - cuboid.position
    )
}

func solveConstraints(deltaTime: Double, cuboid: Cuboid) {
    let subStepCount = 10
    let subDeltaTime = deltaTime / Double(subStepCount)
    
    for _ in 0..<subStepCount {
        let currentPosition = cuboid.position
        let currentOrientation = cuboid.orientation
        
        cuboid.velocity += subDeltaTime * cuboid.externalForce / cuboid.mass
        cuboid.position += subDeltaTime * cuboid.velocity
        
        cuboid.orientation += subDeltaTime * 0.5 * simd_quatd(real: .zero, imag: cuboid.angularVelocity) * cuboid.orientation
        cuboid.orientation = cuboid.orientation.normalized
        
        if let constraint = intersectCuboidWithGround(cuboid) {
            let angularImpulseDual = cuboid.transform().inverse().rotate(cross(constraint.position, constraint.direction))
            let generalizedInverseMass = cuboid.inverseMass + dot(angularImpulseDual * cuboid.inverseInertia, angularImpulseDual)
            
            let impulse = constraint.magnitude / generalizedInverseMass * constraint.direction
            let angularVelocity = simd_quatd(real: 0, imag: cross(constraint.position, impulse))
            
            let translation = impulse / cuboid.mass
            let rotation = 0.5 * angularVelocity * cuboid.orientation
            
            cuboid.position = cuboid.position + translation
            cuboid.orientation = (cuboid.orientation + rotation).normalized
        }
        
        cuboid.velocity = (cuboid.position - currentPosition) / subDeltaTime
        
        let rotation = cuboid.orientation * currentOrientation.inverse
        cuboid.angularVelocity = 2.0 * rotation.imag / subDeltaTime
        if rotation.real < 0 {
            cuboid.angularVelocity = -cuboid.angularVelocity
        }
    }
    
}
