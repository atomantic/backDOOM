import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class GameStore {
    private(set) var level: LevelSnapshot
    private(set) var player = Player()
    private(set) var position = GridPoint(x: 1, y: 1)
    private(set) var direction: Direction = .east
    private(set) var entities: [GridPoint: Entity] = [:]
    private(set) var items: [GridPoint: Item] = [:]
    private(set) var log: [LogEntry] = []
    private(set) var runState: RunState = .playing
    private(set) var turn = 1
    private(set) var cameraEvent: CameraEvent?
    private(set) var isInputLocked = false
    private(set) var seenByLevel: [Int: Set<GridPoint>] = [:]
    private(set) var runStats = RunStats()
    private(set) var bestLevelEver: Int = 1

    @ObservationIgnored
    private var hasStarted = false
    @ObservationIgnored
    private var rng = SystemRandomNumberGenerator()
    @ObservationIgnored
    private var inputUnlockTask: Task<Void, Never>?
    @ObservationIgnored
    private var cachedVisibleKey: VisibilityKey?
    @ObservationIgnored
    private var cachedVisible: Set<GridPoint> = []
    @ObservationIgnored
    private var levelFloorCounts: [Int: Int] = [:]
    @ObservationIgnored
    private var entitiesVersion: Int = 0
    @ObservationIgnored
    private var cachedVisibleEntityKey: VisibleEntityKey?
    @ObservationIgnored
    private var cachedVisibleEntity: (point: GridPoint, entity: Entity, distance: Int)?

    private static let visibilityRadius: Double = 7.5
    private static let bestLevelDefaultsKey = "backdoom.bestLevelEver"

    init() {
        level = LevelFactory.make(level: 1)
        bestLevelEver = max(1, UserDefaults.standard.integer(forKey: Self.bestLevelDefaultsKey))
        populateLevel()
        markSeen()
    }

    var seenCells: Set<GridPoint> {
        seenByLevel[level.level] ?? []
    }

    var visibleCells: Set<GridPoint> {
        let key = VisibilityKey(level: level.level, position: position)
        if cachedVisibleKey == key {
            return cachedVisible
        }
        let v = computeVisibleCells()
        cachedVisible = v
        cachedVisibleKey = key
        return v
    }

    var visibleEntity: (point: GridPoint, entity: Entity, distance: Int)? {
        let key = VisibleEntityKey(position: position, direction: direction, level: level.level, version: entitiesVersion)
        if cachedVisibleEntityKey == key {
            return cachedVisibleEntity
        }
        let result = computeVisibleEntity()
        cachedVisibleEntity = result
        cachedVisibleEntityKey = key
        return result
    }

    private func computeVisibleEntity() -> (point: GridPoint, entity: Entity, distance: Int)? {
        for distance in 1...4 {
            let point = position.moved(direction, steps: distance)
            if let entity = entities[point] {
                return (point, entity, distance)
            }
            if tile(at: point) == .wall {
                return nil
            }
        }
        return nil
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        addLog("You wake in the \(level.theme.name). The fluorescents buzz.")
        Telemetry.generation.notice("Started run level=\(self.level.level, privacy: .public) theme=\(self.level.theme.name, privacy: .public)")
    }

    func newRun() {
        player = Player()
        position = GridPoint(x: 1, y: 1)
        direction = .east
        level = LevelFactory.make(level: 1)
        entities.removeAll()
        items.removeAll()
        log.removeAll()
        runState = .playing
        turn = 1
        seenByLevel.removeAll()
        runStats = RunStats()
        levelFloorCounts.removeAll()
        populateLevel()
        markSeen()
        publishCameraEvent(.init(
            kind: .reset,
            from: CameraPose.cell(position, facing: direction),
            to: CameraPose.cell(position, facing: direction),
            duration: 0
        ))
        addLog("The level reshapes itself around you.")
        Telemetry.generation.notice("New run generated")
    }

    func turnLeft() {
        guard canAcceptAction else { return }
        let from = CameraPose.cell(position, facing: direction)
        let nextDirection = direction.left
        let event = CameraEvent(
            kind: .turn,
            from: from,
            to: CameraPose(x: from.x, y: from.y, angle: from.angle - Double.pi / 2),
            duration: 0.22
        )
        direction = nextDirection
        addLog("You pivot \(direction.name.lowercased()).")
        publishCameraEvent(event)
        advanceTurn(reason: "turn_left")
        Telemetry.movement.notice("Turned left nowFacing=\(self.direction.name, privacy: .public)")
    }

    func turnRight() {
        guard canAcceptAction else { return }
        let from = CameraPose.cell(position, facing: direction)
        let nextDirection = direction.right
        let event = CameraEvent(
            kind: .turn,
            from: from,
            to: CameraPose(x: from.x, y: from.y, angle: from.angle + Double.pi / 2),
            duration: 0.22
        )
        direction = nextDirection
        addLog("You pivot \(direction.name.lowercased()).")
        publishCameraEvent(event)
        advanceTurn(reason: "turn_right")
        Telemetry.movement.notice("Turned right nowFacing=\(self.direction.name, privacy: .public)")
    }

    func moveForward() {
        move(to: position.moved(direction), verb: "forward")
    }

    func moveBackward() {
        move(to: position.moved(direction, steps: -1), verb: "back")
    }

    func attack() {
        guard canAcceptAction else { return }
        guard let target = visibleEntity, target.distance == 1 else {
            addLog("Your strike cuts only stale air.")
            advanceTurn(reason: "attack_miss")
            Telemetry.combat.notice("Attack missed noAdjacentEntity")
            return
        }

        strikeEntity(at: target.point)
        if runState == .playing {
            entitiesTakeTurn()
        }
        advanceTurn(reason: "attack")
    }

    func wait() {
        guard canAcceptAction else { return }
        addLog("You hold position. The walls breathe.")
        entitiesTakeTurn()
        advanceTurn(reason: "wait")
        Telemetry.movement.notice("Waited turn=\(self.turn, privacy: .public)")
    }

    func examineAhead() {
        let ahead = position.moved(direction)
        if let entity = entities[ahead] {
            addLog("Ahead: \(entity.name) — HP \(max(0, entity.hp))/\(entity.maxHP), ATK \(entity.attack).")
        } else if let item = items[ahead] {
            addLog("Ahead: \(item.name). \(item.effectSummary).")
        } else {
            switch tile(at: ahead) {
            case .wall:
                addLog("Ahead: drywall. Solid, water-stained.")
            case .stairs:
                addLog("Ahead: a noclip seam — step onto it to descend.")
            case .floor:
                addLog("Ahead: empty \(level.theme.name.lowercased()) floor.")
            }
        }
        Telemetry.movement.notice("Examined ahead facing=\(self.direction.name, privacy: .public)")
    }

    var compassDirection: String {
        switch direction {
        case .north: "N"
        case .east: "E"
        case .south: "S"
        case .west: "W"
        }
    }

    var questProgress: [QuestProgress] {
        let q1: QuestProgress = (level.level >= 2 || bestLevelEver >= 2) ? .completed : .notStarted
        let houndKills = runStats.kills["Hound", default: 0]
        let q2: QuestProgress = houndKills >= 3
            ? .completed
            : .inProgress(current: houndKills, target: 3)
        let q3: QuestProgress
        if let totalFloors = levelFloorCounts[3], totalFloors > 0 {
            let seenCount = (seenByLevel[3] ?? []).count
            if seenCount >= totalFloors {
                q3 = .completed
            } else {
                q3 = .inProgress(current: seenCount, target: totalFloors)
            }
        } else {
            q3 = .notStarted
        }
        return [q1, q2, q3]
    }

    func usePotion() {
        guard let index = player.inventory.firstIndex(where: { stack in
            if case .potion = stack.item.kind { return stack.quantity > 0 }
            return false
        }) else { return }
        usePotion(at: index)
    }

    func usePotion(at index: Int) {
        guard canAcceptAction, player.hp < player.maxHP else { return }
        guard player.inventory.indices.contains(index) else { return }
        guard case .potion(let healing) = player.inventory[index].item.kind else { return }
        guard player.inventory[index].quantity > 0 else { return }

        let itemName = player.inventory[index].item.name
        player.inventory[index].quantity -= 1
        if player.inventory[index].quantity <= 0 {
            player.inventory.remove(at: index)
        }

        let healed = min(player.maxHP - player.hp, healing + player.level * 2)
        player.hp += healed
        addLog("You drink \(itemName) and recover \(healed) HP.")
        advanceTurn(reason: "potion")
        Telemetry.inventory.notice("Potion used name=\(itemName, privacy: .public) healed=\(healed, privacy: .public) remaining=\(self.player.potionCount, privacy: .public)")
    }

    func resetBestLevel() {
        bestLevelEver = 1
        UserDefaults.standard.set(bestLevelEver, forKey: Self.bestLevelDefaultsKey)
        addLog("Best-level record cleared.")
    }

    func dropInventoryItem(at index: Int) {
        guard player.inventory.indices.contains(index) else { return }
        let name = player.inventory[index].item.name
        player.inventory[index].quantity -= 1
        if player.inventory[index].quantity <= 0 {
            player.inventory.remove(at: index)
        }
        addLog("You drop \(name).")
        Telemetry.inventory.notice("Dropped item=\(name, privacy: .public) remaining=\(self.player.inventory.count, privacy: .public)")
    }

    func takeStairsIfAvailable() {
        guard canAcceptAction else { return }
        guard position == level.stairs else {
            addLog("There is no seam here.")
            return
        }
        let nextLevel = level.level + 1
        level = LevelFactory.make(level: nextLevel)
        position = GridPoint(x: 1, y: 1)
        direction = .east
        entities.removeAll()
        items.removeAll()
        populateLevel()
        markSeen()
        runStats.levelReached = max(runStats.levelReached, nextLevel)
        if nextLevel > bestLevelEver {
            bestLevelEver = nextLevel
            UserDefaults.standard.set(bestLevelEver, forKey: Self.bestLevelDefaultsKey)
        }
        addLog("You drop into Level \(nextLevel): \(level.theme.name).")
        publishCameraEvent(.init(
            kind: .reset,
            from: CameraPose.cell(position, facing: direction),
            to: CameraPose.cell(position, facing: direction),
            duration: 0
        ))
        advanceTurn(reason: "stairs")
        Telemetry.generation.notice("Advanced level=\(nextLevel, privacy: .public) theme=\(self.level.theme.name, privacy: .public)")
    }

    func tile(at point: GridPoint) -> Tile {
        guard point.y >= 0, point.y < level.height, point.x >= 0, point.x < level.width else {
            return .wall
        }
        return level.tiles[point.y][point.x]
    }

    func isWalkable(_ point: GridPoint) -> Bool {
        switch tile(at: point) {
        case .floor, .stairs:
            true
        case .wall:
            false
        }
    }

    private func move(to point: GridPoint, verb: String) {
        guard canAcceptAction else { return }
        let fromPose = CameraPose.cell(position, facing: direction)

        if entities[point] != nil {
            addLog("An entity blocks your path.")
            strikeEntity(at: point)
            if runState == .playing {
                entitiesTakeTurn()
            }
            publishCameraEvent(bumpEvent(from: fromPose))
            advanceTurn(reason: "bump_entity")
            return
        }

        guard isWalkable(point) else {
            addLog("Drywall blocks the way.")
            publishCameraEvent(bumpEvent(from: fromPose))
            advanceTurn(reason: "bump_wall")
            Telemetry.movement.notice("Blocked movement from=\(self.position.id, privacy: .public) attempted=\(point.id, privacy: .public)")
            return
        }

        position = point
        markSeen()
        publishCameraEvent(.init(
            kind: .walk,
            from: fromPose,
            to: CameraPose.cell(point, facing: direction),
            duration: 0.24
        ))
        Telemetry.movement.notice("Moved \(verb, privacy: .public) to=\(point.id, privacy: .public) level=\(self.level.level, privacy: .public)")

        if let item = items.removeValue(forKey: point) {
            pickUp(item)
        } else if tile(at: point) == .stairs {
            addLog("A noclip seam pulses underfoot.")
        } else {
            addLog("You step \(verb).")
        }

        entitiesTakeTurn()
        advanceTurn(reason: "move_\(verb)")
    }

    private func advanceTurn(reason: String) {
        turn += 1
        Telemetry.movement.notice("Advanced turn=\(self.turn, privacy: .public) reason=\(reason, privacy: .public)")
    }

    private var canAcceptAction: Bool {
        runState == .playing && !isInputLocked
    }

    private func bumpEvent(from pose: CameraPose) -> CameraEvent {
        CameraEvent(
            kind: .bump,
            from: pose,
            to: CameraPose(
                x: pose.x + cos(pose.angle) * 0.16,
                y: pose.y + sin(pose.angle) * 0.16,
                angle: pose.angle
            ),
            duration: 0.16
        )
    }

    private func publishCameraEvent(_ event: CameraEvent) {
        cameraEvent = event
        inputUnlockTask?.cancel()

        guard event.duration > 0 else {
            isInputLocked = false
            return
        }

        isInputLocked = true
        inputUnlockTask = Task { [duration = event.duration] in
            let nanoseconds = UInt64(duration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            await MainActor.run {
                self.isInputLocked = false
            }
        }
    }

    private func strikeEntity(at point: GridPoint) {
        guard var entity = entities[point] else { return }
        let damage = Int.random(in: max(1, player.totalAttack - 2)...player.totalAttack + player.level + 2, using: &rng)
        entity.hp -= damage
        addLog("You hit the \(entity.name) for \(damage).")
        Telemetry.combat.notice("Player hit entity=\(entity.name, privacy: .public) damage=\(damage, privacy: .public) remainingHP=\(max(0, entity.hp), privacy: .public)")

        if entity.hp <= 0 {
            entities.removeValue(forKey: point)
            let goldEarned = Int.random(in: 2...8, using: &rng) + level.level
            player.xp += entity.xp
            player.gold += goldEarned
            runStats.kills[entity.name, default: 0] += 1
            runStats.totalGoldEarned += goldEarned
            addLog("The \(entity.name) collapses. +\(entity.xp) XP.")
            maybeLevelUp()
        } else {
            entities[point] = entity
        }
        entitiesVersion &+= 1
    }

    private func entitiesTakeTurn() {
        guard runState == .playing else { return }
        var totalDamage = 0

        for (point, entity) in entities {
            let distance = abs(point.x - position.x) + abs(point.y - position.y)
            guard distance == 1 else { continue }
            let rawDamage = Int.random(in: max(1, entity.attack - 2)...entity.attack + 2, using: &rng)
            totalDamage += max(1, rawDamage - player.totalArmor)
        }

        guard totalDamage > 0 else { return }
        player.hp -= totalDamage
        addLog("Teeth and claws tear at you for \(totalDamage).")
        Telemetry.combat.notice("Entities attacked totalDamage=\(totalDamage, privacy: .public) playerHP=\(max(0, self.player.hp), privacy: .public)")

        if player.hp <= 0 {
            player.hp = 0
            runState = .defeated
            addLog("You collapse on the wet carpet. Start a new run.")
            Telemetry.combat.notice("Player defeated level=\(self.level.level, privacy: .public)")
        }
    }

    private func maybeLevelUp() {
        while player.xp >= player.nextLevelXP {
            player.xp -= player.nextLevelXP
            player.level += 1
            player.maxHP += 8
            player.hp = player.maxHP
            player.attack += 2
            if player.level.isMultiple(of: 2) {
                player.armor += 1
            }
            addLog("Hardened. You are now rank \(player.level).")
            Telemetry.combat.notice("Player leveled level=\(self.player.level, privacy: .public) maxHP=\(self.player.maxHP, privacy: .public)")
        }
    }

    private func pickUp(_ item: Item) {
        switch item.kind {
        case .potion, .equipment, .key:
            addInventoryItem(item)
        }
        runStats.itemsPicked += 1
        addLog("You scavenge \(item.name).")
        Telemetry.inventory.notice("Picked item=\(item.name, privacy: .public) kind=\(item.symbol, privacy: .public)")
    }

    private func addInventoryItem(_ item: Item) {
        if let index = player.inventory.firstIndex(where: { stack in
            stack.item.name == item.name && stack.item.effectSummary == item.effectSummary
        }) {
            player.inventory[index].quantity += 1
        } else {
            player.inventory.append(InventoryStack(item: item, quantity: 1))
        }
    }

    private func populateLevel() {
        let allFloors = LevelFactory.floorPoints(in: level)
        levelFloorCounts[level.level] = allFloors.count
        let floors = allFloors.filter { $0 != position && $0 != level.stairs }
        let entityCount = min(12, 5 + level.level * 2)
        let itemCount = min(7, 3 + level.level)

        for point in floors.shuffled().prefix(entityCount) {
            entities[point] = EntityFactory.make(level: level.level)
        }
        entitiesVersion &+= 1

        let freePoints = floors.filter { entities[$0] == nil }.shuffled()
        for point in freePoints.prefix(itemCount) {
            items[point] = ItemFactory.make(level: level.level)
        }

        Telemetry.generation.notice("Populated level=\(self.level.level, privacy: .public) entities=\(self.entities.count, privacy: .public) items=\(self.items.count, privacy: .public)")
    }

    private func addLog(_ text: String) {
        log.insert(LogEntry(text: text), at: 0)
        if log.count > 10 {
            log.removeLast(log.count - 10)
        }
    }

    private func markSeen() {
        let v = computeVisibleCells()
        cachedVisible = v
        cachedVisibleKey = VisibilityKey(level: level.level, position: position)
        var s = seenByLevel[level.level] ?? []
        s.formUnion(v)
        seenByLevel[level.level] = s
    }

    private func computeVisibleCells() -> Set<GridPoint> {
        var result: Set<GridPoint> = [position]
        let radius = Self.visibilityRadius
        let radiusSquared = radius * radius
        let originX = Double(position.x) + 0.5
        let originY = Double(position.y) + 0.5
        let span = Int(radius) + 1
        let yStart = max(0, position.y - span)
        let yEnd = min(level.height, position.y + span + 1)
        let xStart = max(0, position.x - span)
        let xEnd = min(level.width, position.x + span + 1)

        for y in yStart..<yEnd {
            for x in xStart..<xEnd {
                let dx = Double(x) + 0.5 - originX
                let dy = Double(y) + 0.5 - originY
                if dx * dx + dy * dy > radiusSquared { continue }
                let cell = GridPoint(x: x, y: y)
                if hasLineOfSight(to: cell) {
                    result.insert(cell)
                }
            }
        }
        return result
    }

    private func hasLineOfSight(to cell: GridPoint) -> Bool {
        if cell == position { return true }
        let originX = Double(position.x) + 0.5
        let originY = Double(position.y) + 0.5
        let targetX = Double(cell.x) + 0.5
        let targetY = Double(cell.y) + 0.5
        let dx = targetX - originX
        let dy = targetY - originY
        let distance = hypot(dx, dy)
        let steps = max(2, Int(distance * 12))

        for i in 1..<steps {
            let t = Double(i) / Double(steps)
            let sx = Int((originX + dx * t).rounded(.down))
            let sy = Int((originY + dy * t).rounded(.down))
            let sample = GridPoint(x: sx, y: sy)
            if sample == cell { return true }
            if tile(at: sample) == .wall { return false }
        }
        return true
    }
}

private struct VisibilityKey: Equatable {
    let level: Int
    let position: GridPoint
}

private struct VisibleEntityKey: Equatable {
    let position: GridPoint
    let direction: Direction
    let level: Int
    let version: Int
}

enum RunState: Equatable {
    case playing
    case defeated
}

struct RunStats: Equatable {
    var kills: [String: Int] = [:]
    var itemsPicked: Int = 0
    var totalGoldEarned: Int = 0
    var levelReached: Int = 1

    var totalKills: Int {
        kills.values.reduce(0, +)
    }
}

enum QuestProgress: Equatable {
    case notStarted
    case inProgress(current: Int, target: Int)
    case completed
}

enum LevelFactory {
    static func make(level: Int) -> LevelSnapshot {
        let size = 17 + min(10, level / 2) * 2
        let width = size | 1
        let height = size | 1
        var tiles = Array(repeating: Array(repeating: Tile.wall, count: width), count: height)
        var rng = SystemRandomNumberGenerator()

        func carve(_ point: GridPoint) {
            tiles[point.y][point.x] = .floor
            let directions = Direction.allCases.shuffled()
            for direction in directions {
                let between = point.moved(direction)
                let next = point.moved(direction, steps: 2)
                guard next.x > 0, next.y > 0, next.x < width - 1, next.y < height - 1 else { continue }
                guard tiles[next.y][next.x] == .wall else { continue }
                tiles[between.y][between.x] = .floor
                carve(next)
            }
        }

        carve(GridPoint(x: 1, y: 1))

        for _ in 0..<(width * height / 18) {
            let x = Int.random(in: 1..<(width - 1), using: &rng)
            let y = Int.random(in: 1..<(height - 1), using: &rng)
            if tiles[y][x] == .wall {
                tiles[y][x] = .floor
            }
        }

        let floorPoints = tiles.enumerated().flatMap { y, row in
            row.enumerated().compactMap { x, tile in
                if case .floor = tile {
                    return GridPoint(x: x, y: y)
                }
                return nil
            }
        }

        let stairs = floorPoints.max { lhs, rhs in
            (lhs.x + lhs.y) < (rhs.x + rhs.y)
        } ?? GridPoint(x: width - 2, y: height - 2)
        tiles[stairs.y][stairs.x] = .stairs

        return LevelSnapshot(
            tiles: tiles,
            width: width,
            height: height,
            level: level,
            theme: LevelTheme.theme(for: level),
            stairs: stairs
        )
    }

    static func floorPoints(in level: LevelSnapshot) -> [GridPoint] {
        level.tiles.enumerated().flatMap { y, row in
            row.enumerated().compactMap { x, tile in
                switch tile {
                case .floor, .stairs:
                    return GridPoint(x: x, y: y)
                case .wall:
                    return nil
                }
            }
        }
    }
}

enum EntityFactory {
    static func make(level: Int) -> Entity {
        let options = [
            ("Smiler", "face.smiling.inverse", 12 + level * 2, 3 + level, 7 + level),
            ("Skin-Stealer", "person.fill.questionmark", 18 + level * 3, 4 + level, 10 + level * 2),
            ("Agent", "flame.fill", 14 + level * 3, 5 + level, 11 + level * 2),
            ("Hound", "pawprint.fill", 22 + level * 4, 6 + level, 14 + level * 3)
        ]
        let picked = options.randomElement() ?? options[0]
        return Entity(name: picked.0, glyph: picked.1, maxHP: picked.2, hp: picked.2, attack: picked.3, xp: picked.4)
    }
}

enum ItemFactory {
    static func make(level: Int) -> Item {
        if Int.random(in: 0...3) == 0 {
            return ItemCatalog.plasmaKnife(power: max(1, level / 2))
        }
        return ItemCatalog.almondWater(healing: 18 + level * 2)
    }
}
