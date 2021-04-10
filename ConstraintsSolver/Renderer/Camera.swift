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
    
    /// Slides the camera position in the X-Y plane.
    mutating func slide(righwards: Double, forwards: Double)
    {
        position +=
            righwards * right +
            forwards * double3(forward.x, forward.y, 0).normalize
    }
    
}

fileprivate extension double3 {
    func rotate(by angle: Double, around axis: Self) -> Self {
        let c = cos(angle)
        let s = sin(angle)
        
        let temp = (1 - c) * axis
        
        var rotationMatrix = simd_double4x4(diagonal: .init(repeating: 1))
        rotationMatrix[0][0] = c + temp.x * axis.x
        rotationMatrix[0][1] = temp.x * axis.y + s * axis.z
        rotationMatrix[0][2] = temp.x * axis.z - s * axis.y

        rotationMatrix[1][0] = temp.y * axis.x - s * axis.z
        rotationMatrix[1][1] = c + temp.y * axis.y
        rotationMatrix[1][2] = temp.y * axis.z + s * axis.x

        rotationMatrix[2][0] = temp.z * axis.x + s * axis.y
        rotationMatrix[2][1] = temp.z * axis.y - s * axis.x
        rotationMatrix[2][2] = c + temp.z * axis.z
        
        let rotated = rotationMatrix * simd_double4(self, 1)
        return Self(rotated.x, rotated.y, rotated.z)
    }
    
    var normalize: Self {
        simd_normalize(self)
    }
    
    func distance(to rhs: Self) -> Double {
        simd_distance(self, rhs)
    }
}
