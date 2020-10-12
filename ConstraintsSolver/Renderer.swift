import Metal
import MetalKit
import simd

struct Color {
    let rgb: SIMD3<Float>
    
    init(_ red: Float, _ green: Float, _ blue: Float) {
        rgb = .init(red, green, blue)
    }
    
    init(_ grey: Float) {
        rgb = .init(repeating: grey)
    }
    
    static let red = Color(1, 0, 0)
    static let green = Color(0, 1, 0)
    static let blue = Color(0, 0, 1)
    static let yellow = Color(1, 1, 0)
    static let cyan = Color(0, 1, 1)
    static let magenta = Color(1, 0, 1)
    static let white = Color(1)
    static let black = Color(0)
}

struct Geometry {
    let name: String
    let vertices: UnsafeMutableBufferPointer<Vertex>
    
    subscript(index: Int) -> Vertex {
        get {
            vertices[index]
        }
        set {
            vertices[index] = newValue
        }
    }
}

class Renderer: NSObject, MTKViewDelegate {
    
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState
    
    var uniformBuffer: MTLBuffer
    var uniforms: UnsafeMutablePointer<Uniforms>
    var aspectRatio: Float = 1
    
    var geometries: [Geometry] = []
    
    var vertexBuffer: MTLBuffer
    var vertices: UnsafeMutablePointer<Vertex>
    
    var currentVertexCount = 0
    static let maximalVertexCount = 1024
    
    func makeGeometry(name: String, vertexCount: Int) -> Geometry {
        if currentVertexCount + vertexCount >= Renderer.maximalVertexCount {
            fatalError("Vertex buffer is out of memory")
        }
        
        let pointer = UnsafeMutableBufferPointer(start: vertices.advanced(by: currentVertexCount), count: vertexCount)
        currentVertexCount += vertexCount

        let geometry = Geometry(name: name, vertices: pointer)
        geometries.append(geometry)
        return geometry
    }
    
    func makeTriangle(name: String, colors: (Color, Color, Color)) -> Geometry {
        var geometry = makeGeometry(name: name, vertexCount: 3)
        geometry[0] = .init(position: .init(-1, -1, 5), color: colors.0.rgb)
        geometry[1] = .init(position: .init(1, -1, 5), color: colors.1.rgb)
        geometry[2] = .init(position: .init(0, 1, 5), color: colors.2.rgb)
        return geometry
    }
    
    init(metalKitView: MTKView) {
        device = metalKitView.device!
        commandQueue = device.makeCommandQueue()!
        
        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1
        
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [MTLResourceOptions.storageModeShared])!
        uniforms = uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        
        let library = device.makeDefaultLibrary()!
        
        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Unable to compile render pipeline state: \(error)")
        }
        
        vertexBuffer = device.makeBuffer(length: Renderer.maximalVertexCount * MemoryLayout<Vertex>.stride, options: .cpuCacheModeWriteCombined)!
        vertices = vertexBuffer.contents().bindMemory(to: Vertex.self, capacity: Renderer.maximalVertexCount)
        
        super.init()
    }
    
    private func updateUniforms() {
        uniforms[0].transform = .init(diagonal: .init(repeating: 1.0))
        uniforms[0].projection = perspectiveTransform(fovy: 1.0472, aspectRatio: aspectRatio)
    }
    
    func draw(in view: MTKView) {
        updateUniforms()
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: view.currentRenderPassDescriptor!)!
        
        renderEncoder.label = "Primary Render Encoder"
        
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)
        
        renderEncoder.setRenderPipelineState(pipelineState)
        
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: Int(BufferIndexUniforms))
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: Int(BufferIndexUniforms))
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(BufferIndexVertices))
        
        renderEncoder.pushDebugGroup("Draw Geometries")
        
        for geometry in geometries {
            renderEncoder.pushDebugGroup("Draw Geometry '\(geometry.name)'")
            
            let vertexStart = geometry.vertices.baseAddress! - vertices
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: vertexStart, vertexCount: geometry.vertices.count)
            
            renderEncoder.popDebugGroup()
        }
        
        renderEncoder.popDebugGroup()
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        aspectRatio = Float(size.width / size.height)
    }
}

/// Left-handed perspective projection matrix.
/// The camera looks in the positive z-direction.
func perspectiveTransform(fovy: Float, aspectRatio: Float) -> matrix_float4x4 {
    // Scale x and y according to the field of view and the given aspect ratio.
    // Then copy the z value to the w coordinate.
    // The resulting matrix is actually so sparse that it could be represented by a single vector.
    let y = 1 / tanf(fovy * 0.5)
    let x = y / aspectRatio
    return matrix_float4x4(columns: (vector_float4(x, 0, 0, 0),
                                     vector_float4(0, y, 0, 0),
                                     vector_float4(0, 0, 1, 1),
                                     vector_float4(0, 0, 0, 0)))
}
