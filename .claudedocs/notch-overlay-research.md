# Notch Overlay Research — Saved for Future Feature

## TL;DR
NSPanel at `.screenSaver` window level (101), positioned using `NSScreen.auxiliaryTopLeftArea/RightArea`
to compute notch rect. Animate panel frame downward for pull-down drawer.

## Key APIs
- `NSScreen.auxiliaryTopLeftArea` + `auxiliaryTopRightArea` → compute notch width/center (macOS 12+)
- `NSScreen.safeAreaInsets.top` → notch height (~32pt on 14" MBP)
- Window level: `.screenSaver` (101) — above menu bar (24) and status bar (25)
- `NSPanel` with `.borderless + .nonactivatingPanel` styleMask, `.canJoinAllSpaces + .stationary`

## Reference Libraries
- DynamicNotchKit: github.com/MrKai77/DynamicNotchKit (MIT, Swift package)
- Notchmeister: github.com/chockenberry/Notchmeister (glow effects reference)
- TheBoringNotch: github.com/TheBoredTeam/boring.notch

## Glow Effect
SwiftUI double-shadow with pulsing animation:
```swift
RoundedRectangle(cornerRadius: notchRect.height / 2)
    .shadow(color: accentColor.opacity(glowOpacity), radius: 12)
    .shadow(color: accentColor.opacity(glowOpacity * 0.6), radius: 24)
    .animation(.easeInEaseOut(duration: 1.2).repeatForever(autoreverses: true), value: glowOpacity)
```

## Sandbox
Cinder already has `com.apple.security.app-sandbox: false` — no blocker.
Sandboxed apps max out at `.floating` level and cannot overlay the notch.

## Note
NSStatusItem cannot be placed AT the notch — it's positioned by the system in the menu bar areas
left/right of the notch. This design uses a freestanding NSPanel instead.
