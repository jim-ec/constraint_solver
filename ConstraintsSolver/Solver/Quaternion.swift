//
//  Quaternion.swift
//  ConstraintsSolver
//
//  Created by Jim on 10.04.21.
//

import Foundation


infix operator ^+: AdditionPrecedence


/// A unit quaternion.
struct Quaternion {
    private var coordinates: simd_quatd
    
    static let identity = Quaternion(coordinates: simd_quatd(ix: 0, iy: 0, iz: 0, r: 1))
    
    /// Axis-angle constructor.
    init(by angle: Double, around axis: Point) {
        coordinates = simd_quatd(angle: angle, axis: simd_double3(axis.ex, axis.ey, axis.ez))
    }
    
    /// Constructs a pure imaginary quaternion.
    init(bivector: Point) {
        coordinates = simd_quatd(ix: bivector.ex, iy: bivector.ey, iz: bivector.ez, r: 0)
    }
    
    private init(coordinates: simd_quatd) {
        self.coordinates = coordinates
    }
    
    var scalar: Double {
        coordinates.real
    }
    
    var bivector: Point {
        Point(coordinates.imag.x, coordinates.imag.y, coordinates.imag.z)
    }
    
    var matrix: simd_float3x3 {
        simd_float3x3(simd_quatf(
            ix: Float(bivector.ex),
            iy: Float(bivector.ey),
            iz: Float(bivector.ez),
            r: Float(scalar)
        ))
    }
    
    static func *(lhs: Quaternion, rhs: Quaternion) -> Quaternion {
        Quaternion(coordinates: lhs.coordinates * rhs.coordinates)
    }
    
    static func *(scalar: Double, rhs: Quaternion) -> Quaternion {
        Quaternion(coordinates: scalar * rhs.coordinates)
    }
    
    /// Adds two quaternions, then normalizes the result so that it is still a unit quaternion.
    static func ^+(lhs: Quaternion, rhs: Quaternion) -> Quaternion {
        Quaternion(coordinates: (lhs.coordinates + rhs.coordinates).normalized)
    }
    
    var inverse: Quaternion {
        Quaternion(coordinates: coordinates.conjugate)
    }
    
    func act(on v: Point) -> Point {
        let rotated = coordinates.act(simd_double3(v.ex, v.ey, v.ez))
        return Point(rotated.x, rotated.y, rotated.z)
    }
    
    func integrate(by dt: Double, velocity: Point) -> Quaternion {
        let delta = dt * 0.5 * Quaternion(bivector: velocity) * self
        return self ^+ delta
    }
    
    func derive(by dt: Double, _ past: Quaternion) -> Point {
        let delta = (1 / dt) * self * past.inverse
        var velocity = 2.0 * delta.bivector
        if delta.scalar < 0 {
            velocity = -velocity
        }
        return velocity
    }
}
