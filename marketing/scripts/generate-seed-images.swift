import AppKit

// Output directory: first CLI argument, defaulting to /tmp/cs_seed.
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/cs_seed"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func img(_ size: Int, _ draw: (NSImage) -> Void) -> NSImage {
    let i = NSImage(size: NSSize(width: size, height: size)); draw(i); return i
}
func save(_ image: NSImage, _ path: String) {
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: path))
}
let S = 1200
// Build N "scenes", each with several near-duplicate variants (jitter in
// position/brightness) so Dupless finds real similar-photo groups.
let scenes: [(NSColor, NSColor)] = [
    (.systemTeal, .systemBlue), (.systemOrange, .systemPink),
    (.systemGreen, .systemYellow), (.systemPurple, .systemIndigo),
    (.systemRed, .systemOrange)
]
var idx = 0
for (s, pair) in scenes.enumerated() {
    for v in 0..<3 {
        let im = img(S) { image in
            image.lockFocus()
            let grad = NSGradient(starting: pair.0, ending: pair.1)!
            grad.draw(in: NSRect(x: 0, y: 0, width: S, height: S), angle: Double(35 + v*4))
            // a "subject" circle that shifts slightly between variants
            let cx = CGFloat(380 + s*30 + v*18), cy = CGFloat(420 + v*22)
            NSColor.white.withAlphaComponent(0.9).setFill()
            NSBezierPath(ovalIn: NSRect(x: cx, y: cy, width: 360, height: 360)).fill()
            NSColor.black.withAlphaComponent(0.18 + Double(v)*0.04).setFill()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: S, height: 120)).fill()
            image.unlockFocus()
        }
        save(im, String(format: "%@/scene%02d_v%d.png", outDir, s, v))
        idx += 1
    }
}
print("wrote \(idx) images")
