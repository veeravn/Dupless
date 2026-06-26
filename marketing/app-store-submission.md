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
Dupless cleans up your photo library the private way — entirely on your device. It finds duplicates and near-identical shots, picks the best one in each set, and helps you safely remove the rest. No account, no cloud, no uploads.

WHY DUPLESS
• Private by design — your photos are analyzed right on your iPhone or iPad and never leave your device.
• Nothing is deleted automatically. You review every group, and removed photos go to Recently Deleted, so they're always recoverable.
• Built for the photos you actually take — portrait series, bursts, and drone sequences.

FIND WHAT'S REDUNDANT
• Detects exact duplicates and visually similar shots using on-device perceptual hashing and Apple's Vision framework.
• Groups a same-scene series — like a "Happy Birthday" portrait burst — and pre-selects everything but the keeper.
• Shows a match percentage so you can see why photos were grouped.

KEEP THE BEST SHOT
• Automatically ranks each group by sharpness, exposure, and resolution to recommend the keeper.
• Tap "Why this one?" for a plain-language explanation of the pick.
• Protects favorites, edited photos, Live Photos, hidden, shared, and photos with people.

ASK IN PLAIN LANGUAGE
• Type a request like "scan last month, be conservative" — interpreted on-device by Apple Intelligence, with a reliable fallback when it's unavailable.
• Optionally scope a scan to a place you name; matching looks up where photos were taken using Apple's location service. This is off by default and the only feature that sends anything off your device — and it sends coordinates only, never your photos.

DRONE & BURST
• Clusters photo sessions by time and location, finds redundant sequences, and preserves genuinely unique angles — including different drone altitudes.

SIRI & SHORTCUTS
• Start scans, review groups, and build albums by voice.

Dupless has no ads, no trackers, no analytics SDKs, and no account. It just makes your library smaller, on your terms.
```

### What's New (1.0)
```
First release of Dupless:
• On-device duplicate and similar-photo detection
• Best-shot ranking with plain-language explanations
• Natural-language scans with Apple Intelligence
• Drone/Burst session cleanup that protects unique angles
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

**Recommended answer to "Do you or your third-party partners collect data from
this app?": → No, "Data Not Collected".**

### Why this is accurate
Apple defines "collect" as transmitting data off the device in a way that lets
**you (the developer) or your partners access it beyond what's needed to service
the request in real time**. Against that definition:

- **No developer data collection of any kind.** No account, no analytics, no ads,
  no third-party SDKs, and no server — confirmed: the codebase contains no
  networking, analytics, or login code.
- **Photos never leave the device.** All analysis (hashing, Vision, ranking,
  on-device Apple Intelligence) runs locally.
- **The one off-device call is reverse geocoding** photo coordinates via Apple's
  **MapKit** (`MKReverseGeocodingRequest`). That data is processed by **Apple's
  own framework** to service the request in real time; you never receive, store,
  or reuse it, and Apple as the OS platform provider is not a "third-party
  partner" you declare. It is also **opt-in and off by default**.

So there is no data type that meets Apple's "collection" bar for *you* to
declare.

### The one judgment call (so you can confirm)
The only debatable item is the geocoding location lookup. The position above —
that framework-only, real-time-serviced, developer-inaccessible data isn't
developer "collection" — is consistent with Apple's guidance and is the accurate
declaration. **If you prefer maximum caution**, you may instead declare:

> **Location → Coarse Location** · Used for: **App Functionality** · **Not** used
> for tracking · **Not** linked to the user's identity.

Either is defensible; "Data Not Collected" is the more accurate one given you
never access the data. This is your legal declaration — pick the one you're
comfortable signing.

---

## 5. App Review notes (paste into "Notes" / "Review Information")

```
Dupless is a fully on-device photo-deduplication app. No account or login is required (no demo account needed).

To test: grant Photos access when prompted. The app scans the library for duplicate and similar photos and presents them for review. Nothing is deleted without explicit user action; removals go to Recently Deleted.

"Ask Dupless" interprets a typed request using on-device Apple Intelligence (Foundation Models); when unavailable it falls back to deterministic keyword parsing, so the feature works on all supported devices.

Optional place-name scan scoping is OFF by default. When a user enables it for a scan, the app reverse-geocodes photo coordinates via MapKit (MKReverseGeocodingRequest) to match a named place. Only coordinates are sent to Apple's location service — never photos. This is the only off-device transmission and is disclosed in the privacy policy.

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
- [ ] **iPhone 6.9" screenshots** — 7 captured in `marketing/screenshots/iphone-6.9/` ✓
- [ ] **iPad 13" screenshots** — 3 captured in `marketing/screenshots/ipad-13/` ✓
- [x] **Onboarding screenshot refreshed** — `iphone-6.9/1-onboarding.png` re-captured with the current "Find duplicates" title.
- [x] **Privacy Policy URL is live** — `https://veeravn.github.io/cleanshots-site/privacy-policy.html` (GitHub Pages, public `cleanshots-site` repo)
- [x] **Support URL is live** — `https://veeravn.github.io/cleanshots-site/`
- [ ] Listing copy, keywords, categories, age rating entered **(your action)**
- [ ] App Privacy answered ("Data Not Collected" recommended) **(your action)**
- [ ] Archive in Xcode (Release) and upload via Organizer **(your action)**
- [ ] Export-compliance answer set / `ITSAppUsesNonExemptEncryption` configured

---

*Generated as submission prep. Verify every field in App Store Connect before
submitting — the privacy declaration in particular is yours to confirm.*
