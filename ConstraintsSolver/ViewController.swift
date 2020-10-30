import Cocoa
import MetalKit

class ViewController: NSViewController, FrameDelegate {
    
    var renderer: Renderer!
    var mtkView: MTKView!
    var cube: Geometry!
    var cuboid = Cuboid(mass: 1.0, extent: simd_float3(1, 1, 1))
    var triangle: Geometry!
    
    override func loadView() {
        mtkView = MTKView(frame: AppDelegate.windowRect)
        mtkView.device = MTLCreateSystemDefaultDevice()!
        
        renderer = Renderer(metalKitView: mtkView)
        mtkView.delegate = renderer
        
        renderer.frameDelegate = self
        renderer.viewOrbitRadius = 10
        
        cube = renderer.makeCube(name: "Cube", color: .white)
        //cube.map(by: Transform.translation(-cube.findCenterOfMass()))
//        cube.transform.translation.z = 2
        cube.transform.rotation = .init(angle: .pi / 6, axis: normalize(simd_float3(2, 1, 0)))
        cube.transform.translation.z = 1
        
        let X = renderer.makeCube(name: "x", color: .red)
        X.map(by: Transform.translation(-X.findCenterOfMass()))
        X.map { x in x * 0.5 }
        X.transform.translation.x = 4
        
        let Y = renderer.makeCube(name: "y", color: .green)
        Y.map(by: Transform.translation(-Y.findCenterOfMass()))
        Y.map { x in x * 0.5 }
        Y.transform.translation.y = 4
        
        let floor = renderer.makeQuadliteral(name: "Floor", color: Color(0.2))
        floor.map(by: Transform.translation(-floor.findCenterOfMass()))
        floor.map { position in position * 10 }
        
        view = mtkView
        mtkView.allowedTouchTypes = .indirect
    }
    
    func onFrame(dt: Float, t: Float) {
        
//        let velocity = timeSubStep * externalForce / mass
        
        cube.transform.translation.z -= 0.5 * dt
        
        cuboid.transform = cube.transform
//        cuboid.velocity += velocity
//        cuboid.transform.translation += cuboid.velocity
        
        solveConstraints(cuboid: cuboid)
        
        cube.transform = cuboid.transform
        
//
//        cuboid.transform.translation.z -= 1
//
//        if var contact = intersectCuboidWithGround(cuboid: cuboid) {
//            contactConstraint(contact: &contact, timeSubStep: timeSubStep)
//        }
//
//        cube.transform = cuboid.transform
        
        
//        cube.transform = Transform.around(z: t)
//            .then(.translation(.e2))
//            .then(.around(x: t))
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 12 && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
            NSApplication.shared.terminate(self)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        let sensitivity: Float = 0.01
        renderer.viewOrbitAzimuth += Float(event.deltaX) * sensitivity
        renderer.viewOrbitElevation += Float(event.deltaY) * sensitivity
    }
    
    override func scrollWheel(with event: NSEvent) {
        let sensitivity: Float = 0.001 * renderer.viewOrbitRadius
        renderer.viewPanning.x += Float(-event.scrollingDeltaX) * sensitivity
        renderer.viewPanning.z += Float(event.scrollingDeltaY) * sensitivity
    }
    
    override func magnify(with event: NSEvent) {
        renderer.viewOrbitRadius *= Float(1 - event.magnification)
    }
    
}
