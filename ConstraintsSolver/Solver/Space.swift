//
//  Attitude.swift
//  ConstraintsSolver
//
//  Created by Jim on 10.04.21.
//

import Foundation


typealias Rotation = simd_double3


infix operator .* : MultiplicationPrecedence


/// A point in 3-D Euclidean space.
struct Point {
    var coordinates: simd_double3 // TODO: Make fileprivate
    
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
    
    init(_ copy: Point) {
        coordinates = copy.coordinates
    }
    
    init(from base: Point, to target: Point) {
        self.init(target - base)
    }
    
    fileprivate init(_ values: simd_double3) {
        self.coordinates = values
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
    
    func integrate(by dt: Double, velocity: Point) -> Point {
        let delta = dt * velocity
        return self + delta
    }
    
    func derive(by dt: Double, _ past: Point) -> Point {
        (1 / dt) * (self - past)
    }
    
    var normalize: Point {
        Point(simd_normalize(coordinates))
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
        Point(simd_cross(coordinates, rhs.coordinates))
    }
    
    func angle(to rhs: Point) -> Double {
        return cos(dot(rhs) / (length * rhs.length))
    }
    
    func project(onto rhs: Point) -> Point {
        Point(simd_project(coordinates, rhs.coordinates))
    }
}


extension simd_quatd {
    static var identity: Self {
        Self(ix: 0, iy: 0, iz: 0, r: 1)
    }
}


// A functor, able to rotate positions.
struct Orientation {
    var coordinates: simd_quatd // TODO: Make fileprivate
    
    static let identity = Orientation(simd_quatd.identity)
    
    init(by angle: Double, around axis: Point) {
        coordinates = simd_quatd(angle: angle, axis: axis.coordinates)
    }
    
    init(_ values: simd_quatd) {
        self.coordinates = values
    }
    
    static func *(lhs: Orientation, rhs: Orientation) -> Orientation {
        Orientation(lhs.coordinates * rhs.coordinates)
    }
    
    var inverse: Orientation {
        Orientation(coordinates.inverse)
    }
    
    func act(on position: Point) -> Point {
        Point(coordinates.act(position.coordinates))
    }
    
    func integrate(by dt: Double, velocity: Rotation) -> Orientation {
        let delta = dt * 0.5 * simd_quatd(real: .zero, imag: velocity) * coordinates
        return Orientation((coordinates + delta).normalized)
    }
    
    func derive(by dt: Double, _ past: Orientation) -> Rotation {
        let deltaOrientation = coordinates / past.coordinates / dt
        var velocity = 2.0 * deltaOrientation.imag
        if deltaOrientation.real < 0 {
            velocity = -velocity
        }
        return velocity
    }
}


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
