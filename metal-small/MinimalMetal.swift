import Foundation
import Cocoa
import Metal
import MetalKit

class AppDelegate : NSObject, NSApplicationDelegate {
    let window = NSWindow()
    let windowDelegate = WindowDelegate()
    var rootViewController: NSViewController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        window.setContentSize(NSSize(width: 800, height: 600))
        window.styleMask = [ .titled, .closable, .miniaturizable, .resizable ]
        window.title = "Window"
        window.level = .normal
        window.delegate = windowDelegate
        window.center()

        let view = window.contentView!
        rootViewController = ViewController(nibName: nil, bundle: nil)
        rootViewController!.view.frame = view.bounds
        view.addSubview(rootViewController!.view)

        window.makeKeyAndOrderFront(window)

        NSApp.activate(ignoringOtherApps: true)
    }
}

class WindowDelegate : NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(self)
    }
}

class ViewController : NSViewController, MTKViewDelegate {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func loadView() {
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!

        let metalView = MTKView(frame: .zero, device: device)
        metalView.clearColor = MTLClearColorMake(0, 0, 1, 1)
        metalView.delegate = self

        self.view = metalView
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let passDescriptor = view.currentRenderPassDescriptor else { return }
        if let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) {
            // set state, issue draw calls, etc.
            commandEncoder.endEncoding()
        }
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
    }
}

func makeMainMenu() -> NSMenu {
    let mainMenu = NSMenu()
    let mainAppMenuItem = NSMenuItem(title: "Application", action: nil, keyEquivalent: "")
    let mainFileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
    mainMenu.addItem(mainAppMenuItem)
    mainMenu.addItem(mainFileMenuItem)

    let appMenu = NSMenu()
    mainAppMenuItem.submenu = appMenu

    let appServicesMenu = NSMenu()
    NSApp.servicesMenu = appServicesMenu

    appMenu.addItem(withTitle: "Hide", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
    appMenu.addItem({ () -> NSMenuItem in
        let m = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        m.keyEquivalentModifierMask = [.command, .option]
        return m
    }())
    appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")

    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "Services", action: nil, keyEquivalent: "").submenu = appServicesMenu
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

    let fileMenu = NSMenu(title: "Window")
    mainFileMenuItem.submenu = fileMenu
    fileMenu.addItem(withTitle: "Close", action: #selector(NSWindowController.close), keyEquivalent: "w")

    return mainMenu
}

let app = NSApplication.shared
NSApp.setActivationPolicy(.regular)

NSApp.mainMenu = makeMainMenu()

let appDelegate = AppDelegate()
NSApp.delegate = appDelegate

NSApp.run()
