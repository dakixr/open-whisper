import Foundation
import Observation

struct UsagePricing {
	// Whisper API pricing is per minute of audio.
	// Update this if OpenAI pricing changes.
	static let whisperUSDPerMinute: Decimal = 0.006
}

struct UsageTotals: Codable, Equatable {
	var seconds: Double
	var requests: Int
	var successes: Int

	static let zero = UsageTotals(seconds: 0, requests: 0, successes: 0)
}

@Observable
final class UsageStore {
	static let shared = UsageStore()

	private let storageKey = "openwhisper.usage.v1"
	private let calendar = Calendar.current

	var byDay: [String: UsageTotals] = [:]

	private init() {
		load()
	}

	func recordTranscription(durationSeconds: Double, succeeded: Bool) {
		let dayKey = Self.dayKey(for: Date())
		var totals = byDay[dayKey] ?? .zero
		totals.seconds += max(0, durationSeconds)
		totals.requests += 1
		if succeeded { totals.successes += 1 }
		byDay[dayKey] = totals
		save()
	}

	func resetAll() {
		byDay = [:]
		save()
	}

	func totals(for date: Date) -> UsageTotals {
		byDay[Self.dayKey(for: date)] ?? .zero
	}

	var totalsAllTime: UsageTotals {
		byDay.values.reduce(.zero) { acc, v in
			UsageTotals(seconds: acc.seconds + v.seconds, requests: acc.requests + v.requests, successes: acc.successes + v.successes)
		}
	}

	var totalsToday: UsageTotals {
		totals(for: Date())
	}

	func estimatedCostUSD(for totals: UsageTotals) -> Decimal {
		let minutes = Decimal(totals.seconds / 60.0)
		return minutes * UsagePricing.whisperUSDPerMinute
	}

	private func save() {
		do {
			let data = try JSONEncoder().encode(byDay)
			UserDefaults.standard.set(data, forKey: storageKey)
		} catch {
			NSLog("OpenWhisper: failed saving usage: \(error.localizedDescription)")
		}
	}

	private func load() {
		guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
		do {
			byDay = try JSONDecoder().decode([String: UsageTotals].self, from: data)
		} catch {
			byDay = [:]
		}
	}

	private static func dayKey(for date: Date) -> String {
		let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
		let y = comps.year ?? 0
		let m = comps.month ?? 0
		let d = comps.day ?? 0
		return String(format: "%04d-%02d-%02d", y, m, d)
	}
}

