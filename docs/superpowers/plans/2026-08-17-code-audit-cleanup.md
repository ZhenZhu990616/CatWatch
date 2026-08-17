# Code Audit and Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Audit CatGPT end-to-end, correct confirmed defects with minimal regressions, and remove only code or files proven unused.

**Architecture:** Preserve the accepted settings UI and focus on runtime behavior: capture lifecycle, streaming updates, panel persistence, configuration, and system integration. Every behavioral change starts with a failing focused test; inconclusive cleanup candidates are reported rather than removed.

**Tech Stack:** Swift 5.9+, Swift Package Manager, AppKit, SwiftUI, XCTest.

---

### Task 1: Establish the auditable baseline

**Files:**
- Review: `Package.swift`, `Scripts/build-app.sh`, `README.md`, `Sources/**/*.swift`, `Tests/CatGPTTests/**/*.swift`

- [x] **Step 1: Run the existing test suite and compiler-warning gate**

Run: `swift test && swift build -Xswiftc -warnings-as-errors`

Expected: tests pass and the package compiles without warnings.

- [x] **Step 2: Map runtime ownership and potential dead code**

Run: `rg -n "(TODO|FIXME|fatalError|try!|force unwrap|Task \\{|UserDefaults|Timer|NotificationCenter|DFRFoundation)" Sources Tests`

Expected: every result is classified as a confirmed issue, intentional platform integration, or non-actionable observation.

### Task 2: Fix confirmed state and interaction defects

**Files:**
- Modify if confirmed: `Sources/main.swift`, `Sources/Settings/SettingsViewModel.swift`, `Sources/SelectionCapture.swift`
- Test: `Tests/CatGPTTests/*.swift`

- [x] **Step 1: Write a focused failing test for each reproducible defect**

Use a test that observes the public state transition, not private implementation details.

- [x] **Step 2: Run each focused test before the production change**

Run: `swift test --filter <test name>`

Expected: the test fails for the identified root cause.

- [x] **Step 3: Implement the smallest source-level correction**

Keep behavior and the accepted UI unchanged except where the defect requires an interaction correction.

- [x] **Step 4: Re-run the focused and full suites**

Run: `swift test --filter <test name> && swift test`

Expected: the regression test and the complete suite pass.

### Task 3: Perform conservative cleanup and final verification

**Files:**
- Modify/delete only after reference checks: proven-unused production files or code
- Review: all tracked non-build assets

- [x] **Step 1: Verify each deletion candidate is unreferenced and not a tracked source asset**

Run: `git ls-files && rg -n "<candidate name or symbol>" . --glob '!\.build/**'`

Expected: only files with no build, runtime, test, packaging, documentation, or design-source purpose are eligible.

- [x] **Step 2: Apply only verified cleanup**

Use targeted patches; retain design sources and runtime compatibility fallbacks unless separately approved.

- [x] **Step 3: Run final static and behavioral verification**

Run: `swift test --enable-code-coverage && swift build -Xswiftc -warnings-as-errors && git diff --check`

Expected: all checks pass. Do not perform a release build, commit, merge, or delete unconfirmed assets.
