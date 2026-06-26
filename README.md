<div align="center">

<img src="CleanShots/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="120" alt="Dupless app icon" />

# Dupless

**On-device photo deduplication and best-shot cleanup for iOS — private by design.**

</div>

Dupless scans your photo library entirely **on your device** to find duplicate and
visually similar photos, ranks the best shot in each group, and helps you safely clean
up the rest. It understands natural-language requests, explains its recommendations, and
detects drone/burst sequences — all without a single photo leaving your phone.

---

## Highlights

- 🔍 **Find duplicates & similar photos** — perceptual hashing + Vision feature prints, grouped with union-find.
- ⭐ **Smart best-shot ranking** — keeps the sharpest, best-exposed, highest-resolution shot; explains why.
- 🛡️ **Safety first** — favorites, edited, Live Photos, hidden, shared, and photos with people are protected. Nothing is ever auto-deleted; everything routes to manual review and **Recently Deleted** (reversible).
- 🗣️ **Siri & Shortcuts** — start scans, review groups, and build albums by voice.
- ✨ **Apple Intelligence** — natural-language scan requests ("scan last month, be conservative") and conversational explanations, powered by the on-device Foundation Models — with deterministic template fallbacks when unavailable.
- 🚁 **Drone / Burst mode** — clusters photo sessions by time, location, and burst, finds redundant sequences, and **preserves unique angles** (including different drone altitudes).

## How it works

```
PhotoKit scope ─▶ analyze (thumbnail → hash + Vision feature print + quality + flags + metadata)
              ─▶ group (visual)            ─▶ best-shot ranking ─▶ review ─▶ Recently Deleted
              └▶ cluster (time/GPS/burst)  ─▶ redundancy + scene diversity ─▶ best shots / unique angles
```

The AI layer sits **on top** of this engine: it only ever translates language ⇄ structured
commands and narrates results from structured scores. It can never reach PhotoKit or delete
a photo directly — there is deliberately no deletion tool.

## Privacy & safety

These are non-negotiable and enforced in code:

- **On-device only.** No cloud, no network calls for analysis; photos are never uploaded. The AI uses Apple's local Foundation Models — never a cloud LLM.
- **No silent deletion.** Every cleanup requires explicit review and moves photos to Recently Deleted.
- **Protected by default.** Favorites · edited · Live Photos · hidden · shared · photos with people.
- **Grounded explanations.** The model is given only quality scores and counts (never image pixels), so it can't overstate certainty.

## Architecture

| Area | Where | Notes |
|---|---|---|
| Scan engine | `CleanShots/ScanEngine/`, `CleanShots/Analysis/` | Checkpointed, resumable scans; off-main analysis |
| Ranking & protection | `CleanShots/Ranking/` | Weighted best-shot score, protection policy |
| Persistence | `CleanShots/Persistence/` | SwiftData models (`ImageFeatureRecord`, `DuplicateGroupRecord`, `SessionClusterRecord`, …) |
| Siri / App Intents | `CleanShots/Intents/` | 10 intents + `AppShortcutsProvider` |
| AI layer | `CleanShots/AI/` | `FoundationModelService` is the **only** file importing `FoundationModels`; everything else is behind protocols with template fallbacks |
| Drone / burst | `CleanShots/Analysis/SessionClusterer.swift`, `DroneBurstAnalyzer.swift`, `DroneBurstScanner.swift` | Session clustering, redundancy, scene diversity |
| UI | `CleanShots/Features/` | SwiftUI; path-based navigation driven by app + Siri |

Built across five MVPs: **(1)** core scanning · **(2)** smart ranking · **(3)** Siri/App Intents · **(4)** Foundation Models · **(5)** drone/burst mode.

## Requirements

- **Xcode 26.5+**, **iOS 27** deployment target
- A device or simulator on the **iOS 27** runtime
- Apple Intelligence enabled for the AI features (the app falls back to templates without it)

## Build & run

```bash
# Open in Xcode
open CleanShots.xcodeproj

# …or from the command line (use an iOS 27 simulator)
xcodebuild build \
  -project CleanShots.xcodeproj -scheme CleanShots \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

On first launch, grant **Full Access** to Photos so the app can scan your whole library.

## Tests

185 unit tests cover the analysis, ranking, clustering, parsing, and AI-fallback logic. The
PhotoKit-bound scan glue and SwiftUI views are verified by running the app.

```bash
# Run serially — the iOS 27 simulator can crash the test host under parallel clones
xcodebuild test \
  -project CleanShots.xcodeproj -scheme CleanShots \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO
```

## Status

All five MVPs are complete. The app is feature-complete for its scope; there is no
SwiftData migration plan yet (schema changes recreate the local store — acceptable
pre-release).
