//
//  Quaternion.swift
//  ConstraintsSolver
//
//  Created by Jim on 10.04.21.
//

import Foundation


// A functor, able to rotate positions.
struct Quaternion {
    var coordinates: simd_quatd // TODO: Make fileprivate
    
    static let identity = Quaternion(coordinates: simd_quatd(ix: 0, iy: 0, iz: 0, r: 1))
    
    init(by angle: Double, around axis: Point) {
        coordinates = simd_quatd(angle: angle, axis: axis.coordinates)
    }
    
    fileprivate init(coordinates: simd_quatd) {
        self.coordinates = coordinates
    }
    
    static func *(lhs: Quaternion, rhs: Quaternion) -> Quaternion {
        Quaternion(coordinates: lhs.coordinates * rhs.coordinates)
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
