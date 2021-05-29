//
//  Point.swift
//  ConstraintsSolver
//
//  Created by Jim on 10.04.21.
//

import Foundation


infix operator .*: MultiplicationPrecedence


extension Double {
    var sq: Double {
        self * self
    }
}


/// A point in 3-D Euclidean frame.
struct Point {
    var ex: Double
    var ey: Double
    var ez: Double
    
    static let null = Point(0, 0, 0)
    static let ex = Point(1, 0, 0)
    static let ey = Point(0, 1, 0)
    static let ez = Point(0, 0, 1)
    
    init(_ scalar: Double) {
        ex = scalar
        ey = scalar
        ez = scalar
    }
    
    init(_ ex: Double, _ ey: Double, _ ez: Double) {
        self.ex = ex
        self.ey = ey
        self.ez = ez
    }
    
    static func +(rhs: Point, lhs: Point) -> Point {
        Point(rhs.ex + lhs.ex, rhs.ey + lhs.ey, rhs.ez + lhs.ez)
    }
    
    static func -(rhs: Point, lhs: Point) -> Point {
        Point(rhs.ex - lhs.ex, rhs.ey - lhs.ey, rhs.ez - lhs.ez)
    }
    
    static prefix func -(lhs: Point) -> Point {
        Point(-lhs.ex, -lhs.ey, -lhs.ez)
    }
    
    static func *(scalar: Double, lhs: Point) -> Point {
        Point(scalar * lhs.ex, scalar * lhs.ey, scalar * lhs.ez)
    }
    
    static func -(scalar: Double, lhs: Point) -> Point {
        Point(scalar / lhs.ex, scalar / lhs.ey, scalar / lhs.ez)
    }
    
    /// A component-wise multiplication.
    static func .*(_ lhs: Point, _ rhs: Point) -> Point {
        Point(lhs.ex * rhs.ex, lhs.ey * rhs.ey, lhs.ez * rhs.ez)
    }
    
    /// Constructs a vector pointing from `self` to `target`.
    func to(_ target: Point) -> Point {
        target - self
    }
    
    func integrate(by dt: Double, velocity: Point) -> Point {
        let delta = dt * velocity
        return self + delta
    }
    
    func derive(by dt: Double, _ past: Point) -> Point {
        (1 / dt) * (self - past)
    }
    
    var normalize: Point {
        (1 / length) * self
    }
    
    var length: Double {
        (ex.sq + ey.sq + ez.sq).squareRoot()
    }
    
    func distance(to rhs: Point) -> Double {
        (rhs - self).length
    }
    
    func dot(_ rhs: Point) -> Double {
        ex * rhs.ex + ey * rhs.ey + ez * rhs.ez
    }
    
    func cross(_ rhs: Point) -> Point {
        Point(
            ey * rhs.ez - ez * rhs.ey,
            ez * rhs.ex - ex * rhs.ez,
            ex * rhs.ey - ey * rhs.ex
        )
    }
    
    func angle(to rhs: Point) -> Double {
        return cos(dot(rhs) / (length * rhs.length))
    }
    
    func project(onto point: Point) -> Point {
        self.dot(point) / point.dot(point) * point
    }
    
    func project(onto plane: Plane) -> Point {
        plane.normal.cross(cross(plane.normal)) + plane.offset * plane.normal
    }
    
    func reject(from plane: Plane) -> Point {
        project(onto: plane).to(self)
    }
    
    func rotate(by angle: Double, around axis: Point) -> Point {
        let c = cos(angle)
        let s = sin(angle)
        
        let temp = (1 - c) * axis
        
        var rotationMatrix = simd_double4x4(diagonal: .init(repeating: 1))
        rotationMatrix[0][0] = c + temp.ex * axis.ex
        rotationMatrix[0][1] = temp.ex * axis.ey + s * axis.ez
        rotationMatrix[0][2] = temp.ex * axis.ez - s * axis.ey

        rotationMatrix[1][0] = temp.ey * axis.ex - s * axis.ez
        rotationMatrix[1][1] = c + temp.ey * axis.ey
        rotationMatrix[1][2] = temp.ey * axis.ez + s * axis.ex

        rotationMatrix[2][0] = temp.ez * axis.ex + s * axis.ey
        rotationMatrix[2][1] = temp.ez * axis.ey - s * axis.ex
        rotationMatrix[2][2] = c + temp.ez * axis.ez
        
        let rotated = rotationMatrix * simd_double4(ex, ey, ez, 1)
        return Point(rotated.x, rotated.y, rotated.z)
    }
    
    var str: String {
        String(format: "(%.3f, %.3f, %.3f)", ex, ey, ez)
    }
}

extension Point: CustomDebugStringConvertible {
    var debugDescription: String {
        "(\(ex), \(ey), \(ey))"
    }
}
