//
//  Camera.swift
//  ConstraintsSolver
//
//  Created by Jim on 08.04.21.
//

import Foundation


public struct Camera {
    var position: double3
    var radius: Double
    var right: double3
    var forward: double3
    
    init() {
        position = double3(0, -1, 0)
        radius = 1
        right = double3(1, 0, 0)
        forward = double3(0, 0, 0)
    }
    
    var up: double3 {
        forward.cross(-right).normalize
    }
    
    var focus: double3 {
        position + radius * forward
    }
    
    var viewMatrix: simd_double4x4 {
        let matrix = simd_double4x4(columns: (
            simd_double4(right, 0),
            simd_double4(up, 0),
            simd_double4(-forward, 0),
            simd_double4(position, 1)
        ))
        
        let inverse = simd_double4x4(columns: (
            simd_double4(matrix[0].x, matrix[1].x, matrix[2].x, 0),
            simd_double4(matrix[0].y, matrix[1].y, matrix[2].y, 0),
            simd_double4(matrix[0].z, matrix[1].z, matrix[2].z, 0),
            simd_double4(
                -dot(matrix[0], matrix[3]),
                -dot(matrix[1], matrix[3]),
                -dot(matrix[2], matrix[3]),
                1
            )
        ))
        
        return inverse
    }
    
    mutating func look(at focus: double3, from position: double3, up: double3)
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
    
}
