import ServiceManagement

@MainActor
final class LoginItemManager {
    private let defaults = UserDefaults.standard
    private let parentDisabledKey = "TimeBoxerParentDisabledLoginProtection"

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func toggle() throws {
        if isEnabled {
            try SMAppService.mainApp.unregister()
            defaults.set(true, forKey: parentDisabledKey)
        } else {
            try SMAppService.mainApp.register()
            defaults.set(false, forKey: parentDisabledKey)
        }
    }

    func ensureEnabled() throws {
        guard !defaults.bool(forKey: parentDisabledKey) else { return }
        guard !isEnabled else { return }
        try SMAppService.mainApp.register()
    }
}
