# Contributing to LifeGrid

Thanks for your interest in improving LifeGrid! Contributions of all kinds are welcome.

## Development setup

LifeGrid uses [XcodeGen](https://github.com/yonsdesign/XcodeGen) — the `.xcodeproj` is generated and **not** committed.

```bash
brew install xcodegen
xcodegen generate
open LifeGrid.xcodeproj
```

Requirements: macOS with the latest stable Xcode (iOS 18 minimum; iOS 26 SDK to compile the Liquid Glass code paths).

## Before you open a PR

- Run `xcodegen generate` if you added, removed, or renamed files.
- Keep the build **warning-free**.
- Run the tests:
  ```bash
  xcodebuild test -scheme LifeGrid -destination 'platform=iOS Simulator,name=iPhone 16'
  ```
- Add any new user-facing strings to `LifeGrid/Localizable.xcstrings` **with Italian translations** (the app ships EN + IT).

## Code style

- SwiftUI-first, Swift 6 with strict concurrency.
- Prefer small, focused views and SwiftUI-native state (`@State`, `@Binding`, `@Observable`, `@Environment`) — avoid view models unless they earn their keep.
- Gate iOS 26 APIs behind `#available(iOS 26, *)` with an `.ultraThinMaterial` fallback.
- Reuse the design tokens and components in `DesignSystem.swift`; use `store.accent` for the primary accent rather than hardcoded colors.

## Commits & PRs

- Use clear, descriptive commit messages (Conventional Commits style is appreciated: `feat:`, `fix:`, `docs:`, `test:`, `chore:`).
- Keep PRs focused; describe the change and how you tested it.

## Privacy principle

LifeGrid is **local-only**: no account, no network, no analytics. Please don't add anything that sends user data off the device.
