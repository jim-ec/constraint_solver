import Foundation

extension simd_double3 {
    public static var ex: simd_double3 {
        get { simd_double3(1, 0, 0) }
    }
    
    public static var ey: simd_double3 {
        get { simd_double3(0, 1, 0) }
    }
    
    public static var ez: simd_double3 {
        get { simd_double3(0, 0, 1) }
    }
}

extension simd_double3 {
    public var string: String {
        get { "(\(x), \(y), \(z))" }
    }
}

extension simd_float3x3 {
    public static var identity: simd_float3x3 {
        get { simd_float3x3(diagonal: .one) }
    }
}

extension simd_quatd {
    public static var identity: simd_quatd {
        get { simd_quatd(ix: 0, iy: 0, iz: 0, r: 1) }
    }
}

struct Transform {
    var position: simd_double3
    var orientation: simd_quatd
    
    func matrix() -> simd_float4x4 {
        let upperLeft3x3 = simd_float3x3(simd_quatf(vector: simd_float4(orientation.vector)))
        return simd_float4x4(simd_float4(upperLeft3x3.columns.0, 0),
                             simd_float4(upperLeft3x3.columns.1, 0),
                             simd_float4(upperLeft3x3.columns.2, 0),
                             simd_float4(simd_float3(position), 1))
    }
    
    static func identity() -> Transform {
        return Transform(position: .zero, orientation: .identity)
    }
    
    static func position(_ position: simd_double3) -> Transform {
        return Transform(position: position, orientation: .identity)
    }
    
    static func orientation(_ orientation: simd_quatd) -> Transform {
        return Transform(position: .zero, orientation: orientation)
    }
    
    static func around(x angle: Double) -> Transform {
        return Transform(position: .zero, orientation: simd_quatd(angle: angle, axis: .ex))
    }
    
    static func around(y angle: Double) -> Transform {
        return Transform(position: .zero, orientation: simd_quatd(angle: angle, axis: .ey))
    }
    
    static func around(z angle: Double) -> Transform {
        return Transform(position: .zero, orientation: simd_quatd(angle: angle, axis: .ez))
    }
    
    static func around(axis: simd_double3, angle: Double) -> Transform {
        return Transform(position: .zero, orientation: simd_quatd(angle: angle, axis: axis))
    }
    
    /// Positions the viewer along the negative y-axis, offsets from that axis are given in angle quantities.
    static func look(azimuth: Double, elevation: Double, radius: Double) -> Transform {
        .around(z: azimuth) *
            .around(x: elevation) *
            .position(simd_double3(0, radius, 0))
    }
    
    /// Composition of two transforms.
    /// The resultant transform describes the first transform as happening within the second transform.
    /// The second transform therefore acts as a parent transform.
    static func *(_ a: Transform, _ b: Transform) -> Transform {
        let orientation = b.orientation * a.orientation
        let position = b.orientation.act(a.position) + b.position
        return Transform(position: position, orientation: orientation)
    }
    
    /// The inverse composition of two transforms.
    /// The resultant transform relative to to the second transform desbribes the first transform.
    static func /(_ a: Transform, _ b: Transform) -> Transform {
        a * b.inverse()
    }
    
    /// Concatenates two transforms.
    static func +(_ a: Transform, _ b: Transform) -> Transform {
        Transform(position: a.position + b.position, orientation: a.orientation * b.orientation)
    }
    
    /// The difference between two transforms.
    static func -(_ a: Transform, _ b: Transform) -> Transform {
        a + b.inverse()
    }
    
    /// Applies this transform to some vector.
    func act(on x: simd_double3) -> simd_double3 {
        orientation.act(x) + position
    }
    
    /// Applies only the rotational part of this transform to the given vector.
    func rotate(_ x: simd_double3) -> simd_double3 {
        orientation.act(x)
    }
    
    func inverse() -> Transform {
        let inverseOrientation = orientation.inverse
        let inversePosition = -inverseOrientation.act(position)
        return Transform(position: inversePosition, orientation: inverseOrientation)
    }
}
