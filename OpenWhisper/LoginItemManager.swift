import Foundation
import Observation
import ServiceManagement

@Observable
final class LoginItemManager {
	static let shared = LoginItemManager()

	private init() {}

	var isEnabled: Bool {
		get { SMAppService.mainApp.status == .enabled }
		set {
			do {
				if newValue {
					try SMAppService.mainApp.register()
				} else {
					try SMAppService.mainApp.unregister()
				}
			} catch {
				NSLog("OpenWhisper: failed to update login item: \(error.localizedDescription)")
			}
		}
	}
}

