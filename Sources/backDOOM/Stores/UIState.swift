import Foundation
import Observation

@MainActor
@Observable
final class UIState {
    enum SidebarTab: Hashable {
        case map
        case levels
        case quests
    }

    enum ActiveSheet: String, Identifiable {
        case inventory
        case stats
        case settings

        var id: String { rawValue }
    }

    enum ActivePanel: String, Identifiable {
        case navigator
        case player

        var id: String { rawValue }
    }

    var sidebarTab: SidebarTab = .map
    var compassEnabled: Bool
    var targetLockEnabled: Bool = false
    var activeSheet: ActiveSheet?
    var activePanel: ActivePanel?
    var isImmersiveMode: Bool = false

    private static let compassKey = "backdoom.compassEnabled"

    init() {
        compassEnabled = UserDefaults.standard.object(forKey: Self.compassKey) as? Bool ?? true
    }

    func setCompass(_ enabled: Bool) {
        compassEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.compassKey)
    }
}
