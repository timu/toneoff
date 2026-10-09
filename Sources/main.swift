import AppKit
import Carbon.HIToolbox
import ServiceManagement

private enum Key {
    static let autoManage = "autoManage"
    static let weTurnedItOff = "weTurnedItOff"
}

/// Debug hook: `TONEOFF_EXTERNALS=<n>` pretends n external displays are connected.
func externalDisplayCount() -> Int {
    if let fake = ProcessInfo.processInfo.environment["TONEOFF_EXTERNALS"], let n = Int(fake) {
        return n
    }
    var ids = [CGDirectDisplayID](repeating: 0, count: 16)
    var count: UInt32 = 0
    CGGetOnlineDisplayList(UInt32(ids.count), &ids, &count)
    return ids.prefix(Int(count)).filter { CGDisplayIsBuiltin($0) == 0 }.count
}

// MARK: - Command line

/// `--status | --on | --off | --toggle`: headless use, e.g. from Shortcuts or a script.
func runCommandLine(_ flag: String) -> Never {
    guard ["--status", "--on", "--off", "--toggle"].contains(flag) else {
        print("usage: Toneoff [--status | --on | --off | --toggle]")
        exit(2)
    }
    guard TrueTone.isSupported, let current = TrueTone.isEnabled else {
        print("unsupported")
        exit(1)
    }
    if flag == "--status" {
        print(current ? "on" : "off")
    } else {
        let target = flag == "--on" ? true : flag == "--off" ? false : !current
        UserDefaults.standard.set(false, forKey: Key.weTurnedItOff)
        guard TrueTone.setEnabled(target) else {
            print("failed")
            exit(1)
        }
        print(target ? "on" : "off")
    }
    exit(0)
}

if let flag = CommandLine.arguments.dropFirst().first, flag.hasPrefix("--") {
    runCommandLine(flag)
}

// MARK: - Menu bar app

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let defaults = UserDefaults.standard
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let stateItem = NSMenuItem()
    private let displaysItem = NSMenuItem()
    private let autoItem = NSMenuItem(title: "Turn off with external displays", action: #selector(toggleAuto), keyEquivalent: "")
    private let trueToneItem = NSMenuItem(title: "True Tone", action: #selector(toggleTrueTone), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")

    private var wasExternalPresent: Bool?
    private var pendingReconcile: DispatchWorkItem?

    private var weTurnedItOff: Bool {
        get { defaults.bool(forKey: Key.weTurnedItOff) }
        set { defaults.set(newValue, forKey: Key.weTurnedItOff) }
    }

    private var autoManage: Bool {
        get { defaults.bool(forKey: Key.autoManage) }
        set { defaults.set(newValue, forKey: Key.autoManage) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: [Key.autoManage: true])

        buildMenu()
        refresh()
        registerHotKey()

        CGDisplayRegisterReconfigurationCallback({ _, _, info in
            guard let info else { return }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(info).takeUnretainedValue()
            DispatchQueue.main.async { delegate.scheduleReconcile() }
        }, Unmanaged.passUnretained(self).toOpaque())
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.scheduleReconcile(after: 2) }

        reconcile()
    }

    // MARK: Policy

    /// Display changes arrive in bursts, so wait for them to settle before acting.
    private func scheduleReconcile(after delay: TimeInterval = 1) {
        pendingReconcile?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reconcile() }
        pendingReconcile = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func reconcile() {
        defer { refresh() }
        guard autoManage, TrueTone.isSupported, let trueToneOn = TrueTone.isEnabled else { return }

        let count = externalDisplayCount()
        let decision = decideTrueTone(
            externalPresent: count > 0,
            wasExternalPresent: wasExternalPresent,
            trueToneOn: trueToneOn,
            weTurnedItOff: weTurnedItOff
        )
        NSLog("Toneoff: externals=%d trueTone=%@ -> %@", count, trueToneOn ? "on" : "off", "\(decision.action)")

        switch decision.action {
        case .none: break
        case .turnOff, .turnOn:
            guard TrueTone.setEnabled(decision.action == .turnOn) else {
                // Leave the transition unrecorded so the next display event retries.
                NSLog("Toneoff: could not change True Tone")
                return
            }
        }
        wasExternalPresent = count > 0
        weTurnedItOff = decision.weTurnedItOff
    }

    // MARK: Menu

    private func buildMenu() {
        menu.delegate = self
        stateItem.isEnabled = false
        displaysItem.isEnabled = false
        for item in [autoItem, trueToneItem, loginItem] { item.target = self }
        trueToneItem.title = "True Tone  (⌃⌥⌘T)"

        menu.addItem(stateItem)
        menu.addItem(displaysItem)
        menu.addItem(.separator())
        menu.addItem(autoItem)
        menu.addItem(trueToneItem)
        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) { refresh() }

    private func refresh() {
        let supported = TrueTone.isSupported
        let on = TrueTone.isEnabled ?? false
        let count = externalDisplayCount()

        stateItem.title = supported ? "True Tone is \(on ? "On" : "Off")" : "True Tone is not supported on this Mac"
        displaysItem.title = "External displays: \(count)"
        autoItem.state = autoManage ? .on : .off
        trueToneItem.state = on ? .on : .off
        trueToneItem.isEnabled = supported
        autoItem.isEnabled = supported
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off

        let symbol = on ? "sun.max.fill" : "sun.max"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "True Tone \(on ? "on" : "off")")
        statusItem.button?.toolTip = "True Tone \(on ? "on" : "off") · \(count) external display\(count == 1 ? "" : "s")"
    }

    @objc private func toggleAuto() {
        autoManage.toggle()
        // Start from "unknown" so enabling the option applies the policy straight away.
        wasExternalPresent = nil
        reconcile()
    }

    @objc func toggleTrueTone() {
        guard let current = TrueTone.isEnabled else { return }
        weTurnedItOff = false
        TrueTone.setEnabled(!current)
        refresh()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Toneoff: login item change failed: %@", error.localizedDescription)
        }
        refresh()
    }

    // MARK: Hotkey (⌃⌥⌘T)

    private func registerHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { delegate.toggleTrueTone() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)

        var hotKey: EventHotKeyRef?
        RegisterEventHotKey(
            UInt32(kVK_ANSI_T), UInt32(controlKey | optionKey | cmdKey),
            EventHotKeyID(signature: OSType(0x5454_4744), id: 1),
            GetApplicationEventTarget(), 0, &hotKey
        )
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
