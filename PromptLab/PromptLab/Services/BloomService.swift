import Foundation

struct BloomService {
    static let apiKey = "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"
    static let baseUrl = "https://api-inference.huggingface.co/models/bigscience/bloom"

    static func analyzeAndOptimizePrompt(userQuery: String, temperature: Double = 0.7) async throws -> String {
        let userQueryLength = userQuery.count
        let maxTokens: Int
        let optimizationInstructions: String
        let temperature: Double = 0.6 // Sıcaklık değeri

        switch userQueryLength {
        case 1...20:
            maxTokens = 50
            optimizationInstructions = """
            - Kullanıcının kısa bir girdi yazdığı bağlamda yanıt üret.
            - Anlamı vurgula, kısa ve net tut.
            - Gereksiz ifadeleri çıkararak bağlama uygun bir sonuç sun.
            """
        case 21...100:
            maxTokens = 100
            optimizationInstructions = """
            - Kullanıcı girdisini anlamlı bir bağlama oturt.
            - Açıklayıcı ama aşırı detaylandırmadan yanıt üret.
            - Yanıtı profesyonel bir tonla 2-3 cümlede tamamla.
            """
        default:
            maxTokens = 150
            optimizationInstructions = """
            - Uzun girdiyi bağlama uygun şekilde sadeleştir.
            - Yanıtı yapılandırılmış bir formatta sun.
            - Kullanıcıya bağlamı açıklayan ve detaylı öneriler içeren 3-4 paragraf oluştur.
            """
        }

        // Bağlam Örnekleri
        let contextExamples = """
        Örnek Bağlamlar:
        1. Girdi: "Bugün hava kötü olacak gibi." 
           Bağlam: Kullanıcı hava durumu hakkında bilgi almak veya öneri arıyor.
           İyileştirilmiş Sorgu: "Hava kötü olacak gibi hissediyorum. Bugün dışarı çıkmadan önce hava durumu hakkında bilgi verebilir misin?"

        2. Girdi: "Swift dilinde yeni şeyler öğrenmek istiyorum."
           Bağlam: Kullanıcı Swift programlama diliyle ilgili başlangıç veya ileri düzeyde bilgi ve kaynaklar arıyor.
           İyileştirilmiş Sorgu: "Swift programlama dilinde öğrenebileceğim yeni konuları önerir misin? Başlangıç seviyesinden ileri seviyeye kadar kaynaklar ve projeler sunabilir misin?"

        3. Girdi: "Yeni bir hobi edinmek istiyorum." 
           Bağlam: Kullanıcı boş zamanlarını değerlendirebileceği yaratıcı veya eğlenceli hobiler arıyor.
           İyileştirilmiş Sorgu: "Yeni bir hobi edinmek istiyorum. Bana yaratıcı, eğlenceli ve kolay başlangıç yapabileceğim hobiler önerebilir misin?"
        """

        let prompt = """
        Sen profesyonel bir yapay zeka dil modelisin. Görevin:
        - Kullanıcının girdisini analiz ederek bağlama uygun şekilde optimize etmek.
        \(optimizationInstructions)

        \(contextExamples)

        Girdi (Türkçe): "\(userQuery)"

        Optimizasyon Sonucu:
        """

        guard let url = URL(string: baseUrl) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "inputs": prompt,
            "parameters": [
                "max_new_tokens": maxTokens,
                "temperature": temperature,
                "return_full_text": false
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            throw NSError(domain: "BloomService", code: -1, userInfo: [NSLocalizedDescriptionKey: "JSON Gövdesi oluşturulamadı."])
        }
        request.httpBody = httpBody

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "BloomService", code: statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Bloom API yanıtı başarısız. HTTP Kod: \(statusCode)"
            ])
        }

        guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let generatedText = jsonResponse.first?["generated_text"] as? String else {
            throw NSError(domain: "BloomService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Beklenmeyen JSON formatı."])
        }

        return sanitizeOutput(generatedText)
    }

    private static func sanitizeOutput(_ output: String) -> String {
        let cleanedOutput = output
            .replacingOccurrences(of: "Optimizasyon Sonucu:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleanedOutput.isEmpty || cleanedOutput.count < 5
            ? "Optimizasyon sırasında yeterli içerik üretilmedi."
            : cleanedOutput
    }
}
