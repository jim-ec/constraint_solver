import Cocoa
import MetalKit

class ViewController: NSViewController {
    
    var renderer: Renderer!
    var mtkView: MTKView!
    
    override func loadView() {
        mtkView = MTKView(frame: AppDelegate.windowRect)
        mtkView.device = MTLCreateSystemDefaultDevice()!
        
        renderer = Renderer(metalKitView: mtkView)
        mtkView.delegate = renderer
        
        renderer.makeTriangle(name: "Triangle", colors: (.red, .green, .blue))
        
        self.view = mtkView
    }
    
    override func keyDown(with event: NSEvent) {
        if event.type == .keyDown && event.characters == "q" && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
            NSApplication.shared.terminate(self)
        }
    }
}
