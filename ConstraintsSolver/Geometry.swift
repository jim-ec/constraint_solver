import Foundation

class Geometry {
    let name: String
    let vertices: UnsafeMutableBufferPointer<Vertex>
    var transform = Transform.identity()
    
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
    
    func builder() -> GeometryBuilder {
        GeometryBuilder(geometry: self)
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
        map(by: transform.act)
    }
    
    /// Maps all position vectors of this geometry according to mapping function.
    func map(by function: (simd_float3) -> simd_float3) {
        for i in 0..<vertices.count {
            vertices[i].position = function(vertices[i].position)
        }
    }
}

/// A type soley for the purpose of pushing vertices into a geometry.
class GeometryBuilder {
    
    let geometry: Geometry
    var index: Int
    
    /// The builder will start overwriting vertices from the start.
    init(geometry: Geometry) {
        self.geometry = geometry
        self.index = 0
    }
    
    /// Push a single vertex.
    func push(vertex: Vertex) {
        geometry[index] = vertex
        index += 1
    }
    
    /// Push a uni-colored triangle.
    /// The normal is computed automatically, assuming counter-clockwise winding.
    func push(_ a: simd_float3, _ b: simd_float3, _ c: simd_float3, color: Color) {
        let normal = normalize(cross(b - a, c - a))
        push(vertex: Vertex(position: a, normal: normal, color: color.rgb))
        push(vertex: Vertex(position: b, normal: normal, color: color.rgb))
        push(vertex: Vertex(position: c, normal: normal, color: color.rgb))
    }
    
}

extension Renderer {
    
    func makeTriangle(name: String, colors: (Color, Color, Color)) -> Geometry {
        let builder = makeGeometry(name: name, vertexCount: 6).builder()
                
        builder.push(vertex: Vertex(position: -.e1 - .e3, normal: -.e2, color: colors.0.rgb))
        builder.push(vertex: Vertex(position: .e1 - .e3, normal: -.e2, color: colors.1.rgb))
        builder.push(vertex: Vertex(position: .e3, normal: -.e2, color: colors.2.rgb))
        builder.push(vertex: Vertex(position: -.e1 - .e3, normal: .e2, color: colors.0.rgb))
        builder.push(vertex: Vertex(position: .e3, normal: .e2, color: colors.2.rgb))
        builder.push(vertex: Vertex(position: .e1 - .e3, normal: .e2, color: colors.1.rgb))
        
        return builder.geometry
    }
    
    func makeQuadliteral(name: String, color: Color) -> Geometry {
        let builder = makeGeometry(name: name, vertexCount: 6).builder()
        
        builder.push(.zero, .e1, .e1 + .e2, color: color)
        builder.push(.zero, .e1 + .e2, .e2, color: color)
        
        return builder.geometry
    }
    
    func makeCube(name: String, color: Color) -> Geometry {
        let builder = makeGeometry(name: name, vertexCount: 36).builder()
        
        builder.push(.zero, .e1, .e1 + .e3, color: color)
        builder.push(.zero, .e1 + .e3, .e3, color: color)
        
        builder.push(.zero, .e2 + .e1, .e1, color: color)
        builder.push(.zero, .e2, .e2 + .e1, color: color)
        
        builder.push(.zero, .e3, .e3 + .e2, color: color)
        builder.push(.zero, .e3 + .e2, .e2, color: color)
        
        builder.push(.e1, .e1 + .e2 + .e3, .e1 + .e3, color: color)
        builder.push(.e1, .e1 + .e2, .e1 + .e2 + .e3, color: color)
        
        builder.push(.e2, .e1 + .e2 + .e3, .e1 + .e2, color: color)
        builder.push(.e2, .e2 + .e3, .e1 + .e2 + .e3, color: color)
        
        builder.push(.e3, .e1 + .e3, .e1 + .e2 + .e3, color: color)
        builder.push(.e3, .e1 + .e2 + .e3, .e2 + .e3, color: color)
        
        return builder.geometry
    }
    
}
