//
//  Attitude.swift
//  ConstraintsSolver
//
//  Created by Jim on 10.04.21.
//

import Foundation


typealias Rotation = simd_double3


struct Space {
    var position: Point
    var quaternion: Quaternion
    
    static let identity = Space(position: .null, quaternion: .identity)
    
    init(position: Point = .null, quaternion: Quaternion = .identity) {
        self.position = position
        self.quaternion = quaternion
    }
    
    var matrix: simd_float4x4 {
        let upperLeft = simd_float3x3(simd_quatf(
            ix: Float(quaternion.coordinates.imag.x),
            iy: Float(quaternion.coordinates.imag.y),
            iz: Float(quaternion.coordinates.imag.z),
            r: Float(quaternion.coordinates.real)
        ))
        let translation = simd_float3(
            Float(position.x),
            Float(position.y),
            Float(position.z)
        )
        return simd_float4x4(
            simd_float4(upperLeft[0], 0),
            simd_float4(upperLeft[1], 0),
            simd_float4(upperLeft[2], 0),
            simd_float4(translation, 1))
    }
    
    var inverse: Space {
        let inverseOrientation = quaternion.inverse
        return Space(position: inverseOrientation.act(on: -position),
                     quaternion: inverseOrientation)
    }
    
    func act(_ x: Point) -> Point {
        quaternion.act(on: x) + position
    }
    
    func integrate(by dt: Double, linearVelocity: Point, angularVelocity: Rotation) -> Space {
        Space(position: position.integrate(by: dt, velocity: linearVelocity),
              quaternion: quaternion.integrate(by: dt, velocity: angularVelocity))
    }
    
    func derive(for dt: Double, _ past: Space) -> (Point, Rotation) {
        (position: position.derive(by: dt, past.position),
         quaternion: quaternion.derive(by: dt, past.quaternion))
    }
    
    mutating func translate(by translation: Point) {
        position = position + translation
    }
}
