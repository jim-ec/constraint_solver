import Cocoa
import MetalKit

class ViewController: NSViewController {
    
    var renderer: Renderer!
    var mtkView: MTKView!
    var cube: Geometry!
    var triangle: Geometry!
    
    override func loadView() {
        mtkView = MTKView(frame: AppDelegate.windowRect)
        mtkView.device = MTLCreateSystemDefaultDevice()!
        
        renderer = Renderer(metalKitView: mtkView)
        mtkView.delegate = renderer
        
        cube = renderer.makeCube(name: "Cube", color: .white)
        cube.translation.x = 1
        cube.translation.z = 5
        
        triangle = renderer.makeTriangle(name: "Triangle", colors: (.red, .green, .blue))
        triangle.translation.z = 3
        
        self.view = mtkView
    }
    
    override func keyDown(with event: NSEvent) {
        if event.characters == "q" && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
            NSApplication.shared.terminate(self)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        cube.rotation.x += Float(event.deltaY * 0.01)
        cube.rotation.y += Float(event.deltaX * 0.01)
        triangle.rotation.x += Float(event.deltaY * 0.01)
        triangle.rotation.y += Float(event.deltaX * 0.01)
    }
}
