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

/// A cuboid located at the origin, extending in the positive axis directions.
class Cuboid {
    let mass: Double
    var velocity: simd_double3
    let extent: simd_double3
    var transform: Transform
    
    init(mass: Double, extent: simd_double3) {
        self.mass = mass
        self.extent = extent
        self.velocity = .zero
        self.transform = .identity()
    }
    
    func restTransform() -> Transform {
        .translation(0.5 * simd_double3(-extent.x, -extent.y, -extent.z))
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
}

/// Intersects a cube with the plane defined by `z = 0`, returning the penetration vector.
func intersectCuboidWithGround(_ cuboid: Cuboid) -> Contact? {
    let canonicalVertices: [simd_double3] = [
        .init(0, 0, 0),
        .init(cuboid.extent.x, 0, 0),
        .init(0, cuboid.extent.y, 0),
        .init(cuboid.extent.x, cuboid.extent.y, 0),
        .init(0, 0, cuboid.extent.z),
        .init(cuboid.extent.x, 0, cuboid.extent.z),
        .init(0, cuboid.extent.y, cuboid.extent.z),
        .init(cuboid.extent.x, cuboid.extent.y, cuboid.extent.z)
    ]
    
    let vertices = canonicalVertices.map(cuboid.transform.act)
    let deepestVertex = vertices.min { a, b in a.z < b.z }!
    
    if deepestVertex.z >= 0 {
        return .none
    }
    
    let normal = simd_double3(0, 0, 1)
    let deepestVertexRestSpace = (cuboid.restTransform() * cuboid.transform.inverse()).act(on: deepestVertex)
    let normalRestSpace = (cuboid.restTransform() * cuboid.transform.inverse()).rotate(normal)
    
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
