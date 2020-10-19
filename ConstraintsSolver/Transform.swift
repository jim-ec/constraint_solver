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

struct Transform {
    var translation: simd_float3
    var rotation: simd_float3x3
    
    init() {
        translation = .zero
        rotation = .identity
    }
    
    init(translation: simd_float3) {
        self.translation = translation
        self.rotation = .identity
    }
    
    init(rotation: simd_float3x3) {
        self.translation = simd_float3()
        self.rotation = rotation
    }
    
    init(translation: simd_float3, rotation: simd_float3x3) {
        self.translation = translation
        self.rotation = rotation
    }
    
    init(eulerAngles: simd_float3) {
        self.init(translation: simd_float3(), eulerAngles: eulerAngles)
    }
    
    init(translation: simd_float3, eulerAngles: simd_float3) {
        let rotationX = simd_float3x3(columns: (
            simd_float3(1, 0, 0),
            simd_float3(0, cosf(eulerAngles.x), -sinf(eulerAngles.x)),
            simd_float3(0, sinf(eulerAngles.x), cosf(eulerAngles.x))
        ))
        
        let rotationY = simd_float3x3(columns: (
            simd_float3(cosf(eulerAngles.y), 0, sinf(eulerAngles.y)),
            simd_float3(0, 1, 0),
            simd_float3(-sinf(eulerAngles.y), 0, cosf(eulerAngles.y))
        ))
        
        let rotationZ = simd_float3x3(columns: (
            simd_float3(cosf(eulerAngles.z), -sinf(eulerAngles.z), 0),
            simd_float3(sinf(eulerAngles.z), cosf(eulerAngles.z), 0),
            simd_float3(0, 0, 1)
        ))
        
        rotation = rotationX * rotationY * rotationZ
        self.translation = translation
    }
    
    /// Positions the camera along the negative y-axis, offsets from that axis are given in angle quantities.
    static func look(azimuth: Float, elevation: Float, radius: Float) -> Transform {
        let rotationZ = simd_float3x3(columns: (
            simd_float3(cosf(azimuth), -sinf(azimuth), 0),
            simd_float3(sinf(azimuth), cosf(azimuth), 0),
            simd_float3(0, 0, 1)
        ))
        
        let rotationX = simd_float3x3(columns: (
            simd_float3(1, 0, 0),
            simd_float3(0, cosf(-elevation), -sinf(-elevation)),
            simd_float3(0, sinf(-elevation), cosf(-elevation))
        ))
        
        return Transform(translation: simd_float3(0, radius, 0), rotation: rotationX * rotationZ)
    }
    
    func then(_ other: Transform) -> Transform {
        let rotation = other.rotation * self.rotation
        let translation = other.apply(to: self.translation)
        return Transform(translation: translation, rotation: rotation)
    }
    
    mutating func rotate(eulerAngles: simd_float3) {
        let rotationX = simd_float3x3(columns: (
            simd_float3(1, 0, 0),
            simd_float3(0, cosf(eulerAngles.x), -sinf(eulerAngles.x)),
            simd_float3(0, sinf(eulerAngles.x), cosf(eulerAngles.x))
        ))
        let rotationY = simd_float3x3(columns: (
            simd_float3(cosf(eulerAngles.y), 0, sinf(eulerAngles.y)),
            simd_float3(0, 1, 0),
            simd_float3(-sinf(eulerAngles.y), 0, cosf(eulerAngles.y))
        ))
        let rotationZ = simd_float3x3(columns: (
            simd_float3(1, 0, 0),
            simd_float3(0, cosf(eulerAngles.z), -sinf(eulerAngles.z)),
            simd_float3(0, sinf(eulerAngles.z), cosf(eulerAngles.z))
        ))
        self.rotation = rotationX * rotationY * rotationZ * self.rotation
    }
    
    /// Applies this transform to some vector.
    func apply(to x: simd_float3) -> simd_float3 {
        rotation * x + translation
    }
}
