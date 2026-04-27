import Foundation
import ImageIO
import SwiftUI

struct ViewportView: View {
    @Environment(GameStore.self) private var game
    @Environment(UIState.self) private var ui
    @State private var activeAnimation: ActiveCameraAnimation?
    @State private var clearAnimationTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                let cameraPose = activeAnimation?.pose(at: timeline.date) ?? CameraPose.cell(game.position, facing: game.direction)
                let isAnimating = activeAnimation?.isActive(at: timeline.date) ?? false
                let viewportBob = activeAnimation?.screenOffset(at: timeline.date) ?? .zero

                ZStack {
                    RaycastView(size: proxy.size, cameraPose: cameraPose)

                    ForEach(projectedItems(cameraPose: cameraPose, size: proxy.size), id: \.point) { projected in
                        ItemBillboard(item: projected.item, spriteHeight: projected.spriteHeight)
                            .position(x: projected.screenX, y: projected.spriteCenterY)
                    }

                    if let projected = projectedEntity(cameraPose: cameraPose, size: proxy.size) {
                        EntitySpriteBillboard(entity: projected.entity, spriteHeight: projected.spriteHeight)
                            .position(x: projected.screenX, y: projected.spriteCenterY)
                        EntityNameplate(entity: projected.entity, scale: max(0.45, min(1.05, projected.spriteHeight / 220)))
                            .position(
                                x: projected.screenX,
                                y: projected.spriteCenterY - projected.spriteHeight * 0.55 - 18
                            )
                    }

                    if !isAnimating, game.tile(at: game.position) == .stairs {
                        SeamOverlay(theme: game.level.theme)
                    }

                    if game.runState == .defeated {
                        DefeatOverlay()
                    }

                    FluorescentFlicker(theme: game.level.theme)
                        .allowsHitTesting(false)

                    if ui.compassEnabled {
                        CompassOverlay(direction: game.compassDirection)
                            .cornerOverlay(.bottomLeading)
                    }

                    if ui.targetLockEnabled {
                        if let target = game.visibleEntity {
                            TargetLockOverlay(entity: target.entity, distance: target.distance)
                                .cornerOverlay(.topTrailing)
                        } else {
                            TargetLockEmptyOverlay()
                                .cornerOverlay(.topTrailing)
                        }
                    }
                }
                .offset(viewportBob)
            }
            .contentShape(Rectangle())
            .onChange(of: game.cameraEvent) { _, event in
                handleCameraEvent(event)
            }
        }
        .background(.black)
    }

    private func handleCameraEvent(_ event: CameraEvent?) {
        guard let event else { return }
        clearAnimationTask?.cancel()

        guard event.duration > 0 else {
            activeAnimation = nil
            return
        }

        activeAnimation = ActiveCameraAnimation(event: event, start: Date())
        clearAnimationTask = Task { [duration = event.duration] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await MainActor.run {
                activeAnimation = nil
            }
        }
    }

    private func projectedItems(cameraPose: CameraPose, size: CGSize) -> [ProjectedItem] {
        let fieldOfView = Double.pi / 2.35

        return game.items.compactMap { point, item in
            let targetX = Double(point.x) + 0.5
            let targetY = Double(point.y) + 0.5
            let dx = targetX - cameraPose.x
            let dy = targetY - cameraPose.y
            let distance = hypot(dx, dy)
            guard distance > 0.25 else { return nil }

            let angle = atan2(dy, dx)
            let angleDelta = normalizedAngle(angle - cameraPose.angle)
            guard abs(angleDelta) < fieldOfView * 0.48 else { return nil }
            guard hasLineOfSight(from: cameraPose, to: point, distance: distance) else { return nil }

            let projection = billboardProjection(distance: distance, angleDelta: angleDelta, size: size, heightFactor: 0.34)
            let screenX = size.width * CGFloat(0.5 + angleDelta / fieldOfView)
            return ProjectedItem(
                point: point,
                item: item,
                distance: distance,
                screenX: screenX,
                spriteCenterY: projection.spriteCenterY,
                spriteHeight: projection.spriteHeight
            )
        }
        .sorted { $0.distance > $1.distance }
    }

    private func projectedEntity(cameraPose: CameraPose, size: CGSize) -> ProjectedEntity? {
        let fieldOfView = Double.pi / 2.35

        return game.entities.compactMap { point, entity in
            let targetX = Double(point.x) + 0.5
            let targetY = Double(point.y) + 0.5
            let dx = targetX - cameraPose.x
            let dy = targetY - cameraPose.y
            let distance = hypot(dx, dy)
            guard distance > 0.25 else { return nil }

            let angle = atan2(dy, dx)
            let angleDelta = normalizedAngle(angle - cameraPose.angle)
            guard abs(angleDelta) < fieldOfView * 0.48 else { return nil }
            guard hasLineOfSight(from: cameraPose, to: point, distance: distance) else { return nil }

            let projection = billboardProjection(distance: distance, angleDelta: angleDelta, size: size, heightFactor: 0.96)
            let screenX = size.width * CGFloat(0.5 + angleDelta / fieldOfView)
            return ProjectedEntity(
                entity: entity,
                distance: distance,
                screenX: screenX,
                spriteCenterY: projection.spriteCenterY,
                spriteHeight: projection.spriteHeight
            )
        }
        .min { lhs, rhs in
            lhs.distance < rhs.distance
        }
    }

    private func billboardProjection(distance: Double, angleDelta: Double, size: CGSize, heightFactor: CGFloat) -> (spriteCenterY: CGFloat, spriteHeight: CGFloat) {
        let cameraZ = max(0.22, distance * cos(angleDelta))
        let projectedHeight = min(size.height * 1.85, size.height / CGFloat(cameraZ) * 1.08)
        let floorY = (size.height + projectedHeight) * 0.5
        let spriteHeight = projectedHeight * heightFactor
        let spriteCenterY = floorY - spriteHeight * 0.5
        return (spriteCenterY, spriteHeight)
    }

    private func hasLineOfSight(from cameraPose: CameraPose, to point: GridPoint, distance: Double) -> Bool {
        let targetX = Double(point.x) + 0.5
        let targetY = Double(point.y) + 0.5
        let steps = max(1, Int(distance / 0.05))

        for index in 1..<steps {
            let t = Double(index) / Double(steps)
            let sample = GridPoint(
                x: Int((cameraPose.x + (targetX - cameraPose.x) * t).rounded(.down)),
                y: Int((cameraPose.y + (targetY - cameraPose.y) * t).rounded(.down))
            )

            if game.tile(at: sample) == .wall {
                return false
            }
        }

        return true
    }
}

