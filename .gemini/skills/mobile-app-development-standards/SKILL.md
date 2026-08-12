---
name: mobile-app-development-standards
description: >-
  Mobile app development standards, versioning protocols (Option A), UI drag-and-drop architecture, map viewport rules, and Git release procedures for Antigravity AI pair programming.
---

# Mobile App Development Standards & Guidelines

This skill provides comprehensive procedural standards and guidelines for building mobile applications (Flutter/iOS/Android) with Antigravity AI.

--------------------------------------------------------------------------------

## 1. Git Release Protocol (STRICT)

1. **NO PUSH WITHOUT EXPLICIT PERMISSION**:
   - Never run `git commit`, `git tag`, or `git push` unless the user explicitly commands `"可以推"` or `"推"`.
   - Keep all unreleased work local and uncommitted.
2. **Pre-Release Verification Checklist**:
   - `flutter analyze` must return 0 issues.
   - `flutter test` must pass 100%.

--------------------------------------------------------------------------------

## 2. Versioning Protocol (Option A)

Format: `X.Y.Z+B` (e.g. `1.0.0+34`)

1. **`X.Y.Z` (Semantic Versioning)**: Keep fixed at `1.0.0` during active iteration and small updates to avoid jumping store versions too early.
2. **`+B` (Build Number)**: Increment ONLY `+B` by +1 on every release push (e.g. `1.0.0+34` -> `1.0.0+35`).
3. **Artifact Updates**: Update `pubspec.yaml`, `changelog.txt`, and git tag (`vX.Y.Z+B`).

--------------------------------------------------------------------------------

## 3. UI & Drag-and-Drop Architecture

1. **Flat Independent Node List**:
   - Separate Section Headers (`_DayHeaderNode`) and Cards (`_LandmarkCardNode`) into top-level flat nodes in `ReorderableListView`.
   - Never nest headers inside card columns to prevent header dragging visual bugs.
2. **Direction-Aware Drop Logic**:
   - Dragging DOWNWARDS onto header -> place AFTER header (1st card of that section).
   - Dragging UPWARDS onto header/last card -> place BEFORE header / AFTER last card (last card of previous section).
3. **Whole-Section Swapping**:
   - Provide section header action buttons (`▲`, `▼`, and swap dropdown) to move whole sections in 1 tap.

--------------------------------------------------------------------------------

## 4. Map & Viewport Standards

1. **Auto Initial Fit-All Viewport**:
   - On app startup or trip switch, calculate `LatLngBounds` of all markers and trigger camera `fitCamera` to fit all pins cleanly.
2. **Day Route Line Labels**:
   - Draw day-color coded labels (e.g., `第 1 天`) at the midpoint of route lines for sections with >= 2 points.
3. **Z-Index Bring-to-Front**:
   - Tapping any pin or card dynamically moves that marker to top z-index layer.

--------------------------------------------------------------------------------

## 5. Link Parsing & Error Callouts

1. **No Camera Viewport Fallbacks**:
   - Unresolvable map links must fail gracefully returning `null` with explicit error banner rather than falling back to home/viewport coordinates.
2. **Inline Red Callout Banner**:
   - Display prominent red callout banner inside input dialogs to ensure error visibility above keyboard.
