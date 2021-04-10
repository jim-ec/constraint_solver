import Metal
import MetalKit
import simd

protocol FrameDelegate {
    func onFrame(dt: Double, t: Double)
}

class Renderer: NSObject, MTKViewDelegate {
    var frameDelegate: FrameDelegate? = .none
    private var startTime = Double(CACurrentMediaTime())
    private var lastFrameTime = Double(CACurrentMediaTime())
    
    public let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState
    private var depthState: MTLDepthStencilState
    private var hudDepthState: MTLDepthStencilState
    
    let fovY: Float = 1.0472
    let zNear: Float = 0.1
    let zFar: Float = 100.0
    var width: Float = 1.0
    var height: Float = 1.0
    var aspectRatio: Float = 1.0
    var camera = Camera()
    
    private var meshBuffers: [(Mesh, MTLBuffer)] = []
    fileprivate let grid: Grid
    fileprivate let axes: Axes
    
    init(mtkView: MTKView) {
        device = mtkView.device!
        commandQueue = device.makeCommandQueue()!
        
        mtkView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        mtkView.colorPixelFormat = MTLPixelFormat.bgra8Unorm
        mtkView.sampleCount = 4
        mtkView.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0)
        
        let library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.sampleCount = mtkView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
        
        let hudDepthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .always
        depthStencilDescriptor.isDepthWriteEnabled = false
        hudDepthState = device.makeDepthStencilState(descriptor: hudDepthStencilDescriptor)!
        
        grid = Grid(device: device, sections: 30)
        axes = Axes(device: device)
        
        super.init()
    }
    
    func draw(in view: MTKView) {
        if let frameDelegate = frameDelegate {
            let currentTime = Double(CACurrentMediaTime())
            let dt = currentTime - lastFrameTime
            if dt > 0 {
                frameDelegate.onFrame(dt: dt, t: currentTime - startTime)
            }
            lastFrameTime = currentTime
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: view.currentRenderPassDescriptor!)!
        
        encoder.label = "Primary Render Encoder"
        
        encoder.setCullMode(.back)
        encoder.setFrontFacing(.counterClockwise)
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthState)
        
        var uniforms = Uniforms()
        uniforms.view = camera.viewMatrix
        uniforms.projection = projectionMatrix
        
        encoder.pushDebugGroup("Draw Meshes")
        for (mesh, buffer) in meshBuffers {
            encoder.pushDebugGroup("Draw Mesh '\(mesh.name)'")
            
            uniforms.model = mesh.transform
            
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: Int(BufferIndexUniforms))
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: Int(BufferIndexUniforms))
            
            encoder.setVertexBuffer(buffer, offset: 0, index: Int(BufferIndexVertices))

            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: mesh.vertices.count)
            
            encoder.popDebugGroup()
        }
        encoder.popDebugGroup()
        
        grid.render(into: encoder, uniforms: &uniforms)
        
        encoder.pushDebugGroup("Draw HUDs")
        
        let viewMatrix = uniforms.view
        uniforms.model = simd_float4x4(1)
        uniforms.projection = simd_float4x4(1)
        uniforms.view = simd_float4x4(1)
        uniforms.view[0, 0] = 2 * Float(1 / width)
        uniforms.view[1, 1] = -2 * Float(1 / height)
        uniforms.view[3, 0] = -1
        uniforms.view[3, 1] = 1
        encoder.setCullMode(.none)
        encoder.setDepthStencilState(hudDepthState)
        axes.render(into: encoder, uniforms: &uniforms, width: width, height: height, viewMatrix: viewMatrix)
        
        encoder.popDebugGroup()
        
        
        encoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        width = Float(size.width)
        height = Float(size.height)
        aspectRatio = Float(size.width / size.height)
    }
    
    private var projectionMatrix: simd_float4x4 {
        let tanHalfFovy = tan(0.5 * fovY)

        var perspectiveMatrix = simd_float4x4(1)
        perspectiveMatrix[0][0] = 1 / (aspectRatio * tanHalfFovy)
        perspectiveMatrix[1][1] = 1 / (tanHalfFovy)
        perspectiveMatrix[2][2] = zFar / (zNear - zFar)
        perspectiveMatrix[2][3] = -1
        perspectiveMatrix[3][2] = -(zFar * zNear) / (zFar - zNear)
        
        return perspectiveMatrix
    }
    
    func registerMesh(_ newMesh: Mesh) {
        for (mesh, buffer) in meshBuffers {
            if (mesh === newMesh) {
                if (newMesh.vertices.count != buffer.length / MemoryLayout<Vertex>.stride) {
                    fatalError("Cannot update mesh when the vertex count is different")
                }
                buffer.contents().copyMemory(from: newMesh.vertices, byteCount: newMesh.vertices.count * MemoryLayout<Vertex>.stride)
            }
        }
        
        let buffer = device.makeBuffer(bytes: newMesh.vertices, length: newMesh.vertices.count * MemoryLayout<Vertex>.stride, options: .cpuCacheModeWriteCombined)!
        meshBuffers.append((newMesh, buffer))
    }
}

