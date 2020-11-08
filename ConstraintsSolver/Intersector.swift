//
//  Intersector.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 28.10.20.
//

import Foundation

struct Contact {
    var body: Cuboid
    let normal: simd_float3
    let magnitude: Float
    let penetratingVertex: simd_float3
}

extension Float {
    func sqare() -> Float {
        self * self
    }
}

/// TODO: Resting or not?
/// A cuboid located at the origin, extending in the positive axis directions.
/// A resting cuboid.
class Cuboid {
    let mass: Float
    var velocity: simd_float3
    let extent: simd_float3
    var transform: Transform
    
    init(mass: Float, extent: simd_float3) {
        self.mass = mass
        self.extent = extent
        self.velocity = .zero
        self.transform = .identity()
    }
    
    func restTransform() -> Transform {
        //.translation(simd_float3(-extent.x, -extent.y, -extent.z))
        .identity()
    }
    
    func inertiaTensor() -> simd_float3 {
        1.0 / 12.0 * mass * simd_float3(
            extent.y * extent.y + extent.z * extent.z,
            extent.x * extent.x + extent.z * extent.z,
            extent.x * extent.x + extent.y * extent.y
        )
//        .e2 * (1 / 12 * mass * (extent.x * extent.x + extent.z * extent.z))
    }
    
    func inverseInertiaTensor() -> simd_float3 {
        1 / inertiaTensor()
    }
}

/// Intersects a cube with the plane defined by `z = 0`, returning the penetration vector.
func intersectCuboidWithGround(_ cuboid: Cuboid) -> Contact? {
    let canonicalVertices: [simd_float3] = [
        simd_float3(0, 0, 0),
        simd_float3(cuboid.extent.x, 0, 0),
        simd_float3(0, cuboid.extent.y, 0),
        simd_float3(cuboid.extent.x, cuboid.extent.y, 0),
        simd_float3(0, 0, cuboid.extent.z),
        simd_float3(cuboid.extent.x, 0, cuboid.extent.z),
        simd_float3(0, cuboid.extent.y, cuboid.extent.z),
        simd_float3(cuboid.extent.x, cuboid.extent.y, cuboid.extent.z)
    ]
    
    let vertices = canonicalVertices.map { x in x - 0.5 * cuboid.extent }.map(cuboid.transform.act)
    let deepestVertex = vertices.min { a, b in a.z < b.z }!
    
    if deepestVertex.z >= 0 {
        return .none
    }
    
    let normal = simd_float3(0, 0, 1)
    let deepestVertexRestSpace = (cuboid.restTransform() * cuboid.transform.inverse()).act(on: deepestVertex)
//    let collisionNormalRestSpace = cuboid.restTransform().act(on: simd_float3(0, 0, -1))
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
            let inverseMass: Float = 1 / contact.body.mass
            let conormal = cross(contact.penetratingVertex, contact.normal)
            let tau = dot(conormal * contact.body.inverseInertiaTensor(), conormal)
            let generalizedInverseMass = inverseMass + tau
            
            let impulse = -contact.magnitude / generalizedInverseMass * contact.normal
            let angularVelocity = simd_quatf(real: 0, imag: cross(contact.penetratingVertex, impulse))
            
            let deltaTranslation = impulse / contact.body.mass
            let deltaRotation = 0.5 * angularVelocity * contact.body.transform.rotation
            
            contact.body.transform.translation -= deltaTranslation
            
            contact.body.transform.rotation -= deltaRotation
            contact.body.transform.rotation = contact.body.transform.rotation.normalized
        }
    }
}
