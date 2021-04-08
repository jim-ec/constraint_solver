import Cocoa
import MetalKit

class ViewController: NSViewController, FrameDelegate {
    private var renderer: Renderer!
    private var mtkView: MTKView!
    private var cubeGeometry: Geometry!
    private var triangle: Geometry!
    private let system = System(subStepCount: 10, collisionGroup: CollisionGroup(rigidBody: RigidBody(mass: 1, extent: double3(1, 1, 1))))
    private var cube: RigidBody!
    
    override func loadView() {
        mtkView = MTKView(frame: AppDelegate.windowRect)
        mtkView.device = MTLCreateSystemDefaultDevice()!
        
        renderer = Renderer(mtkView: mtkView)
        mtkView.delegate = renderer
        
        renderer.frameDelegate = self
        renderer.camera.look(at: .zero, from: double3(4, 4, 4), up: .ez)
        
        cubeGeometry = renderer.makeCube(name: "Cube", color: .white)
        cubeGeometry.map { x in x - simd_float3(0.5, 0.5, 0.5) }
        
        cube = system.collisionGroup.rigidBody
        cube.orientation = .init(angle: .pi / 8, axis: .ey + 0.5 * .ex)
        cube.position = double3(0, 0, 4)
        cube.externalForce.z = -5
        cube.angularVelocity = .init(1, 2, 0.5)
        
        let X = renderer.makeCube(name: "x", color: .red)
        X.map(by: Transform.position(-X.findCenterOfMass()))
        X.map { x in x * 0.5 }
        X.transform.position.x = 4
        
        let Y = renderer.makeCube(name: "y", color: .green)
        Y.map(by: Transform.position(-Y.findCenterOfMass()))
        Y.map { x in x * 0.5 }
        Y.transform.position.y = 4
        
        view = mtkView
        mtkView.allowedTouchTypes = .indirect
    }
    
    func onFrame(dt: Double, t: Double) {
        system.step(by: dt)
        cubeGeometry.transform.position = cube.position
        cubeGeometry.transform.orientation = cube.orientation
    }
    
    override func mouseDragged(with event: NSEvent) {
        // Orbit
        let sensitivity = 0.01
        renderer.camera.orbit(rightwards: sensitivity * Double(-event.deltaX), upwards: sensitivity * Double(event.deltaY))
    }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.shift) {
            // Zoom
            let sensitivity = 0.002
            renderer.camera.zoom(by: 1 + sensitivity * Double(event.scrollingDeltaY))
        }
        else {
            // Pan
            let sensitivity = 0.001 * renderer.camera.radius
            renderer.camera.pan(rightwards: sensitivity * Double(-event.scrollingDeltaX), upwards: sensitivity * Double(event.scrollingDeltaY))
        }
    }

    override func magnify(with event: NSEvent) {
        // Zoom
        renderer.camera.zoom(by: 1 + Double(event.magnification))
    }
}
