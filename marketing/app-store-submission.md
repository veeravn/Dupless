# Dupless — App Store Submission Guide

Everything needed to fill out App Store Connect for the **1.0** release. Copy
fields are written to App Store Connect's character limits. Items marked
**(your action)** happen in the Connect web UI or require a decision only you can
make.

---

## 1. App information

| Field | Value |
|---|---|
| App name | `Dupless` |
| Bundle ID | `com.vnaidu.Dupless` |
| Version / Build | `1.0` / `1` |
| Primary category | **Photo & Video** |
| Secondary category | **Utilities** |
| Age rating | **4+** (answer every content question "None") |
| Price | Free *(your action — set tier)* |

---

## 2. Listing copy (paste-ready)

### Subtitle (≤30 chars)
```
Find & remove duplicate photos
```

### Promotional text (≤170 chars — editable later without review)
```
Find duplicate and similar photos right on your device, keep the best shot in each set, and free up space — all without a single photo leaving your iPhone.
```

### Keywords (≤100 chars, comma-separated, no name/subtitle repeats)
```
duplicate,cleaner,storage,similar,burst,declutter,gallery,space,best shot,organize,delete,free up
```

### Description
```
Dupless cleans up your photo library the private way — right on your device. It finds duplicate and near-identical shots, picks the best one in each set, and helps you safely remove the rest. No account, no cloud, and your photos are never uploaded.

WHY DUPLESS
• Private by design — your photos are analyzed right on your iPhone or iPad and never leave your device.
• Nothing is deleted automatically. You review every group, and removed photos go to Recently Deleted, so they're always recoverable.
• Fast, on-device analysis powered by Apple's Vision framework.

FIND WHAT'S REDUNDANT
• Detects exact duplicates and visually similar shots using on-device perceptual hashing and Apple's Vision framework.
• Groups a same-scene series — like a "Happy Birthday" portrait burst — and pre-selects everything but the keeper.
• Shows a match percentage so you can see why photos were grouped.

KEEP THE BEST SHOT
• Automatically ranks each group by sharpness, exposure, and resolution to recommend the keeper.
• Tap "Why this one?" for a plain-language explanation of the pick.
• Protects your favorites, edited photos, Live Photos, hidden, shared, and photos with people.

REVIEW WITH CONFIDENCE
• Swipe through groups, adjust what's selected, and move only what you choose to Recently Deleted.
• Browse your library and revisit past results anytime.

SIRI & SHORTCUTS
• Start scans, review groups, and build a best-shots album by voice.

Made for iPhone and iPad — reclaim space and tidy your library, on your terms.
```

### What's New (1.0)
```
First release of Dupless:
• On-device duplicate and similar-photo detection
• Best-shot ranking with plain-language explanations
• Protect favorites, edited photos, and Live Photos (each toggleable)
• Siri & Shortcuts support
• Optional, off-by-default place-name scan matching
```

---

## 3. URLs

| Field | Value | Status |
|---|---|---|
| Privacy Policy URL | `https://veeravn.github.io/cleanshots-site/privacy-policy.html` | ✓ live |
| Support URL | `https://veeravn.github.io/cleanshots-site/` | ✓ live |
| Marketing URL (optional) | `https://veeravn.github.io/cleanshots-site/` | optional |

> **Hosting:** these pages are served by GitHub Pages from the dedicated public
> repo **`veeravn/cleanshots-site`** (this app repo is private, and Pages on a
> private repo needs a paid plan). The site's source mirrors `docs/`
> (`index.html` + `privacy-policy.html`); update the public repo if those pages
> change. Both URLs are verified returning HTTP 200.

---

## 4. App Privacy ("nutrition labels")

**The app is ad-supported (Google AdMob), so you MUST declare data collection —
"Data Not Collected" is no longer accurate and would be a misrepresentation.**

### What to declare
AdMob collects a device advertising identifier and ad-interaction data. At minimum:

> **Identifiers → Device ID** · Used for: **Third-Party Advertising** · **Used for
> tracking: Yes** · Linked to identity: No.

AdMob may also collect Usage Data / Advertising Data / Diagnostics. Reconcile the
full set against Google's current AdMob "Prepare for earnings/iOS" data-collection
guidance and the **GoogleMobileAds SDK's bundled privacy manifest**, and declare
those too. Because tracking is involved, the app must show Apple's **App Tracking
Transparency** prompt, and `Dupless/PrivacyInfo.xcprivacy` declares
`NSPrivacyTracking = true` with Google's tracking domains + the collected data
types (already updated in the repo — verify the domain/data list before submit).

### Still on-device
Your **photos never leave the device** — all analysis is local — and you (the
developer) run no server or account. Only the AdMob SDK collects data, and only
for advertising.

### Location
The opt-in reverse-geocoding lookup lived in the "Ask Dupless" feature, which is
**hidden in this build**, so it isn't reachable — no Location to declare.

---

## 5. App Review notes (paste into "Notes" / "Review Information")

```
Dupless is a fully on-device photo-deduplication app. No account or login is required (no demo account needed).

To test: grant Photos access when prompted. The app scans the library for duplicate and similar photos and presents them for review. Nothing is deleted without explicit user action; removals go to Recently Deleted.

Photo-library permission strings explain both read access (for scanning) and add access (for optionally saving best shots to a new album).
```

---

## 6. Export compliance

The app uses only standard encryption provided by Apple's frameworks (e.g. HTTPS
inside MapKit) and no custom/proprietary cryptography. You can declare it
**exempt**.

> **Tip:** add `ITSAppUsesNonExemptEncryption = NO` to the app's Info settings to
> skip the encryption question on every upload. **(optional, your action)**

---

## 7. Pre-submission checklist

- [ ] **App icon** — 1024×1024 present in the asset catalog ✓ (confirm it has no alpha/transparency)
- [x] **iPhone 6.9" screenshots** — 7 captured in `marketing/screenshots/iphone-6.9/` ✓ (re-captured 2026-07-08 against current build: dropped "Ask Dupless" bar and Drone/Burst — both hidden Pro features per `abbf76e` — picked up the AdMob banner and the new Protect Live Photos toggle, and replaced the Drone/Burst slot with Browse Photos)
- [x] **iPad 13" screenshots** — 3 captured in `marketing/screenshots/ipad-13/` ✓ (re-captured 2026-07-08, same reasons)
- [x] **Privacy Policy URL is live** — `https://veeravn.github.io/cleanshots-site/privacy-policy.html` (GitHub Pages, public `cleanshots-site` repo)
- [x] **Support URL is live** — `https://veeravn.github.io/cleanshots-site/`
- [ ] Listing copy, keywords, categories, age rating entered **(your action)**
- [ ] App Privacy answered — **declare data collection for Google AdMob** (Device
      ID → Third-Party Advertising, used for tracking); NOT "Data Not Collected" **(your action)**
- [ ] Age rating updated for ads (Apple asks about third-party ads) **(your action)**
- [ ] Archive in Xcode (Release) and upload via Organizer **(your action)**
- [ ] Export-compliance answer set / `ITSAppUsesNonExemptEncryption` configured

---

*Generated as submission prep. Verify every field in App Store Connect before
submitting — the privacy declaration in particular is yours to confirm.*
