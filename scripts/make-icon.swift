// Generates Resources/AppIcon.icns: a dot-matrix "M" on a dark background.
// Usage: swift scripts/make-icon.swift
import AppKit

let ink = NSColor(srgbRed: 0x17 / 255, green: 0x17 / 255, blue: 0x17 / 255, alpha: 1)
let paper = NSColor(srgbRed: 0xFA / 255, green: 0xFA / 255, blue: 0xFA / 255, alpha: 1)
let accent = NSColor(srgbRed: 0xB8 / 255, green: 0xA4 / 255, blue: 0xF8 / 255, alpha: 1)

// Rows from top to bottom; "o" is the accent dot.
let glyph = ["x...x", "xx.xx", "x.o.x", "x...x", "x...x"]

func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let size = CGFloat(pixels)
    // Standard macOS icon proportions: an 824 square on a 1024 canvas.
    let tile = NSRect(x: size * 0.0977, y: size * 0.0977, width: size * 0.8046, height: size * 0.8046)
    ink.setFill()
    NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.2237, yRadius: tile.width * 0.2237).fill()

    let step = tile.width * 0.15
    let dot = step * 0.62
    let origin = NSPoint(x: tile.midX - step * 2, y: tile.midY + step * 2)
    for (row, line) in glyph.enumerated() {
        for (column, mark) in line.enumerated() where mark != "." {
            (mark == "o" ? accent : paper).setFill()
            let center = NSPoint(x: origin.x + CGFloat(column) * step, y: origin.y - CGFloat(row) * step)
            NSBezierPath(ovalIn: NSRect(x: center.x - dot / 2, y: center.y - dot / 2, width: dot, height: dot)).fill()
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: "Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try render(points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try render(1024).write(to: URL(fileURLWithPath: "Resources/icon-1024.png"))
