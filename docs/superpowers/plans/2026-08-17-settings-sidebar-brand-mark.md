# Settings Sidebar Brand Mark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a subtle CatGPT app icon to the bottom of the settings sidebar without disrupting the existing SwiftUI settings layout.

**Architecture:** Keep sidebar composition in `SettingsRootView`, and put the icon rendering/loading in a focused `SidebarBrandMark` view. The view loads `AppIcon.icns` from the bundle when available and falls back to a Canvas drawing that mirrors the approved icon geometry, so Debug and packaged builds both show the mark.

**Tech Stack:** SwiftUI, AppKit `NSImage`, Core SwiftUI `Canvas`, macOS 14.

---

### Task 1: Add the sidebar brand mark view

**Files:**
- Create: `Sources/Settings/SidebarBrandMark.swift`

- [ ] **Step 1: Implement resource loading and the debug fallback**

Create a `SidebarBrandMark` view that:

1. Loads `Bundle.main.url(forResource: "AppIcon", withExtension: "icns")` and renders it with `Image(nsImage:)` when present.
2. Otherwise draws the black rounded square, white cat silhouette, small mouth, and four whisker strokes using `Canvas` and normalized 0–100 coordinates; keep the cat bottom at `y = 97` so it stays inside the icon.
3. Applies `.opacity(0.78)` in dark mode and `.opacity(0.60)` in light mode.
4. Sets a 34×34 frame and accessibility label `CatGPT`.

### Task 2: Place the mark below the sidebar list

**Files:**
- Modify: `Sources/Settings/SettingsRootView.swift:35-61`

- [ ] **Step 1: Wrap the existing list and brand mark in a vertical layout**

Keep the existing `List` unchanged inside a `VStack(spacing: 0)`, then append `SidebarBrandMark()` with `.padding(.top, 8)` and `.padding(.bottom, 14)`. Do not add a separator or change the sidebar frame width.

### Task 3: Verify the settings UI change

**Files:**
- Test: existing `Tests/CatGPTTests/SettingsWindowControllerTests.swift`

- [ ] **Step 1: Build Debug with warnings as errors**

Run `swift build -Xswiftc -warnings-as-errors`; expect a successful Debug build.

- [ ] **Step 2: Run all tests**

Run `swift test`; expect all existing tests to pass.

- [ ] **Step 3: Check source diff**

Run `git diff --check -- Sources/Settings/SettingsRootView.swift Sources/Settings/SidebarBrandMark.swift` and confirm no whitespace errors or unrelated layout changes.
