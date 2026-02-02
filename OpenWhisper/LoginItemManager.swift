import Foundation
import Combine
import ServiceManagement

@MainActor
final class LoginItemManager: ObservableObject {
	static let shared = LoginItemManager()

	@Published private(set) var isEnabled: Bool

	private init() {
		isEnabled = SMAppService.mainApp.status == .enabled
	}

	private var isSyncing = false

	private func syncFromSystemStatus() {
		isSyncing = true
		isEnabled = SMAppService.mainApp.status == .enabled
		isSyncing = false
	}

	func setEnabled(_ enabled: Bool) {
		guard !isSyncing else { return }
		guard (SMAppService.mainApp.status == .enabled) != enabled else {
			syncFromSystemStatus()
			return
		}

		do {
			if enabled {
				try SMAppService.mainApp.register()
			} else {
				try SMAppService.mainApp.unregister()
			}
		} catch {
			NSLog("OpenWhisper: failed to update login item: \(error.localizedDescription)")
		}

		syncFromSystemStatus()
	}
}
