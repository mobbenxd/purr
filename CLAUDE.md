# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Purr is a macOS 14+ menu bar app (SwiftUI `MenuBarExtra`, no Dock icon) that is a GUI wrapper around the [Mole](https://github.com/tw93/mole) CLI (`mo`). Every button ultimately runs a `mo` subcommand; Purr does no cleaning itself. Swift Package Manager only — there is no Xcode project.

## Commands

```bash
swift build                      # debug build
swift run Purr --window          # panel in a normal window (no menu bar); append `history` or `settings` to open that page
./test.sh                        # run tests (works with Command Line Tools only; plain `swift test` needs Xcode)
./test.sh --filter VersionTests  # single suite; `--filter VersionTests/ordering` for a single test
scripts/check-strings.sh         # list UI strings missing an English translation (fails if any are missing)
./build.sh                       # release build → Purr.app (icon, Info.plist, codesign)
scripts/release.sh X.Y.Z [--publish]
```

CI (`.github/workflows/ci.yml`) runs `swift test`, `scripts/check-strings.sh`, and `./build.sh`.

Under `swift run` there is no bundle/Info.plist: notifications are disabled, the app reports itself as a dev build, and Mole-upgrade relaunch is skipped. Test those behaviours from `Purr.app`.

## Architecture

Two targets (see `Package.swift`):

- **`PurrCore`** — no UI, fully unit-tested. Process running (`GroupProcess`), locating/invoking `mo` (`MoleCLI`), parsers for Mole output (`MoleStatus`, `MoleHistory`, `OutputParser`), health score + alert rules (`Health`), version comparison and GitHub release decoding (`SemanticVersion`), kernel-level stats fallback when Mole is missing (`SystemStats`). Put new logic here when it can be tested without AppKit.
- **`Purr`** — SwiftUI app. Tests do not cover it.

Tests use Swift Testing (`import Testing`, `@Suite`/`@Test`/`#expect`), not XCTest. Sample Mole output lives in `Tests/PurrCoreTests/Fixtures/`.

### How the app is wired

`PurrApp.swift`'s `AppServices` owns long-lived `@MainActor` services and connects them with closures rather than direct references (e.g. `care.isBusy = { model.isRunning }`, `monitor.onSnapshot = { care.handle($0) }`). When adding a cross-service interaction, follow this pattern there.

- `PurrModel` — the task catalogue (`CatTasks`) and running in-app tasks with live log streaming. A `CatTask` with `inApp: false` is an interactive TUI and is opened in Terminal via a generated `.command` file instead. `confirm:` adds a confirmation dialog. Add/change buttons in `CatTasks`.
- `StatusMonitor` — streams `mo status --watch`, at 3s while the panel is visible and 60s while hidden (battery). Uses a `generation` counter to ignore callbacks from a stream that was restarted.
- `CareService` — health notifications and the weekly background dry-run ("sniff").
- `UpdateChecker` — daily check of GitHub Releases for the repo named in Info.plist `PurrRepository` (set by `build.sh` from the git remote), plus Mole version checks.
- `MoleWatcher` — detects Mole being replaced on disk (install stamp = resolved path + mtime, must be seen twice in a row because Homebrew links in steps) and relaunches Purr, but never mid-task.
- `Prefs` — all UserDefaults keys and defaults; views use `@AppStorage(Prefs.x)`, services read via `Prefs` helpers so defaults agree.

### Running `mo`

Always go through `GroupProcess` / `MoleCLI.run`. `mo` is a shell wrapper that spawns helpers; `GroupProcess` spawns it in its own process group so Stop/quit kill the whole group, and restores default signal handlers (the app itself ignores SIGTERM/SIGINT and routes them to `NSApp.terminate` so cleanup runs). `MoleCLI.environment` sets `NO_COLOR=1`, `TERM=dumb` and a fixed `PATH`; stdin is `/dev/null`, so commands must not expect interaction. `LogBuffer` additionally strips ANSI/spinner output.

## Localization

Thai is the development language: Thai string literals in code *are* the localization keys, and `th.lproj` is intentionally empty. Only `Resources/en.lproj/Localizable.strings` needs entries. After adding or changing any user-facing string, run `scripts/check-strings.sh` and add the missing English entries (and remove ones reported unused).

## Versioning and releases

- Version is in `VERSION`; build number is the git commit count (CI checks out with `fetch-depth: 0` for this).
- Every release needs a `## [X.Y.Z] - YYYY-MM-DD` section in `CHANGELOG.md` (Keep a Changelog format, written in Thai) before running `scripts/release.sh`, which requires a clean `main` equal to `origin/main`. Add user-visible changes under `## [Unreleased]`.
- The app icon is drawn in code (`CatFace.exportIconSet`, invoked by `build.sh` via `Purr --export-icon`); there is no icon asset to edit.
- Optional signing/notarization: `PURR_SIGN_IDENTITY`, `NOTARY_PROFILE`.
