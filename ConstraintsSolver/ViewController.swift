import Cocoa
import MetalKit

class ViewController: NSViewController {
    
    var renderer: Renderer!
    var mtkView: MTKView!
    var triangle: Geometry!
    
    override func loadView() {
        mtkView = MTKView(frame: AppDelegate.windowRect)
        mtkView.device = MTLCreateSystemDefaultDevice()!
        
        renderer = Renderer(metalKitView: mtkView)
        mtkView.delegate = renderer
        
        triangle = renderer.makeCube(name: "Cube", color: .white)
        triangle.translation.z = 5
        
        self.view = mtkView
    }
    
    override func keyDown(with event: NSEvent) {
        if event.characters == "q" && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
            NSApplication.shared.terminate(self)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        triangle.rotation.x += Float(event.deltaY * 0.01)
        triangle.rotation.y += Float(event.deltaX * 0.01)
    }
}
