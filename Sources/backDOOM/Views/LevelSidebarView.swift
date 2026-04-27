import SwiftUI

struct LevelSidebarView: View {
    @Environment(GameStore.self) private var game
    @Environment(UIState.self) private var ui

    private let levels = [
        ("Yellow Corridor", "Level 1", Color.yellow),
        ("Wet Carpet", "Level 2", Color.gray),
        ("Office Maze", "Level 3", Color.gray),
        ("Run For Your Life", "Level 4", Color.gray),
        ("The End", "Level 5", Color.gray)
    ]

    private let quests: [(title: String, subtitle: String, color: Color)] = [
        ("Find the Seam", "Descend through the first noclip seam.", .yellow),
        ("Outlast the Hounds", "Put down 3 Hounds before they put down you.", .red),
        ("Map the Maze", "Walk every aisle of the Office Maze.", .gray)
    ]

    var body: some View {
        @Bindable var ui = ui

        VStack(spacing: 14) {
            HStack(spacing: 0) {
                SidebarTopButton(icon: "map.fill", tab: .map)
                SidebarTopButton(icon: "list.bullet", tab: .levels)
                SidebarTopButton(icon: "flag.fill", tab: .quests)
            }

            ScrollView {
                VStack(spacing: 14) {
                    switch ui.sidebarTab {
                    case .map:
                        MiniMapCard()
                    case .levels:
                        SidebarPanel(title: "Levels") {
                            VStack(spacing: 0) {
                                ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                                    LevelRow(
                                        title: level.0,
                                        subtitle: level.1,
                                        selected: index == min(4, game.level.level - 1),
                                        marker: level.2,
                                        sprite: levelSprite(index)
                                    )
                                }
                            }
                        }
                    case .quests:
                        let entries = game.questProgress
                        SidebarPanel(title: "Objectives") {
                            VStack(spacing: 0) {
                                ForEach(Array(quests.enumerated()), id: \.offset) { index, quest in
                                    QuestRow(
                                        title: quest.title,
                                        subtitle: quest.subtitle,
                                        color: quest.color,
                                        progress: entries.indices.contains(index) ? entries[index] : .notStarted
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 2)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 0) {
                SidebarBottomButton(icon: "briefcase.fill") { ui.activeSheet = .inventory }
                SidebarBottomButton(icon: "star") { ui.activeSheet = .stats }
                SidebarBottomButton(icon: "gearshape") { ui.activeSheet = .settings }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }

    private func levelSprite(_ index: Int) -> Sprite {
        switch index {
        case 0:
            .stairs
        case 1:
            .flashlight
        case 2:
            .shield
        case 3:
            .keycard
        default:
            .hound
        }
    }
}

private struct MiniMapCard: View {
    @Environment(GameStore.self) private var game

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Map")
                    .font(.headline)
                Spacer()
                Text("\(game.position.x), \(game.position.y)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)

            MiniMapCanvas()
                .frame(height: 132)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .padding(.top, 2)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct MiniMapCanvas: View {
    @Environment(GameStore.self) private var game

    var body: some View {
        Canvas { context, size in
            let level = game.level
            let cell = min(size.width / CGFloat(level.width), size.height / CGFloat(level.height))
            let mapSize = CGSize(width: CGFloat(level.width) * cell, height: CGFloat(level.height) * cell)
            let origin = CGPoint(x: (size.width - mapSize.width) / 2, y: (size.height - mapSize.height) / 2)

            func rect(for point: GridPoint, inset: CGFloat = 0.8) -> CGRect {
                CGRect(
                    x: origin.x + CGFloat(point.x) * cell + inset,
                    y: origin.y + CGFloat(point.y) * cell + inset,
                    width: max(1, cell - inset * 2),
                    height: max(1, cell - inset * 2)
                )
            }

            context.fill(
                Path(roundedRect: CGRect(origin: origin, size: mapSize), cornerRadius: 4),
                with: .color(.black.opacity(0.22))
            )

            let visible = game.visibleCells
            let seen = game.seenCells

            for y in 0..<level.height {
                for x in 0..<level.width {
                    let point = GridPoint(x: x, y: y)
                    let isVisible = visible.contains(point)
                    let isSeen = isVisible || seen.contains(point)
                    guard isSeen else { continue }
                    let dim: Double = isVisible ? 1.0 : 0.42

                    switch level.tiles[y][x] {
                    case .wall:
                        context.fill(Path(rect(for: point)), with: .color(.white.opacity(0.12 * dim)))
                    case .floor:
                        context.fill(Path(rect(for: point)), with: .color(.white.opacity(0.30 * dim)))
                    case .stairs:
                        context.fill(Path(rect(for: point)), with: .color(level.theme.accent.opacity(0.95 * dim)))
                    }
                }
            }

            for point in game.items.keys {
                let isVisible = visible.contains(point)
                let isSeen = isVisible || seen.contains(point)
                guard isSeen else { continue }
                context.fill(
                    Path(ellipseIn: rect(for: point, inset: cell * 0.25)),
                    with: .color(.cyan.opacity(isVisible ? 0.95 : 0.45))
                )
            }

            for point in game.entities.keys where visible.contains(point) {
                context.fill(Path(ellipseIn: rect(for: point, inset: cell * 0.2)), with: .color(.red.opacity(0.95)))
            }

            let playerRect = rect(for: game.position, inset: -1)
            context.fill(Path(ellipseIn: playerRect), with: .color(.white))

            let noseLength = max(5, cell * 1.25)
            let center = CGPoint(x: playerRect.midX, y: playerRect.midY)
            let delta = game.direction.delta
            var path = Path()
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + CGFloat(delta.x) * noseLength, y: center.y + CGFloat(delta.y) * noseLength))
            context.stroke(path, with: .color(.white), lineWidth: 2)
        }
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct SidebarTopButton: View {
    @Environment(UIState.self) private var ui
    let icon: String
    let tab: UIState.SidebarTab

    var body: some View {
        Button {
            ui.sidebarTab = tab
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(ui.sidebarTab == tab ? Color.white.opacity(0.11) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SidebarPanel<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 12)
            content
        }
    }
}

private struct LevelRow: View {
    let title: String
    let subtitle: String
    let selected: Bool
    let marker: Color
    let sprite: Sprite

    var body: some View {
        HStack(spacing: 10) {
            SpriteAtlasImage(sprite: sprite)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(marker.opacity(selected ? 1 : 0.55))
                .frame(width: 7, height: 7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(selected ? Color.red.opacity(0.22) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 10)
        }
    }
}

private struct QuestRow: View {
    let title: String
    let subtitle: String
    let color: Color
    let progress: QuestProgress

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            statusIcon
                .font(.callout)
                .foregroundStyle(color)
                .padding(.top, 2)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title)
                        .font(.callout)
                        .strikethrough(progress == .completed, color: .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let progressText {
                        Text(progressText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch progress {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
        case .inProgress:
            Image(systemName: "circle.dotted")
        case .notStarted:
            Image(systemName: "circle")
        }
    }

    private var progressText: String? {
        switch progress {
        case .completed:
            "done"
        case .inProgress(let current, let target):
            target > 9 ? "\(percent(current: current, target: target))%" : "\(current)/\(target)"
        case .notStarted:
            nil
        }
    }

    private func percent(current: Int, target: Int) -> Int {
        guard target > 0 else { return 0 }
        return min(100, Int((Double(current) / Double(target)) * 100))
    }
}

private struct SidebarBottomButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
