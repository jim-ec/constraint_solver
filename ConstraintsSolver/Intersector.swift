//
//  Intersector.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 28.10.20.
//

import Foundation

struct Contact {
    var body: Cuboid
    let normal: simd_double3
    let magnitude: Double
    let penetratingVertex: simd_double3
}

extension Double {
    func sqare() -> Double {
        self * self
    }
}

class Cuboid {
    let extent: simd_double3
    let mass: Double
    var externalForce: simd_double3
    var velocity: simd_double3
    var angularVelocity: simd_double3
    var previousTransform: Transform
    var transform: Transform
    
    init(mass: Double, extent: simd_double3) {
        self.mass = mass
        self.extent = extent
        self.velocity = .zero
        self.angularVelocity = .zero
        self.transform = .identity()
        self.previousTransform = .identity()
        self.externalForce = .zero
    }
    
    func inertiaTensor() -> simd_double3 {
        1.0 / 12.0 * mass * simd_double3(
            extent.y * extent.y + extent.z * extent.z,
            extent.x * extent.x + extent.z * extent.z,
            extent.x * extent.x + extent.y * extent.y
        )
    }
    
    func inverseInertiaTensor() -> simd_double3 {
        1 / inertiaTensor()
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
func intersectCuboidWithGround(_ cuboid: Cuboid) -> Contact? {
    let deepestVertex = cuboid.vertices().min { a, b in a.z < b.z }!
    
    if deepestVertex.z >= 0 {
        return .none
    }
    
    let normal = simd_double3(0, 0, 1)
    let deepestVertexRestSpace = cuboid.transform.inverse().act(on: deepestVertex)
    let normalRestSpace = cuboid.transform.inverse().rotate(normal)
    
    return Contact(
        body: cuboid,
        normal: normalRestSpace,
        magnitude: -deepestVertex.z,
        penetratingVertex: deepestVertexRestSpace
    )
}

func solveConstraints(cuboid: Cuboid) {
    let countOfSubSteps = 10
    for _ in 0..<countOfSubSteps {
        if let contact = intersectCuboidWithGround(cuboid) {
            let inverseMass = 1.0 / contact.body.mass
            let conormal = cross(contact.penetratingVertex, contact.normal)
            let tau = dot(conormal * contact.body.inverseInertiaTensor(), conormal)
            let generalizedInverseMass = inverseMass + tau
            
            let impulse = -contact.magnitude / generalizedInverseMass * contact.normal
            let angularVelocity = simd_quatd(real: 0, imag: cross(contact.penetratingVertex, impulse))
            
            let deltaTranslation = impulse / contact.body.mass
            let deltaRotation = 0.5 * angularVelocity * contact.body.transform.rotation
            
            contact.body.transform.translation -= deltaTranslation
            
            contact.body.transform.rotation -= deltaRotation
            contact.body.transform.rotation = contact.body.transform.rotation.normalized
        }
    }
}
