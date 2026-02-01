import Foundation
import Security

enum CodeSigningInfo {
	struct Info: Sendable {
		let bundleIdentifier: String?
		let teamIdentifier: String?
		let isAdHoc: Bool
	}

	static func current() -> Info {
		var code: SecCode?
		let selfStatus = SecCodeCopySelf([], &code)
		guard selfStatus == errSecSuccess, let code else {
			return Info(bundleIdentifier: Bundle.main.bundleIdentifier, teamIdentifier: nil, isAdHoc: true)
		}

		var staticCode: SecStaticCode?
		let staticStatus = SecCodeCopyStaticCode(code, SecCSFlags(), &staticCode)
		guard staticStatus == errSecSuccess, let staticCode else {
			return Info(bundleIdentifier: Bundle.main.bundleIdentifier, teamIdentifier: nil, isAdHoc: true)
		}

		var cfInfo: CFDictionary?
		let infoStatus = SecCodeCopySigningInformation(staticCode, SecCSFlags(), &cfInfo)
		guard infoStatus == errSecSuccess, let dict = cfInfo as? [CFString: Any] else {
			return Info(bundleIdentifier: Bundle.main.bundleIdentifier, teamIdentifier: nil, isAdHoc: true)
		}

		let identifier = dict[kSecCodeInfoIdentifier] as? String
		let team = dict[kSecCodeInfoTeamIdentifier] as? String

		// "Team identifier missing" is a strong signal this is ad-hoc signed (common when Xcode uses "Sign to Run Locally").
		let adHoc = (team == nil || team?.isEmpty == true)
		return Info(bundleIdentifier: identifier ?? Bundle.main.bundleIdentifier, teamIdentifier: team, isAdHoc: adHoc)
	}
}
