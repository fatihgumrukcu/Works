import Foundation
import UIKit
import SwiftUI

@MainActor
class PromptPipeline {
    // MARK: - Servis Bağımlılığı
    private let bloomService: BloomService

    // MARK: - Başlatıcı (Initializer)
    init(bloomService: BloomService) {
        self.bloomService = bloomService
    }

    // MARK: - Pipeline Yürütme
    func executePipeline(userQuery: String) async throws -> String {
        log("Pipeline başlatıldı. Kullanıcı sorgusu: \(userQuery)")

        // Bloom ile analiz ve iyileştirme
        let bloomOptimized: String
        do {
            bloomOptimized = try await analyzeWithBloom(userQuery: userQuery)
            log("🌸 Bloom Servisi Yanıtı Başarılı")
        } catch {
            log("❌ Bloom Servisi Hatası: \(error.localizedDescription)")
            throw error
        }

        // Nihai Çıktıyı Döndür
        return bloomOptimized
    }

    // MARK: - Bloom ile Türkçe Analiz ve İyileştirme
    private func analyzeWithBloom(userQuery: String) async throws -> String {
        let result = try await BloomService.analyzeAndOptimizePrompt(userQuery: userQuery)
        guard !result.isEmpty else { throw PipelineError.emptyOptimizationStep("Bloom Optimization is empty") }
        return limitOutputLength(try validateOutput(result), maxLength: 300)
    }

    // MARK: - Yanıt Uzunluğunu Sınırla
    private func limitOutputLength(_ output: String, maxLength: Int) -> String {
        if output.count > maxLength {
            return String(output.prefix(maxLength)) + "..."
        }
        return output
    }

    // MARK: - Yanıt Doğrulama
    private func validateOutput(_ output: String) throws -> String {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedOutput.count > 3 else {
            log("❌ Yanıt çok kısa: \(trimmedOutput)")
            throw PipelineError.emptyOptimizationStep("Yanıt çok kısa.")
        }
        return trimmedOutput
    }

    // MARK: - Loglama
    private func log(_ message: String) {
        print("[Pipeline Log] \(message)")
    }
}

// MARK: - PipelineError: Hata Türleri
enum PipelineError: Error, LocalizedError {
    case emptyOptimizationStep(String)

    var errorDescription: String? {
        switch self {
        case .emptyOptimizationStep(let message):
            return "Optimize etme aşamasında bir sorun oluştu: \(message)"
        }
    }
}
