//
//  Intersector.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 28.10.20.
//

import Foundation

func intersectGround(_ rigidBody: RigidBody) -> [PositionalConstraint] {
    rigidBody.vertices().filter { vertex in vertex.z < 0 }.map { position in
        let targetPosition = simd_double3(position.x, position.y, 0)
        let difference = targetPosition - position
        
        let deltaPosition = position - rigidBody.intoPreviousAttidue(position)
        let deltaTangentialPosition = deltaPosition - project(deltaPosition, difference)
        
        return PositionalConstraint(
            body: rigidBody,
            positions: (position, targetPosition - deltaTangentialPosition),
            distance: 0,
            compliance: 0.0000001
        )
    }
}

fileprivate enum Simplex {
    case point(simd_float3)
    case line(simd_float3, simd_float3)
    case triangle(simd_float3, simd_float3, simd_float3)
    case tetrahedron(simd_float3, simd_float3, simd_float3, simd_float3)
}

func gjk(a: (simd_float3) -> simd_float3, b: (simd_float3) -> simd_float3) -> Bool {
    
    /// Returns the point within the Minkowski difference which is furthest away from the origin in the given direction.
    func support(in direction: simd_float3) -> simd_float3 {
        a(direction) - b(-direction)
    }
    
    let initialSearchDirection = support(in: simd_float3.random(in: 0...1))
    var simplex = Simplex.point(initialSearchDirection)
    var searchDirection = -initialSearchDirection
    
    while true {
        let nextPoint = support(in: searchDirection)
        
        if dot(nextPoint, searchDirection) < 0 {
            return false
        }
        
        if nextSimplex(simplex: &simplex, direction: &searchDirection) {
            return true
        }
    }
}

fileprivate func nextSimplex(simplex: inout Simplex, direction a: inout simd_float3) -> Bool {
    
    /// Returns true if the given direction points to the origin.
    func test(_ x: simd_float3) -> Bool {
        dot(x, -a) > 0
    }
    
    /// Triple cross product.
    func cross3(_ x: simd_float3, _ y: simd_float3, _ z: simd_float3) -> simd_float3 {
        cross(cross(x, y), z)
    }
    
    switch simplex {
    case let .point(b):
        if test(cross(a, b)) {
            simplex = .line(a, b)
            a = cross3(b - a, -a, b - a)
        }
        else {
            simplex = .point(a)
            a = -a
        }
    case let .line(b, c):
        let ao = -a
        let ab = b - a
        let ac = c - a
        let abc = cross(ab, ac)
        if test(cross(abc, ac)) {
            if test(ac) {
                simplex = .line(a, c)
                a = cross3(ac, ao, ac)
            }
            else {
                if test(ab) {
                    simplex = .line(a, b)
                    a = cross3(ab, ao, ab)
                }
                else {
                    simplex = .point(a)
                    a = ao
                }
            }
        }
        else {
            if test(cross(ab, abc)) {
                if test(ab) {
                    simplex = .line(a, b)
                    a = cross3(ab, ao, ab)
                }
                else {
                    simplex = .point(a)
                    a = ao
                }
            }
            else {
                if test(abc) {
                    simplex = .triangle(a, b, c)
                    a = abc
                }
                else {
                    simplex = .triangle(a, c, b)
                    a = -abc
                }
            }
        }
    default:
        fatalError()
    }
    
    return true
}
