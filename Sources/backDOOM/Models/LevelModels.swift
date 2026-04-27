import Foundation
import SwiftUI

struct GridPoint: Hashable, Codable, Identifiable {
    var x: Int
    var y: Int

    var id: String { "\(x):\(y)" }

    func moved(_ direction: Direction, steps: Int = 1) -> GridPoint {
        GridPoint(x: x + direction.delta.x * steps, y: y + direction.delta.y * steps)
    }
}

enum Direction: Int, CaseIterable, Codable {
    case north
    case east
    case south
    case west

    var delta: (x: Int, y: Int) {
        switch self {
        case .north: (0, -1)
        case .east: (1, 0)
        case .south: (0, 1)
        case .west: (-1, 0)
        }
    }

    var left: Direction {
        Direction(rawValue: (rawValue + 3) % 4) ?? .north
    }

    var right: Direction {
        Direction(rawValue: (rawValue + 1) % 4) ?? .north
    }

    var name: String {
        switch self {
        case .north: "North"
        case .east: "East"
        case .south: "South"
        case .west: "West"
        }
    }

    var radians: Double {
        switch self {
        case .east:
            0
        case .south:
            Double.pi / 2
        case .west:
            Double.pi
        case .north:
            -Double.pi / 2
        }
    }
}

struct CameraPose: Equatable {
    var x: Double
    var y: Double
    var angle: Double

    static func cell(_ point: GridPoint, facing direction: Direction) -> CameraPose {
        CameraPose(
            x: Double(point.x) + 0.5,
            y: Double(point.y) + 0.5,
            angle: direction.radians
        )
    }
}

enum CameraAnimationKind: Equatable {
    case walk
    case turn
    case bump
    case reset
}

struct CameraEvent: Identifiable, Equatable {
    let id = UUID()
    let kind: CameraAnimationKind
    let from: CameraPose
    let to: CameraPose
    let duration: TimeInterval
}

enum Tile: Codable {
    case wall
    case floor
    case stairs
}

struct LevelTheme: Identifiable, Equatable {
    let id: Int
    let name: String
    let accent: Color
    let wallBase: Color
    let wallShade: Color
    let floorBase: Color
    let fog: Color

    static let all: [LevelTheme] = [
        .init(id: 1, name: "Yellow Corridor", accent: .yellow,
              wallBase: Color(red: 0.83, green: 0.74, blue: 0.30),
              wallShade: Color(red: 0.36, green: 0.30, blue: 0.10),
              floorBase: Color(red: 0.58, green: 0.46, blue: 0.18),
              fog: Color(red: 0.96, green: 0.84, blue: 0.32)),
        .init(id: 2, name: "Wet Carpet", accent: .red,
              wallBase: Color(red: 0.46, green: 0.20, blue: 0.18),
              wallShade: Color(red: 0.16, green: 0.06, blue: 0.06),
              floorBase: Color(red: 0.30, green: 0.10, blue: 0.10),
              fog: Color(red: 0.62, green: 0.20, blue: 0.16)),
        .init(id: 3, name: "Office Maze", accent: .gray,
              wallBase: Color(red: 0.62, green: 0.60, blue: 0.55),
              wallShade: Color(red: 0.16, green: 0.16, blue: 0.16),
              floorBase: Color(red: 0.28, green: 0.27, blue: 0.25),
              fog: Color(red: 0.78, green: 0.75, blue: 0.70)),
        .init(id: 4, name: "Run For Your Life", accent: .orange,
              wallBase: Color(red: 0.55, green: 0.18, blue: 0.10),
              wallShade: Color(red: 0.18, green: 0.05, blue: 0.04),
              floorBase: Color(red: 0.30, green: 0.10, blue: 0.06),
              fog: Color(red: 1.00, green: 0.34, blue: 0.10)),
        .init(id: 5, name: "The End", accent: .red,
              wallBase: Color(red: 0.42, green: 0.10, blue: 0.14),
              wallShade: Color(red: 0.10, green: 0.02, blue: 0.04),
              floorBase: Color(red: 0.20, green: 0.04, blue: 0.06),
              fog: Color(red: 0.95, green: 0.18, blue: 0.18))
    ]

    static func theme(for level: Int) -> LevelTheme {
        all[(max(1, level) - 1) % all.count]
    }
}

struct Entity: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let glyph: String
    let maxHP: Int
    var hp: Int
    let attack: Int
    let xp: Int

    var healthFraction: Double {
        guard maxHP > 0 else { return 0 }
        return max(0, min(1, Double(hp) / Double(maxHP)))
    }
}

struct Item: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let symbol: String
    let sprite: Sprite
    let detail: String
    let quality: ItemQuality
    let kind: ItemKind

    var effectSummary: String {
        switch kind {
        case .potion(let healing):
            "Heals \(healing) HP"
        case .equipment(_, let attack, let armor):
            [attack > 0 ? "+\(attack) ATK" : nil, armor > 0 ? "+\(armor) ARM" : nil]
                .compactMap { $0 }
                .joined(separator: "  ")
        case .key:
            "Unlocks sealed level doors"
        }
    }

    var equipmentSlot: EquipmentSlot? {
        if case .equipment(let slot, _, _) = kind {
            return slot
        }
        return nil
    }
}

