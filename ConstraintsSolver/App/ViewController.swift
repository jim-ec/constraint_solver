import Cocoa
import MetalKit

class ViewController: NSViewController, FrameDelegate {
    private var renderer: Renderer!
    private var mtkView: MTKView!
    private var cubeMesh: Mesh!
    private var triangle: Mesh!
    private let system = System(subStepCount: 10, collisionGroup: CollisionGroup(rigidBody: RigidBody(mass: 1, extent: double3(1, 1, 1))))
    private var cube: RigidBody!
    
    override func loadView() {
        mtkView = MTKView(frame: AppDelegate.windowRect)
        mtkView.device = MTLCreateSystemDefaultDevice()!
        view = mtkView
        
        renderer = Renderer(mtkView: mtkView)
        mtkView.delegate = renderer
        
        renderer.frameDelegate = self
        renderer.camera.look(at: .zero, from: double3(4, 4, 4), up: .ez)
        
        cubeMesh = Mesh.makeCube(name: "Cube", color: .white)
        cubeMesh.map { x in x - simd_float3(0.5, 0.5, 0.5) }
        renderer.registerMesh(cubeMesh)
        
        cube = system.collisionGroup.rigidBody
        cube.orientation = .init(angle: .pi / 8, axis: .ey + 0.5 * .ex)
        cube.position = double3(0, 0, 4)
        cube.externalForce.z = -5
        cube.angularVelocity = .init(1, 2, 0.5)
        
        let X = Mesh.makeCube(name: "x", color: .red)
        X.map(by: Transform.position(-X.findCenterOfMass()))
        X.map { x in x * 0.5 }
        X.transform.position.x = 4
        renderer.registerMesh(X)
        
        let Y = Mesh.makeCube(name: "y", color: .green)
        Y.map(by: Transform.position(-Y.findCenterOfMass()))
        Y.map { x in x * 0.5 }
        Y.transform.position.y = 4
        renderer.registerMesh(Y)
    }
    
    func onFrame(dt: Double, t: Double) {
        system.step(by: dt)
        cubeMesh.transform.position = cube.position
        cubeMesh.transform.orientation = cube.orientation
    }
    
    override func mouseDragged(with event: NSEvent) {
        // Orbit
        let sensitivity = 0.01
        renderer.camera.orbit(rightwards: sensitivity * Double(-event.deltaX), upwards: sensitivity * Double(event.deltaY))
    }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.shift) {
            // Pan
            let sensitivity = 0.001 * renderer.camera.radius
            renderer.camera.pan(rightwards: sensitivity * Double(-event.scrollingDeltaX), upwards: sensitivity * Double(event.scrollingDeltaY))
        }
        else {
            // Pan relative to ground
            let sensitivity = 0.001 * renderer.camera.radius
            let dx = sensitivity * Double(-event.scrollingDeltaX)
            let dy = sensitivity * Double(event.scrollingDeltaY)
            renderer.camera.position +=
                dx * renderer.camera.right +
                dy * double3(renderer.camera.forward.x, renderer.camera.forward.y, 0).normalize
        }
    }

    override func magnify(with event: NSEvent) {
        // Zoom
        renderer.camera.zoom(by: 1 + Double(event.magnification))
    }
}
