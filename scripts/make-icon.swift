import AppKit

// Draw the app's native SF Symbols leaf mark into the standard macOS icon sizes.
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let p = CGFloat(pixels)
        let inset = p * 0.07
        let rect = NSRect(x: inset, y: inset, width: p - inset * 2, height: p - inset * 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: p * 0.19, yRadius: p * 0.19)
        NSGradient(starting: NSColor(srgbRed: 0.31, green: 0.46, blue: 0.38, alpha: 1), ending: NSColor(srgbRed: 0.15, green: 0.28, blue: 0.23, alpha: 1))!.draw(in: path, angle: -90)
        let symbol = NSImage(systemSymbolName: "leaf", accessibilityDescription: nil)!
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: p * 0.50, weight: .light))!
            .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [NSColor(srgbRed: 0.95, green: 0.92, blue: 0.81, alpha: 1)]))!
        symbol.draw(in: NSRect(x: p * 0.24, y: p * 0.245, width: p * 0.52, height: p * 0.51))
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
