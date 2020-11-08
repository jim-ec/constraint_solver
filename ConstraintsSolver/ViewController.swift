import Cocoa
import MetalKit

class ViewController: NSViewController, FrameDelegate {
    
    var renderer: Renderer!
    var mtkView: MTKView!
    var cube: Geometry!
    var cuboid = Cuboid(mass: 2.0, extent: simd_double3(1, 1, 1))
    var triangle: Geometry!
    
    override func loadView() {
        mtkView = MTKView(frame: AppDelegate.windowRect)
        mtkView.device = MTLCreateSystemDefaultDevice()!
        
        renderer = Renderer(metalKitView: mtkView)
        mtkView.delegate = renderer
        
        renderer.frameDelegate = self
        renderer.viewOrbitRadius = 10
        
        cube = renderer.makeCube(name: "Cube", color: .white)
//        cube.map(by: Transform.translation(-cube.findCenterOfMass()))
        cube.transform.rotation = .init(angle: atan(1 / 2), axis: .e2 + 0.5 * .e1)
        cube.transform.translation.z = 2
        
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
    
    func onFrame(dt: Double, t: Double) {
        
//        let velocity = timeSubStep * externalForce / mass
        
        cube.transform.translation.z -= 1 * dt
//
        cuboid.transform = cube.transform
////        cuboid.velocity += velocity
////        cuboid.transform.translation += cuboid.velocity
//
        solveConstraints(cuboid: cuboid)
//
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
