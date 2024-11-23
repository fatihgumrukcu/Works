import AVFoundation
import SwiftUI
import AVFAudio

@MainActor
class PromptViewModel: ObservableObject {
    // MARK: - Yayınlanan Durumlar
    @Published var isLoading = false // Yükleme durumu
    @Published var finalResponse: String = "" // Nihai Türkçe Yanıt
    @Published var transcription: String = "" // Ses transkripsiyonu
    @Published var isCriticalError = false // Kritik hata durumu
    @Published var isRecording = false // Ses kaydı durumu
    @Published var hasMicrophonePermission = false // Mikrofon izni durumu

    // Ses Kaydedici
    let audioRecorder = AudioRecorder()

    // Servis Bağımlılığı
    private let pipeline: PromptPipeline

    // MARK: - Başlatıcı (Initializer)
    init(pipeline: PromptPipeline) {
        self.pipeline = pipeline
    }

    // MARK: - Mikrofon İzni Kontrolü
    func checkMicrophonePermission() async {
        if #available(iOS 17.0, *) {
            let permissionStatus = AVAudioApplication.shared.recordPermission
            switch permissionStatus {
            case .undetermined:
                let granted = await withCheckedContinuation { continuation in
                    AVAudioApplication.requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
                self.hasMicrophonePermission = granted
            case .denied:
                self.hasMicrophonePermission = false
            case .granted:
                self.hasMicrophonePermission = true
            @unknown default:
                self.hasMicrophonePermission = false
            }
        } else {
            let audioSession = AVAudioSession.sharedInstance()
            switch audioSession.recordPermission {
            case .undetermined:
                let granted = await withCheckedContinuation { continuation in
                    audioSession.requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
                self.hasMicrophonePermission = granted
            case .denied:
                self.hasMicrophonePermission = false
            case .granted:
                self.hasMicrophonePermission = true
            @unknown default:
                self.hasMicrophonePermission = false
            }
        }
    }

    // MARK: - Ses Kaydı Yönetimi
    func startRecording() async {
        await checkMicrophonePermission()

        guard hasMicrophonePermission else {
            log("❌ Mikrofon izni reddedildi.")
            transcription = "Mikrofon izni gerekli. Lütfen ayarlardan mikrofon erişimini etkinleştirin."
            return
        }

        do {
            try startAudioSession()
            log("🎙️ Ses kaydı başladı.")
            audioRecorder.startRecording()
            isRecording = true
        } catch {
            log("❌ Ses kaydı başlatılamadı: \(error.localizedDescription)")
            transcription = "Ses kaydı başlatılamadı. Lütfen tekrar deneyin."
        }
    }

    func stopRecording() async -> URL? {
        log("🛑 Ses kaydı durduruluyor.")
        isRecording = false
        return audioRecorder.stopRecording()
    }

    // MARK: - Ses Dosyasını İşleme
    func processAudio(fileURL: URL) async {
        log("📂 Ses dosyası işleniyor: \(fileURL.absoluteString)")
        isLoading = true
        defer { isLoading = false }

        do {
            transcription = try await WhisperService.transcribe(audioFileURL: fileURL)
            log("✅ Transkripsiyon tamamlandı: \(transcription)")
            await processPrompt(userQuery: transcription)
        } catch {
            transcription = "Hata: \(error.localizedDescription)"
            log("❌ Ses dosyası işlenirken hata: \(error.localizedDescription)")
        }
    }

    // MARK: - Prompt İşleme
    func processPrompt(userQuery: String) async {
        log("🔄 Prompt işleniyor: \(userQuery)")
        isLoading = true
        defer { isLoading = false }

        let correctedQuery = correctSpelling(for: userQuery)
        let validationResult = validateQuery(correctedQuery)

        guard validationResult.isValid else {
            handleValidationError(validationResult)
            return
        }

        do {
            let result = try await pipeline.executePipeline(userQuery: correctedQuery)
            finalResponse = filterResponse(result)
            log("✅ Nihai yanıt: \(finalResponse)")
        } catch {
            handlePipelineError(error)
        }
    }

    // MARK: - Ses Oturumu Başlatma
    private func startAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Yazım Kontrolü
    private func correctSpelling(for query: String) -> String {
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: query.utf16.count)
        let misspelledRange = checker.rangeOfMisspelledWord(in: query, range: range, startingAt: 0, wrap: false, language: "tr")

        guard misspelledRange.location != NSNotFound else { return query }

        return checker.guesses(forWordRange: misspelledRange, in: query, language: "tr")?.first ?? query
    }

    // MARK: - Sorgu Doğrulama
    public func validateQuery(_ query: String) -> (isValid: Bool, message: String, isCritical: Bool) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedQuery.isEmpty {
            return (false, "Sorgu boş olamaz.", false)
        }

        if trimmedQuery.count < 2 {
            return (false, "Sorgu çok kısa. Daha fazla bilgi ekleyin.", false)
        }

        if trimmedQuery.count > 200 {
            return (false, "Sorgu çok uzun. 200 karakter sınırını aşmayın.", false)
        }

        return (true, "", false)
    }

    // MARK: - Hata Yönetimi
    private func handleValidationError(_ validationResult: (isValid: Bool, message: String, isCritical: Bool)) {
        finalResponse = validationResult.message
        isCriticalError = validationResult.isCritical
        log("❌ Geçersiz sorgu: \(validationResult.message)")
    }

    private func handlePipelineError(_ error: Error) {
        finalResponse = "Bir hata oluştu: \(error.localizedDescription)"
        log("❌ Pipeline Hatası: \(error.localizedDescription)")
    }

    // MARK: - Yanıt Filtreleme
    private func filterResponse(_ rawResponse: String) -> String {
        let cleanedResponse = rawResponse
            .replacingOccurrences(of: "Girdi:", with: "")
            .replacingOccurrences(of: "Çıktı:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleanedResponse.isEmpty ? "Optimizasyon sırasında yeterli içerik üretilemedi." : cleanedResponse
    }

    // MARK: - Loglama
    private func log(_ message: String) {
        print("[PromptViewModel Log] \(message)")
    }
}
