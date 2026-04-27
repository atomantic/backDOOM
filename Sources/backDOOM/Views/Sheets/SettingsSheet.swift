import SwiftUI

struct SettingsSheet: View {
    @Environment(GameStore.self) private var game
    @Environment(UIState.self) private var ui
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var ui = ui

        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(18)

            Divider().opacity(0.3)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Display")
                        .font(.headline)
                    Toggle("Show compass overlay on viewport", isOn: Binding(
                        get: { ui.compassEnabled },
                        set: { ui.setCompass($0) }
                    ))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Run")
                        .font(.headline)
                    HStack(spacing: 10) {
                        Button(role: .destructive) {
                            game.newRun()
                            dismiss()
                        } label: {
                            Label("Restart current run", systemImage: "arrow.counterclockwise")
                        }
                        Button {
                            game.resetBestLevel()
                        } label: {
                            Label("Reset best level (\(game.bestLevelEver))", systemImage: "trophy")
                        }
                        .disabled(game.bestLevelEver <= 1)
                    }
                }

                Spacer()

                HStack {
                    Spacer()
                    Text(versionString)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(18)
        }
        .frame(minWidth: 460, minHeight: 380)
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "backDOOM \(version) (\(build))"
    }
}
