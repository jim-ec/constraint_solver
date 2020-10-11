import Metal
import MetalKit
import simd

class Geometry {
    let name: String
    let color: SIMD3<Float>
    let vertices: UnsafeMutableBufferPointer<Vertex>
    
    init(name: String, vertexCount: Int, color: SIMD3<Float>, renderer: Renderer) {
        self.name = name
        self.color = color
        vertices = renderer.allocateVertices(vertexCount: vertexCount)
        renderer.geometries.append(self)
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

class Renderer: NSObject, MTKViewDelegate {
    
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState
    
    var uniformBuffer: MTLBuffer
    var uniforms: UnsafeMutablePointer<Uniforms>
    
    var geometries: [Geometry] = []
    
    var vertexBuffer: MTLBuffer
    var vertices: UnsafeMutablePointer<Vertex>
    
    var currentVertexCount = 0
    static let vertexCount = 1024
    
    func makeTriangle(name: String, color: SIMD3<Float>) -> Geometry {
        let geometry = Geometry(name: name, vertexCount: 3, color: color, renderer: self)
        geometry[0] = .init(position: .init(-1, -1, 0), color: .init(1, 0, 0))
        geometry[1] = .init(position: .init(1, -1, 0), color: .init(0, 1, 0))
        geometry[2] = .init(position: .init(0, 1, 0), color: .init(0, 0, 1))
        return geometry
    }
    
    func allocateVertices(vertexCount: Int) -> UnsafeMutableBufferPointer<Vertex> {
        if currentVertexCount + vertexCount >= Renderer.vertexCount {
            fatalError("Vertex buffer is out of memory")
        }
        
        let pointer = UnsafeMutableBufferPointer(start: vertices.advanced(by: currentVertexCount), count: vertexCount)
        currentVertexCount += vertexCount
        return pointer
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
        
        vertexBuffer = device.makeBuffer(length: Renderer.vertexCount * MemoryLayout<Vertex>.stride, options: .cpuCacheModeWriteCombined)!
        vertices = vertexBuffer.contents().bindMemory(to: Vertex.self, capacity: Renderer.vertexCount)
        
        super.init()
    }
    
    private func updateUniforms() {
        uniforms[0].transform = .init(diagonal: .init(repeating: 1.0))
    }
    
    func draw(in view: MTKView) {
        updateUniforms()
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: view.currentRenderPassDescriptor!)!
        
        renderEncoder.label = "Primary Render Encoder"
        renderEncoder.pushDebugGroup("Draw Triangle")
        
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)
        
        renderEncoder.setRenderPipelineState(pipelineState)
        
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: Int(BufferIndexUniforms))
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: Int(BufferIndexUniforms))
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(BufferIndexVertices))
        
        for geometry in geometries {
            renderEncoder.pushDebugGroup("Draw '\(geometry.name)'")
            
            let vertexStart = geometry.vertices.baseAddress! - vertices
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: vertexStart, vertexCount: geometry.vertices.count)
            
            renderEncoder.popDebugGroup()
        }
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
}
