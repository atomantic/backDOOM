import SwiftUI

#if os(macOS)
import AppKit
#endif

@main
struct BackDOOMApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    @State private var game = GameStore()
    @State private var uiState = UIState()

    var body: some Scene {
        WindowGroup("backDOOM") {
            ContentView()
                .environment(game)
                .environment(uiState)
                #if os(macOS)
                .frame(minWidth: 860, minHeight: 640)
                #endif
                .onAppear {
                    Telemetry.app.notice("Main window appeared")
                    game.startIfNeeded()
                }
        }
        #if os(macOS)
        .commands {
            CommandMenu("Crawl") {
                Button("New Run") {
                    game.newRun()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Strike") {
                    game.attack()
                }
                .keyboardShortcut(.space, modifiers: [])

                Divider()

                Button("Turn Left") {
                    game.turnLeft()
                }
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button("Move Forward") {
                    game.moveForward()
                }
                .keyboardShortcut(.upArrow, modifiers: [])

                Button("Turn Right") {
                    game.turnRight()
                }
                .keyboardShortcut(.rightArrow, modifiers: [])

                Button("Move Back") {
                    game.moveBackward()
                }
                .keyboardShortcut(.downArrow, modifiers: [])

                Divider()

                Button("Wait") {
                    game.wait()
                }
                .keyboardShortcut(".", modifiers: [])

                Button("Examine Ahead") {
                    game.examineAhead()
                }
                .keyboardShortcut("e", modifiers: [])

                Button("Drink Potion") {
                    game.usePotion()
                }
                .keyboardShortcut("q", modifiers: [])
            }
        }
        #endif
    }
}

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        Telemetry.app.notice("Application did finish launching")
    }
}
#endif
