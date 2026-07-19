# CatWatch Floating Panel Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Change CatWatch's first-launch floating panel to 520×320, preserve saved user sizes, then build, Developer ID-sign, package, and publish version 0.2.0 to a private GitHub repository.

**Architecture:** Keep the existing configuration data flow: `ConfigDraft` owns default dimensions, `UserDefaults` and environment variables retain precedence, and `FloatingResultPresenter` consumes the resolved values unchanged. Add a narrow Swift Package regression test, keep build products out of Git, create a signed DMG from the existing Release app bundle, and publish source plus the DMG as a GitHub Release.

**Tech Stack:** Swift 5.9 package, XCTest, AppKit, `swift build`, `codesign`, `hdiutil`, Git, GitHub CLI.

---

### Task 1: Establish the source baseline and isolated implementation branch

**Files:**
- Create: `.gitignore`
- Track: `Package.swift`, `Sources/`, `Scripts/`, `README.md`, `猫主题应用图标设计/`, `docs/`

- [ ] **Step 1: Add repository exclusions**

Create `.gitignore` with:

```gitignore
.DS_Store
.tmp-*.png
.vscode/
.worktrees/
.build/
.swiftpm/
DerivedData/
dist/
node_modules/
*.xcuserstate
```

- [ ] **Step 2: Confirm the intended initial source scope**

Run: `git status --short --ignored`

Expected: source, scripts, documentation, and design assets are untracked; `.build/` and `dist/` are ignored.

- [ ] **Step 3: Commit the source baseline**

Run: `git add .gitignore Package.swift Sources Scripts README.md 猫主题应用图标设计 docs && git commit -m "chore: import CatWatch sources"`

Expected: a commit containing the project source but no generated build products.

- [ ] **Step 4: Create an isolated worktree**

Run: `git worktree add .worktrees/floating-panel-release -b agent/floating-panel-release`

Expected: a clean worktree on `agent/floating-panel-release`.

### Task 2: Add the failing first-launch size regression test

**Files:**
- Modify: `Package.swift`
- Create: `Tests/CatWatchTests/ConfigDefaultsTests.swift`

- [ ] **Step 1: Register the XCTest target**

Add this target after the executable target:

```swift
.testTarget(
    name: "CatWatchTests",
    dependencies: ["CatWatch"],
    path: "Tests/CatWatchTests"
)
```

- [ ] **Step 2: Write the failing test**

Create `Tests/CatWatchTests/ConfigDefaultsTests.swift`:

```swift
import XCTest
@testable import CatWatch

final class ConfigDefaultsTests: XCTestCase {
    func testFloatingPanelUsesReadableFirstLaunchSize() {
        XCTAssertEqual(ConfigDraft.defaultPanelWidth, 520)
        XCTAssertEqual(ConfigDraft.defaultPanelHeight, 320)

        let aspectRatio = Double(ConfigDraft.defaultPanelWidth) / Double(ConfigDraft.defaultPanelHeight)
        XCTAssertGreaterThan(aspectRatio, 1.55)
        XCTAssertLessThan(aspectRatio, 1.70)
    }
}
```

- [ ] **Step 3: Verify RED**

Run: `swift test --filter ConfigDefaultsTests/testFloatingPanelUsesReadableFirstLaunchSize`

Expected: FAIL because the current defaults are 430×260 rather than 520×320.

### Task 3: Implement the approved default dimensions

**Files:**
- Modify: `Sources/Config.swift:95`
- Test: `Tests/CatWatchTests/ConfigDefaultsTests.swift`

- [ ] **Step 1: Apply the minimal production change**

Change only the two defaults:

```swift
static let defaultPanelWidth = 520
static let defaultPanelHeight = 320
```

- [ ] **Step 2: Verify GREEN**

Run: `swift test --filter ConfigDefaultsTests/testFloatingPanelUsesReadableFirstLaunchSize`

Expected: PASS.

- [ ] **Step 3: Run the complete package checks**

Run: `swift test && swift build -c release`

Expected: all tests pass and the Release executable builds without errors.

- [ ] **Step 4: Commit the behavior change**

Run: `git add Package.swift Sources/Config.swift Tests/CatWatchTests/ConfigDefaultsTests.swift && git commit -m "feat: improve floating panel default size"`

### Task 4: Merge and create the signed release package

**Files:**
- Generate: `dist/CatWatch.app`
- Generate: `dist/CatWatch-0.2.0-arm64.dmg`

- [ ] **Step 1: Merge the verified feature branch into main**

From the primary worktree run: `git merge --no-ff agent/floating-panel-release -m "merge: improve floating panel default size"`

Expected: `main` contains the test and default-size change.

- [ ] **Step 2: Build and sign the app**

Run:

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Zhen Zhu (JH83G4NL6Z)" Scripts/build-app.sh
```

Expected: `dist/CatWatch.app` is signed with Team ID `JH83G4NL6Z` and hardened runtime.

- [ ] **Step 3: Create and sign the DMG**

Create a temporary staging directory with `mktemp -d`, copy `CatWatch.app`, add an `/Applications` symlink, create a compressed UDZO DMG with `hdiutil create`, then run:

```bash
codesign --force --timestamp --sign "Developer ID Application: Zhen Zhu (JH83G4NL6Z)" dist/CatWatch-0.2.0-arm64.dmg
```

Expected: a signed, versioned DMG in `dist/`.

- [ ] **Step 4: Verify signatures and artifact integrity**

Run:

```bash
codesign --verify --deep --strict --verbose=2 dist/CatWatch.app
codesign --verify --strict --verbose=2 dist/CatWatch-0.2.0-arm64.dmg
codesign -dvvv dist/CatWatch.app
shasum -a 256 dist/CatWatch-0.2.0-arm64.dmg
```

Expected: both signature verifications succeed, the app reports the Developer ID authority and Team ID, and a SHA-256 checksum is produced.

### Task 5: Publish source and GitHub Release

**Files:**
- Publish repository: `ZhenZhu990616/CatWatch`
- Upload release asset: `dist/CatWatch-0.2.0-arm64.dmg`

- [ ] **Step 1: Recheck repository scope and history**

Run: `git status -sb && git ls-files | rg '(^|/)(\.build|dist|node_modules)(/|$)' && git log --oneline --decorate -5`

Expected: the worktree is clean and no generated directory is tracked; the `rg` check returns no matches.

- [ ] **Step 2: Create the private GitHub repository**

Run: `gh repo create ZhenZhu990616/CatWatch --private --source=. --remote=origin --description "macOS menu bar screenshot analysis tool powered by ChatGPT/Codex OAuth"`

Expected: GitHub creates the private repository and configures `origin`.

- [ ] **Step 3: Push main**

Run: `git push -u origin main`

Expected: the source history appears on GitHub.

- [ ] **Step 4: Create the versioned release**

Run: `gh release create v0.2.0 dist/CatWatch-0.2.0-arm64.dmg --target main --title "CatWatch 0.2.0" --notes "Developer ID-signed arm64 macOS build. First-launch floating panel now defaults to 520×320; saved user dimensions remain unchanged."`

Expected: release `v0.2.0` exists and contains the signed DMG.

- [ ] **Step 5: Verify remote publication**

Run: `gh repo view ZhenZhu990616/CatWatch --json nameWithOwner,visibility,url,defaultBranchRef && gh release view v0.2.0 --repo ZhenZhu990616/CatWatch --json url,tagName,assets`

Expected: repository visibility is PRIVATE, default branch is `main`, and the release asset is listed with its download URL.
