//
//  Quaternion.swift
//  ConstraintsSolver
//
//  Created by Jim on 10.04.21.
//

import Foundation


infix operator ^+: AdditionPrecedence


// A functor, able to rotate positions.
struct Quaternion {
    private var coordinates: simd_quatd
    
    static let identity = Quaternion(coordinates: simd_quatd(ix: 0, iy: 0, iz: 0, r: 1))
    
    /// Axis-angle constructor.
    init(by angle: Double, around axis: Point) {
        coordinates = simd_quatd(angle: angle, axis: axis.coordinates)
    }
    
    /// Constructs a pure imaginary quaternion.
    init(bivector: Point) {
        coordinates = simd_quatd(ix: bivector.x, iy: bivector.y, iz: bivector.z, r: 0)
    }
    
    private init(coordinates: simd_quatd) {
        self.coordinates = coordinates
    }
    
    var matrix: simd_float3x3 {
        simd_float3x3(simd_quatf(
            ix: Float(coordinates.imag.x),
            iy: Float(coordinates.imag.y),
            iz: Float(coordinates.imag.z),
            r: Float(coordinates.real)
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
    
    func act(on position: Point) -> Point {
        let rotated = coordinates.act(position.coordinates)
        return Point(rotated.x, rotated.y, rotated.z)
    }
    
    func integrate(by dt: Double, velocity: Rotation) -> Quaternion {
        let delta = dt * 0.5 * simd_quatd(real: .zero, imag: velocity) * coordinates
        return Quaternion(coordinates: (coordinates + delta).normalized)
    }
    
    func derive(by dt: Double, _ past: Quaternion) -> Rotation {
        let deltaOrientation = coordinates / past.coordinates / dt
        var velocity = 2.0 * deltaOrientation.imag
        if deltaOrientation.real < 0 {
            velocity = -velocity
        }
        return velocity
    }
}
