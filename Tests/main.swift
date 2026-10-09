// Run with: swiftc -swift-version 5 Sources/Policy.swift Tests/main.swift -o /tmp/policy-tests && /tmp/policy-tests
import Foundation

var failures = 0

func check(_ name: String, _ got: TrueToneDecision, _ want: TrueToneDecision) {
    if got == want {
        print("ok   \(name)")
    } else {
        failures += 1
        print("FAIL \(name): got \(got), want \(want)")
    }
}

func decide(_ present: Bool, was: Bool?, on: Bool, ours: Bool) -> TrueToneDecision {
    decideTrueTone(externalPresent: present, wasExternalPresent: was, trueToneOn: on, weTurnedItOff: ours)
}

func d(_ action: TrueToneAction, _ ours: Bool) -> TrueToneDecision {
    TrueToneDecision(action: action, weTurnedItOff: ours)
}

check("connect: turns it off and remembers", decide(true, was: false, on: true, ours: false), d(.turnOff, true))
check("connect with True Tone already off: leave it, don't claim it", decide(true, was: false, on: false, ours: false), d(.none, false))
check("disconnect after we turned it off: turn it back on", decide(false, was: true, on: false, ours: true), d(.turnOn, false))
check("disconnect when user had it off before: stay off", decide(false, was: true, on: false, ours: false), d(.none, false))
check("disconnect, user already re-enabled by hand: no-op, flag cleared", decide(false, was: true, on: true, ours: true), d(.none, false))
check("still connected (no transition), user turned it on by hand: leave it", decide(true, was: true, on: true, ours: true), d(.none, true))
check("still disconnected: nothing", decide(false, was: false, on: true, ours: false), d(.none, false))
check("launch with externals, True Tone on: turn off", decide(true, was: nil, on: true, ours: false), d(.turnOff, true))
check("launch with externals, already off by our earlier run: keep flag", decide(true, was: nil, on: false, ours: true), d(.none, true))
check("launch with no externals, we left it off last time: restore", decide(false, was: nil, on: false, ours: true), d(.turnOn, false))
check("launch with no externals, nothing to restore", decide(false, was: nil, on: true, ours: false), d(.none, false))

print(failures == 0 ? "all passed" : "\(failures) failed")
if failures > 0 { exit(1) }
