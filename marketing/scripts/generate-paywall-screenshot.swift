// Renders a pixel-accurate replica of the in-app PaywallView (Dupless/App/RootView.swift)
// for the App Store Connect IAP / subscription "review screenshot" slots. Runs
// headless on macOS via SwiftUI ImageRenderer — no simulator, no app navigation.
//
//   swift marketing/scripts/generate-paywall-screenshot.swift
//
// Output: marketing/screenshots/app-store-iap/paywall-review.png (1320×2868).
// Keep the copy/prices here in sync with RootView.swift + Products.storekit.

import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import AppKit

// MARK: - Content (mirrors ProFeature + the .storekit products)

private struct Benefit { let icon: String; let title: String; let blurb: String }

private let benefits = [
    Benefit(icon: "sparkles", title: "Ask Dupless",
            blurb: "Describe what to scan in plain language, and scope a scan to a place you name — powered by on-device Apple Intelligence."),
    Benefit(icon: "airplane", title: "Drone & Burst Mode",
            blurb: "Clean up drone and burst sequences while protecting genuinely unique angles and altitudes."),
]

// Prices mirror Products.storekit and the App Store Connect price tiers.
private let annualPrice = "$2.99"
private let lifetimePrice = "$29.99"

private let accent = Color(red: 0.0, green: 0.48, blue: 1.0) // system blue

// MARK: - View

private struct PaywallShot: View {
    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollViewReplica {
                VStack(spacing: 24) {
                    header
                    benefitsCard
                    options
                    restoreAndLinks
                }
                .padding(20)
            }
        }
        .frame(width: 440, height: 956)
        .background(Color(white: 0.96))
    }

    private var navBar: some View {
        ZStack {
            Text("Dupless Pro").font(.system(size: 17, weight: .semibold))
            HStack {
                Spacer()
                Text("Close").font(.system(size: 17)).foregroundStyle(accent)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 52)
        .background(Color(white: 0.96))
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(accent)
            Text("Unlock Dupless Pro")
                .font(.system(size: 22, weight: .bold))
            Text("Everything stays on your device. No ads, no tracking — ever.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(benefits, id: \.title) { b in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: b.icon)
                        .font(.system(size: 17))
                        .foregroundStyle(accent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(b.title).font(.system(size: 17, weight: .semibold))
                        Text(b.blurb).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(white: 0.91), in: RoundedRectangle(cornerRadius: 16))
    }

    private var options: some View {
        VStack(spacing: 12) {
            // Annual — prominent
            purchaseRow(title: "Dupless Pro (Annual)", caption: "per year", price: annualPrice,
                        filled: true)
            // Lifetime — bordered
            purchaseRow(title: "Dupless Pro (Lifetime)", caption: "one-time purchase", price: lifetimePrice,
                        filled: false)
        }
    }

    private func purchaseRow(title: String, caption: String, price: String, filled: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 17, weight: .semibold))
                Text(caption).font(.system(size: 12))
                    .foregroundStyle(filled ? Color.white.opacity(0.85) : Color.secondary)
            }
            Spacer()
            Text(price).font(.system(size: 17, weight: .semibold))
        }
        .foregroundStyle(filled ? Color.white : Color.primary)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(filled ? accent : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(filled ? Color.clear : accent.opacity(0.6), lineWidth: 1))
        )
    }

    private var restoreAndLinks: some View {
        VStack(spacing: 12) {
            Text("Restore Purchases").font(.system(size: 15)).foregroundStyle(accent)
            Text("Payment is charged to your Apple Account. Subscriptions renew automatically until canceled in Settings.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Text("Privacy Policy")
                Text("Terms (EULA)")
            }
            .font(.system(size: 11))
            .foregroundStyle(accent)
        }
        .padding(.top, 4)
    }
}

// A plain container (no real scrolling needed; content fits the frame).
private struct ScrollViewReplica<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { VStack { content; Spacer(minLength: 0) } }
}

// MARK: - Render

@MainActor
func render() {
    let outDir = "marketing/screenshots/app-store-iap"
    try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

    let renderer = ImageRenderer(content: PaywallShot())
    renderer.scale = 3.0 // 440×956 pt → 1320×2868 px (iPhone 6.9")

    guard let cg = renderer.cgImage else {
        FileHandle.standardError.write(Data("ERROR: ImageRenderer produced no image\n".utf8))
        exit(1)
    }
    let url = URL(fileURLWithPath: "\(outDir)/paywall-review.png")
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        FileHandle.standardError.write(Data("ERROR: could not create PNG destination\n".utf8))
        exit(1)
    }
    CGImageDestinationAddImage(dest, cg, nil)
    if CGImageDestinationFinalize(dest) {
        print("Wrote \(url.path)  (\(cg.width)×\(cg.height))")
    } else {
        FileHandle.standardError.write(Data("ERROR: PNG finalize failed\n".utf8))
        exit(1)
    }
}

MainActor.assumeIsolated { render() }
