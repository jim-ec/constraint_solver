import Foundation

private let e1 = simd_float3(1, 0, 0)
private let e2 = simd_float3(0, 1, 0)
private let e3 = simd_float3(0, 0, 1)

class Geometry {
    let name: String
    let vertices: UnsafeMutableBufferPointer<Vertex>
    
    var translation: simd_float3 = .zero
    var rotation: simd_float3 = .zero
    
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
    
    func transform() -> simd_float3x3 {
        let rotationX = simd_float3x3(columns: (
            simd_float3(1, 0, 0),
            simd_float3(0, cosf(rotation.x), -sinf(rotation.x)),
            simd_float3(0, sinf(rotation.x), cosf(rotation.x))
        ))
        
        let rotationY = simd_float3x3(columns: (
            simd_float3(cosf(rotation.y), 0, sinf(rotation.y)),
            simd_float3(0, 1, 0),
            simd_float3(-sinf(rotation.y), 0, cosf(rotation.y))
        ))
        
//        let rotationZ = simd_float3x3(columns: (
//            simd_float3(cosf(rotation.z), -sinf(rotation.z), 0),
//            simd_float3(sinf(rotation.z), cosf(rotation.z), 0),
//            simd_float3(0, 0, 1)
//        ))
        
        return rotationX * rotationY
    }
}

extension Renderer {
    
    func makeTriangle(name: String, colors: (Color, Color, Color)) -> Geometry {
        let geometry = makeGeometry(name: name, vertexCount: 3)
        geometry[0] = .init(position: -e1 - e2, normal: -e3, color: colors.0.rgb)
        geometry[1] = .init(position: e1 - e2, normal: -e3, color: colors.1.rgb)
        geometry[2] = .init(position: e2, normal: -e3, color: colors.2.rgb)
        return geometry
    }
    
    func makeCube(name: String, color: Color) -> Geometry {
        let geometry = makeGeometry(name: name, vertexCount: 36)
        
        geometry[0] = .init(position: .zero, normal: -e3, color: color.rgb)
        geometry[1] = .init(position: e1, normal: -e3, color: color.rgb)
        geometry[2] = .init(position: e1 + e2, normal: -e3, color: color.rgb)
        geometry[3] = .init(position: .zero, normal: -e3, color: color.rgb)
        geometry[4] = .init(position: e1 + e2, normal: -e3, color: color.rgb)
        geometry[5] = .init(position: e2, normal: -e3, color: color.rgb)
        
        geometry[6] = .init(position: e1, normal: e1, color: color.rgb)
        geometry[7] = .init(position: e1 + e3, normal: e1, color: color.rgb)
        geometry[8] = .init(position: e1 + e2 + e3, normal: e1, color: color.rgb)
        geometry[9] = .init(position: e1, normal: e1, color: color.rgb)
        geometry[10] = .init(position: e1 + e2 + e3, normal: e1, color: color.rgb)
        geometry[11] = .init(position: e1 + e2, normal: e1, color: color.rgb)
        
        geometry[12] = .init(position: e2, normal: e2, color: color.rgb)
        geometry[13] = .init(position: e1 + e2, normal: e2, color: color.rgb)
        geometry[14] = .init(position: e1 + e2 + e3, normal: e2, color: color.rgb)
        geometry[15] = .init(position: e2, normal: e2, color: color.rgb)
        geometry[16] = .init(position: e1 + e2 + e3, normal: e2, color: color.rgb)
        geometry[17] = .init(position: e2 + e3, normal: e2, color: color.rgb)
        
        geometry[18] = .init(position: e3, normal: e3, color: color.rgb)
        geometry[19] = .init(position: e1 + e2 + e3, normal: e3, color: color.rgb)
        geometry[20] = .init(position: e1 + e3, normal: e3, color: color.rgb)
        geometry[21] = .init(position: e3, normal: e3, color: color.rgb)
        geometry[22] = .init(position: e2 + e3, normal: e3, color: color.rgb)
        geometry[23] = .init(position: e1 + e2 + e3, normal: e3, color: color.rgb)
        
        geometry[24] = .init(position: .zero, normal: -e1, color: color.rgb)
        geometry[25] = .init(position: e2 + e3, normal: -e1, color: color.rgb)
        geometry[26] = .init(position: e3, normal: -e1, color: color.rgb)
        geometry[27] = .init(position: .zero, normal: -e1, color: color.rgb)
        geometry[28] = .init(position: e2, normal: -e1, color: color.rgb)
        geometry[29] = .init(position: e2 + e3, normal: -e1, color: color.rgb)
        
        geometry[30] = .init(position: .zero, normal: -e2, color: color.rgb)
        geometry[31] = .init(position: e1 + e3, normal: -e2, color: color.rgb)
        geometry[32] = .init(position: e1, normal: -e2, color: color.rgb)
        geometry[33] = .init(position: .zero, normal: -e2, color: color.rgb)
        geometry[34] = .init(position: e3, normal: -e2, color: color.rgb)
        geometry[35] = .init(position: e1 + e3, normal: -e2, color: color.rgb)
        
        return geometry
    }
    
}
