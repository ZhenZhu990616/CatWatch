# CatGPT Complete Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the CatGPT macOS project to CatGPT as a new application with no legacy data migration, and remove two menu actions.

**Architecture:** First remove menu entries and their now-unused selector methods under test. Then migrate source/runtime identifiers and SwiftPM target names. Finally rename the filesystem root and nested test directory while repairing Git worktree metadata, because the current project has both a main worktree and an active settings-redesign worktree under the root folder.

**Tech Stack:** Swift 5.9, SwiftPM, AppKit, SwiftUI, Git worktrees, zsh.

---

### Task 1: Remove the two status-menu actions

**Files:**
- Modify: `Sources/main.swift:110-165, 500-515, 1040-1060`
- Modify: `Tests/CatGPTTests/StatusMenuTests.swift`

- [ ] **Step 1: Add a failing menu composition regression test**

Create `Tests/CatGPTTests/StatusMenuTests.swift` that builds the status menu through a testable helper and asserts its item titles exclude `打开屏幕录制权限设置` and `重新注册快捷键`, while still containing `设置…` and `退出 CatGPT`.

- [ ] **Step 2: Run the focused test and verify it fails because the menu still contains both titles**

Run: `swift test --filter StatusMenuTests`

Expected: failure showing at least one removed title is still present.

- [ ] **Step 3: Remove menu entries and unused selectors**

Delete the two `menu.addItem(makeMenuItem(...))` calls, remove `permissionFromMenu` and `registerHotKeyFromMenu`, and rewrite the permission error text to direct users to Settings instead of a removed menu item.

- [ ] **Step 4: Run the focused test and verify it passes**

Run: `swift test --filter StatusMenuTests`

Expected: all selected tests pass.

### Task 2: Rename source-level and runtime identifiers without migration

**Files:**
- Modify: `Package.swift`
- Modify: `Sources/**/*.swift`
- Modify: `Tests/CatGPTTests/**/*.swift`
- Modify: `Scripts/build-app.sh`
- Modify: `README.md`

- [ ] **Step 1: Add failing configuration defaults tests for new storage identity**

Extend `Tests/CatGPTTests/ConfigDefaultsTests.swift` with assertions that newly constructed configuration uses `catGPT.*` UserDefaults keys, `CatGPT` App Support identity, and `CatGPT` Keychain service; it must not use `catGPT`, `CatGPT`, or `CatGPT`.

- [ ] **Step 2: Run the focused test and verify it fails on legacy identifiers**

Run: `swift test --filter ConfigDefaultsTests`

Expected: assertions identify legacy key/service/path values.

- [ ] **Step 3: Apply the complete identifier rename**

Replace user-facing `CatGPT` copy, target imports, test module names, App Support path, Keychain service, dispatch labels, Touch Bar identifiers, window autosave names, UserDefaults key prefix, script app name, Bundle ID and bundle display strings with `CatGPT` equivalents. Do not add fallback reads or migration code for legacy storage.

- [ ] **Step 4: Run the focused configuration and module tests**

Run: `swift test --filter 'ConfigDefaultsTests|SettingsWindowControllerTests|ShortcutSettingsTests'`

Expected: all selected tests pass with `@testable import CatGPT`.

### Task 3: Rename tracked folder names and all repository references

**Files:**
- Move: `Tests/CatGPTTests` → `Tests/CatGPTTests`
- Modify: `docs/**/*.md`
- Modify: file names under `docs/` containing `catgpt` or `CatGPT`

- [ ] **Step 1: Inventory remaining old project-name references**

Run: `rg -n -i 'CatGPT|catGPT|CatGPT' --glob '!/.build/**' --glob '!/.git/**' .`

Expected: list every remaining source, test, script, README and document reference before replacement.

- [ ] **Step 2: Rename the test directory and update Package.swift paths**

Use `git mv Tests/CatGPTTests Tests/CatGPTTests`; update package target names and dependencies from `CatGPT`/`CatGPTTests` to `CatGPT`/`CatGPTTests`.

- [ ] **Step 3: Update documents and tracked filename stems**

Replace historical project-name references in Markdown and rename any tracked file whose basename contains `CatGPT` or `catgpt` to the `CatGPT` spelling. Preserve document content meaning while making shell examples use `CatGPT` paths and commands.

- [ ] **Step 4: Confirm the old names remain only where intentionally preserved outside the repository**

Run: `rg -n -i 'CatGPT|catGPT|CatGPT' --glob '!/.build/**' --glob '!/.git/**' .`

Expected: no matches in the project tree.

### Task 4: Move the project root and repair Git worktrees

**Files:**
- Move: `/Users/apple/Developer/CatGPT` → `/Users/apple/Developer/CatGPT`

- [ ] **Step 1: Stop the Debug CatGPT process and validate both worktree paths**

Run: `ps -axo pid=,command= | rg '/CatGPT$'` and `git worktree list --porcelain`.

Expected: record the running Debug app PID and the two old absolute worktree paths before moving.

- [ ] **Step 2: Move the root directory from its parent directory**

From `/Users/apple/Developer`, validate that exactly one directory named `CatGPT` exists and is a directory, then execute `mv /Users/apple/Developer/CatGPT /Users/apple/Developer/CatGPT`.

- [ ] **Step 3: Repair main and linked worktree metadata using their new paths**

Run `git worktree repair /Users/apple/Developer/CatGPT` and `git worktree repair /Users/apple/Developer/CatGPT/.worktrees/settings-redesign`, then `git worktree list --porcelain` from the renamed active worktree.

Expected: both worktrees report only `/Users/apple/Developer/CatGPT...` paths.

### Task 5: Full Debug verification and launch

**Files:**
- Verify only.

- [ ] **Step 1: Run all tests**

Run: `swift test`

Expected: all tests pass.

- [ ] **Step 2: Run warnings-as-errors Debug build and repository check**

Run: `swift build -Xswiftc -warnings-as-errors && git diff --check`

Expected: Debug build succeeds and the diff check emits no output.

- [ ] **Step 3: Launch the renamed Debug product for acceptance**

Run: `CATGPT_OPEN_SETTINGS=shortcuts swift run CatGPT`

Expected: the settings window opens from the renamed `CatGPT` executable; no Release build, signing, packaging or publishing command is run.
