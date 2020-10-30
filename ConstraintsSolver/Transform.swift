import Foundation

extension simd_float3 {
    public static var e1: simd_float3 {
        get { simd_float3(1, 0, 0) }
    }
    
    public static var e2: simd_float3 {
        get { simd_float3(0, 1, 0) }
    }
    
    public static var e3: simd_float3 {
        get { simd_float3(0, 0, 1) }
    }
}

extension simd_float3x3 {
    public static var identity: simd_float3x3 {
        get { simd_float3x3(diagonal: simd_float3(repeating: 1)) }
    }
}

extension simd_quatf {
    public static var identity: simd_quatf {
        get { simd_quatf(ix: 0, iy: 0, iz: 0, r: 1) }
    }
}

struct Transform {
    var translation: simd_float3
    var rotation: simd_quatf
    
    static func identity() -> Transform {
        return Transform(translation: .zero, rotation: .identity)
    }
    
    static func translation(_ translation: simd_float3) -> Transform {
        return Transform(translation: translation, rotation: .identity)
    }
    
    static func rotation(_ rotation: simd_quatf) -> Transform {
        return Transform(translation: .zero, rotation: rotation)
    }
    
    static func around(x angle: Float) -> Transform {
        return Transform(translation: .zero, rotation: simd_quatf(angle: angle, axis: .e1))
    }
    
    static func around(y angle: Float) -> Transform {
        return Transform(translation: .zero, rotation: simd_quatf(angle: angle, axis: .e2))
    }
    
    static func around(z angle: Float) -> Transform {
        return Transform(translation: .zero, rotation: simd_quatf(angle: angle, axis: .e3))
    }
    
    static func around(axis: simd_float3, angle: Float) -> Transform {
        return Transform(translation: .zero, rotation: simd_quatf(angle: angle, axis: axis))
    }
    
    /// Positions the viewer along the negative y-axis, offsets from that axis are given in angle quantities.
    static func look(azimuth: Float, elevation: Float, radius: Float) -> Transform {
        .around(z: azimuth) *
            .around(x: elevation) *
            .translation(simd_float3(0, radius, 0))
    }
    
    /// Composition of two transforms.
    /// The resultant transform describes the first transform as happening within the second transform.
    /// The second transform therefore acts as a parent transform.
    static func *(_ a: Transform, _ b: Transform) -> Transform {
        let rotation = b.rotation * a.rotation
        let translation = b.rotation.act(a.translation) + b.translation
        return Transform(translation: translation, rotation: rotation)
    }
    
    /// The inverse composition of two transforms.
    /// The resultant transform relative to to the second transform desbribes the first transform.
    static func /(_ a: Transform, _ b: Transform) -> Transform {
        a * b.inverse()
    }
    
    /// Concatenates two transforms.
    static func +(_ a: Transform, _ b: Transform) -> Transform {
        Transform(translation: a.translation + b.translation, rotation: a.rotation * b.rotation)
    }
    
    /// The difference between two transforms.
    static func -(_ a: Transform, _ b: Transform) -> Transform {
        a + b.inverse()
    }
    
    /// Applies this transform to some vector.
    func act(on x: simd_float3) -> simd_float3 {
        rotation.act(x) + translation
    }
    
    func inverse() -> Transform {
        let inverseRotation = rotation.inverse
        let inverseTranslaton = -inverseRotation.act(translation)
        return Transform(translation: inverseTranslaton, rotation: inverseRotation)
    }
}
