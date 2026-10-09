/// What to do with True Tone when external displays come or go.
enum TrueToneAction: Equatable {
    case none
    case turnOff
    case turnOn
}

struct TrueToneDecision: Equatable {
    var action: TrueToneAction
    /// True while the app is the reason True Tone is off, so it knows to turn it back on later.
    var weTurnedItOff: Bool
}

/// Acts only when external-display presence changes (or on first launch, when `wasExternalPresent`
/// is nil), so a True Tone choice made by hand while displays stay connected is never overridden.
/// True Tone is only restored if this app was the one that turned it off.
func decideTrueTone(
    externalPresent: Bool,
    wasExternalPresent: Bool?,
    trueToneOn: Bool,
    weTurnedItOff: Bool
) -> TrueToneDecision {
    guard externalPresent != wasExternalPresent else {
        return TrueToneDecision(action: .none, weTurnedItOff: weTurnedItOff)
    }
    if externalPresent {
        return trueToneOn
            ? TrueToneDecision(action: .turnOff, weTurnedItOff: true)
            : TrueToneDecision(action: .none, weTurnedItOff: weTurnedItOff)
    }
    guard weTurnedItOff else {
        return TrueToneDecision(action: .none, weTurnedItOff: false)
    }
    return TrueToneDecision(action: trueToneOn ? .none : .turnOn, weTurnedItOff: false)
}
