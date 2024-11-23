import Foundation

struct WhisperService {
    static let apiKey = "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"
    static let baseUrl = "https://api-inference.huggingface.co/models/openai/whisper-large"

    static func transcribe(audioFileURL: URL) async throws -> String {
        guard let audioData = try? Data(contentsOf: audioFileURL) else {
            throw NSError(domain: "WhisperService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ses dosyası yüklenemedi."])
        }

        var request = URLRequest(url: URL(string: baseUrl)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "WhisperService", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "API Hatası."])
        }

        guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let transcription = jsonResponse["text"] as? String else {
            throw NSError(domain: "WhisperService", code: -1, userInfo: [NSLocalizedDescriptionKey: "API Yanıtı Beklenmeyen Formatta."])
        }

        return transcription
    }
}