private struct RaycastView: View {
    @Environment(GameStore.self) private var game

    let size: CGSize
    let cameraPose: CameraPose

    var body: some View {
        Canvas { context, canvasSize in
            drawBackdrop(in: &context, size: canvasSize)
            drawWalls(in: &context, size: canvasSize)
            drawVignette(in: &context, size: canvasSize)
        }
    }

    private func drawBackdrop(in context: inout GraphicsContext, size: CGSize) {
        let ceiling = CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.52)
        let floor = CGRect(x: 0, y: size.height * 0.48, width: size.width, height: size.height * 0.52)

        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
        context.withCGContext { cgContext in
            drawProjectedPlaneTextures(
                floorTexture: TextureLibrary.cgImage(for: .floor),
                ceilingTexture: TextureLibrary.cgImage(for: .ceiling),
                size: size,
                cameraPose: cameraPose,
                context: cgContext
            )
        }

        context.fill(Path(ceiling), with: .color(game.level.theme.wallShade.opacity(0.22)))
        context.fill(Path(floor), with: .color(.black.opacity(0.18)))

        let glow = Path(ellipseIn: CGRect(x: size.width * 0.18, y: size.height * 0.08, width: size.width * 0.64, height: size.height * 0.72))
        context.fill(glow, with: .radialGradient(
            Gradient(colors: [game.level.theme.fog.opacity(0.35), .clear]),
            center: CGPoint(x: size.width * 0.5, y: size.height * 0.42),
            startRadius: 10,
            endRadius: size.width * 0.36
        ))
    }

    private func drawWalls(in context: inout GraphicsContext, size: CGSize) {
        let wallStrips = TextureLibrary.wallStrips(for: game.level.level)
        let step: CGFloat = 3
        let columnWidth = step + 1
        let fieldOfView = Double.pi / 2.35
        let originX = cameraPose.x
        let originY = cameraPose.y
        let facing = cameraPose.angle
        let maxDistance = 18.0

        var screenX: CGFloat = 0
        while screenX < size.width {
            let cameraX = Double(screenX / max(1, size.width)) - 0.5
            let rayAngle = facing + cameraX * fieldOfView
            let hit = castRay(originX: originX, originY: originY, angle: rayAngle, maxDistance: maxDistance)
            let correctedDistance = max(0.18, hit.distance * cos(rayAngle - facing))
            let projectedHeight = min(size.height * 1.75, size.height / correctedDistance * 1.08)
            let wallTop = (size.height - projectedHeight) * 0.5
            let wallRect = CGRect(x: screenX, y: wallTop, width: columnWidth, height: projectedHeight)
            let shade = max(0.16, 1.0 - correctedDistance / maxDistance)
            let mortar = mortarLine(for: hit.texture, y: wallTop, height: projectedHeight)
            let stripIndex = max(0, min(wallStrips.count - 1, Int(hit.texture * Double(wallStrips.count))))

            context.withCGContext { cgContext in
                cgContext.interpolationQuality = .none
                cgContext.draw(wallStrips[stripIndex], in: wallRect)
            }

            context.fill(Path(wallRect), with: .color(wallShade(shade: shade, hitSide: hit.side, mortar: mortar)))

            if Int(screenX).isMultiple(of: 24) {
                context.stroke(Path(CGRect(x: screenX, y: wallTop, width: 1, height: projectedHeight)), with: .color(.black.opacity(0.18)), lineWidth: 1)
            }

            let floorShade = max(0, min(0.22, 0.22 - correctedDistance * 0.012))
            if floorShade > 0 {
                let floorRect = CGRect(x: screenX, y: wallRect.maxY, width: columnWidth, height: size.height - wallRect.maxY)
                context.fill(Path(floorRect), with: .color(game.level.theme.fog.opacity(floorShade)))
            }

            screenX += step
        }
    }

    private func castRay(originX: Double, originY: Double, angle: Double, maxDistance: Double) -> RayHit {
        let dx = cos(angle)
        let dy = sin(angle)
        var distance = 0.03
        var lastCell = GridPoint(x: Int(originX), y: Int(originY))

        while distance < maxDistance {
            let sampleX = originX + dx * distance
            let sampleY = originY + dy * distance
            let cell = GridPoint(x: Int(sampleX.rounded(.down)), y: Int(sampleY.rounded(.down)))

            if game.tile(at: cell) == .wall {
                let changedX = cell.x != lastCell.x
                let texture = changedX ? sampleY - floor(sampleY) : sampleX - floor(sampleX)
                return RayHit(distance: distance, texture: texture, side: changedX ? .vertical : .horizontal)
            }

            lastCell = cell
            distance += 0.025
        }

        return RayHit(distance: maxDistance, texture: 0, side: .horizontal)
    }

    private func wallShade(shade: Double, hitSide: RaySide, mortar: Bool) -> Color {
        if mortar {
            return .black.opacity(0.20)
        }

        let darkness = hitSide == .vertical ? 0.50 : 0.64
        return .black.opacity(max(0.05, min(0.62, darkness - shade * 0.48)))
    }

    private func mortarLine(for texture: Double, y: CGFloat, height: CGFloat) -> Bool {
        texture < 0.012 || texture > 0.988
    }

    private func drawVignette(in context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(rect), with: .radialGradient(
            Gradient(colors: [.clear, .black.opacity(0.78)]),
            center: CGPoint(x: size.width * 0.5, y: size.height * 0.5),
            startRadius: min(size.width, size.height) * 0.22,
            endRadius: max(size.width, size.height) * 0.7
        ))
    }
}

