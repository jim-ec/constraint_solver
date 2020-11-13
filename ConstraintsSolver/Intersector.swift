//
//  Intersector.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 28.10.20.
//

import Foundation

struct PositionalConstraint {
    let positions: (simd_double3, simd_double3)
    let distance: Double
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
    var previousPosition: simd_double3
    var previousOrientation: simd_quatd
    
    init(mass: Double, extent: simd_double3) {
        self.mass = mass
        self.inverseMass = 1 / mass
        self.extent = extent
        self.velocity = .zero
        self.angularVelocity = .zero
        self.position = .zero
        self.orientation = .identity
        self.previousPosition = position
        self.previousOrientation = orientation
        self.externalForce = .zero
        self.inertia = 1.0 / 12.0 * mass * simd_double3(
            extent.y * extent.y + extent.z * extent.z,
            extent.x * extent.x + extent.z * extent.z,
            extent.x * extent.x + extent.y * extent.y)
        self.inverseInertia = 1 / inertia
    }
    
    func intoRestAttidue(_ x: simd_double3) -> simd_double3 {
        orientation.inverse.act(x - position)
    }
    
    func fromRestAttidue(_ x: simd_double3) -> simd_double3 {
        orientation.act(x) + position
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
        return verticesRestSpace.map(fromRestAttidue)
    }
}

func intersectCuboidWithGround(_ cuboid: Cuboid) -> [PositionalConstraint] {
    cuboid.vertices().filter { vertex in vertex.z < 0 }.map { vertex in
        PositionalConstraint(
            positions: (vertex, simd_double3(vertex.x, vertex.y, 0)),
            distance: 0
        )
    }
}

func solveConstraints(deltaTime: Double, cuboid: Cuboid) {
    let subStepCount = 10
    let subDeltaTime = deltaTime / Double(subStepCount)
    
    let compliance = 0.0000001
    let timeStepCompliance = compliance / (subDeltaTime * subDeltaTime)
    
    for _ in 0..<subStepCount {
        cuboid.previousPosition = cuboid.position
        cuboid.previousOrientation = cuboid.orientation
        
        cuboid.velocity += subDeltaTime * cuboid.externalForce / cuboid.mass
        cuboid.position += subDeltaTime * cuboid.velocity
        
        cuboid.orientation += subDeltaTime * 0.5 * simd_quatd(real: .zero, imag: cuboid.angularVelocity) * cuboid.orientation
        cuboid.orientation = cuboid.orientation.normalized
        
        var groundPosition = simd_double3.zero
        var groundOrientation = simd_quatd.identity
        let groundInverseMass = 0.0
        let groundInverseInertia = simd_double3.zero
        let groundTransformInverse = Transform.identity()
        
        let constraints = intersectCuboidWithGround(cuboid)
        for constraint in constraints {
            let difference = constraint.positions.1 - constraint.positions.0
            let magnitude = length(difference) - constraint.distance
            
            let position = constraint.positions.0
            let positionRestAttidude = cuboid.intoRestAttidue(constraint.positions.0)
            let previousPosition = cuboid.previousOrientation.act(positionRestAttidude) + cuboid.previousPosition
            let deltaPosition = position - previousPosition
            let tangentialDeltaPosition = deltaPosition - project(deltaPosition, normalize(difference))
            let direction = normalize(difference - tangentialDeltaPosition)
            
            let angularImpulseDual0 = cuboid.orientation.inverse.act(cross(constraint.positions.0 - cuboid.position, direction))
            let angularImpulseDual1 = groundTransformInverse.rotate(cross(constraint.positions.1, direction))
            
            let generalizedInverseMass0 = cuboid.inverseMass + dot(angularImpulseDual0 * cuboid.inverseInertia, angularImpulseDual0)
            let generalizedInverseMass1 = groundInverseMass + dot(angularImpulseDual1 * groundInverseInertia, angularImpulseDual1)
            
            let lagrangeMultiplier = magnitude / (generalizedInverseMass0 + generalizedInverseMass1 + timeStepCompliance)
            let impulse = lagrangeMultiplier * direction
            
            let translation0 = impulse * cuboid.inverseMass
            let translation1 = impulse * groundInverseMass
            
            let rotation0 = 0.5 * simd_quatd(real: 0, imag: cross(constraint.positions.0 - cuboid.position, impulse)) * cuboid.orientation
            let rotation1 = 0.5 * simd_quatd(real: 0, imag: cross(constraint.positions.1, impulse)) * groundOrientation
            cuboid.position += translation0
            cuboid.orientation = (cuboid.orientation + rotation0).normalized
            
            groundPosition += translation1
            groundOrientation = (groundOrientation + rotation1).normalized
        }
        
        cuboid.velocity = (cuboid.position - cuboid.previousPosition) / subDeltaTime
        
        let rotation = cuboid.orientation * cuboid.previousOrientation.inverse
        cuboid.angularVelocity = 2.0 * rotation.imag / subDeltaTime
        if rotation.real < 0 {
            cuboid.angularVelocity = -cuboid.angularVelocity
        }
    }
    
}
