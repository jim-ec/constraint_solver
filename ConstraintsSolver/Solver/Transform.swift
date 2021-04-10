import Foundation

typealias double3 = simd_double3
typealias quat = simd_quatd

extension double3 {
    static var ex: double3 {
        double3(1, 0, 0)
    }
    
    static var ey: double3 {
        double3(0, 1, 0)
    }
    
    static var ez: double3 {
        double3(0, 0, 1)
    }
    
    var string: String {
        "(\(x), \(y), \(z))"
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
        Transform(position: position, orientation: .identity)
    }
    
    static func orientation(_ orientation: quat) -> Transform {
        Transform(position: .zero, orientation: orientation)
    }
    
    static func rotation(by angle: Double, around axis: double3) -> Transform {
        Transform(position: .zero, orientation: quat(angle: angle, axis: axis))
    }
    
    /// Composition of two transforms.
    /// The resultant transform describes the first transform as happening within the second transform.
    /// The second transform therefore acts as a parent transform.
    static func *(_ a: Transform, _ b: Transform) -> Transform {
        let orientation = b.orientation * a.orientation
        let position = b.orientation.act(a.position) + b.position
        return Transform(position: position, orientation: orientation)
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
        let inversePosition = inverseOrientation.act(-position)
        return Transform(position: inversePosition, orientation: inverseOrientation)
    }
    
    func integrate(by dt: Double, linear: double3, angular: double3) -> Transform {
        let positionStep = dt * linear
        let orientationStep = dt * 0.5 * quat(real: .zero, imag: angular) * orientation
        return Transform(position: position + positionStep,
                         orientation: (orientation + orientationStep).normalized)
    }
    
    func derive(by dt: Double, _ previous: Transform) -> (double3, double3) {
        let linear = (position - previous.position) / dt
        
        let deltaOrientation = orientation / previous.orientation / dt
        var angular = 2.0 * deltaOrientation.imag
        if deltaOrientation.real < 0 {
            angular = -angular
        }
        
        return (linear, angular)
    }
}
