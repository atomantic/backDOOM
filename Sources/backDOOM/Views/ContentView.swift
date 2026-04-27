import SwiftUI

struct ContentView: View {
    @Environment(UIState.self) private var ui
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        @Bindable var ui = ui

        GeometryReader { proxy in
            let layout = layoutMode(for: proxy.size)

            Group {
                if ui.isImmersiveMode || layout == .compact {
                    ImmersivePlayLayout(layout: layout)
                } else if layout == .regular {
                    RegularPlayLayout()
                } else {
                    BalancedPlayLayout()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(.regularMaterial)
        .backDOOMWindowBackground()
        .sheet(item: $ui.activeSheet) { sheet in
            switch sheet {
            case .inventory: InventorySheet()
            case .stats: StatsSheet()
            case .settings: SettingsSheet()
            }
        }
        .sheet(item: $ui.activePanel) { panel in
            switch panel {
            case .navigator:
                LevelSidebarView()
                    .frame(minWidth: 300, minHeight: 440)
                    .padding()
            case .player:
                StatusSidebarView()
                    .frame(minWidth: 320, minHeight: 460)
                    .padding()
            }
        }
    }

    private func layoutMode(for size: CGSize) -> PlayLayoutMode {
        if horizontalSizeClass == .compact || size.width < 720 {
            return .compact
        }
        if size.width < 1080 {
            return .balanced
        }
        return .regular
    }
}

private extension View {
    @ViewBuilder
    func backDOOMWindowBackground() -> some View {
        #if os(macOS)
        if #available(macOS 15.0, *) {
            self.containerBackground(.regularMaterial, for: .window)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

private enum PlayLayoutMode {
    case compact
    case balanced
    case regular
}

private struct RegularPlayLayout: View {
    var body: some View {
        HStack(spacing: 12) {
            LevelSidebarView()
                .frame(width: 280)

            CenterPlayArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            StatusSidebarView()
                .frame(width: 360)
        }
        .padding(14)
    }
}

private struct BalancedPlayLayout: View {
    var body: some View {
        HStack(spacing: 12) {
            CenterPlayArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 12) {
                LevelSidebarView()
                StatusSidebarView()
            }
            .frame(width: 320)
        }
        .padding(12)
    }
}

private struct ImmersivePlayLayout: View {
    let layout: PlayLayoutMode

    var body: some View {
        GeometryReader { proxy in
            let compact = layout == .compact
            let controlsHeight: CGFloat = compact ? 168 : 152

            ZStack(alignment: .bottom) {
                ViewportView()
                    .ignoresSafeArea()

                VStack {
                    ToolStripView(compact: compact)
                        .padding(.top, compact ? proxy.safeAreaInsets.top + 8 : 14)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, compact ? 10 : 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                ControlDeckView()
                    .frame(height: controlsHeight)
                    .padding(.horizontal, compact ? 8 : 18)
                    .padding(.bottom, compact ? proxy.safeAreaInsets.bottom + 8 : 18)
            }
        }
    }
}

private struct CenterPlayArea: View {
    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 14
            let controlsHeight: CGFloat = 142
            let viewportHeight = max(280, proxy.size.height - controlsHeight - spacing)

            VStack(spacing: spacing) {
                ZStack(alignment: .top) {
                    ViewportView()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(.white.opacity(0.18), lineWidth: 1)
                        }

                    ToolStripView(compact: false)
                        .padding(.top, 6)
                }
                .frame(height: viewportHeight)

                ControlDeckView()
                    .frame(height: controlsHeight)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }
}

private struct ToolStripView: View {
    @Environment(GameStore.self) private var game
    @Environment(UIState.self) private var ui
    let compact: Bool

    var body: some View {
        @Bindable var ui = ui

        Group {
            if compact {
                HStack(spacing: 8) {
                ToolButton(icon: "map.fill", active: ui.activePanel == .navigator, help: "Open map and objectives") {
                    ui.activePanel = .navigator
                }
                ToolButton(icon: "person.fill", active: ui.activePanel == .player, help: "Open player and inventory") {
                    ui.activePanel = .player
                }
                    ToolButton(icon: "safari", active: ui.compassEnabled, help: "Toggle compass overlay") {
                        ui.setCompass(!ui.compassEnabled)
                    }
                    ToolButton(icon: "scope", active: ui.targetLockEnabled, help: "Toggle target lock overlay") {
                        ui.targetLockEnabled.toggle()
                    }
                    ToolButton(icon: "hand.raised.fill", help: "Wait one turn") {
                        game.wait()
                    }
                    RunMenuButton()
                }
            } else {
                HStack(spacing: 12) {
                    ToolButton(icon: "rectangle.expand.vertical", active: ui.isImmersiveMode, help: "Toggle full screen controls") {
                        ui.isImmersiveMode.toggle()
                    }
                    if ui.isImmersiveMode {
                        ToolButton(icon: "map.fill", active: ui.activePanel == .navigator, help: "Open map and objectives") {
                            ui.activePanel = .navigator
                        }
                        ToolButton(icon: "person.fill", active: ui.activePanel == .player, help: "Open player and inventory") {
                            ui.activePanel = .player
                        }
                    }
                    ToolButton(icon: "safari", active: ui.compassEnabled, help: "Toggle compass overlay") {
                        ui.setCompass(!ui.compassEnabled)
                    }
                    ToolButton(icon: "magnifyingglass", help: "Examine what's directly ahead") {
                        game.examineAhead()
                    }
                    ToolButton(icon: "checklist", active: ui.sidebarTab == .quests, help: "Show quest list") {
                        ui.sidebarTab = .quests
                    }
                    ToolButton(icon: "hand.raised.fill", help: "Wait one turn") {
                        game.wait()
                    }
                    ToolButton(icon: "scope", active: ui.targetLockEnabled, help: "Toggle target lock overlay") {
                        ui.targetLockEnabled.toggle()
                    }
                    RunMenuButton()
                }
            }
        }
        .padding(6)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ToolButton: View {
    let icon: String
    var active: Bool = false
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 44, height: 34)
                .foregroundStyle(active ? Color.yellow : .primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(active ? Color.yellow.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(active ? Color.yellow.opacity(0.55) : .white.opacity(0.14), lineWidth: 1)
        }
        .help(help)
    }
}

private struct RunMenuButton: View {
    @Environment(GameStore.self) private var game
    @Environment(UIState.self) private var ui

    var body: some View {
        Menu {
            Button {
                game.newRun()
            } label: {
                Label("New Run", systemImage: "arrow.counterclockwise")
            }
            Divider()
            Button {
                game.examineAhead()
            } label: {
                Label("Examine Ahead", systemImage: "magnifyingglass")
            }
            Button {
                game.wait()
            } label: {
                Label("Wait", systemImage: "hand.raised.fill")
            }
            Divider()
            Button {
                ui.sidebarTab = .quests
                ui.activePanel = .navigator
            } label: {
                Label("Quests", systemImage: "flag.fill")
            }
            Button {
                ui.activeSheet = .stats
            } label: {
                Label("Stats", systemImage: "star")
            }
            Button {
                ui.activeSheet = .inventory
            } label: {
                Label("Inventory", systemImage: "briefcase.fill")
            }
            Button {
                ui.activeSheet = .settings
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 44, height: 34)
                .contentShape(Rectangle())
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .help("Run menu")
    }
}
