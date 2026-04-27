import AppKit
import CoreGraphics
import Foundation
import ImageIO

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let atlasURL = root.appendingPathComponent("Sources/backDOOM/Assets/level-texture-atlas.png")

guard
    let image = NSImage(contentsOf: atlasURL),
    let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    fatalError("Could not load texture atlas at \(atlasURL.path)")
}

let width = source.width
let height = source.height
let grid = 5
let cell = min(width / grid, height / grid)
let colorSpace = CGColorSpaceCreateDeviceRGB()

guard let context = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create atlas context")
}

context.interpolationQuality = .high
context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

struct SeededRandom {
    private var state: UInt64

    init(_ seed: UInt64) {
        state = seed
    }

    mutating func next() -> CGFloat {
        state = 2862933555777941757 &* state &+ 3037000493
        return CGFloat(Double((state >> 33) & 0xFFFF) / Double(0xFFFF))
    }
}

func cgColor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

func drawSlabTile(in rect: CGRect, base: CGColor, seam: CGColor, highlight: CGColor, seed: UInt64, largeBlocks: Bool) {
    var rng = SeededRandom(seed)

    context.setFillColor(base)
    context.fill(rect)

    let blockHeight = largeBlocks ? rect.height / 4 : rect.height / 5
    for row in 0..<(largeBlocks ? 4 : 5) {
        let y = rect.minY + CGFloat(row) * blockHeight
        let offset = row.isMultiple(of: 2) ? 0 : rect.width * 0.22
        var x = rect.minX - offset

        while x < rect.maxX {
            let blockWidth = rect.width * (largeBlocks ? 0.42 : 0.34) * (0.88 + rng.next() * 0.22)
            let blockRect = CGRect(
                x: x + 1,
                y: y + 1,
                width: blockWidth - 2,
                height: blockHeight - 2
            ).intersection(rect)

            let tone = rng.next() * 0.045 - 0.022
            context.setFillColor(cgColor(0.24 + tone, 0.225 + tone, 0.19 + tone, 1))
            context.fill(blockRect)

            context.setStrokeColor(highlight.copy(alpha: 0.16) ?? highlight)
            context.setLineWidth(1)
            context.stroke(CGRect(x: blockRect.minX + 1, y: blockRect.minY + 1, width: blockRect.width - 2, height: 1))

            x += blockWidth
        }
    }

    context.setStrokeColor(seam)
    context.setLineWidth(2)
    for row in 1..<(largeBlocks ? 4 : 5) {
        let y = rect.minY + CGFloat(row) * blockHeight
        context.move(to: CGPoint(x: rect.minX, y: y))
        context.addLine(to: CGPoint(x: rect.maxX, y: y))
    }
    context.strokePath()

    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.10))
    for _ in 0..<220 {
        let x = rect.minX + rng.next() * rect.width
        let y = rect.minY + rng.next() * rect.height
        let size = 1 + rng.next() * 2
        context.fill(CGRect(x: x, y: y, width: size, height: size))
    }
}

let floorRect = CGRect(x: 0, y: CGFloat(cell * 2), width: CGFloat(cell), height: CGFloat(cell))
let ceilingRect = CGRect(x: CGFloat(cell), y: CGFloat(cell * 2), width: CGFloat(cell), height: CGFloat(cell))

drawSlabTile(
    in: floorRect,
    base: cgColor(0.18, 0.16, 0.13),
    seam: cgColor(0.06, 0.05, 0.045, 0.54),
    highlight: cgColor(0.70, 0.62, 0.48, 1),
    seed: 42,
    largeBlocks: false
)

drawSlabTile(
    in: ceilingRect,
    base: cgColor(0.13, 0.125, 0.115),
    seam: cgColor(0.03, 0.03, 0.03, 0.62),
    highlight: cgColor(0.42, 0.40, 0.36, 1),
    seed: 314,
    largeBlocks: true
)

guard
    let result = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(atlasURL as CFURL, "public.png" as CFString, 1, nil)
else {
    fatalError("Could not create output atlas")
}

CGImageDestinationAddImage(destination, result, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("Could not write output atlas")
}

print("Updated floor and ceiling texture cells in \(atlasURL.path)")
