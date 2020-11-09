//
//  Intersector.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 28.10.20.
//

import Foundation

struct Contact {
    var body: Cuboid
    let n: simd_double3
    let c: Double
    let r: simd_double3
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
    let verticesBelowGround = cuboid.vertices().filter { v in v.z < 0 }
    
    if verticesBelowGround.isEmpty {
        return .none
    }
    
    var deepestVertex = verticesBelowGround[0]
    for v in verticesBelowGround.dropFirst(1) {
        deepestVertex += v
    }
    deepestVertex /= Double(verticesBelowGround.count)
    
//    let deepestVertex = cuboid.vertices().min { a, b in a.z < b.z }!
//
//    if deepestVertex.z >= 0 {
//        return .none
//    }
//
    let normal = simd_double3(0, 0, 1)
    let deepestVertexRestSpace = cuboid.transform.inverse().act(on: deepestVertex)
    let normalRestSpace = cuboid.transform.inverse().rotate(normal)

    return Contact(
        body: cuboid,
        n: normalRestSpace,
        c: -deepestVertex.z,
        r: deepestVertexRestSpace
    )
}

func solveConstraints(dt: Double, cuboid: Cuboid) {
    let countOfSubSteps = 100
    let h = dt / Double(countOfSubSteps)
    
    for _ in 0..<countOfSubSteps {
        cuboid.previousTransform = cuboid.transform
        
        cuboid.velocity += h * cuboid.externalForce / cuboid.mass
        cuboid.transform.translation += h * cuboid.velocity
        
        //        cuboid.angularVelocity += dt *
        cuboid.transform.rotation += h * 0.5 * simd_quatd(real: .zero, imag: cuboid.angularVelocity) * cuboid.transform.rotation
        cuboid.transform.rotation = cuboid.transform.rotation.normalized
        
        if let contact = intersectCuboidWithGround(cuboid) {
            let inverseMass = 1.0 / contact.body.mass
            let conormal = cross(contact.r, contact.n)
            let tau = dot(conormal * contact.body.inverseInertiaTensor(), conormal)
            let generalizedInverseMass = inverseMass + tau
            
            let impulse = -contact.c / generalizedInverseMass * contact.n
            let angularVelocity = simd_quatd(real: 0, imag: cross(contact.r, impulse))
            
            let deltaTranslation = impulse / contact.body.mass
            let deltaRotation = 0.5 * angularVelocity * contact.body.transform.rotation
            
            let deltaTranslationGlobal = cuboid.transform.rotate(deltaTranslation)
            let deltaRotationGlobal = cuboid.transform.rotation * deltaRotation
            
            contact.body.transform.translation -= deltaTranslationGlobal
            
            contact.body.transform.rotation -= deltaRotationGlobal
            contact.body.transform.rotation = contact.body.transform.rotation.normalized
        }
        
        cuboid.velocity = (cuboid.transform.translation - cuboid.previousTransform.translation) / h
        
        let deltaRotation = (cuboid.transform.rotation * cuboid.previousTransform.rotation.inverse).normalized
        cuboid.angularVelocity = 2.0 * deltaRotation.imag / h
        if deltaRotation.real < 0 {
            cuboid.angularVelocity = -cuboid.angularVelocity
        }
    }
    
}
