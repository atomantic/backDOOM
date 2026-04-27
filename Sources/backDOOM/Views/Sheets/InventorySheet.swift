import SwiftUI

struct InventorySheet: View {
    @Environment(GameStore.self) private var game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Inventory")
                    .font(.title2.bold())
                Spacer()
                Text("\(totalCount) / 24")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .padding(.leading, 8)
            }
            .padding(18)

            Divider().opacity(0.3)

            if game.player.inventory.isEmpty {
                Spacer()
                Text("Your pockets are empty.")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(game.player.inventory.enumerated()), id: \.element.id) { index, stack in
                            InventoryRow(
                                stack: stack,
                                canUse: canUse(stack),
                                onUse: { game.usePotion(at: index) },
                                onDrop: { game.dropInventoryItem(at: index) }
                            )
                        }
                    }
                    .padding(18)
                }
            }
        }
        .frame(minWidth: 460, minHeight: 420)
    }

    private var totalCount: Int {
        game.player.inventory.reduce(0) { $0 + $1.quantity }
    }

    private func canUse(_ stack: InventoryStack) -> Bool {
        if case .potion = stack.item.kind {
            return game.player.hp < game.player.maxHP && stack.quantity > 0
        }
        return false
    }
}

private struct InventoryRow: View {
    let stack: InventoryStack
    let canUse: Bool
    let onUse: () -> Void
    let onDrop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SpriteAtlasImage(sprite: stack.item.sprite)
                .frame(width: 48, height: 48)
                .background(.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(stack.item.quality.tint.opacity(0.5), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(stack.item.name)
                        .font(.callout.bold())
                    if stack.quantity > 1 {
                        Text("×\(stack.quantity)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(stack.item.effectSummary)
                    .font(.caption)
                    .foregroundStyle(stack.item.quality.tint)
                Text(stack.item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(spacing: 6) {
                if isPotion {
                    Button("Use") { onUse() }
                        .disabled(!canUse)
                }
                Button("Drop") { onDrop() }
                    .foregroundStyle(.red)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var isPotion: Bool {
        if case .potion = stack.item.kind { return true }
        return false
    }
}