private func drawProjectedPlaneTextures(
    floorTexture: CGImage,
    ceilingTexture: CGImage,
    size: CGSize,
    cameraPose: CameraPose,
    context: CGContext
) {
    let horizon = size.height * 0.52
    let fieldOfView = Double.pi / 2.35
    let originX = cameraPose.x
    let originY = cameraPose.y
    let facing = cameraPose.angle
    let leftRay = facing - fieldOfView / 2
    let rightRay = facing + fieldOfView / 2
    let rayLeftX = cos(leftRay)
    let rayLeftY = sin(leftRay)
    let rayRightX = cos(rightRay)
    let rayRightY = sin(rightRay)
    let rowStep: CGFloat = 6
    let cameraHeight = Double(size.height) * 0.40

    context.saveGState()
    context.interpolationQuality = .high

    var screenY = horizon + 1
    while screenY < size.height {
        let p = max(1, Double(screenY - horizon))
        let rowDistance = cameraHeight / p
        let floorStepX = rowDistance * (rayRightX - rayLeftX) / Double(max(1, size.width))
        let floorStepY = rowDistance * (rayRightY - rayLeftY) / Double(max(1, size.width))
        let ceilingY = max(0, size.height - screenY - rowStep)
        let distanceShade = max(0.0, min(0.78, 0.20 + rowDistance * 0.072))
        let floorX = originX + rowDistance * rayLeftX
        let floorY = originY + rowDistance * rayLeftY
        let floorTileSize: CGFloat = 156
        let ceilingTileSize: CGFloat = 184
        let offsetX = CGFloat(floorX * Double(floorTileSize))
        let offsetY = CGFloat(floorY * Double(floorTileSize))
        let skew = CGFloat((floorStepX + floorStepY) * 38)
        let floorRow = CGRect(x: 0, y: screenY, width: size.width, height: rowStep + 1)
        let ceilingRow = CGRect(x: 0, y: ceilingY, width: size.width, height: rowStep + 1)

        drawFastTiledRow(
            image: floorTexture,
            in: floorRow,
            tileSize: floorTileSize,
            offsetX: offsetX + skew,
            offsetY: offsetY,
            context: context
        )
        drawFastTiledRow(
            image: ceilingTexture,
            in: ceilingRow,
            tileSize: ceilingTileSize,
            offsetX: -offsetX + skew,
            offsetY: offsetY * 0.7,
            context: context
        )

        context.setFillColor(CGColor(gray: 0, alpha: distanceShade))
        context.fill(CGRect(x: 0, y: screenY, width: size.width, height: rowStep + 1))
        context.fill(CGRect(x: 0, y: ceilingY, width: size.width, height: rowStep + 1))

        screenY += rowStep
    }

    context.restoreGState()
}

