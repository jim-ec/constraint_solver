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
        
        cube.rigidBody.orientation = .init(angle: .pi / 8, axis: .ey + 0.5 * .ex)
        cube.rigidBody.position = double3(0, 0, 4)
        cube.rigidBody.externalForce.z = -9.81
        cube.rigidBody.angularVelocity = .init(1, 2, 0.5)
    }
    
    func integrate(dt: Double) {
        integrator.integrate([cube], by: dt)
        cubeMesh.transform.position = cube.rigidBody.position
        cubeMesh.transform.orientation = cube.rigidBody.orientation
    }
}
