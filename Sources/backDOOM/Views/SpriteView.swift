import ImageIO
import SwiftUI

enum Sprite {
    case survivor
    case smiler
    case skinStealer
    case hellspawn
    case hound
    case almondWater
    case knife
    case shield
    case gold
    case keycard
    case stairs
    case flashlight

    var column: Int {
        switch self {
        case .survivor, .hound, .gold:
            0
        case .smiler, .almondWater, .keycard:
            1
        case .skinStealer, .knife, .stairs:
            2
        case .hellspawn, .shield, .flashlight:
            3
        }
    }

    var row: Int {
        switch self {
        case .survivor, .smiler, .skinStealer, .hellspawn:
            0
        case .hound, .almondWater, .knife, .shield:
            1
        case .gold, .keycard, .stairs, .flashlight:
            2
        }
    }

    static func entity(named name: String) -> Sprite {
        switch name {
        case "Smiler":
            .smiler
        case "Skin-Stealer":
            .skinStealer
        case "Agent":
            .hellspawn
        case "Hound":
            .hound
        default:
            .smiler
        }
    }

    static func item(named name: String) -> Sprite {
        if name.contains("Almond Water") {
            return .almondWater
        }
        if name.contains("Knife") {
            return .knife
        }
        return .gold
    }
}

struct SpriteAtlasImage: View {
    let sprite: Sprite

    var body: some View {
        Image(decorative: SpriteLibrary.cgImage(for: sprite), scale: 1, orientation: .up)
            .resizable()
            .interpolation(.high)
            .aspectRatio(1, contentMode: .fit)
            .scaleEffect(sprite.presentationScale)
    }
}

struct AnimatedEntitySprite: View {
    let entityName: String
    var framesPerSecond = 6.5

    var body: some View {
        TimelineView(.animation) { timeline in
            let rawFrame = Int(timeline.date.timeIntervalSinceReferenceDate * framesPerSecond)
            let frame = EntitySpriteLibrary.loopedFrame(for: rawFrame)
            Image(decorative: EntitySpriteLibrary.cgImage(for: entityName, frame: frame), scale: 1, orientation: .up)
                .resizable()
                .interpolation(.high)
                .aspectRatio(1, contentMode: .fit)
                .scaleEffect(0.92)
        }
    }
}

private extension Sprite {
    var presentationScale: CGFloat {
        switch self {
        case .gold:
            0.84
        case .almondWater, .knife, .shield, .keycard, .stairs, .flashlight:
            0.90
        case .survivor, .smiler, .skinStealer, .hellspawn, .hound:
            0.92
        }
    }
}

@MainActor
enum SpriteLibrary {
    private static var cache: [String: CGImage] = [:]

    static func cgImage(for sprite: Sprite) -> CGImage {
        let key = "\(sprite.column)-\(sprite.row)"
        if let cached = cache[key] {
            return cached
        }

        guard
            let url = Bundle.backDOOMResources.backDOOMAssetURL(forResource: "sprite-atlas", withExtension: "png"),
            let cgImage = CGImage.load(from: url)
        else {
            return fallbackImage
        }

        let cellWidth = cgImage.width / 4
        let cellHeight = cgImage.height / 3
        let topInset = Int(Double(cellHeight) * topInsetFactor(for: sprite))
        let croppedHeight = cellHeight - topInset
        let rect = CGRect(
            x: sprite.column * cellWidth,
            y: sprite.row * cellHeight + topInset,
            width: cellWidth,
            height: croppedHeight
        )

        guard let cropped = cgImage.cropping(to: rect) else {
            return fallbackImage
        }

        cache[key] = cropped
        return cropped
    }

    private static func topInsetFactor(for sprite: Sprite) -> Double {
        switch sprite {
        case .almondWater, .knife, .shield:
            // row-0 entity figures' feet bleed into the top of these row-1 cells,
            // but keep enough headroom for tall item silhouettes.
            return 0.20
        case .gold, .keycard, .stairs, .flashlight:
            // small bleed from row-1 items
            return 0.06
        case .survivor, .smiler, .skinStealer, .hellspawn, .hound:
            return 0
        }
    }

    private static var fallbackImage: CGImage {
        CGImage.fallbackPixel
    }
}

@MainActor
private enum EntitySpriteLibrary {
    static let frameCount = 6
    private static let entityRows: [String: Int] = [
        "Smiler": 0,
        "Skin-Stealer": 1,
        "Agent": 2,
        "Hound": 3
    ]
    private static var cache: [String: CGImage] = [:]

    static func loopedFrame(for rawFrame: Int) -> Int {
        let cycleFrameCount = frameCount * 2 - 2
        let frame = rawFrame % cycleFrameCount
        return frame < frameCount ? frame : cycleFrameCount - frame
    }

    static func cgImage(for entityName: String, frame: Int) -> CGImage {
        let row = entityRows[entityName] ?? 0
        let column = max(0, min(frameCount - 1, frame))
        let key = "\(row)-\(column)"

        if let cached = cache[key] {
            return cached
        }

        guard
            let url = Bundle.backDOOMResources.backDOOMAssetURL(forResource: "entity-idle-spritesheet", withExtension: "png"),
            let cgImage = CGImage.load(from: url)
        else {
            return SpriteLibrary.cgImage(for: .entity(named: entityName))
        }

        let frameWidth = cgImage.width / frameCount
        let frameHeight = cgImage.height / entityRows.count
        let rect = CGRect(
            x: column * frameWidth,
            y: row * frameHeight,
            width: frameWidth,
            height: frameHeight
        )

        guard let cropped = cgImage.cropping(to: rect) else {
            return SpriteLibrary.cgImage(for: .entity(named: entityName))
        }

        cache[key] = cropped
        return cropped
    }
}

private extension CGImage {
    static func load(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static var fallbackPixel: CGImage {
        let bytes = [UInt8(0), UInt8(0), UInt8(0), UInt8(255)]
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }
}
