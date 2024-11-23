import Foundation

@MainActor
class APIHealthCheckViewModel: ObservableObject {
    @Published var apiStatus: [String: String] = [:] // API durumlarını tutar
    @Published var areAPIsHealthy: Bool = true // API'nin sağlıklı olup olmadığını tutar

    // BloomService'in durumunu kontrol et
    func checkAPI() async {
        var isHealthy = true

        // BloomService testi
        do {
            _ = try await MyAppBloomService.analyzeAndOptimizePrompt(userQuery: "Merhaba, nasılsınız?")
            apiStatus["BloomService"] = "Başarılı"
        } catch {
            isHealthy = false
            print("❌ BloomService Hatası: \(error.localizedDescription)")
            apiStatus["BloomService"] = "Hata: \(error.localizedDescription)"
        }

        // API durumu değerlendir
        areAPIsHealthy = isHealthy

        if !isHealthy {
            print("🔍 API Durumu: \(apiStatus)")
        } else {
            print("✅ API sağlıklı.")
        }
    }
}

// Uygulama başlatıldığında Bloom API'yi kontrol et
@MainActor
class AppStartupManager {
    let healthCheckViewModel = APIHealthCheckViewModel()

    // Uygulama başlatıldığında çağrılacak fonksiyon
    func initializeApp() async {
        print("🚀 Uygulama başlatılıyor, Bloom API kontrol ediliyor...")
        await healthCheckViewModel.checkAPI()

        if !healthCheckViewModel.areAPIsHealthy {
            print("⚠️ Uygulama Bloom API'de sorun olduğunu tespit etti.")
        } else {
            print("✅ Bloom API sağlıklı.")
        }
    }
}

// MyAppBloomService
struct MyAppBloomService {
    static func analyzeAndOptimizePrompt(userQuery: String) async throws -> String {
        // Simüle edilen Bloom API çağrısı
        if userQuery.isEmpty { throw NSError(domain: "MyAppBloomService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Boş sorgu gönderilemez."]) }
        return "Bloom Optimized Prompt: \(userQuery)"
    }
}
