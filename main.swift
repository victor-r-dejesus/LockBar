import AppKit
import CoreGraphics

// MARK: - Dock Locker

final class DockLocker {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    // The screen the dock was on when lock() was called.
    private(set) var dockedScreen: NSScreen?

    var isLocked: Bool { eventTap != nil }

    func lock() -> Bool {
        guard checkAccessibility() else { return false }
        dockedScreen = screenWithDock()

        let mask: CGEventMask =
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mouseEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = eventTap else { return false }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        runLoopSource = source
        return true
    }

    func unlock() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        dockedScreen = nil
    }

    // The screen whose visibleFrame bottom edge is higher than its frame bottom
    // is the one the dock is sitting on.
    func screenWithDock() -> NSScreen? {
        NSScreen.screens.first { $0.visibleFrame.origin.y > $0.frame.origin.y }
            ?? NSScreen.screens.first
    }

    // Returns the primary screen height in points (used for CG <-> NS coordinate conversion).
    func primaryHeight() -> CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    // If the cursor is within `threshold` pixels of the bottom of any screen
    // that is NOT the docked screen, return a clamped y to block the hover.
    func clampedY(for location: CGPoint, threshold: CGFloat = 3) -> CGFloat? {
        let ph = primaryHeight()
        for screen in NSScreen.screens {
            guard screen != dockedScreen else { continue }
            let f = screen.frame
            let cgBottom = ph - f.origin.y
            let cgTop    = ph - (f.origin.y + f.height)
            let cgLeft   = f.origin.x
            let cgRight  = f.origin.x + f.width

            guard location.x >= cgLeft,
                  location.x <= cgRight,
                  location.y >= cgTop,
                  location.y <= cgBottom else { continue }

            if location.y >= cgBottom - threshold {
                return cgBottom - threshold - 1
            }
        }
        return nil
    }

    private func checkAccessibility() -> Bool {
        AXIsProcessTrusted()
    }
}

// C-compatible callback for CGEvent.tapCreate.
private func mouseEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passRetained(event) }
    let locker = Unmanaged<DockLocker>.fromOpaque(userInfo).takeUnretainedValue()

    if let newY = locker.clampedY(for: event.location) {
        var loc = event.location
        loc.y = newY
        event.location = loc
    }

    return Unmanaged.passRetained(event)
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    let locker = DockLocker()
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        let toggle = NSMenuItem(title: "Lock Dock Position", action: #selector(toggleLock), keyEquivalent: "l")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit LockBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        refreshUI()
    }

    @objc func toggleLock() {
        if locker.isLocked {
            locker.unlock()
        } else {
            let granted = locker.lock()
            if !granted {
                showAccessibilityAlert()
                return
            }
        }
        refreshUI()
    }

    func refreshUI() {
        guard let button = statusItem.button else { return }
        let locked = locker.isLocked
        button.image = NSImage(systemSymbolName: locked ? "lock.fill" : "lock.open",
                               accessibilityDescription: locked ? "Dock Locked" : "Dock Unlocked")
        button.toolTip = locked ? "Dock locked — click to unlock" : "Dock unlocked — click to lock"

        if let item = statusItem.menu?.item(at: 0) {
            item.title = locked ? "Unlock Dock Position" : "Lock Dock Position"
        }
    }

    func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "LockBar needs Accessibility access to intercept mouse events and prevent the Dock from switching monitors.\n\nClick \"Open System Settings\", enable LockBar under Accessibility, then LockBar will relaunch automatically."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            relaunchAfterPermission()
        }
    }

    // Polls until Accessibility is granted, then relaunches the app so the
    // new permission takes effect (macOS requires a process restart).
    func relaunchAfterPermission() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if AXIsProcessTrusted() {
                timer.invalidate()
                let bundlePath = Bundle.main.bundleURL.path
                let task = Process()
                task.launchPath = "/bin/sh"
                task.arguments = ["-c", "sleep 0.5 && open '\(bundlePath)'"]
                task.launch()
                NSApp.terminate(nil)
            }
        }
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
