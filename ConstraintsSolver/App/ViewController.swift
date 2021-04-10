import Cocoa
import MetalKit

class ViewController: NSViewController, FrameDelegate {
    private var renderer: Renderer!
    private var mtkView: MTKView!
    private var world: World!
    
    override func loadView() {
        mtkView = MTKView(frame: AppDelegate.windowRect)
        mtkView.device = MTLCreateSystemDefaultDevice()!
        view = mtkView
        
        renderer = Renderer(mtkView: mtkView)
        mtkView.delegate = renderer
        
        renderer.frameDelegate = self
        renderer.camera.look(at: .zero, from: double3(6, 6, 6), up: .ez)
        
        world = World(renderer: renderer)
    }
    
    func onFrame(dt: Double, t: Double) {
        world.integrate(dt: dt)
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
            renderer.camera.slide(righwards: dx, forwards: dy)
        }
    }

    override func magnify(with event: NSEvent) {
        // Zoom
        renderer.camera.zoom(by: 1 + Double(event.magnification))
    }
}
