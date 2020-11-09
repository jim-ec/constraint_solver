import Cocoa
import MetalKit

class ViewController: NSViewController, FrameDelegate {
    
    var renderer: Renderer!
    var mtkView: MTKView!
    var cube: Geometry!
    var cuboid = Cuboid(mass: 1, extent: simd_double3(1, 1, 1))
    var triangle: Geometry!
    
    override func loadView() {
        mtkView = MTKView(frame: AppDelegate.windowRect)
        mtkView.device = MTLCreateSystemDefaultDevice()!
        
        renderer = Renderer(metalKitView: mtkView)
        mtkView.delegate = renderer
        
        renderer.frameDelegate = self
        renderer.viewOrbitRadius = 10
        
        cube = renderer.makeCube(name: "Cube", color: .white)
        cube.map { x in x - simd_float3(0.5, 0.5, 0.5) }
        cube.transform.orientation = .init(angle: .pi / 8, axis: .e2 + 0.5 * .e1)
        cube.transform.position.z = 4
        
        cuboid.externalForce.z = -5
        cuboid.angularVelocity = .init(1, 2, 0.5)
        
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
        cuboid.transform = cube.transform
        solveConstraints(dt: dt, cuboid: cuboid)
        cube.transform = cuboid.transform
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 12 && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
            NSApplication.shared.terminate(self)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        let sensitivity = 0.01
        renderer.viewOrbitAzimuth += Double(event.deltaX) * sensitivity
        renderer.viewOrbitElevation += Double(event.deltaY) * sensitivity
    }
    
    override func scrollWheel(with event: NSEvent) {
        let sensitivity = 0.001 * renderer.viewOrbitRadius
        renderer.viewPanning.x += Double(-event.scrollingDeltaX) * sensitivity
        renderer.viewPanning.z += Double(event.scrollingDeltaY) * sensitivity
    }
    
    override func magnify(with event: NSEvent) {
        renderer.viewOrbitRadius *= Double(1 - event.magnification)
    }
    
}