fileprivate class Grid {
    let buffer: MTLBuffer
    private let vertexCount: Int
    
    init(device: MTLDevice, sections: Int) {
        var vertices: [Vertex] = []
        
        let majorColor = simd_float3(repeating: 0.8)
        let minorColor = simd_float3(repeating: 0.3)
        let normal = simd_float3(0, 0, 1)
        let extent = Float(sections)
        
        vertices.append(Vertex(position: simd_float3(0, extent, 0), normal: normal, color: majorColor))
        vertices.append(Vertex(position: simd_float3(0, -extent, 0), normal: normal, color: majorColor))
        vertices.append(Vertex(position: simd_float3(extent, 0, 0), normal: normal, color: majorColor))
        vertices.append(Vertex(position: simd_float3(-extent, 0, 0), normal: normal, color: majorColor))
        
        for i in 1 ... sections {
            let t = Float(i)
            
            let color = i % 10 == 0 ? majorColor : minorColor
            
            vertices.append(Vertex(position: simd_float3(t, extent, 0), normal: normal, color: color))
            vertices.append(Vertex(position: simd_float3(t, -extent, 0), normal: normal, color: color))
            vertices.append(Vertex(position: simd_float3(-t, extent, 0), normal: normal, color: color))
            vertices.append(Vertex(position: simd_float3(-t, -extent, 0), normal: normal, color: color))
            vertices.append(Vertex(position: simd_float3(extent, t, 0), normal: normal, color: color))
            vertices.append(Vertex(position: simd_float3(-extent, t, 0), normal: normal, color: color))
            vertices.append(Vertex(position: simd_float3(extent, -t, 0), normal: normal, color: color))
            vertices.append(Vertex(position: simd_float3(-extent, -t, 0), normal: normal, color: color))
        }
        
        vertexCount = vertices.count
        buffer = device.makeBuffer(bytes: &vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: .cpuCacheModeWriteCombined)!
    }
    
    func render(into encoder: MTLRenderCommandEncoder, uniforms: inout Uniforms) {
        encoder.pushDebugGroup("Draw Grid")
        uniforms.model = simd_float4x4(1)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: Int(BufferIndexUniforms))
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: Int(BufferIndexUniforms))
        encoder.setVertexBuffer(buffer, offset: 0, index: Int(BufferIndexVertices))
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: vertexCount)
        encoder.popDebugGroup()
    }
}

fileprivate class Axes {
    var vertices: [Vertex] = []
    let buffer: MTLBuffer
    let size: Float = 120
    let margin: Float = 10
    let circleColor = simd_float3(repeating: 0.2)
    let circleSubdivisions = 50
    let axesVertexOffset: Int
    
    init(device: MTLDevice) {
        axesVertexOffset = circleSubdivisions * 3
        buffer = device.makeBuffer(length: MemoryLayout<Vertex>.stride * (axesVertexOffset + 6 * 3), options: .cpuCacheModeWriteCombined)!
        
        for i in 0 ..< circleSubdivisions {
            let t1 = 2 * .pi * Float(i) / Float(circleSubdivisions)
            let t2 = 2 * .pi * Float(i + 1) / Float(circleSubdivisions)
            
            push(0, 0, circleColor)
            push(cos(t1), sin(t1), circleColor)
            push(cos(t2), sin(t2), circleColor)
        }
    }
    
    private func push(_ x: Float, _ y: Float, _ color: simd_float3) {
        vertices.append(Vertex(
                            position: simd_float3(x, y, 0),
                            normal: simd_float3(0, 0, -1),
                            color: color)
        )
    }
    
    func render(into encoder: MTLRenderCommandEncoder, uniforms: inout Uniforms, width: Float, height: Float, viewMatrix: simd_float4x4) {
        encoder.pushDebugGroup("Draw Axes")
        
        uniforms.model[0, 0] = size / 2
        uniforms.model[1, 1] = size / 2
        uniforms.model[3, 0] = width - size / 2 - margin
        uniforms.model[3, 1] = height - size / 2 - margin
        
        // Overwrite axes vertices from last frame.
        vertices.removeLast(vertices.count - axesVertexOffset)
        
        // Get axes in the current view space.
        let ex = viewMatrix * simd_float4(1, 0, 0, 0)
        let ey = viewMatrix * simd_float4(0, 1, 0, 0)
        let ez = viewMatrix * simd_float4(0, 0, 1, 0)
        
        // Sort axes by depth.
        var axes: [(simd_float4, simd_float3)] = []
        axes.append((ex, simd_float3(1, 0.5, 0.5)))
        axes.append((ey, simd_float3(0.5, 1, 0.5)))
        axes.append((ez, simd_float3(0.5, 0.5, 1)))
        axes.sort { (a, b) -> Bool in
            a.0.z < b.0.z
        }
        
        for (axis, color) in axes {
            // Generate a thin quad from the line spanning from the origin to the computed axis end-point.
            let p = 0.95 * simd_float2(axis.x, -axis.y)
            let n = 0.03 * simd_normalize(simd_float2(axis.y, axis.x))
            let p1 = n
            let p2 = -n
            let p3 = p + n
            let p4 = p - n
            
            // Axes which point away from the camera are grayed out.
            let c = axis.z > 0 ? color : simd_float3(repeating: 0.6)
            
            push(p1.x, p1.y, c)
            push(p2.x, p2.y, c)
            push(p4.x, p4.y, c)
            
            push(p1.x, p1.y, c)
            push(p4.x, p4.y, c)
            push(p3.x, p3.y, c)
        }
        
        buffer.contents().copyMemory(from: vertices, byteCount: buffer.length)
        
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: Int(BufferIndexUniforms))
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: Int(BufferIndexUniforms))
        encoder.setVertexBuffer(buffer, offset: 0, index: Int(BufferIndexVertices))
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        encoder.popDebugGroup()
    }
}
