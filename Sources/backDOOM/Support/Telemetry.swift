import Foundation
import OSLog

enum Telemetry {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.atomantic.backDOOM"

    static let app = Logger(subsystem: subsystem, category: "App")
    static let generation = Logger(subsystem: subsystem, category: "Generation")
    static let movement = Logger(subsystem: subsystem, category: "Movement")
    static let combat = Logger(subsystem: subsystem, category: "Combat")
    static let inventory = Logger(subsystem: subsystem, category: "Inventory")
}
