import Metal
import MetalKit
import simd

class Renderer: NSObject, MTKViewDelegate {
    
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState
    
    var uniformBuffer: MTLBuffer
    var uniforms: UnsafeMutablePointer<Uniforms>
    
    var vertexDescriptor = MTLVertexDescriptor()
    var indexBuffer: MTLBuffer
    var positionBuffer: MTLBuffer
    var colorBuffer: MTLBuffer
    
    let t0 = CACurrentMediaTime()
    
    init(metalKitView: MTKView) {
        device = metalKitView.device!
        commandQueue = device.makeCommandQueue()!
        
        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1
        
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [MTLResourceOptions.storageModeShared])!
        uniforms = UnsafeMutableRawPointer(uniformBuffer.contents()).bindMemory(to: Uniforms.self, capacity: 1)
        
        vertexDescriptor.attributes[Int(VertexAttributePosition)].format = MTLVertexFormat.float3
        vertexDescriptor.attributes[Int(VertexAttributePosition)].offset = 0
        vertexDescriptor.attributes[Int(VertexAttributePosition)].bufferIndex = Int(BufferIndexMeshPositions)
        
        vertexDescriptor.attributes[Int(VertexAttributeColor)].format = MTLVertexFormat.float3
        vertexDescriptor.attributes[Int(VertexAttributeColor)].offset = 0
        vertexDescriptor.attributes[Int(VertexAttributeColor)].bufferIndex = Int(BufferIndexMeshColors)
        
        vertexDescriptor.layouts[Int(BufferIndexMeshPositions)].stride = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[Int(BufferIndexMeshPositions)].stepRate = 1
        vertexDescriptor.layouts[Int(BufferIndexMeshPositions)].stepFunction = MTLVertexStepFunction.perVertex
        
        vertexDescriptor.layouts[Int(BufferIndexMeshColors)].stride = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[Int(BufferIndexMeshColors)].stepRate = 1
        vertexDescriptor.layouts[Int(BufferIndexMeshColors)].stepFunction = MTLVertexStepFunction.perVertex
        
        let library = device.makeDefaultLibrary()!
        
        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Unable to compile render pipeline state: \(error)")
        }
        
        let indices: [UInt16] = [0, 1, 2]
        let positions: [SIMD3<Float>] = [.init(-1, -1, 0), .init(1, -1, 0), .init(0, 1, 0)];
        let colors: [SIMD3<Float>] = [.init(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)];
        
        indexBuffer = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.stride * indices.count, options: .cpuCacheModeWriteCombined)!
        positionBuffer = device.makeBuffer(bytes: positions, length: MemoryLayout<SIMD3<Float>>.stride * positions.count, options: .cpuCacheModeWriteCombined)!
        colorBuffer = device.makeBuffer(bytes: colors, length: MemoryLayout<SIMD3<Float>>.stride * colors.count, options: .cpuCacheModeWriteCombined)!
        
        super.init()
    }
    
    private func updateUniforms() {
        let dt = CACurrentMediaTime() - t0;
        let scale = Float((sin(dt * 2) * 0.125 + 0.5))
        uniforms[0].transform = .init(diagonal: .init(repeating: scale))
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
        renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(BufferIndexMeshPositions))
        renderEncoder.setVertexBuffer(colorBuffer, offset: 0, index: Int(BufferIndexMeshColors))
        
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: 3, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
}
