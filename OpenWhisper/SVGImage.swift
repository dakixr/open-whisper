import AppKit
import Foundation

final class SVGImage {
	enum SVGError: Error {
		case resourceMissing
		case invalidSVG
		case unsupportedPath
	}

	static func templateImage(resource: String, ext: String = "svg", size: CGSize) throws -> NSImage {
		guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
			throw SVGError.resourceMissing
		}
		let svg = try String(contentsOf: url, encoding: .utf8)
		let parsed = try parse(svg: svg)
		let image = rasterize(paths: parsed.paths, viewBox: parsed.viewBox, size: size)
		image.isTemplate = true
		return image
	}

	private struct ParsedSVG {
		let viewBox: CGRect
		let paths: [CGPath]
	}

	private static func parse(svg: String) throws -> ParsedSVG {
		guard let viewBox = parseViewBox(svg: svg) else { throw SVGError.invalidSVG }
		let pathStrings = parsePathDs(svg: svg)
		guard !pathStrings.isEmpty else { throw SVGError.invalidSVG }
		let paths = try pathStrings.map { try parsePath(d: $0) }
		return ParsedSVG(viewBox: viewBox, paths: paths)
	}

	private static func parseViewBox(svg: String) -> CGRect? {
		let pattern = "viewBox\\s*=\\s*\"([^\"]+)\""
		guard let match = firstMatch(pattern: pattern, in: svg),
			  let raw = match.first else { return nil }
		let parts = raw.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\n" || $0 == "\t" })
		guard parts.count == 4,
			  let x = Double(parts[0]),
			  let y = Double(parts[1]),
			  let w = Double(parts[2]),
			  let h = Double(parts[3]) else { return nil }
		return CGRect(x: x, y: y, width: w, height: h)
	}

	private static func parsePathDs(svg: String) -> [String] {
		let pattern = "<path[^>]*\\sd\\s*=\\s*\"([^\"]+)\"[^>]*/?>"
		return allMatches(pattern: pattern, in: svg)
	}

	private static func rasterize(paths: [CGPath], viewBox: CGRect, size: CGSize) -> NSImage {
		let image = NSImage(size: size)
		image.lockFocusFlipped(false)
		defer { image.unlockFocus() }

		guard let ctx = NSGraphicsContext.current?.cgContext else { return image }

		ctx.clear(CGRect(origin: .zero, size: size))
		ctx.setFillColor(NSColor.black.cgColor)
		ctx.setAllowsAntialiasing(true)
		ctx.setShouldAntialias(true)

		let scale = min(size.width / viewBox.width, size.height / viewBox.height)
		let dx = (size.width - viewBox.width * scale) / 2.0
		let dy = (size.height - viewBox.height * scale) / 2.0

		ctx.saveGState()
		ctx.translateBy(x: dx, y: dy)
		ctx.scaleBy(x: scale, y: scale)
		ctx.translateBy(x: -viewBox.minX, y: -viewBox.minY)

		for path in paths {
			ctx.addPath(path)
			ctx.fillPath()
		}
		ctx.restoreGState()

		return image
	}

	private static func parsePath(d: String) throws -> CGPath {
		let path = CGMutablePath()
		var tokenizer = PathTokenizer(d)

		var currentPoint = CGPoint.zero
		var startPoint = CGPoint.zero

		var currentCommand: Character?
		while let token = tokenizer.nextToken() {
			switch token {
			case .command(let c):
				currentCommand = c
				if c == "Z" || c == "z" {
					path.closeSubpath()
					currentPoint = startPoint
				}
			case .number:
				guard let cmd = currentCommand else { throw SVGError.invalidSVG }
				tokenizer.pushBack(token)

				switch cmd {
				case "M", "m":
					let first = try readPoint(&tokenizer)
					path.move(to: first)
					currentPoint = first
					startPoint = first
					while tokenizer.peekIsNumber() {
						let p = try readPoint(&tokenizer)
						path.addLine(to: p)
						currentPoint = p
					}
				case "L", "l":
					while tokenizer.peekIsNumber() {
						let p = try readPoint(&tokenizer)
						path.addLine(to: p)
						currentPoint = p
					}
				case "C", "c":
					while tokenizer.peekIsNumber() {
						let c1 = try readPoint(&tokenizer)
						let c2 = try readPoint(&tokenizer)
						let p = try readPoint(&tokenizer)
						path.addCurve(to: p, control1: c1, control2: c2)
						currentPoint = p
					}
				default:
					throw SVGError.unsupportedPath
				}
			}
		}

		_ = currentPoint
		return path
	}

	private static func readPoint(_ tokenizer: inout PathTokenizer) throws -> CGPoint {
		guard let x = tokenizer.nextNumber(), let y = tokenizer.nextNumber() else {
			throw SVGError.invalidSVG
		}
		return CGPoint(x: x, y: y)
	}

	private enum Token {
		case command(Character)
		case number(Double)
	}

	private struct PathTokenizer {
		private let chars: [Character]
		private var index: Int = 0
		private var pushedBack: [Token] = []

		init(_ d: String) {
			self.chars = Array(d)
		}

		mutating func peekIsNumber() -> Bool {
			let token = nextToken()
			if let token { pushBack(token) }
			if case .number = token { return true }
			return false
		}

		mutating func pushBack(_ token: Token) {
			pushedBack.append(token)
		}

		mutating func nextToken() -> Token? {
			if let t = pushedBack.popLast() { return t }
			skipSeparators()
			guard index < chars.count else { return nil }
			let c = chars[index]
			if isCommand(c) {
				index += 1
				return .command(c)
			}
			if let number = readNumber() {
				return .number(number)
			}
			index += 1
			return nextToken()
		}

		mutating func nextNumber() -> Double? {
			if let t = nextToken() {
				if case .number(let n) = t { return n }
			}
			return nil
		}

		private mutating func skipSeparators() {
			while index < chars.count {
				let c = chars[index]
				if c == " " || c == "\n" || c == "\t" || c == "," {
					index += 1
				} else {
					break
				}
			}
		}

		private func isCommand(_ c: Character) -> Bool {
			switch c {
			case "M", "m", "L", "l", "C", "c", "Z", "z":
				return true
			default:
				return false
			}
		}

		private mutating func readNumber() -> Double? {
			var start = index
			var seenDigit = false

			if start < chars.count, (chars[start] == "-" || chars[start] == "+") {
				start += 1
			}
			var i = start
			while i < chars.count {
				let c = chars[i]
				if c.isNumber {
					seenDigit = true
					i += 1
					continue
				}
				if c == "." {
					i += 1
					continue
				}
				break
			}

			guard seenDigit else { return nil }
			let s = String(chars[index..<i])
			index = i
			return Double(s)
		}
	}

	private static func firstMatch(pattern: String, in text: String) -> [Substring]? {
		guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
		let range = NSRange(text.startIndex..<text.endIndex, in: text)
		guard let match = re.firstMatch(in: text, options: [], range: range) else { return nil }
		var groups: [Substring] = []
		for i in 1..<match.numberOfRanges {
			let r = match.range(at: i)
			if let sr = Range(r, in: text) {
				groups.append(text[sr])
			}
		}
		return groups
	}

	private static func allMatches(pattern: String, in text: String) -> [String] {
		guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
		let range = NSRange(text.startIndex..<text.endIndex, in: text)
		return re.matches(in: text, options: [], range: range).compactMap { match in
			guard match.numberOfRanges > 1 else { return nil }
			let r = match.range(at: 1)
			guard let sr = Range(r, in: text) else { return nil }
			return String(text[sr])
		}
	}
}
