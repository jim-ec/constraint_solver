//
//  World.swift
//  ConstraintsSolver
//
//  Created by Jim on 08.04.21.
//

import Foundation

class World {
    private let integrator = SubStepIntegrator(subStepCount: 10)
    private let cubeMesh: Mesh
    private let cube: Collider
    
    init(renderer: Renderer) {
        cubeMesh = Mesh.makeCube(name: "Cube", color: .white)
        cubeMesh.map { x in x - simd_float3(0.5, 0.5, 0.5) }
        renderer.registerMesh(cubeMesh)
        
        cube = Collider(rigidBody: RigidBody(mass: 1))
        
        cube.rigidBody.frame.quaternion = Quaternion(by: .pi / 8, around: .ey + 0.5 * .ex)
        cube.rigidBody.frame.position = Point(0, -2, 4)
        cube.rigidBody.externalForce.z = -9.81
        cube.rigidBody.angularVelocity = .init(1, 2, 0.5)
        cube.rigidBody.velocity.y = 4
    }
    
    func integrate(dt: Double) {
        integrator.integrate([cube], by: dt)
        cubeMesh.transform = cube.rigidBody.frame.matrix
    }
}
