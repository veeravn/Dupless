# App Store Connect — IAP / Subscription review screenshots

App Store Connect requires a **review screenshot** for each in-app purchase and
subscription on its first submission (Review Information → Screenshot). It must
show the product in context — i.e. the paywall.

These are rendered headlessly from the real `PaywallView`
(`Dupless/App/RootView.swift`) by
`marketing/scripts/generate-paywall-screenshot.swift` — no simulator or app
navigation needed. Regenerate with:

```sh
swift marketing/scripts/generate-paywall-screenshot.swift
```

## Files (all 1320×2868, iPhone 6.9")

| File | Upload to |
| --- | --- |
| `subscription-annual-review.png` | **Dupless Pro (Annual)** — `com.vnaidu.Dupless.pro.annual` |
| `iap-lifetime-review.png` | **Dupless Pro (Lifetime)** — `com.vnaidu.Dupless.pro.lifetime` |
| `paywall-review.png` | canonical source (the other two are copies) |

The single paywall shows **both** products, so the same image is valid for each
slot; the two named copies just make the ASC upload unambiguous.

## Prices

Annual **$2.99/yr**, Lifetime **$29.99** one-time — matching the App Store
Connect price tiers and the local `Products.storekit` config. If you change a
tier, update `annualPrice` / `lifetimePrice` at the top of the generator script
and regenerate.
