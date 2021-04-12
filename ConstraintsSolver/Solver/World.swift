//
//  World.swift
//  ConstraintsSolver
//
//  Created by Jim on 08.04.21.
//

import Foundation

class World {
    private let integrator = SubStepIntegrator(subStepCount: 50)
    private let cubeMesh1: Mesh
    private let cubeMesh2: Mesh
    private let cube1: Rigid
    private let cube2: Rigid
    private let ground: Rigid
    
    init(renderer: Renderer) {
        cubeMesh1 = Mesh.makeCube(name: "Cube", color: .white)
        cubeMesh1.map { $0 - simd_float3(0.5, 0.5, 0.5) }
        renderer.registerMesh(cubeMesh1)
        
        cubeMesh2 = Mesh.makeCube(name: "Cube", color: .white)
        cubeMesh2.map { $0 - simd_float3(0.5, 0.5, 0.5) }
        renderer.registerMesh(cubeMesh2)
        
        cube1 = Rigid(collider: .box(BoxCollider()), mass: 1)
        cube1.frame.quaternion = Quaternion(by: .pi / 8, around: .ey + 0.5 * .ex)
        cube1.frame.position = Point(0, -2, 4)
        cube1.externalForce = -9.81 * .ez
        cube1.angularVelocity = Point(1, 2, 0.1)
        cube1.velocity = 4 * .ey
        
        cube2 = Rigid(collider: .box(BoxCollider()), mass: 2)
        cube2.frame.position = Point(1, 1, 3)
        cube2.frame.quaternion = Quaternion(by: .pi / 8, around: .ey + 0.25 * .ex)
        cube2.externalForce = -9.81 * .ez
        cube2.angularVelocity = Point(1, 2, 0.1)
        cube2.velocity = -2 * .ex
        
        ground = Rigid(collider: .plane(Plane(direction: .ez, offset: 0)), mass: nil)
    }
    
    func integrate(dt: Double) {
        integrator.integrate([cube1, cube2, ground], by: dt)
        cubeMesh1.transform = cube1.frame.matrix
        cubeMesh2.transform = cube2.frame.matrix
    }
}
