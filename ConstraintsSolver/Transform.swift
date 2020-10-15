import Foundation

let e1: simd_float3 = simd_float3(1, 0, 0)
let e2: simd_float3 = simd_float3(0, 1, 0)
let e3: simd_float3 = simd_float3(0, 0, 1)

struct Transform {
    var translation: simd_float3
    var rotation: simd_float3x3
    
    init() {
        translation = .zero
        rotation = simd_float3x3(diagonal: simd_float3(repeating: 1))
    }
    
    init(translation: simd_float3, rotation: simd_float3x3) {
        self.translation = translation
        self.rotation = rotation
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
    
    static func look(at: simd_float3, azimuth: Float, elevation: Float, radius: Float) -> Transform {
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
        
        return Transform(translation: simd_float3(0, radius, 0) - at, rotation: rotationX * rotationZ)
    }
    
    func then(_ other: Transform) -> Transform {
        let rotation = other.rotation * self.rotation
        let translation = simd_float3(
            other.rotation[0][0] * self.translation[0] +
                other.rotation[1][0] * self.translation[1] +
                other.rotation[2][0] * self.translation[2] +
                other.translation[0],
            other.rotation[0][1] * self.translation[0] +
                other.rotation[1][1] * self.translation[1] +
                other.rotation[2][1] * self.translation[2] +
                other.translation[1],
            other.rotation[0][2] * self.translation[0] +
                other.rotation[1][2] * self.translation[1] +
                other.rotation[2][2] * self.translation[2] +
                other.translation[2]
        )
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
}