private func drawFastTiledRow(
    image: CGImage,
    in rect: CGRect,
    tileSize: CGFloat,
    offsetX: CGFloat,
    offsetY: CGFloat,
    context: CGContext
) {
    context.saveGState()
    context.clip(to: rect)

    var x = -tileSize - offsetX.truncatingRemainder(dividingBy: tileSize)
    let y = rect.minY - offsetY.truncatingRemainder(dividingBy: tileSize)
    while x < rect.maxX + tileSize {
        context.draw(image, in: CGRect(x: x, y: y, width: tileSize, height: tileSize))
        x += tileSize
    }

    context.restoreGState()
}

@MainActor
private enum TextureLibrary {
    enum AtlasTile {
        case wall(level: Int)
        case floor
        case ceiling

        var atlasColumn: Int {
            switch self {
            case .wall(let level):
                (max(1, level) - 1) % 5
            case .floor:
                0
            case .ceiling:
                1
            }
        }

        var atlasRow: Int {
            switch self {
            case .wall:
                0
            case .floor:
                2
            case .ceiling:
                2
            }
        }

        var cacheKey: String {
            switch self {
            case .wall(let level):
                "wall-\((max(1, level) - 1) % 5)"
            case .floor:
                "floor"
            case .ceiling:
                "ceiling"
            }
        }
    }

    private static var cache: [String: CGImage] = [:]
    private static var stripCache: [String: [CGImage]] = [:]

