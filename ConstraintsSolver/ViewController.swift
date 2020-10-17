import Cocoa
import MetalKit

class ViewController: NSViewController, FrameDelegate {
    
    var renderer: Renderer!
    var mtkView: MTKView!
    var cube: Geometry!
    var triangle: Geometry!
    
    override func loadView() {
        mtkView = MTKView(frame: AppDelegate.windowRect)
        mtkView.device = MTLCreateSystemDefaultDevice()!
        
        renderer = Renderer(metalKitView: mtkView)
        mtkView.delegate = renderer
        
        renderer.frameDelegate = self
        renderer.cameraDistance = 10
        
        cube = renderer.makeCube(name: "Cube", color: .white)
        cube.transform = Transform(eulerAngles: simd_float3(0, 3.1415 * 0.25, 0))
        cube.transform(by: Transform(translation: -cube.findCenterOfMass()))
        
        let floor = renderer.makeQuadliteral(name: "Floor", color: Color(0.2))
        floor.transform(by: Transform(translation: -floor.findCenterOfMass()))
        floor.map { position in position * 10 }
        
        view = mtkView
        mtkView.allowedTouchTypes = .indirect
    }
    
    func onFrame(dt: Float, t: Float) {
        cube.transform.translation.z = cbrt(3) + 0.5 + sinf(t)
        cube.transform.rotate(eulerAngles: simd_float3(1.8 * dt, dt, 0))
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 12 && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
            NSApplication.shared.terminate(self)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        let sensitivity: Float = 0.01
        renderer.cameraRotationAroundZ += Float(-event.deltaX) * sensitivity
        renderer.cameraRotationElevation += Float(event.deltaY) * sensitivity
    }
    
    override func scrollWheel(with event: NSEvent) {
        let sensitivity: Float = 0.001 * renderer.cameraDistance
        renderer.cameraPanning.x += Float(-event.scrollingDeltaX) * sensitivity
        renderer.cameraPanning.z += Float(event.scrollingDeltaY) * sensitivity
    }
    
    override func magnify(with event: NSEvent) {
        renderer.cameraDistance *= Float(1 - event.magnification)
    }
    
}
