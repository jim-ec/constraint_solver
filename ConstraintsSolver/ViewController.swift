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
        renderer.viewOrbitRadius = 10
        
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
        
        let floor = renderer.makeQuadliteral(name: "Floor", color: Color(0.2))
        floor.map(by: Transform.position(-floor.findCenterOfMass()))
        floor.map { position in position * 10 }
        
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
        renderer.viewOrbitAzimuth += Double(event.deltaX) * sensitivity
        renderer.viewOrbitElevation += Double(event.deltaY) * sensitivity
    }
    
    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock) == .shift {
            // Zoom
            let sensitivity = 0.002
            renderer.viewOrbitRadius *= 1 + sensitivity * Double(event.scrollingDeltaY)
        }
        else {
            // Pan
            let sensitivity = 0.001 * renderer.viewOrbitRadius
            renderer.viewPanning.x += Double(event.scrollingDeltaX) * sensitivity
            renderer.viewPanning.z += Double(-event.scrollingDeltaY) * sensitivity
        }
    }
    
    override func magnify(with event: NSEvent) {
        // Zoom
        renderer.viewOrbitRadius *= Double(1 - event.magnification)
    }
}
