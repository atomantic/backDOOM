import SwiftUI

struct ControlDeckView: View {
    @Environment(GameStore.self) private var game

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 620

            Group {
                if compact {
                    CompactControlDeck()
                } else {
                    WideControlDeck()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct WideControlDeck: View {
    @Environment(GameStore.self) private var game

    var body: some View {
        HStack(spacing: 12) {
            CharacterPanel()
                .frame(width: 326)

            RunStatusStrip()
                .frame(maxWidth: .infinity)

            MovementPad()
                .frame(width: 150)
                .disabled(game.isInputLocked)

            HStack(spacing: 8) {
                TurnBadge(turn: game.turn)

                Button {
                    game.takeStairsIfAvailable()
                } label: {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 19, weight: .medium))
                        .frame(width: 46, height: 46)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(game.isInputLocked || game.tile(at: game.position) != .stairs)
            }
            .frame(width: 104)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .frame(height: 142)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct CompactControlDeck: View {
    @Environment(GameStore.self) private var game

    var body: some View {
        VStack(spacing: 6) {
            CompactRunStatusStrip()
                .frame(height: 44)

            HStack(spacing: 8) {
                CompactVitals()
                    .frame(width: 154)

                CompactMovementPad()
                    .frame(width: 126)
                    .disabled(game.isInputLocked)

                VStack(spacing: 6) {
                    Button {
                        game.takeStairsIfAvailable()
                    } label: {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 40, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .disabled(game.isInputLocked || game.tile(at: game.position) != .stairs)

                    Text("\(game.turn)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .frame(width: 40, height: 24)
                        .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .frame(width: 40)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct CompactRunStatusStrip: View {
    @Environment(GameStore.self) private var game

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Label("L\(game.level.level)", systemImage: "map")
                Text(game.level.theme.name)
                    .foregroundStyle(game.level.theme.accent)
                Spacer(minLength: 4)
                Text(game.direction.name)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .font(.caption2.weight(.semibold))
            .lineLimit(1)

            Text(game.log.first?.text ?? "The level breathes around you.")
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.black.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.white.opacity(0.11), lineWidth: 1)
        }
    }
}

private struct CompactVitals: View {
    @Environment(GameStore.self) private var game

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                SpriteAtlasImage(sprite: .survivor)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Level \(game.player.level)")
                        .font(.caption.weight(.semibold))
                    Text("\(game.player.gold) gold")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
            }

            CompactStatMeter(icon: "heart.fill", color: .red, value: game.player.healthFraction, label: "\(game.player.hp)")
            CompactStatMeter(icon: "wand.and.stars", color: .purple, value: Double(game.player.xp) / Double(game.player.nextLevelXP), label: "\(game.player.xp)")
            CompactStatMeter(icon: "cross.vial.fill", color: .green, value: game.player.potionCount > 0 ? 1 : 0, label: "\(game.player.potionCount)")
        }
        .padding(7)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.black.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct CompactStatMeter: View {
    let icon: String
    let color: Color
    let value: Double
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 14)

            ProgressView(value: value)
                .tint(color)

            Text(label)
                .font(.caption.monospacedDigit())
                .frame(width: 24, alignment: .trailing)
        }
    }
}

private struct CompactMovementPad: View {
    @Environment(GameStore.self) private var game

    var body: some View {
        Grid(horizontalSpacing: 7, verticalSpacing: 7) {
            GridRow {
                Color.clear.frame(width: 34, height: 28)
                CompactPadButton(icon: "arrow.up", size: 20) { game.moveForward() }
                Color.clear.frame(width: 34, height: 28)
            }
            GridRow {
                CompactPadButton(icon: "arrow.left", size: 20) { game.turnLeft() }
                CompactPadButton(icon: "sparkle", size: 16, prominent: true) { game.attack() }
                CompactPadButton(icon: "arrow.right", size: 20) { game.turnRight() }
            }
            GridRow {
                Color.clear.frame(width: 34, height: 28)
                CompactPadButton(icon: "arrow.down", size: 20) { game.moveBackward() }
                Color.clear.frame(width: 34, height: 28)
            }
        }
        .buttonStyle(.plain)
        .padding(7)
        .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct CompactPadButton: View {
    let icon: String
    let size: CGFloat
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .bold))
                .frame(width: 34, height: 28)
                .contentShape(Rectangle())
        }
        .background(prominent ? Color.red.opacity(0.28) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(prominent ? 0.22 : 0.12), lineWidth: 1)
        }
    }
}

private struct CharacterPanel: View {
    @Environment(GameStore.self) private var game

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                SpriteAtlasImage(sprite: .survivor)
                    .scaledToFit()
                    .frame(width: 82, height: 106)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    }

                Text("\(game.player.level)")
                    .font(.headline.bold())
                    .frame(width: 26, height: 26)
                    .background(.black.opacity(0.55), in: Hexagon())
                    .padding(6)
            }