    static func cgImage(for tile: AtlasTile) -> CGImage {
        if let cached = cache[tile.cacheKey] {
            return cached
        }

        guard
            let url = Bundle.backDOOMResources.backDOOMAssetURL(forResource: "level-texture-atlas", withExtension: "png"),
            let atlas = CGImage.load(from: url)
        else {
            return fallbackTexture
        }

        let grid = 5
        let cellWidth = atlas.width / grid
        let cellHeight = atlas.height / grid
        let rect = CGRect(
            x: min(grid - 1, tile.atlasColumn) * cellWidth,
            y: min(grid - 1, tile.atlasRow) * cellHeight,
            width: cellWidth,
            height: cellHeight
        )

        guard let cropped = atlas.cropping(to: rect) else {
            return fallbackTexture
        }

        cache[tile.cacheKey] = cropped
        return cropped
    }

    static func wallStrips(for level: Int) -> [CGImage] {
        let key = "wall-strips-\((max(1, level) - 1) % 5)"
        if let cached = stripCache[key] {
            return cached
        }

        let wall = cgImage(for: .wall(level: level))
        let count = 96
        let stripWidth = max(1, wall.width / count)
        let strips = (0..<count).compactMap { index in
            wall.cropping(to: CGRect(
                x: min(wall.width - stripWidth, index * stripWidth),
                y: 0,
                width: stripWidth,
                height: wall.height
            ))
        }

        let result = strips.isEmpty ? [wall] : strips
        stripCache[key] = result
        return result
    }

    private static var fallbackTexture: CGImage {
        let width = 8
        let height = 8
        let bytes = Array(repeating: UInt8(96), count: width * height * 4)
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }
}

private extension CGImage {
    static func load(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

private struct RayHit {
    let distance: Double
    let texture: Double
    let side: RaySide
}

private enum RaySide {
    case horizontal
    case vertical
}

private struct ActiveCameraAnimation {
    let event: CameraEvent
    let start: Date

    func pose(at date: Date) -> CameraPose {
        let progress = progress(at: date)

        switch event.kind {
        case .bump:
            let pulse = sin(progress * Double.pi)
            return interpolatedPose(amount: pulse)
        case .reset:
            return event.to
        case .turn, .walk:
            return interpolatedPose(amount: smoothstep(progress))
        }
    }

    func screenOffset(at date: Date) -> CGSize {
        let progress = progress(at: date)

        switch event.kind {
        case .walk:
            return CGSize(width: 0, height: -sin(progress * Double.pi) * 4)
        case .bump:
            return CGSize(width: sin(progress * Double.pi * 2) * 3, height: 0)
        case .turn, .reset:
            return .zero
        }
    }

    func isActive(at date: Date) -> Bool {
        progress(at: date) < 1
    }

    private func progress(at date: Date) -> Double {
        guard event.duration > 0 else { return 1 }
        return max(0, min(1, date.timeIntervalSince(start) / event.duration))
    }

    private func interpolatedPose(amount: Double) -> CameraPose {
        CameraPose(
            x: event.from.x + (event.to.x - event.from.x) * amount,
            y: event.from.y + (event.to.y - event.from.y) * amount,
            angle: event.from.angle + (event.to.angle - event.from.angle) * amount
        )
    }

    private func smoothstep(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }
}

private struct ProjectedEntity {
    let entity: Entity
    let distance: Double
    let screenX: CGFloat
    let spriteCenterY: CGFloat
    let spriteHeight: CGFloat
}

private struct ProjectedItem {
    let point: GridPoint
    let item: Item
    let distance: Double
    let screenX: CGFloat
    let spriteCenterY: CGFloat
    let spriteHeight: CGFloat
}

private struct ItemBillboard: View {
    let item: Item
    let spriteHeight: CGFloat

    var body: some View {
        SpriteAtlasImage(sprite: .item(named: item.name))
            .frame(width: spriteHeight, height: spriteHeight)
            .shadow(color: .black.opacity(0.85), radius: spriteHeight * 0.10, y: spriteHeight * 0.06)
    }
}

private func normalizedAngle(_ angle: Double) -> Double {
    var result = angle
    while result > Double.pi {
        result -= Double.pi * 2
    }
    while result < -Double.pi {
        result += Double.pi * 2
    }
    return result
}

private struct EntitySpriteBillboard: View {
    let entity: Entity
    let spriteHeight: CGFloat

    var body: some View {
        AnimatedEntitySprite(entityName: entity.name)
            .frame(width: spriteHeight, height: spriteHeight)
            .shadow(color: .black.opacity(0.95), radius: spriteHeight * 0.085, y: spriteHeight * 0.045)
            .shadow(color: entityGlow.opacity(0.42), radius: spriteHeight * 0.10)
    }

    private var entityGlow: Color {
        switch entity.name {
        case "Agent":
            .orange
        case "Hound":
            .red
        case "Skin-Stealer":
            .pink
        default:
            .yellow
        }
    }
}

private struct EntityNameplate: View {
    let entity: Entity
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            Text(entity.name)
                .font(.headline.weight(.heavy))
                .shadow(color: .black.opacity(0.8), radius: 4)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.black.opacity(0.52))
                Capsule()
                    .fill(.red)
                    .frame(width: 146 * scale * entity.healthFraction)
            }
            .frame(width: 146 * scale, height: 8 * scale)
        }
        .padding(.horizontal, 12 * scale)
        .padding(.vertical, 8 * scale)
        .background(.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 10 * scale, style: .continuous))
    }
}

