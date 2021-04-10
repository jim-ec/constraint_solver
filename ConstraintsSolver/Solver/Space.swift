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
    var orientation: Orientation
    
    static let identity = Space(position: .null, orientation: .identity)
    
    init(position: Point = .null, orientation: Orientation = .identity) {
        self.position = position
        self.orientation = orientation
    }
    
    var matrix: simd_float4x4 {
        let upperLeft = simd_float3x3(simd_quatf(
            ix: Float(orientation.coordinates.imag.x),
            iy: Float(orientation.coordinates.imag.y),
            iz: Float(orientation.coordinates.imag.z),
            r: Float(orientation.coordinates.real)
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
        let inverseOrientation = orientation.inverse
        return Space(position: inverseOrientation.act(on: -position),
                     orientation: inverseOrientation)
    }
    
    func leave(_ x: Point) -> Point {
        orientation.act(on: x) + position
    }
    
    func enter(_ x: Point) -> Point {
        inverse.leave(x)
    }
    
    func integrate(by dt: Double, linearVelocity: Point, angularVelocity: Rotation) -> Space {
        Space(position: position.integrate(by: dt, velocity: linearVelocity),
              orientation: orientation.integrate(by: dt, velocity: angularVelocity))
    }
    
    func derive(for dt: Double, _ past: Space) -> (Point, Rotation) {
        (position: position.derive(by: dt, past.position),
         orientation: orientation.derive(by: dt, past.orientation))
    }
    
    mutating func translate(by translation: Point) {
        position = position + translation
    }
}
