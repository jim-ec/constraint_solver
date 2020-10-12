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
        
        triangle = renderer.makeTriangle(name: "Triangle", colors: (.red, .green, .blue))
        triangle.rotationY = 1.0
        
        self.view = mtkView
    }
    
    override func keyDown(with event: NSEvent) {
        if event.characters == "q" && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
            NSApplication.shared.terminate(self)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        triangle.rotationY += Float(event.deltaX * 0.005)
    }
}
