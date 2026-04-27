import AppKit
import CoreGraphics
import Foundation
import ImageIO

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("Sources/backDOOM/Assets/sprite-atlas.png")
let outputURL = root.appendingPathComponent("Sources/backDOOM/Assets/entity-idle-spritesheet.png")

guard
    let sourceImage = NSImage(contentsOf: sourceURL),
    let atlas = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    fatalError("Could not load source sprite atlas")
}

let sourceColumns = 4
let sourceRows = 3
let cellWidth = atlas.width / sourceColumns
let cellHeight = atlas.height / sourceRows
let frameSize = 256
let framesPerEntity = 6

let entities: [(name: String, column: Int, row: Int)] = [
    ("Smiler", 1, 0),
    ("Skin-Stealer", 2, 0),
    ("Agent", 3, 0),
    ("Hound", 0, 1)
]

let outputWidth = frameSize * framesPerEntity
let outputHeight = frameSize * entities.count
let colorSpace = CGColorSpaceCreateDeviceRGB()

guard let output = CGContext(
    data: nil,
    width: outputWidth,
    height: outputHeight,
    bitsPerComponent: 8,
    bytesPerRow: outputWidth * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create output context")
}

output.clear(CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
output.interpolationQuality = .high

func transparentCutout(from image: CGImage) -> CGImage {
    let width = image.width
    let height = image.height
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return image
    }

    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    for y in 0..<height {
        for x in 0..<width {
            let index = y * bytesPerRow + x * 4
            let r = CGFloat(pixels[index]) / 255
            let g = CGFloat(pixels[index + 1]) / 255
            let b = CGFloat(pixels[index + 2]) / 255
            let maxChannel = max(r, g, b)
            let minChannel = min(r, g, b)
            let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
            let saturation = maxChannel == 0 ? 0 : (maxChannel - minChannel) / maxChannel

            if luma < 0.09 && saturation < 0.24 {
                pixels[index + 3] = 0
            } else if luma < 0.20 && saturation < 0.18 {
                let alpha = max(0, min(1, (luma - 0.09) / 0.11))
                pixels[index + 3] = UInt8(alpha * 255)
            }
        }
    }

    guard let cutout = context.makeImage() else {
        return image
    }

    return cutout
}

for (entityIndex, entity) in entities.enumerated() {
    let cropRect = CGRect(
        x: entity.column * cellWidth,
        y: entity.row * cellHeight,
        width: cellWidth,
        height: cellHeight
    )
    guard let cropped = atlas.cropping(to: cropRect) else { continue }
    let cutout = transparentCutout(from: cropped)

    for frame in 0..<framesPerEntity {
        let t = CGFloat(frame) / CGFloat(framesPerEntity)
        let bob = sin(t * .pi * 2) * 5
        let squash = 1 + sin(t * .pi * 2) * 0.025
        let frameRect = CGRect(
            x: frame * frameSize,
            y: entityIndex * frameSize,
            width: frameSize,
            height: frameSize
        )
        let spriteWidth = CGFloat(frameSize) * (0.88 + (1 - squash) * 0.4)
        let spriteHeight = CGFloat(frameSize) * 0.88 * squash
        let drawRect = CGRect(
            x: frameRect.midX - spriteWidth / 2,
            y: frameRect.midY - spriteHeight / 2 + bob,
            width: spriteWidth,
            height: spriteHeight
        )

        output.saveGState()
        output.clip(to: frameRect)
        output.draw(cutout, in: drawRect)
        output.restoreGState()
    }
}

guard
    let result = output.makeImage(),
    let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, "public.png" as CFString, 1, nil)
else {
    fatalError("Could not create output spritesheet")
}

CGImageDestinationAddImage(destination, result, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("Could not write output spritesheet")
}

print("Generated \(outputURL.path)")
