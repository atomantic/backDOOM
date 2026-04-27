import SwiftUI

struct StatusSidebarView: View {
    @Environment(GameStore.self) private var game

    var body: some View {
        VStack(spacing: 12) {
            PlayerCard()

            InventoryCard()
                .frame(maxHeight: .infinity)
        }
        .padding(12)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct PlayerCard: View {
    @Environment(GameStore.self) private var game

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Player")
                    .font(.title3.bold())
                Spacer()
                CircleMenuButton()
            }

            HStack {
                Text("Level \(game.player.level)")
                Spacer()
                Text("\(game.player.xp) / \(game.player.nextLevelXP) XP")
            }
            .font(.callout)

            ProgressView(value: Double(game.player.xp) / Double(game.player.nextLevelXP))
                .tint(.purple)

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 11) {
                    InspectorMetric(icon: "heart.fill", color: .red, title: "HP", value: "\(game.player.hp) / \(game.player.maxHP)")
                    InspectorMetric(icon: "bolt.fill", color: .orange, title: "ATK", value: "\(game.player.totalAttack)")
                    InspectorMetric(icon: "shield.fill", color: .blue, title: "ARM", value: "\(game.player.totalArmor)")
                    InspectorMetric(icon: "cross.vial.fill", color: .green, title: "POT", value: "\(game.player.potionCount)")
                    InspectorMetric(icon: "circle.hexagongrid.fill", color: .yellow, title: "GLD", value: "\(game.player.gold)")
                }

                EquipmentGrid()
                    .frame(width: 154)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct InventoryCard: View {
    @Environment(GameStore.self) private var game

    private var inventoryCount: Int {
        game.player.inventory.reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Inventory")
                    .font(.title3.bold())
                Spacer()
                Text("\(inventoryCount) / 24")
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(game.player.inventory) { stack in
                    HoverItemSlot(item: stack.item, count: stack.quantity > 1 ? "\(stack.quantity)" : nil)
                }

                ForEach(0..<emptySlotCount, id: \.self) { _ in
                    EmptyInventorySlot()
                }
            }

            Spacer(minLength: 18)

            Divider().opacity(0.4)

            CurrencyView(sprite: .gold, value: "\(game.player.gold)")
        }
        .padding(18)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }

    private var emptySlotCount: Int {
        max(0, min(20, 20 - game.player.inventory.count))
    }
}

private struct InspectorMetric: View {
    let icon: String
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 18)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .font(.callout)
    }
}

private struct EquipmentGrid: View {
    @Environment(GameStore.self) private var game

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
            ForEach(EquipmentSlot.allCases) { slot in
                HoverItemSlot(
                    item: game.player.equipment[slot],
                    count: nil,
                    placeholder: slot.emptySprite,
                    accessibilityLabel: slot.title
                )
            }
        }
    }
}

private struct HoverItemSlot: View {
    let item: Item?
    let count: String?
    var placeholder: Sprite?
    var accessibilityLabel: String?

    @State private var isHovered = false

    var body: some View {
        let accent = item?.quality.tint ?? .secondary

        ZStack(alignment: .bottomTrailing) {
            Group {
                if let item {
                    SpriteAtlasImage(sprite: item.sprite)
                        .padding(8)
                } else if let placeholder {
                    SpriteAtlasImage(sprite: placeholder)
                        .padding(13)
                        .opacity(0.22)
                }
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(.black.opacity(item == nil ? 0.14 : 0.22), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                if item != nil {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(itemGlow(accent: accent, highlighted: isHovered))
                        .blendMode(.plusLighter)
                        .opacity(isHovered ? 0.9 : 0.35)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isHovered && item != nil ? accent.opacity(0.72) : .white.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: item == nil ? .clear : accent.opacity(isHovered ? 0.32 : 0), radius: 16, y: 4)

            if let count {
                Text(count)
                    .font(.caption.bold())
                    .padding(4)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(4)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.16)) {
                isHovered = hovering
            }
        }
        .popover(isPresented: Binding(
            get: { isHovered && item != nil },
            set: { presented in
                if !presented {
                    isHovered = false
                }
            }
        ), attachmentAnchor: .rect(.bounds), arrowEdge: .leading) {
            if let item {
                ItemHoverCard(item: item)
                    .presentationBackground(.clear)
            }
        }
        .zIndex(isHovered ? 10 : 0)
        .help(item?.name ?? accessibilityLabel ?? "Empty slot")
    }

    private func itemGlow(accent: Color, highlighted: Bool) -> RadialGradient {
        RadialGradient(
            colors: [
                accent.opacity(highlighted ? 0.42 : 0.24),
                .white.opacity(highlighted ? 0.10 : 0.04),
                accent.opacity(0.00)
            ],
            center: .topLeading,
            startRadius: 1,
            endRadius: 72
        )
    }
}

private struct ItemHoverCard: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                SpriteAtlasImage(sprite: item.sprite)
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(itemSubtitle)
                        .font(.caption)
                        .foregroundStyle(item.quality.tint)
                }
            }

            Text(item.effectSummary)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)

            Text(item.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 236, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    LinearGradient(
                        colors: [
                            item.quality.tint.opacity(0.28),
                            .white.opacity(0.08),
                            item.quality.tint.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .blendMode(.plusLighter)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(item.quality.tint.opacity(0.38), lineWidth: 1)
        }
        .shadow(color: item.quality.tint.opacity(0.22), radius: 18, y: 4)
        .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
        .allowsHitTesting(false)
    }

    private var itemSubtitle: String {
        if let slot = item.equipmentSlot {
            return "\(item.quality.title) \(slot.title)"
        }
        return item.quality.title
    }
}

private struct EmptyInventorySlot: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(.black.opacity(0.14))
            .frame(height: 60)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
    }
}

private struct CurrencyView: View {
    let sprite: Sprite
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            SpriteAtlasImage(sprite: sprite)
                .frame(width: 22, height: 22)
                .clipShape(Circle())
            Text(value)
                .font(.callout.monospacedDigit())
        }
    }
}

private struct CircleMenuButton: View {
    @Environment(GameStore.self) private var game
    @Environment(UIState.self) private var ui

    var body: some View {
        Menu {
            Button {
                game.usePotion()
            } label: {
                Label("Drink Potion", systemImage: "cross.vial.fill")
            }
            .disabled(game.player.potionCount == 0 || game.player.hp >= game.player.maxHP)

            Button {
                ui.activeSheet = .inventory
            } label: {
                Label("Open Inventory", systemImage: "briefcase.fill")
            }

            Divider()

            Button(role: .destructive) {
                game.newRun()
            } label: {
                Label("End Run & Restart", systemImage: "arrow.counterclockwise")
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.1), in: Circle())
                .contentShape(Circle())
        }
        .fixedSize()
        .help("Player menu")
    }
}
