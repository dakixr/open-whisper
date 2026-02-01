import Foundation

enum UsageFormat {
	static func minutesString(seconds: Double) -> String {
		let minutes = max(0, seconds) / 60.0
		if minutes < 1 {
			return String(format: "%.0f sec", max(0, seconds))
		}
		return String(format: "%.1f min", minutes)
	}

	static func currencyUSD(_ value: Decimal, maxFractionDigits: Int = 2) -> String {
		let formatter = NumberFormatter()
		formatter.numberStyle = .currency
		formatter.currencyCode = "USD"
		formatter.maximumFractionDigits = maxFractionDigits
		return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
	}
}
