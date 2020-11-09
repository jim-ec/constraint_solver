import Metal
import MetalKit
import simd

protocol FrameDelegate {
    func onFrame(dt: Double, t: Double)
}

class Renderer: NSObject, MTKViewDelegate {
    
    var frameDelegate: FrameDelegate? = .none
    var startTime = Double(CACurrentMediaTime())
    var lastFrameTime = Double(CACurrentMediaTime())
    
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState
    var depthState: MTLDepthStencilState
    
    var aspectRatio: Double = 1
    var viewOrbitAzimuth: Double = .pi * 2 / 3
    var viewOrbitElevation: Double = .pi * 1 / 8
    var viewOrbitRadius = Double(4)
    var viewPanning = simd_double3()
    
    var geometries: [Geometry] = []
    
    var vertexBuffer: MTLBuffer
    var vertices: UnsafeMutablePointer<Vertex>
    
    var currentVertexCount = 0
    static let maximalVertexCount = 1024
    
    init(metalKitView: MTKView) {
        device = metalKitView.device!
        commandQueue = device.makeCommandQueue()!
        
        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1
        
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
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        
        depthState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
        
        vertexBuffer = device.makeBuffer(length: Renderer.maximalVertexCount * MemoryLayout<Vertex>.stride, options: .cpuCacheModeWriteCombined)!
        vertices = vertexBuffer.contents().bindMemory(to: Vertex.self, capacity: Renderer.maximalVertexCount)
        
        super.init()
    }
    
    func draw(in view: MTKView) {
        if let frameDelegate = frameDelegate {
            let currentTime = Double(CACurrentMediaTime())
            let deltaTime = currentTime - lastFrameTime
            if deltaTime > 0 {
                frameDelegate.onFrame(dt: deltaTime, t: currentTime - startTime)
            }
            lastFrameTime = currentTime
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        renderPassDescriptor.colorAttachments[0].clearColor = .init(red: 0.01, green: 0.01, blue: 0.01, alpha: 0.0)
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        renderEncoder.label = "Primary Render Encoder"
        
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(BufferIndexVertices))
        
        var viewTransform = Transform.look(azimuth: viewOrbitAzimuth, elevation: viewOrbitElevation, radius: viewOrbitRadius)
        viewTransform.position -= viewPanning
        
        var uniforms = Uniforms(
            model: simd_float4x4(diagonal: .one),
            view: viewTransform.matrix(),
            viewPosition: simd_float3(viewTransform.inverse().act(on: .zero)),
            projection: projectionMatrix()
        )
        
        renderEncoder.pushDebugGroup("Draw Geometries")
        
        for geometry in geometries {
            renderEncoder.pushDebugGroup("Draw Geometry '\(geometry.name)'")
            
            uniforms.model = geometry.transform.matrix()
            
            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: Int(BufferIndexUniforms))
            renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: Int(BufferIndexUniforms))

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
        aspectRatio = Double(size.width / size.height)
    }
    
    func projectionMatrix() -> simd_float4x4 {
        let fovY = 1.0472
        let ys = 1 / tan(fovY * 0.5)
        let xs = ys / aspectRatio
        let nearZ = 0.1
        let farZ = 100.0
        let zs = farZ / (nearZ - farZ)
        
        return simd_float4x4(columns: (
            simd_float4(Float(xs), 0, 0, 0),
            simd_float4(0, Float(ys), 0, 0),
            simd_float4(0, 0, Float(zs), -1),
            simd_float4(0, 0, Float(zs * nearZ), 0)
        ))
    }
    
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
}
