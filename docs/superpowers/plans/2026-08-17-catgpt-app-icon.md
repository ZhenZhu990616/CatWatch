# CatGPT App Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update the CatGPT macOS app icon generator to preserve the existing minimalist cat silhouette while adding only a small mouth and symmetric whiskers.

**Architecture:** Keep all drawing in the existing Core Graphics function `drawIcon(in:scale:)`. Add two stroked paths after the unchanged white cat fill, using the existing 0–100 normalized coordinate system so every generated icon size stays aligned.

**Tech Stack:** Swift 5.9, AppKit, Core Graphics, `iconutil`, Swift Package Manager.

---

### Task 1: Add the approved facial marks to the icon generator

**Files:**
- Modify: `Scripts/generate-app-icon.swift:65-92`

- [ ] **Step 1: Preserve the existing silhouette and add only approved paths**

After `context.fillPath()` for `cat`, add a black rounded-stroke mouth and four symmetric whisker strokes. Convert normalized design units to pixels with `iconRect.width / 100`, and set `lineCap`/`lineJoin` to `.round` so the marks match the approved preview.

- [ ] **Step 2: Run the generator against a temporary ICNS path**

Run:

```bash
tmp_icon="$(mktemp -t catgpt-icon).icns"
swift Scripts/generate-app-icon.swift "$tmp_icon"
test -s "$tmp_icon"
rm -f "$tmp_icon"
```

Expected: the Swift script exits 0 and the output file is non-empty.

### Task 2: Verify the project without a Release build

**Files:**
- No additional source changes.

- [ ] **Step 1: Build the Debug package with warnings as errors**

Run:

```bash
swift build -Xswiftc -warnings-as-errors
```

Expected: build succeeds without warnings.

- [ ] **Step 2: Run the existing test suite**

Run:

```bash
swift test
```

Expected: all existing CatGPT tests pass.

- [ ] **Step 3: Check the final diff**

Run:

```bash
git diff --check -- Scripts/generate-app-icon.swift docs/superpowers/specs/2026-08-17-catgpt-app-icon-design.md docs/superpowers/plans/2026-08-17-catgpt-app-icon.md
git diff -- Scripts/generate-app-icon.swift
```

Expected: no whitespace errors; only the approved icon drawing and documentation are present.
