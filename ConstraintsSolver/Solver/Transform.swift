import Foundation

typealias double3 = simd_double3
typealias quat = simd_quatd

extension double3 {
    static var ex: double3 {
        get { double3(1, 0, 0) }
    }
    
    static var ey: double3 {
        get { double3(0, 1, 0) }
    }
    
    static var ez: double3 {
        get { double3(0, 0, 1) }
    }
    
    var string: String {
        get { "(\(x), \(y), \(z))" }
    }
    
    var normalize: Self {
        simd_normalize(self)
    }
    
    func distance(to rhs: Self) -> Double {
        simd_distance(self, rhs)
    }
    
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
}

extension quat {
    static var identity: Self {
        Self(ix: 0, iy: 0, iz: 0, r: 1)
    }
}

struct Transform {
    var position: double3
    var orientation: quat
    
    var matrix: simd_double4x4 {
        let upperLeft = simd_double3x3(orientation)
        return simd_double4x4(
            simd_double4(upperLeft[0], 0),
            simd_double4(upperLeft[1], 0),
            simd_double4(upperLeft[2], 0),
            simd_double4(position, 1))
    }
    
    static let identity = Transform(position: .zero, orientation: .identity)
    
    static func position(_ position: double3) -> Transform {
        return Transform(position: position, orientation: .identity)
    }
    
    static func orientation(_ orientation: quat) -> Transform {
        return Transform(position: .zero, orientation: orientation)
    }
    
    static func around(x angle: Double) -> Transform {
        return Transform(position: .zero, orientation: quat(angle: angle, axis: .ex))
    }
    
    static func around(y angle: Double) -> Transform {
        return Transform(position: .zero, orientation: quat(angle: angle, axis: .ey))
    }
    
    static func around(z angle: Double) -> Transform {
        return Transform(position: .zero, orientation: quat(angle: angle, axis: .ez))
    }
    
    static func around(axis: double3, angle: Double) -> Transform {
        return Transform(position: .zero, orientation: quat(angle: angle, axis: axis))
    }
    
    /// Positions the viewer along the negative y-axis, offsets from that axis are given in angle quantities.
    static func look(azimuth: Double, elevation: Double, radius: Double) -> Transform {
        .around(z: azimuth) *
            .around(x: elevation) *
            .position(double3(0, radius, 0))
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
    func act(on x: double3) -> double3 {
        orientation.act(x) + position
    }
    
    /// Applies only the rotational part of this transform to the given vector.
    func rotate(_ x: double3) -> double3 {
        orientation.act(x)
    }
    
    func inverse() -> Transform {
        let inverseOrientation = orientation.inverse
        let inversePosition = -inverseOrientation.act(position)
        return Transform(position: inversePosition, orientation: inverseOrientation)
    }
}
