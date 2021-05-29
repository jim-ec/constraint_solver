//
//  Attitude.swift
//  ConstraintsSolver
//
//  Created by Jim on 10.04.21.
//

import Foundation


struct Frame {
    var position: Point
    var quaternion: Quaternion
    
    static let identity = Frame(position: .null, quaternion: .identity)
    
    init(position: Point = .null, quaternion: Quaternion = .identity) {
        self.position = position
        self.quaternion = quaternion
    }
    
    var matrix: simd_float4x4 {
        let upperLeft = quaternion.matrix
        let translation = simd_float3(
            Float(position.ex),
            Float(position.ey),
            Float(position.ez)
        )
        return simd_float4x4(
            simd_float4(upperLeft[0], 0),
            simd_float4(upperLeft[1], 0),
            simd_float4(upperLeft[2], 0),
            simd_float4(translation, 1))
    }
    
    var inverse: Frame {
        let inverseOrientation = quaternion.inverse
        return Frame(position: inverseOrientation.act(on: -position),
                     quaternion: inverseOrientation)
    }
    
    func act(_ x: Point) -> Point {
        quaternion.act(on: x) + position
    }
    
    func act(_ plane: Plane) -> Plane {
        let support = (plane.support + position).project(onto: plane.normal)
        let offset = support.dot(plane.normal) > 0 ? support.length : -support.length
        let normal = quaternion.act(on: plane.normal)
        return Plane(direction: normal, offset: offset)
    }
    
    func integrate(by dt: Double, linearVelocity: Point, angularVelocity: Point) -> Frame {
        Frame(position: position.integrate(by: dt, velocity: linearVelocity),
              quaternion: quaternion.integrate(by: dt, velocity: angularVelocity))
    }
    
    func derive(for dt: Double, _ past: Frame) -> (Point, Point) {
        (position: position.derive(by: dt, past.position),
         quaternion: quaternion.derive(by: dt, past.quaternion))
    }
    
    mutating func translate(by translation: Point) {
        position = position + translation
    }
}
