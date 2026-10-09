# Toneoff

A tiny macOS menu bar app that turns **True Tone off while an external display is connected** and turns it back on when you unplug the last one.

## Why

True Tone is meant for the built-in display, but on some setups it also warms the picture on external monitors, giving them a yellow tint. macOS has one global True Tone switch and no way to limit it to the MacBook screen, so Toneoff automates that switch instead of making you open System Settings every time you dock and undock.

## How it behaves

- External display connected: True Tone goes off.
- Last external display disconnected: True Tone comes back on, but only if Toneoff was the one that turned it off. If you already had it off, it stays off.
- It acts only when external-display presence changes (and once at launch). If you flip True Tone by hand while your displays stay connected, Toneoff leaves your choice alone.
- Quitting Toneoff leaves True Tone as it is.
- **⌃⌥⌘T** toggles True Tone by hand from anywhere.
- The sun icon in the menu bar shows the current state. Its menu has a switch to disable the automation and a **Launch at Login** option.

## Install

Toneoff is built from source on your Mac and ad-hoc signed, so Gatekeeper does not get in the way. Either route needs the Xcode command line tools (`xcode-select --install`).

### Homebrew

```sh
brew install timu/tap/toneoff
brew services start timu/tap/toneoff
```

The second command starts Toneoff now and at every login. If you would rather start it by hand, run `open "$(brew --prefix toneoff)/Toneoff.app"`. Use either the Homebrew service or the app's own **Launch at Login** option, not both.

### From source

```sh
git clone https://github.com/timu/toneoff.git
cd toneoff
./install.sh
```

This builds `Toneoff.app`, copies it to `~/Applications` and launches it. Then tick **Launch at Login** in the menu bar menu so it starts automatically.

## Command line

The binary also works headless, which is handy for scripts or a Shortcuts "Run Shell Script" action. With Homebrew it is on your PATH as `toneoff`:

```sh
toneoff --status   # prints on / off
toneoff --on
toneoff --off
toneoff --toggle
```

When installed from source, run `~/Applications/Toneoff.app/Contents/MacOS/Toneoff` instead.

## Uninstall

Homebrew:

```sh
brew services stop timu/tap/toneoff
brew uninstall toneoff
defaults delete io.github.timu.toneoff
```

From source: choose Quit from the menu bar menu, untick **Launch at Login** if you enabled it, then:

```sh
rm -rf ~/Applications/Toneoff.app
defaults delete io.github.timu.toneoff
```

## Caveats

- **It uses a private macOS API.** True Tone is switched through `CBTrueToneClient` in the private CoreBrightness framework, the same client System Settings uses. A macOS update could change or remove it.
- **Limited testing.** Developed and tested on macOS 27.0.1 on an Apple Silicon MacBook with two external monitors. The deployment target is macOS 13, but older versions and Intel Macs are untested. The logic that decides when to switch is covered by unit tests, and the real switching has been exercised with a simulated display count, but plugging and unplugging real displays is the part that has had the least coverage.
- Display changes are detected through the standard CoreGraphics reconfiguration callback, with a short debounce, and again after wake from sleep.

## Development

```sh
./build.sh                                   # build into build/Toneoff.app
swiftc -swift-version 5 Sources/Policy.swift Tests/main.swift -o /tmp/policy-tests && /tmp/policy-tests
```

`TONEOFF_EXTERNALS=<n>` makes the app pretend n external displays are connected, so you can test the switching without moving cables:

```sh
TONEOFF_EXTERNALS=2 build/Toneoff.app/Contents/MacOS/Toneoff
```

The decision logic lives in `Sources/Policy.swift`, the True Tone wrapper in `Sources/TrueTone.swift`, and the app in `Sources/main.swift`.

## License

[MIT](LICENSE). Toneoff is an independent project and is not affiliated with or endorsed by Apple. True Tone is a trademark of Apple Inc.
