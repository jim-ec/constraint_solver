import Foundation

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
    
    func findCenterOfMass() -> simd_float3 {
        var centerOfMass = simd_float3()
        for vertex in vertices {
            centerOfMass += vertex.position
        }
        centerOfMass /= Float(vertices.count)
        return centerOfMass
    }
    
    /// Applies the given transform to all position vectors of this geometry.
    func map(by transform: Transform) {
        map(by: transform.apply)
    }
    
    /// Maps all position vectors of this geometry according to mapping function.
    func map(by function: (simd_float3) -> simd_float3) {
        for i in 0..<vertices.count {
            vertices[i].position = function(vertices[i].position)
        }
    }
}

extension Renderer {
    
    func makeTriangle(name: String, colors: (Color, Color, Color)) -> Geometry {
        let geometry = makeGeometry(name: name, vertexCount: 6)
        
        geometry[0] = Vertex(position: -.e1 - .e3, normal: -.e2, color: colors.0.rgb)
        geometry[1] = Vertex(position: .e1 - .e3, normal: -.e2, color: colors.1.rgb)
        geometry[2] = Vertex(position: .e3, normal: -.e2, color: colors.2.rgb)
        geometry[3] = Vertex(position: -.e1 - .e3, normal: .e2, color: colors.0.rgb)
        geometry[4] = Vertex(position: .e3, normal: .e2, color: colors.2.rgb)
        geometry[5] = Vertex(position: .e1 - .e3, normal: .e2, color: colors.1.rgb)
        
        return geometry
    }
    
    func makeQuadliteral(name: String, color: Color) -> Geometry {
        let geometry = makeGeometry(name: name, vertexCount: 6)
        
        geometry[0] = Vertex(position: .zero, normal: .e3, color: color.rgb)
        geometry[1] = Vertex(position: .e1, normal: .e3, color: color.rgb)
        geometry[2] = Vertex(position: .e1 + .e2, normal: .e3, color: color.rgb)
        geometry[3] = Vertex(position: .zero, normal: .e3, color: color.rgb)
        geometry[4] = Vertex(position: .e1 + .e2, normal: .e3, color: color.rgb)
        geometry[5] = Vertex(position: .e2, normal: .e3, color: color.rgb)
        
        return geometry
    }
    
    func makeCube(name: String, color: Color) -> Geometry {
        let geometry = makeGeometry(name: name, vertexCount: 36)
        
        geometry[0] = Vertex(position: .zero, normal: -.e3, color: color.rgb)
        geometry[1] = Vertex(position: .e1 + .e2, normal: -.e3, color: color.rgb)
        geometry[2] = Vertex(position: .e1, normal: -.e3, color: color.rgb)
        geometry[3] = Vertex(position: .zero, normal: -.e3, color: color.rgb)
        geometry[4] = Vertex(position: .e2, normal: -.e3, color: color.rgb)
        geometry[5] = Vertex(position: .e1 + .e2, normal: -.e3, color: color.rgb)
        
        geometry[6] = Vertex(position: .e1, normal: .e1, color: color.rgb)
        geometry[7] = Vertex(position: .e1 + .e2 + .e3, normal: .e1, color: color.rgb)
        geometry[8] = Vertex(position: .e1 + .e3, normal: .e1, color: color.rgb)
        geometry[9] = Vertex(position: .e1, normal: .e1, color: color.rgb)
        geometry[10] = Vertex(position: .e1 + .e2, normal: .e1, color: color.rgb)
        geometry[11] = Vertex(position: .e1 + .e2 + .e3, normal: .e1, color: color.rgb)
        
        geometry[12] = Vertex(position: .e2, normal: .e2, color: color.rgb)
        geometry[13] = Vertex(position: .e1 + .e2 + .e3, normal: .e2, color: color.rgb)
        geometry[14] = Vertex(position: .e1 + .e2, normal: .e2, color: color.rgb)
        geometry[15] = Vertex(position: .e2, normal: .e2, color: color.rgb)
        geometry[16] = Vertex(position: .e2 + .e3, normal: .e2, color: color.rgb)
        geometry[17] = Vertex(position: .e1 + .e2 + .e3, normal: .e2, color: color.rgb)
        
        geometry[18] = Vertex(position: .e3, normal: .e3, color: color.rgb)
        geometry[19] = Vertex(position: .e1 + .e3, normal: .e3, color: color.rgb)
        geometry[20] = Vertex(position: .e1 + .e2 + .e3, normal: .e3, color: color.rgb)
        geometry[21] = Vertex(position: .e3, normal: .e3, color: color.rgb)
        geometry[22] = Vertex(position: .e1 + .e2 + .e3, normal: .e3, color: color.rgb)
        geometry[23] = Vertex(position: .e2 + .e3, normal: .e3, color: color.rgb)
        
        geometry[24] = Vertex(position: .zero, normal: -.e1, color: color.rgb)
        geometry[25] = Vertex(position: .e3, normal: -.e1, color: color.rgb)
        geometry[26] = Vertex(position: .e2 + .e3, normal: -.e1, color: color.rgb)
        geometry[27] = Vertex(position: .zero, normal: -.e1, color: color.rgb)
        geometry[28] = Vertex(position: .e2 + .e3, normal: -.e1, color: color.rgb)
        geometry[29] = Vertex(position: .e2, normal: -.e1, color: color.rgb)
        
        geometry[30] = Vertex(position: .zero, normal: -.e2, color: color.rgb)
        geometry[31] = Vertex(position: .e1, normal: -.e2, color: color.rgb)
        geometry[32] = Vertex(position: .e1 + .e3, normal: -.e2, color: color.rgb)
        geometry[33] = Vertex(position: .zero, normal: -.e2, color: color.rgb)
        geometry[34] = Vertex(position: .e1 + .e3, normal: -.e2, color: color.rgb)
        geometry[35] = Vertex(position: .e3, normal: -.e2, color: color.rgb)
        
        return geometry
    }
    
}
