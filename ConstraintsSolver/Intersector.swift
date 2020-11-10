//
//  Intersector.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 28.10.20.
//

import Foundation

struct PositionalConstraint {
    let direction: simd_double3
    let magnitude: Double
    let positions: (simd_double3, simd_double3)
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
func intersectCuboidWithGround(_ cuboid: Cuboid) -> PositionalConstraint? {
    let penetratingVertices = cuboid.vertices().filter { v in v.z < 0 }
    
    if penetratingVertices.isEmpty {
        return .none
    }
    
    let deepestVertex = penetratingVertices.reduce(simd_double3.zero, +) / Double(penetratingVertices.count)
    
    return PositionalConstraint(
        direction: .e3,
        magnitude: -deepestVertex.z,
        positions: (deepestVertex - cuboid.position, simd_double3(deepestVertex.x, deepestVertex.y, 0))
    )
}

func solveConstraints(deltaTime: Double, cuboid: Cuboid) {
    let subStepCount = 10
    let subDeltaTime = deltaTime / Double(subStepCount)
    
    let compliance = 0.0000001
    let timeStepCompliance = compliance / (subDeltaTime * subDeltaTime)
    
    for _ in 0..<subStepCount {
        let currentPosition = cuboid.position
        let currentOrientation = cuboid.orientation
        
        cuboid.velocity += subDeltaTime * cuboid.externalForce / cuboid.mass
        cuboid.position += subDeltaTime * cuboid.velocity
        
        cuboid.orientation += subDeltaTime * 0.5 * simd_quatd(real: .zero, imag: cuboid.angularVelocity) * cuboid.orientation
        cuboid.orientation = cuboid.orientation.normalized
        
        var groundPosition = simd_double3.zero
        var groundOrientation = simd_quatd.identity
        let groundInverseMass = 0.0
        let groundInverseInertia = simd_double3.zero
        let groundTransformInverse = Transform.identity()
        
        if let constraint = intersectCuboidWithGround(cuboid) {
            let angularImpulseDual0 = cuboid.transform().inverse().rotate(cross(constraint.positions.0, constraint.direction))
            let angularImpulseDual1 = groundTransformInverse.rotate(cross(constraint.positions.1, constraint.direction))
            
            let generalizedInverseMass0 = cuboid.inverseMass + dot(angularImpulseDual0 * cuboid.inverseInertia, angularImpulseDual0)
            let generalizedInverseMass1 = groundInverseMass + dot(angularImpulseDual1 * groundInverseInertia, angularImpulseDual1)
            
            let lagrangeMultiplier = constraint.magnitude / (generalizedInverseMass0 + generalizedInverseMass1 + timeStepCompliance)
            let impulse = lagrangeMultiplier * constraint.direction
            
            let translation0 = impulse * cuboid.inverseMass
            let translation1 = impulse * groundInverseMass
            
            let rotation0 = 0.5 * simd_quatd(real: 0, imag: cross(constraint.positions.0, impulse)) * cuboid.orientation
            let rotation1 = 0.5 * simd_quatd(real: 0, imag: cross(constraint.positions.1, impulse)) * groundOrientation
            
            cuboid.position += translation0
            cuboid.orientation = (cuboid.orientation + rotation0).normalized
            
            groundPosition += translation1
            groundOrientation = (groundOrientation + rotation1).normalized
        }
        
        cuboid.velocity = (cuboid.position - currentPosition) / subDeltaTime
        
        let rotation = cuboid.orientation * currentOrientation.inverse
        cuboid.angularVelocity = 2.0 * rotation.imag / subDeltaTime
        if rotation.real < 0 {
            cuboid.angularVelocity = -cuboid.angularVelocity
        }
    }
    
}