private struct SeamOverlay: View {
    let theme: LevelTheme

    var body: some View {
        VStack(spacing: 12) {
            SpriteAtlasImage(sprite: .stairs)
                .frame(width: 108, height: 108)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            Text("Noclip Seam")
                .font(.title2.bold())
                .textCase(.uppercase)
                .tracking(2)
        }
        .foregroundStyle(theme.accent)
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(radius: 18)
    }
}

private struct DefeatOverlay: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("YOU DIED")
                .font(.system(size: 64, weight: .black, design: .serif))
                .foregroundStyle(.red)
                .shadow(color: .red.opacity(0.6), radius: 18)
                .tracking(6)
            Text("Start a new run from the Crawl menu.")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.78))
    }
}

private extension View {
    func cornerOverlay(_ alignment: Alignment) -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .allowsHitTesting(false)
    }
}

private struct CompassOverlay: View {
    let direction: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "location.north.line.fill")
                .font(.system(size: 18, weight: .bold))
            Text(direction)
                .font(.title3.bold().monospacedDigit())
        }
        .padding(10)
        .frame(width: 56, height: 56)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.30), lineWidth: 1)
        }
        .foregroundStyle(.white)
    }
}

private struct TargetLockOverlay: View {
    let entity: Entity
    let distance: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .font(.callout.bold())
                    .foregroundStyle(.red)
                Text("LOCK")
                    .font(.caption.bold())
                    .tracking(1.4)
                    .foregroundStyle(.red)
            }
            Text(entity.name)
                .font(.headline)
            HStack(spacing: 6) {
                Text("HP \(max(0, entity.hp)) / \(entity.maxHP)")
                    .font(.caption.monospacedDigit())
                Text("•")
                Text("\(distance) tile\(distance == 1 ? "" : "s")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.black.opacity(0.55))
                    .frame(height: 5)
                Capsule()
                    .fill(.red)
                    .frame(width: 140 * entity.healthFraction, height: 5)
            }
            .frame(width: 140)
        }
        .padding(11)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.red.opacity(0.60), lineWidth: 1)
        }
        .foregroundStyle(.white)
    }
}

private struct TargetLockEmptyOverlay: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .font(.callout.bold())
            Text("No target")
                .font(.caption.bold())
                .tracking(1.2)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.white.opacity(0.30), lineWidth: 1)
        }
        .foregroundStyle(.white.opacity(0.7))
    }
}

private struct FluorescentFlicker: View {
    let theme: LevelTheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let flicker = max(0, min(1, 0.85 + 0.15 * sin(t * 7.3) + 0.10 * sin(t * 23.1)))
            let buzz = (sin(t * 41) + 1) * 0.5
            let opacity = 0.06 + 0.05 * (1 - flicker) + 0.02 * buzz
            Rectangle()
                .fill(theme.fog.opacity(opacity))
                .blendMode(.plusLighter)
        }
    }
}