enum ItemKind: Equatable {
    case potion(healing: Int)
    case equipment(slot: EquipmentSlot, attack: Int, armor: Int)
    case key
}

enum ItemQuality: String, Equatable {
    case common
    case uncommon
    case rare
    case relic

    var title: String {
        switch self {
        case .common: "Common"
        case .uncommon: "Uncommon"
        case .rare: "Rare"
        case .relic: "Cursed"
        }
    }

    var tint: Color {
        switch self {
        case .common: .secondary
        case .uncommon: .green
        case .rare: .cyan
        case .relic: .red
        }
    }
}

enum EquipmentSlot: String, CaseIterable, Identifiable {
    case weapon
    case offhand
    case armor
    case light
    case charm
    case relic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weapon: "Weapon"
        case .offhand: "Offhand"
        case .armor: "Armor"
        case .light: "Light"
        case .charm: "Charm"
        case .relic: "Sigil"
        }
    }

    var emptySprite: Sprite {
        switch self {
        case .weapon: .knife
        case .offhand: .shield
        case .armor: .survivor
        case .light: .flashlight
        case .charm: .keycard
        case .relic: .hound
        }
    }
}

struct InventoryStack: Identifiable, Equatable {
    let id = UUID()
    var item: Item
    var quantity: Int
}

struct Player: Equatable {
    var name = "Wanderer"
    var level = 1
    var xp = 0
    var hp = 34
    var maxHP = 34
    var attack = 4
    var armor = 0
    var gold = 12
    var equipment = ItemCatalog.startingEquipment
    var inventory = ItemCatalog.startingInventory

    var nextLevelXP: Int { level * 24 }
    var healthFraction: Double { Double(hp) / Double(maxHP) }
    var equipmentAttack: Int {
        equipment.values.reduce(0) { total, item in
            if case .equipment(_, let attack, _) = item.kind {
                return total + attack
            }
            return total
        }
    }
    var equipmentArmor: Int {
        equipment.values.reduce(0) { total, item in
            if case .equipment(_, _, let armor) = item.kind {
                return total + armor
            }
            return total
        }
    }
    var totalAttack: Int { attack + equipmentAttack }
    var totalArmor: Int { armor + equipmentArmor }
    var potionCount: Int {
        inventory
            .filter { stack in
                if case .potion = stack.item.kind {
                    return true
                }
                return false
            }
            .reduce(0) { $0 + $1.quantity }
    }
}

enum ItemCatalog {
    static let combatKnife = Item(
        name: "Combat Knife",
        symbol: "scribble",
        sprite: .knife,
        detail: "A serrated blade. Quiet, close, dependable when the lights flicker.",
        quality: .common,
        kind: .equipment(slot: .weapon, attack: 3, armor: 0)
    )

    static let riotShield = Item(
        name: "Riot Shield",
        symbol: "shield",
        sprite: .shield,
        detail: "Polycarbonate slab scavenged from a guard post. Already cracked twice.",
        quality: .common,
        kind: .equipment(slot: .offhand, attack: 0, armor: 1)
    )

    static let tacticalVest = Item(
        name: "Tactical Vest",
        symbol: "armor",
        sprite: .survivor,
        detail: "Surplus plate carrier. The straps still smell of someone else's fear.",
        quality: .common,
        kind: .equipment(slot: .armor, attack: 0, armor: 2)
    )

    static let flashlight = Item(
        name: "Flashlight",
        symbol: "flashlight.on.fill",
        sprite: .flashlight,
        detail: "Cuts a narrow cone through the buzzing fluorescent dark.",
        quality: .uncommon,
        kind: .equipment(slot: .light, attack: 0, armor: 0)
    )

    static let levelKeycard = Item(
        name: "Level Keycard",
        symbol: "key",
        sprite: .keycard,
        detail: "A magnetic card stripped from a corpse. Opens one sealed door.",
        quality: .common,
        kind: .key
    )

    static func almondWater(healing: Int = 18) -> Item {
        Item(
            name: "Almond Water",
            symbol: "drop.fill",
            sprite: .almondWater,
            detail: "Bottled from the Backrooms. Tastes wrong. Heals anyway.",
            quality: healing > 20 ? .uncommon : .common,
            kind: .potion(healing: healing)
        )
    }

    static func plasmaKnife(power: Int) -> Item {
        Item(
            name: "Plasma Knife +\(power)",
            symbol: "bolt.fill",
            sprite: .knife,
            detail: "A blade humming with hellfire. The grip is uncomfortably warm.",
            quality: power >= 3 ? .relic : .rare,
            kind: .equipment(slot: .weapon, attack: power + 3, armor: 0)
        )
    }

    static var startingEquipment: [EquipmentSlot: Item] {
        [
            .weapon: combatKnife,
            .offhand: riotShield,
            .armor: tacticalVest,
            .light: flashlight
        ]
    }

    static var startingInventory: [InventoryStack] {
        [
            InventoryStack(item: almondWater(), quantity: 2),
            InventoryStack(item: levelKeycard, quantity: 1)
        ]
    }
}

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let date = Date()
}

struct LevelSnapshot {
    let tiles: [[Tile]]
    let width: Int
    let height: Int
    let level: Int
    let theme: LevelTheme
    let stairs: GridPoint
}
