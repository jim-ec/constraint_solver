//
//  World.swift
//  ConstraintsSolver
//
//  Created by Jim on 08.04.21.
//

import Foundation

class World {
    private let solver = Solver(subStepCount: 10, collisionGroup: CollisionGroup(rigidBody: RigidBody(mass: 1, extent: double3(1, 1, 1))))
    private let cubeMesh: Mesh
    private let cube: RigidBody
    
    init(renderer: Renderer) {
        cubeMesh = Mesh.makeCube(name: "Cube", color: .white)
        cubeMesh.map { x in x - simd_float3(0.5, 0.5, 0.5) }
        renderer.registerMesh(cubeMesh)
        
        cube = solver.collisionGroup.rigidBody
        cube.orientation = .init(angle: .pi / 8, axis: .ey + 0.5 * .ex)
        cube.position = double3(0, 0, 4)
        cube.externalForce.z = -5
        cube.angularVelocity = .init(1, 2, 0.5)
        
        let X = Mesh.makeCube(name: "x", color: .red)
        X.map(by: Transform.position(-X.findCenterOfMass()))
        X.map { x in x * 0.5 }
        X.transform.position.x = 4
        renderer.registerMesh(X)
        
        let Y = Mesh.makeCube(name: "y", color: .green)
        Y.map(by: Transform.position(-Y.findCenterOfMass()))
        Y.map { x in x * 0.5 }
        Y.transform.position.y = 4
        renderer.registerMesh(Y)
    }
    
    func integrate(dt: Double) {
        solver.step(by: dt)
        cubeMesh.transform.position = cube.position
        cubeMesh.transform.orientation = cube.orientation
    }
}
