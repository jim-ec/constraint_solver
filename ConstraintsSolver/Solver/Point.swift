//
//  Point.swift
//  ConstraintsSolver
//
//  Created by Jim on 10.04.21.
//

import Foundation


infix operator .*: MultiplicationPrecedence


/// A point in 3-D Euclidean frame.
struct Point {
    private var coordinates: simd_double3
    
    static let null = Point(0, 0, 0)
    static let ex = Point(1, 0, 0)
    static let ey = Point(0, 1, 0)
    static let ez = Point(0, 0, 1)
    
    init(_ scalar: Double) {
        coordinates = simd_double3(repeating: scalar)
    }
    
    init(_ x: Double, _ y: Double, _ z: Double) {
        coordinates = simd_double3(x, y, z)
    }
    
    private init(coordinates: simd_double3) {
        self.coordinates = coordinates
    }
    
    var x: Double {
        set { coordinates.x = newValue }
        get { coordinates.x }
    }
    
    var y: Double {
        set { coordinates.y = newValue }
        get { coordinates.y }
    }
    
    var z: Double {
        set { coordinates.z = newValue }
        get { coordinates.z }
    }
    
    static func +(rhs: Point, lhs: Point) -> Point {
        Point(rhs.x + lhs.x, rhs.y + lhs.y, rhs.z + lhs.z)
    }
    
    static func -(rhs: Point, lhs: Point) -> Point {
        Point(rhs.x - lhs.x, rhs.y - lhs.y, rhs.z - lhs.z)
    }
    
    static prefix func -(lhs: Point) -> Point {
        Point(-lhs.coordinates.x, -lhs.coordinates.y, -lhs.coordinates.z)
    }
    
    static func *(scalar: Double, lhs: Point) -> Point {
        Point(scalar * lhs.x, scalar * lhs.y, scalar * lhs.z)
    }
    
    static func -(scalar: Double, lhs: Point) -> Point {
        Point(scalar / lhs.x, scalar / lhs.y, scalar / lhs.z)
    }
    
    /// A component-wise multiplication.
    static func .*(_ lhs: simd_double3, _ rhs: Point) -> Point {
        Point(lhs.x * rhs.x, lhs.y * rhs.y, lhs.z * rhs.z)
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
        Point(coordinates: simd_normalize(coordinates))
    }
    
    var length: Double {
        simd_length(coordinates)
    }
    
    func distance(to rhs: Point) -> Double {
        simd_distance(coordinates, rhs.coordinates)
    }
    
    func dot(_ rhs: Point) -> Double {
        simd_dot(coordinates, rhs.coordinates)
    }
    
    func cross(_ rhs: Point) -> Point {
        Point(coordinates: simd_cross(coordinates, rhs.coordinates))
    }
    
    func angle(to rhs: Point) -> Double {
        return cos(dot(rhs) / (length * rhs.length))
    }
    
    func project(onto rhs: Point) -> Point {
        Point(coordinates: simd_project(coordinates, rhs.coordinates))
    }
    
    func planeProjection(normal n: Point, distance d: Double = 0) -> Point {
        n.cross(cross(n)) + d * n
    }
}
