# Marketing assets

App Store screenshots and the tooling used to produce them.

## Screenshots

Captured at exact App Store device resolutions on the iOS 27 simulator, so
they can be uploaded to App Store Connect without resizing.

### iPhone — 6.9" (1320 × 2868), iPhone 17 Pro Max

| File | Screen |
|------|--------|
| `screenshots/iphone-6.9/1-onboarding.png`    | "Find duplicates" intro |
| `screenshots/iphone-6.9/2-home.png`          | Home: Ask Dupless + actions |
| `screenshots/iphone-6.9/3-scan-setup.png`    | Scan scope, options, sensitivity |
| `screenshots/iphone-6.9/4-scan-pipeline.png` | Five-stage on-device scan |
| `screenshots/iphone-6.9/5-duplicates.png`    | Duplicate groups with match % |
| `screenshots/iphone-6.9/6-best-shot.png`     | Best-shot keeper + "Why this one?" |
| `screenshots/iphone-6.9/7-drone-burst.png`   | Drone/Burst setup, protect unique angles |

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

## App Store Connect notes

- 6.9" and 13" are the only two screenshot sizes App Store Connect currently
  requires; smaller iPhones/iPads scale from the 6.9" set.
- The privacy policy URL required at submission is hosted from
  [`docs/privacy-policy.html`](../docs/privacy-policy.html).
