import Foundation

/// Wrapper over the private `CBTrueToneClient` in CoreBrightness.framework, the same client
/// System Settings uses. The setting is global: macOS has no per-display True Tone switch.
enum TrueTone {
    private typealias GetBool = @convention(c) (AnyObject, Selector) -> Bool
    private typealias SetBool = @convention(c) (AnyObject, Selector, Bool) -> Bool

    private static let frameworkPath = "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"

    // A fresh client per call, so a long-running app never reads through a stale daemon connection.
    private static func makeClient() -> NSObject? {
        guard dlopen(frameworkPath, RTLD_NOW) != nil,
              let cls = NSClassFromString("CBTrueToneClient") as? NSObject.Type else { return nil }
        return cls.init()
    }

    private static func getBool(_ name: String) -> Bool? {
        guard let client = makeClient() else { return nil }
        let sel = NSSelectorFromString(name)
        guard client.responds(to: sel) else { return nil }
        let call = unsafeBitCast(client.method(for: sel), to: GetBool.self)
        return call(client, sel)
    }

    static var isSupported: Bool { getBool("supported") ?? false }

    static var isEnabled: Bool? { getBool("enabled") }

    /// Returns whether the new state was actually applied. The daemon applies it asynchronously,
    /// so the read-back polls for up to a second.
    @discardableResult
    static func setEnabled(_ on: Bool) -> Bool {
        guard let client = makeClient() else { return false }
        let sel = NSSelectorFromString("setEnabled:")
        guard client.responds(to: sel) else { return false }
        let call = unsafeBitCast(client.method(for: sel), to: SetBool.self)
        guard call(client, sel, on) else { return false }
        for _ in 0..<10 {
            if isEnabled == on { return true }
            usleep(100_000)
        }
        return false
    }
}
