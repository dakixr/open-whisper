import Foundation
import Security

final class OpenAIWhisperTranscriber {
	enum TranscribeError: Error, LocalizedError {
		case missingAPIKey
		case invalidResponse
		case serverError(String)

		var errorDescription: String? {
			switch self {
			case .missingAPIKey:
				return "Missing OpenAI API key (set OPENAI_API_KEY or save to Keychain in Settings)."
			case .invalidResponse:
				return "Invalid response from transcription API."
			case .serverError(let message):
				return message
			}
		}
	}

	private struct TranscriptionResponse: Decodable {
		let text: String
	}

	func transcribe(fileURL: URL) async -> Result<String, Error> {
		guard let apiKey = APIKeyStore.shared.apiKeyForRequests() else {
			return .failure(TranscribeError.missingAPIKey)
		}

		var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
		request.httpMethod = "POST"
		request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

		let boundary = "Boundary-\(UUID().uuidString)"
		request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

		do {
			let audioData = try Data(contentsOf: fileURL)
			request.httpBody = makeMultipartBody(
				boundary: boundary,
				fields: [
					("model", "whisper-1"),
					("response_format", "json"),
				],
				fileField: ("file", fileURL.lastPathComponent, "audio/m4a", audioData)
			)
		} catch {
			return .failure(error)
		}

		do {
			let (data, response) = try await URLSession.shared.data(for: request)
			guard let http = response as? HTTPURLResponse else { return .failure(TranscribeError.invalidResponse) }

			if !(200...299).contains(http.statusCode) {
				let body = String(data: data, encoding: .utf8) ?? ""
				return .failure(TranscribeError.serverError("Transcription failed (\(http.statusCode)): \(body)"))
			}

			let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
			return .success(decoded.text.trimmingCharacters(in: .whitespacesAndNewlines))
		} catch {
			return .failure(error)
		}
	}

	private func makeMultipartBody(
		boundary: String,
		fields: [(String, String)],
		fileField: (name: String, filename: String, mimeType: String, data: Data)
	) -> Data {
		var body = Data()

		for (name, value) in fields {
			body.appendString("--\(boundary)\r\n")
			body.appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
			body.appendString("\(value)\r\n")
		}

		body.appendString("--\(boundary)\r\n")
		body.appendString("Content-Disposition: form-data; name=\"\(fileField.name)\"; filename=\"\(fileField.filename)\"\r\n")
		body.appendString("Content-Type: \(fileField.mimeType)\r\n\r\n")
		body.append(fileField.data)
		body.appendString("\r\n")

		body.appendString("--\(boundary)--\r\n")
		return body
	}
}

final class APIKeyStore {
	static let shared = APIKeyStore()

	private let service = "OpenWhisper"
	private let account = "OPENAI_API_KEY"

	func apiKeyForRequests() -> String? {
		if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !env.isEmpty {
			return env
		}
		return loadKeychainKey()
	}

	func hasKeychainKey() -> Bool {
		loadKeychainKey() != nil
	}

	@discardableResult
	func saveKeychainKey(_ apiKey: String) -> Bool {
		let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return false }
		guard let data = trimmed.data(using: .utf8) else { return false }

		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account,
		]

		let attributes: [String: Any] = [
			kSecValueData as String: data,
			kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
		]

		let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
		if status == errSecSuccess { return true }

		var addQuery = query
		addQuery[kSecValueData as String] = data
		addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
		return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
	}

	@discardableResult
	func deleteKeychainKey() -> Bool {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account,
		]
		let status = SecItemDelete(query as CFDictionary)
		return status == errSecSuccess || status == errSecItemNotFound
	}

	private func loadKeychainKey() -> String? {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account,
			kSecReturnData as String: true,
			kSecMatchLimit as String: kSecMatchLimitOne,
		]

		var item: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &item)
		guard status == errSecSuccess, let data = item as? Data else { return nil }
		return String(data: data, encoding: .utf8)
	}
}

private extension Data {
	mutating func appendString(_ string: String) {
		if let data = string.data(using: .utf8) {
			append(data)
		}
	}
}
