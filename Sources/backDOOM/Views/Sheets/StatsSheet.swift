import SwiftUI

struct StatsSheet: View {
    @Environment(GameStore.self) private var game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Stats")
                    .font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(18)

            Divider().opacity(0.3)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    StatsBlock(title: "Run") {
                        StatsRow(label: "Turn", value: "\(game.turn)")
                        StatsRow(label: "Current level", value: "\(game.level.level) — \(game.level.theme.name)")
                        StatsRow(label: "Levels reached this run", value: "\(game.runStats.levelReached)")
                        StatsRow(label: "Best level ever", value: "\(game.bestLevelEver)")
                        StatsRow(label: "Items picked up", value: "\(game.runStats.itemsPicked)")
                        StatsRow(label: "Gold earned", value: "\(game.runStats.totalGoldEarned)")
                    }

                    StatsBlock(title: "Player") {
                        StatsRow(label: "Rank", value: "\(game.player.level)")
                        StatsRow(label: "HP", value: "\(game.player.hp) / \(game.player.maxHP)")
                        StatsRow(label: "ATK", value: "\(game.player.totalAttack) (base \(game.player.attack) + gear \(game.player.equipmentAttack))")
                        StatsRow(label: "ARM", value: "\(game.player.totalArmor) (base \(game.player.armor) + gear \(game.player.equipmentArmor))")
                        StatsRow(label: "Gold", value: "\(game.player.gold)")
                        StatsRow(label: "Potions", value: "\(game.player.potionCount)")
                    }

                    StatsBlock(title: "Kills (\(game.runStats.totalKills) total)") {
                        if game.runStats.kills.isEmpty {
                            Text("Nothing slain yet.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(killEntries, id: \.name) { entry in
                                StatsRow(label: entry.name, value: "\(entry.count)")
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
        .frame(minWidth: 460, minHeight: 420)
    }

    private var killEntries: [(name: String, count: Int)] {
        game.runStats.kills
            .map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}

private struct StatsBlock<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            VStack(spacing: 0) {
                content
            }
            .padding(12)
            .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            }
        }
    }
}

private struct StatsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .font(.callout)
        .padding(.vertical, 4)
    }
}
