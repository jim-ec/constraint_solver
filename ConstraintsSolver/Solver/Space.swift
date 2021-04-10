//
//  Attitude.swift
//  ConstraintsSolver
//
//  Created by Jim on 10.04.21.
//

import Foundation


typealias Rotation = simd_double3


extension simd_double3 {
    static var ex: simd_double3 {
        simd_double3(1, 0, 0)
    }
    
    static var ey: simd_double3 {
        simd_double3(0, 1, 0)
    }
    
    static var ez: simd_double3 {
        simd_double3(0, 0, 1)
    }
    
    var string: String {
        "(\(x), \(y), \(z))"
    }
    
    var singlePrecision: simd_float3 {
        simd_float3(Float(x), Float(y), Float(z))
    }
}


infix operator .* : MultiplicationPrecedence


/// A location in 3-D Euclidean space.
struct Position {
    var p: simd_double3 // TODO: Make fileprivate
    
    static let null = Position(0, 0, 0)
    static let ex = Position(1, 0, 0)
    static let ey = Position(0, 1, 0)
    static let ez = Position(0, 0, 1)
    
    init(_ scalar: Double) {
        p = simd_double3(repeating: scalar)
    }
    
    init(_ x: Double, _ y: Double, _ z: Double) {
        p = simd_double3(x, y, z)
    }
    
    init(_ copy: Position) {
        p = copy.p
    }
    
    init(from base: Position, to target: Position) {
        self.init(target - base)
    }
    
    fileprivate init(_ values: simd_double3) {
        self.p = values
    }
    
    var x: Double {
        set { p.x = newValue }
        get { p.x }
    }
    
    var y: Double {
        set { p.y = newValue }
        get { p.y }
    }
    
    var z: Double {
        set { p.z = newValue }
        get { p.z }
    }
    
    static func +(rhs: Position, lhs: Position) -> Position {
        Position(rhs.x + lhs.x, rhs.y + lhs.y, rhs.z + lhs.z)
    }
    
    static func -(rhs: Position, lhs: Position) -> Position {
        Position(rhs.x - lhs.x, rhs.y - lhs.y, rhs.z - lhs.z)
    }
    
    static prefix func -(lhs: Position) -> Position {
        Position(-lhs.p.x, -lhs.p.y, -lhs.p.z)
    }
    
    static func *(scalar: Double, lhs: Position) -> Position {
        Position(scalar * lhs.x, scalar * lhs.y, scalar * lhs.z)
    }
    
    static func -(scalar: Double, lhs: Position) -> Position {
        Position(scalar / lhs.x, scalar / lhs.y, scalar / lhs.z)
    }
    
    /// A component-wise multiplication.
    static func .*(_ lhs: simd_double3, _ rhs: Position) -> Position {
        Position(lhs.x * rhs.x, lhs.y * rhs.y, lhs.z * rhs.z)
    }
    
    func integrate(by dt: Double, velocity: Position) -> Position {
        let delta = dt * velocity
        return self + delta
    }
    
    func derive(by dt: Double, _ past: Position) -> Position {
        (1 / dt) * (self - past)
    }
    
    var normalize: Position {
        Position(simd_normalize(p))
    }
    
    var length: Double {
        simd_length(p)
    }
    
    func distance(to rhs: Position) -> Double {
        simd_distance(p, rhs.p)
    }
    
    func dot(_ rhs: Position) -> Double {
        simd_dot(p, rhs.p)
    }
    
    func cross(_ rhs: Position) -> Position {
        Position(simd_cross(p, rhs.p))
    }
    
    func angle(to rhs: Position) -> Double {
        return cos(dot(rhs) / (length * rhs.length))
    }
    
    func project(onto rhs: Position) -> Position {
        Position(simd_project(p, rhs.p))
    }
}


extension simd_quatd {
    static var identity: Self {
        Self(ix: 0, iy: 0, iz: 0, r: 1)
    }
}


// A functor, able to rotate positions.
struct Orientation {
    var q: simd_quatd // TODO: Make fileprivate
    
    static let identity = Orientation(simd_quatd.identity)
    
    init(by angle: Double, around axis: Position) {
        q = simd_quatd(angle: angle, axis: axis.p)
    }
    
    init(_ values: simd_quatd) {
        self.q = values
    }
    
    static func *(lhs: Orientation, rhs: Orientation) -> Orientation {
        Orientation(lhs.q * rhs.q)
    }
    
    var inverse: Orientation {
        Orientation(q.inverse)
    }
    
    func act(on position: Position) -> Position {
        Position(q.act(position.p))
    }
    
    func integrate(by dt: Double, velocity: Rotation) -> Orientation {
        let delta = dt * 0.5 * simd_quatd(real: .zero, imag: velocity) * q
        return Orientation((q + delta).normalized)
    }
    
    func derive(by dt: Double, _ past: Orientation) -> Rotation {
        let deltaOrientation = q / past.q / dt
        var velocity = 2.0 * deltaOrientation.imag
        if deltaOrientation.real < 0 {
            velocity = -velocity
        }
        return velocity
    }
}


struct Space {
    var position: Position
    var orientation: Orientation
    
    static let identity = Space(position: .null, orientation: .identity)
    
    init(position: Position = .null, orientation: Orientation = .identity) {
        self.position = position
        self.orientation = orientation
    }
    
    var matrix: simd_float4x4 {
        let upperLeft = simd_float3x3(simd_quatf(
            ix: Float(orientation.q.imag.x),
            iy: Float(orientation.q.imag.y),
            iz: Float(orientation.q.imag.z),
            r: Float(orientation.q.real)
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
    
    func leave(_ x: Position) -> Position {
        orientation.act(on: x) + position
    }
    
    func enter(_ x: Position) -> Position {
        inverse.leave(x)
    }
    
    func integrate(by dt: Double, linearVelocity: Position, angularVelocity: Rotation) -> Space {
        Space(position: position.integrate(by: dt, velocity: linearVelocity),
              orientation: orientation.integrate(by: dt, velocity: angularVelocity))
    }
    
    func derive(for dt: Double, _ past: Space) -> (Position, Rotation) {
        (position: position.derive(by: dt, past.position),
         orientation: orientation.derive(by: dt, past.orientation))
    }
    
    mutating func translate(by translation: Position) {
        position = position + translation
    }
}
