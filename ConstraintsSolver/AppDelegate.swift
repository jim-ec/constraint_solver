import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var window: NSWindow?
    static let windowRect = NSMakeRect(0, 0, NSScreen.main!.frame.width, NSScreen.main!.frame.height)
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: AppDelegate.windowRect,
                          styleMask: [.miniaturizable, .closable, .resizable, .titled],
                          backing: .buffered,
                          defer: false)
        window?.title = "Metal Hello Triangle"
        window?.makeKeyAndOrderFront(nil)
        
        let viewController = ViewController()
        window?.contentViewController = viewController
        window?.makeFirstResponder(viewController)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
}
