//
//  Camera.swift
//  ConstraintsSolver
//
//  Created by Jim on 08.04.21.
//

import Foundation


public struct Camera {
    var position: Point
    var radius: Double
    var right: Point
    var forward: Point
    
    init() {
        position = Point(0, -1, 0)
        radius = 1
        right = Point(1, 0, 0)
        forward = Point(0, 0, 0)
    }
    
    var up: Point {
        forward.cross(-right).normalize
    }
    
    var focus: Point {
        position + radius * forward
    }
    
    var viewMatrix: simd_float4x4 {
        let matrix = simd_float4x4(columns: (
            simd_float4(Float(right.x), Float(right.y), Float(right.z), 0),
            simd_float4(Float(up.x), Float(up.y), Float(up.z), 0),
            simd_float4(Float(-forward.x), Float(-forward.y), Float(-forward.z), 0),
            simd_float4(Float(position.x), Float(position.y), Float(position.z), 1)
        ))
        
        let inverse = simd_float4x4(columns: (
            simd_float4(matrix[0].x, matrix[1].x, matrix[2].x, 0),
            simd_float4(matrix[0].y, matrix[1].y, matrix[2].y, 0),
            simd_float4(matrix[0].z, matrix[1].z, matrix[2].z, 0),
            simd_float4(
                -dot(matrix[0], matrix[3]),
                -dot(matrix[1], matrix[3]),
                -dot(matrix[2], matrix[3]),
                1
            )
        ))
        
        return inverse
    }
    
    mutating func look(at focus: Point, from position: Point, up: Point)
    {
        #if DEBUG
        if (focus - position).dot(up) == 1 {
            fatalError("Position, focus, and up vector are colliniear")
        }
        #endif
        radius = focus.distance(to: position)
        forward = (focus - position).normalize
        right = forward.cross(up).normalize
        self.position = position
    }
    
    mutating func turn(rightwards: Double, upwards: Double)
    {
        forward = forward.rotate(by: upwards, around: right)
        forward = forward.rotate(by: -rightwards, around: .ez)
        right = right.rotate(by: -rightwards, around: .ez)
    }
    
    mutating func orbit(rightwards: Double, upwards: Double)
    {
        let orbitCenter = focus
        var orbitPosition = position - focus

        orbitPosition = orbitPosition.rotate(by: -upwards, around: right)
        orbitPosition = orbitPosition.rotate(by: rightwards, around: .ez)
        
        position = orbitCenter + orbitPosition
        forward = forward.rotate(by: -upwards, around: right)
        forward = forward.rotate(by: rightwards, around: .ez)
        right = right.rotate(by: rightwards, around: .ez)
    }
    
    mutating func zoom(by factor: Double)
    {
        let newRadius = radius / factor
        position = position + (radius - newRadius) * forward
        radius = newRadius
    }

    mutating func dolly(by offset: Double)
    {
        position = position + offset * forward
    }

    mutating func pan(rightwards: Double, upwards: Double)
    {
        position = position + rightwards * right + upwards * up
    }
    
    /// Slides the camera position in the X-Y plane.
    mutating func slide(righwards: Double, forwards: Double)
    {
        position = position +
            righwards * right +
            forwards * Point(forward.x, forward.y, 0).normalize
    }
    
}
