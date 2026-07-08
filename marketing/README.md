# Marketing assets

App Store screenshots and the tooling used to produce them.

## Screenshots

Captured at exact App Store device resolutions on the iOS 27 simulator, so
they can be uploaded to App Store Connect without resizing.

### iPhone — 6.9" (1320 × 2868), iPhone 17 Pro Max

| File | Screen |
|------|--------|
| `screenshots/iphone-6.9/1-onboarding.png`     | "Find duplicates" intro |
| `screenshots/iphone-6.9/2-home.png`           | Home: Get started actions |
| `screenshots/iphone-6.9/3-scan-setup.png`     | Scan scope, options (incl. Protect Live Photos), sensitivity |
| `screenshots/iphone-6.9/4-scan-pipeline.png`  | Five-stage on-device scan |
| `screenshots/iphone-6.9/5-duplicates.png`     | Duplicate groups with match % |
| `screenshots/iphone-6.9/6-best-shot.png`      | Best-shot keeper + "Why this one?" |
| `screenshots/iphone-6.9/7-browse-photos.png`  | Browse Photos grid |

### iPad — 13" (2064 × 2752), iPad Pro 13-inch (M5)

| File | Screen |
|------|--------|
| `screenshots/ipad-13/1-split-view.png`    | NavigationSplitView sidebar + welcome |
| `screenshots/ipad-13/2-duplicates.png`    | Duplicate groups in the detail pane |
| `screenshots/ipad-13/3-best-shot.png`     | Best-shot keeper in the detail pane |

All photos shown are synthetic seed images (see below), not real user data.

## Reproducing

```sh
marketing/scripts/capture-screenshots.sh iphone   # or: ipad
```

This builds the app, boots the right iOS 27 simulator, generates ~5 scenes ×
3 near-duplicate variants, seeds them into the photo library, grants Photos
access, and launches the app. Then navigate to each screen and capture at
device resolution:

```sh
xcrun simctl io <UDID> screenshot marketing/screenshots/<name>.png
```

`scripts/generate-seed-images.swift [outDir]` draws the seed images on their
own (gradients with a slightly shifted "subject" so the dedupe engine forms
real similar-photo groups).

> **Gotcha:** `simctl io screenshot` can fail with a TCC permission error if it
> writes directly into this repo (under `~/Documents`). Capture to `/tmp` (or
> anywhere outside `~/Documents`) and `cp` the file into place instead.
>
> **Gotcha:** `find ~/Library/Developer/Xcode/DerivedData -path
> '*Debug-iphonesimulator/Dupless.app'` can match a stale build from an old
> DerivedData folder if more than one exists. Pick the most recently modified
> match (or clear out the others) before `simctl install`.

## App Store Connect notes

- 6.9" and 13" are the only two screenshot sizes App Store Connect currently
  requires; smaller iPhones/iPads scale from the 6.9" set.
- The privacy policy URL required at submission is hosted from
  [`docs/privacy-policy.html`](../docs/privacy-policy.html).
- "Ask Dupless" (natural-language scan bar) and "Drone / Burst Mode" were
  Pro-gated features removed from Home's entry points in `abbf76e` after App
  Review rejected the IAP (2.1(b), 3.1.2(c)); the underlying code is still in
  the repo but unreachable from the UI. Neither should appear in screenshots
  or listing copy referencing 1.0 until/unless they're re-exposed.