            VStack(alignment: .leading, spacing: 6) {
                StatMeter(icon: "heart.fill", color: .red, value: game.player.healthFraction, label: "\(game.player.hp) / \(game.player.maxHP)")
                StatMeter(icon: "drop.fill", color: .blue, value: 0.7, label: "56 / 80")
                StatMeter(icon: "wand.and.stars", color: .purple, value: Double(game.player.xp) / Double(game.player.nextLevelXP), label: "\(game.player.xp) / \(game.player.nextLevelXP)")

                HStack(spacing: 6) {
                    SmallBuff(icon: "leaf.fill", color: .green)
                    SmallBuff(icon: "flame.fill", color: .blue)
                    SmallBuff(icon: "shield.fill", color: .purple)
                    SmallBuff(icon: "ellipsis", color: .secondary)
                }
            }
        }
    }
}

private struct RunStatusStrip: View {
    @Environment(GameStore.self) private var game

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Level \(game.level.level)", systemImage: "map")
                Text(game.level.theme.name)
                    .foregroundStyle(game.level.theme.accent)
                Spacer(minLength: 8)
                Label(game.direction.name, systemImage: "location.north.line")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .lineLimit(1)

            Text(game.log.first?.text ?? "The level breathes around you.")
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(height: 78)
        .background(.black.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.white.opacity(0.11), lineWidth: 1)
        }
    }
}

private struct StatMeter: View {
    let icon: String
    let color: Color
    let value: Double
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 16)

            ProgressView(value: value)
                .tint(color)
                .frame(width: 90)

            Text(label)
                .font(.callout.monospacedDigit())
                .lineLimit(1)
                .frame(width: 52, alignment: .trailing)
        }
    }
}

private struct SmallBuff: View {
    let icon: String
    let color: Color

    var body: some View {
        Image(systemName: icon)
            .font(.caption)
            .foregroundStyle(color)
            .frame(width: 24, height: 24)
            .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            }
    }
}

private struct MovementPad: View {
    @Environment(GameStore.self) private var game

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                Color.clear.frame(width: 38, height: 30)
                PadButton(icon: "arrow.up", size: 20) { game.moveForward() }
                Color.clear.frame(width: 38, height: 30)
            }
            GridRow {
                PadButton(icon: "arrow.left", size: 20) { game.turnLeft() }
                PadButton(icon: "sparkle", size: 17, prominent: true) { game.attack() }
                PadButton(icon: "arrow.right", size: 20) { game.turnRight() }
            }
            GridRow {
                Color.clear.frame(width: 38, height: 30)
                PadButton(icon: "arrow.down", size: 20) { game.moveBackward() }
                PadButton(icon: "arrow.uturn.left", size: 16) { game.attack() }
            }
        }
        .buttonStyle(.plain)
        .padding(8)
        .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct PadButton: View {
    let icon: String
    let size: CGFloat
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .bold))
                .frame(width: 38, height: 30)
                .contentShape(Rectangle())
        }
        .background(prominent ? Color.red.opacity(0.28) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(prominent ? 0.22 : 0.12), lineWidth: 1)
        }
    }
}

private struct TurnBadge: View {
    let turn: Int

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: "hourglass")
                .font(.system(size: 12, weight: .semibold))
            Text("Turn")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(turn)")
                .font(.callout.monospacedDigit().weight(.semibold))
        }
        .frame(width: 50, height: 56)
        .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = [
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25),
            CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.25),
            CGPoint(x: rect.midX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.25),
            CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25)
        ]
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}
