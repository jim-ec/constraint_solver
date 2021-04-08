import Foundation

class Geometry {
    let name: String
    let vertices: UnsafeMutableBufferPointer<Vertex>
    var transform = Transform.identity
    
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
    
    func findCenterOfMass() -> double3 {
        var centerOfMass = double3()
        for vertex in vertices {
            centerOfMass += double3(vertex.position)
        }
        centerOfMass /= Double(vertices.count)
        return centerOfMass
    }
    
    /// Applies the given transform to all position vectors of this geometry.
    func map(by transform: Transform) {
        map { x in
            simd_float3(transform.act(on: double3(x)))
        }
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
        
        builder.push(vertex: Vertex(position: simd_float3(-1, 0, -1), normal: simd_float3(0, -1, 0), color: colors.0.rgb))
        builder.push(vertex: Vertex(position: simd_float3(1, 0, -1), normal: simd_float3(0, -1, 0), color: colors.1.rgb))
        builder.push(vertex: Vertex(position: simd_float3(0, 0, 1), normal: simd_float3(0, -1, 0), color: colors.2.rgb))
        builder.push(vertex: Vertex(position: simd_float3(-1, 0, -1), normal: simd_float3(0, 1, 0), color: colors.0.rgb))
        builder.push(vertex: Vertex(position: simd_float3(0, 0, 1), normal: simd_float3(0, -1, 0), color: colors.2.rgb))
        builder.push(vertex: Vertex(position: simd_float3(1, 0, -1), normal: simd_float3(0, -1, 0), color: colors.1.rgb))
        
        return builder.geometry
    }
    
    func makeQuadliteral(name: String, color: Color) -> Geometry {
        let builder = makeGeometry(name: name, vertexCount: 6).builder()
        
        builder.push(.zero, simd_float3(1, 0, 0), simd_float3(1, 1, 0), color: color)
        builder.push(.zero, simd_float3(1, 1, 0), simd_float3(0, 1, 0), color: color)
        
        return builder.geometry
    }
    
    func makeCube(name: String, color: Color) -> Geometry {
        let builder = makeGeometry(name: name, vertexCount: 36).builder()
        
        builder.push(.zero, simd_float3(1, 0, 0), simd_float3(1, 0, 1), color: color)
        builder.push(.zero, simd_float3(1, 0, 1), simd_float3(0, 0, 1), color: color)
        
        builder.push(.zero, simd_float3(1, 1, 0), simd_float3(1, 0, 0), color: color)
        builder.push(.zero, simd_float3(0, 1, 0), simd_float3(1, 1, 0), color: color)
        
        builder.push(.zero, simd_float3(0, 0, 1), simd_float3(0, 1, 1), color: color)
        builder.push(.zero, simd_float3(0, 1, 1), simd_float3(0, 1, 0), color: color)
        
        builder.push(simd_float3(1, 0, 0), simd_float3(1, 1, 1), simd_float3(1, 0, 1), color: color)
        builder.push(simd_float3(1, 0, 0), simd_float3(1, 1, 0), simd_float3(1, 1, 1), color: color)
        
        builder.push(simd_float3(0, 1, 0), simd_float3(1, 1, 1), simd_float3(1, 1, 0), color: color)
        builder.push(simd_float3(0, 1, 0), simd_float3(0, 1, 1), simd_float3(1, 1, 1), color: color)
        
        builder.push(simd_float3(0, 0, 1), simd_float3(1, 0, 1), simd_float3(1, 1, 1), color: color)
        builder.push(simd_float3(0, 0, 1), simd_float3(1, 1, 1), simd_float3(0, 1, 1), color: color)
        
        return builder.geometry
    }
}
