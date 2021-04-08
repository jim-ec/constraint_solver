import Foundation

class Mesh {
    let name: String
    var vertices: [Vertex] = []
    var transform = Transform.identity
    
    init(name: String) {
        self.name = name
    }
    
    func builder() -> MeshBuilder {
        MeshBuilder(mesh: self)
    }
    
    func findCenterOfMass() -> double3 {
        var centerOfMass = double3()
        for vertex in vertices {
            centerOfMass += double3(vertex.position)
        }
        centerOfMass /= Double(vertices.count)
        return centerOfMass
    }
    
    /// Applies the given transform to all position vectors of this mesh.
    func map(by transform: Transform) {
        map { x in
            simd_float3(transform.act(on: double3(x)))
        }
    }
    
    /// Maps all position vectors of this mesh according to mapping function.
    func map(by function: (simd_float3) -> simd_float3) {
        for i in 0..<vertices.count {
            vertices[i].position = function(vertices[i].position)
        }
    }
}

/// A type soley for the purpose of pushing vertices into a mesh.
class MeshBuilder {
    let mesh: Mesh
    
    /// The builder will start overwriting vertices from the start.
    init(mesh: Mesh) {
        self.mesh = mesh
    }
    
    /// Push a single vertex.
    func push(vertex: Vertex) {
        mesh.vertices.append(vertex)
    }
    
    /// Push a uni-colored triangle.
    /// The normal is computed automatically, assuming counter-clockwise winding.
    func push(_ a: simd_float3, _ b: simd_float3, _ c: simd_float3, color: Color) {
        let normal = normalize(cross(b - a, c - a))
        push(vertex: Vertex(position: a, normal: normal, color: color.rgb))
        push(vertex: Vertex(position: b, normal: normal, color: color.rgb))
        push(vertex: Vertex(position: c, normal: normal, color: color.rgb))
    }
    
    static func makeTriangle(name: String, colors: (Color, Color, Color)) -> Mesh {
        let builder = Mesh(name: name).builder()
        
        builder.push(vertex: Vertex(position: simd_float3(-1, 0, -1), normal: simd_float3(0, -1, 0), color: colors.0.rgb))
        builder.push(vertex: Vertex(position: simd_float3(1, 0, -1), normal: simd_float3(0, -1, 0), color: colors.1.rgb))
        builder.push(vertex: Vertex(position: simd_float3(0, 0, 1), normal: simd_float3(0, -1, 0), color: colors.2.rgb))
        builder.push(vertex: Vertex(position: simd_float3(-1, 0, -1), normal: simd_float3(0, 1, 0), color: colors.0.rgb))
        builder.push(vertex: Vertex(position: simd_float3(0, 0, 1), normal: simd_float3(0, -1, 0), color: colors.2.rgb))
        builder.push(vertex: Vertex(position: simd_float3(1, 0, -1), normal: simd_float3(0, -1, 0), color: colors.1.rgb))
        
        return builder.mesh
    }
    
    static func makeQuadliteral(name: String, color: Color) -> Mesh {
        let builder = Mesh(name: name).builder()
        
        builder.push(.zero, simd_float3(1, 0, 0), simd_float3(1, 1, 0), color: color)
        builder.push(.zero, simd_float3(1, 1, 0), simd_float3(0, 1, 0), color: color)
        
        return builder.mesh
    }
    
    static func makeCube(name: String, color: Color) -> Mesh {
        let builder = Mesh(name: name).builder()
        
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
        
        return builder.mesh
    }
}
