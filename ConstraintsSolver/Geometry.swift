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
    
    static func lookFromOrbit(azimuth: Float, elevation: Float, radius: Float) -> Transform {
        let rotationZ = simd_float3x3(columns: (
            simd_float3(cosf(azimuth), -sinf(azimuth), 0),
            simd_float3(sinf(azimuth), cosf(azimuth), 0),
            simd_float3(0, 0, 1)
        ))
        
        let rotationX = simd_float3x3(columns: (
            simd_float3(1, 0, 0),
            simd_float3(0, cosf(elevation), -sinf(elevation)),
            simd_float3(0, sinf(elevation), cosf(elevation))
        ))
        
        return Transform(translation: simd_float3(0, radius, 0), rotation: rotationX * rotationZ)
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
}

class Geometry {
    let name: String
    let vertices: UnsafeMutableBufferPointer<Vertex>
    var transform = Transform()
    
    init(name: String, vertices: UnsafeMutableBufferPointer<Vertex>) {
        self.name = name
        self.vertices = vertices
    }
    
    subscript(index: Int) -> Vertex {
        get {
            vertices[index]
        }
        set {
            vertices[index] = newValue
        }
    }
}

extension Renderer {
    
    func makeTriangle(name: String, colors: (Color, Color, Color)) -> Geometry {
        let geometry = makeGeometry(name: name, vertexCount: 3)
        geometry[0] = Vertex(position: -e1 - e3, normal: -e2, color: colors.0.rgb)
        geometry[1] = Vertex(position: e1 - e3, normal: -e2, color: colors.1.rgb)
        geometry[2] = Vertex(position: e3, normal: -e2, color: colors.2.rgb)
        return geometry
    }
    
    func makeCube(name: String, color: Color) -> Geometry {
        let geometry = makeGeometry(name: name, vertexCount: 36)
        
        geometry[0] = .init(position: .zero, normal: -e3, color: color.rgb)
        geometry[1] = .init(position: e1 + e2, normal: -e3, color: color.rgb)
        geometry[2] = .init(position: e1, normal: -e3, color: color.rgb)
        geometry[3] = .init(position: .zero, normal: -e3, color: color.rgb)
        geometry[4] = .init(position: e2, normal: -e3, color: color.rgb)
        geometry[5] = .init(position: e1 + e2, normal: -e3, color: color.rgb)
        
        geometry[6] = .init(position: e1, normal: e1, color: color.rgb)
        geometry[7] = .init(position: e1 + e2 + e3, normal: e1, color: color.rgb)
        geometry[8] = .init(position: e1 + e3, normal: e1, color: color.rgb)
        geometry[9] = .init(position: e1, normal: e1, color: color.rgb)
        geometry[10] = .init(position: e1 + e2, normal: e1, color: color.rgb)
        geometry[11] = .init(position: e1 + e2 + e3, normal: e1, color: color.rgb)
        
        geometry[12] = .init(position: e2, normal: e2, color: color.rgb)
        geometry[13] = .init(position: e1 + e2 + e3, normal: e2, color: color.rgb)
        geometry[14] = .init(position: e1 + e2, normal: e2, color: color.rgb)
        geometry[15] = .init(position: e2, normal: e2, color: color.rgb)
        geometry[16] = .init(position: e2 + e3, normal: e2, color: color.rgb)
        geometry[17] = .init(position: e1 + e2 + e3, normal: e2, color: color.rgb)
        
        geometry[18] = .init(position: e3, normal: e3, color: color.rgb)
        geometry[19] = .init(position: e1 + e3, normal: e3, color: color.rgb)
        geometry[20] = .init(position: e1 + e2 + e3, normal: e3, color: color.rgb)
        geometry[21] = .init(position: e3, normal: e3, color: color.rgb)
        geometry[22] = .init(position: e1 + e2 + e3, normal: e3, color: color.rgb)
        geometry[23] = .init(position: e2 + e3, normal: e3, color: color.rgb)
        
        geometry[24] = .init(position: .zero, normal: -e1, color: color.rgb)
        geometry[25] = .init(position: e3, normal: -e1, color: color.rgb)
        geometry[26] = .init(position: e2 + e3, normal: -e1, color: color.rgb)
        geometry[27] = .init(position: .zero, normal: -e1, color: color.rgb)
        geometry[28] = .init(position: e2 + e3, normal: -e1, color: color.rgb)
        geometry[29] = .init(position: e2, normal: -e1, color: color.rgb)
        
        geometry[30] = .init(position: .zero, normal: -e2, color: color.rgb)
        geometry[31] = .init(position: e1, normal: -e2, color: color.rgb)
        geometry[32] = .init(position: e1 + e3, normal: -e2, color: color.rgb)
        geometry[33] = .init(position: .zero, normal: -e2, color: color.rgb)
        geometry[34] = .init(position: e1 + e3, normal: -e2, color: color.rgb)
        geometry[35] = .init(position: e3, normal: -e2, color: color.rgb)
        
        return geometry
    }
    
}
