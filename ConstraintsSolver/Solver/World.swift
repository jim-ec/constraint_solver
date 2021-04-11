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
    private let cube: RigidBody
    
    init(renderer: Renderer) {
        cubeMesh = Mesh.makeCube(name: "Cube", color: .white)
        cubeMesh.map { x in x - simd_float3(0.5, 0.5, 0.5) }
        renderer.registerMesh(cubeMesh)
        
        cube = RigidBody(collider: Collider(), mass: 1)
        cube.frame.quaternion = Quaternion(by: .pi / 8, around: .ey + 0.5 * .ex)
        cube.frame.position = Point(0, -2, 4)
        cube.externalForce.z = -9.81
        cube.angularVelocity = .init(1, 2, 0.5)
        cube.velocity.y = 4
    }
    
    func integrate(dt: Double) {
        integrator.integrate([cube], by: dt)
        cubeMesh.transform = cube.frame.matrix
    }
}
