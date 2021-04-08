import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    static let windowRect = NSMakeRect(0, 0, NSScreen.main!.frame.width, NSScreen.main!.frame.height)
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate), keyEquivalent: "q"))

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu

        let mainMenu = NSMenu()
        mainMenu.addItem(appMenuItem)

        NSApp.mainMenu = mainMenu

        NSApp.setActivationPolicy(.regular)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: AppDelegate.windowRect,
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered,
                          defer: false)
        
        window.title = "Constraints Solver"
        window.level = .normal
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.acceptsMouseMovedEvents = true
        window.makeKeyAndOrderFront(nil)
        
        let viewController = ViewController()
        window.contentViewController = viewController
        window.makeFirstResponder(viewController)
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
