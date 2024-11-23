import Foundation
import SwiftUI
import UIKit
import AVFoundation

struct PromptView: View {
    @StateObject private var viewModel: PromptViewModel
    @State private var userQuery = "" // Kullanıcı girişi
    @State private var messages: [(query: String, response: String)] = [] // Mesajlar
    @State private var showAlert = false // Uyarı göstermek için
    @State private var alertMessage = "" // Uyarı mesajı
    @State private var isCriticalError = false // Kritik hata durumu
    @State private var isRecording = false // Ses kaydı durumu

    init() {
        let pipeline = PromptPipeline(
            bloomService: BloomService()
        )
        _viewModel = StateObject(wrappedValue: PromptViewModel(pipeline: pipeline))
    }

    var body: some View {
        NavigationView {
            VStack {
                // Başlık
                headerView()

                Spacer(minLength: 20)

                // Mesaj Listesi
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(messages, id: \.query) { message in
                            VStack(alignment: .leading, spacing: 10) {
                                if !message.query.isEmpty {
                                    userQueryBubble(query: message.query)
                                }
                                responseBubble(response: message.response)
                            }
                        }
                        if viewModel.isLoading { // Yükleniyor durumunda animasyonu göster
                            HStack {
                                Spacer()
                                ProgressView("Yanıt bekleniyor...")
                                    .padding()
                                    .foregroundColor(.gray)
                                    .font(.footnote)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()

                // Giriş ve Gönderim Alanı
                inputArea()
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(isCriticalError ? "Ciddi Uyarı" : "Uyarı"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("Tamam"))
                )
            }
        }
    }

    // Başlık
    private func headerView() -> some View {
        HStack(spacing: 0) {
            Text("Prompt")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text("Lab")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "5CE1E6"))
        }
        .padding(.vertical)
    }

    // Kullanıcı sorgusu balonu
    private func userQueryBubble(query: String) -> some View {
        HStack {
            Spacer()
            Text(query)
                .padding()
                .background(Color(UIColor.systemBlue))
                .foregroundColor(.white)
                .cornerRadius(15)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
        }
        .padding(.horizontal)
    }

    // Yanıt balonu
    private func responseBubble(response: String) -> some View {
        HStack {
            Text(response)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(15)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
            Spacer()
        }
        .padding(.horizontal)
    }

    // Giriş ve Gönderim Alanı
    private func inputArea() -> some View {
        HStack {
            TextField("Sorunuzu yazın...", text: $userQuery)
                .padding(12)
                .background(Color(UIColor.systemGray5))
                .cornerRadius(25)
                .font(.body)
                .onSubmit { submitQuery() }

            HStack(spacing: 10) {
                // Gönder Butonu
                Button(action: {
                    submitQuery()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 50, height: 50)
                            .shadow(radius: 2)
                        Image(systemName: "arrow.up")
                            .foregroundColor(Color(UIColor.systemBlue))
                            .font(.system(size: 20, weight: .bold))
                    }
                }

                // Ses Butonu
                Button(action: {}) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red : Color.white) // Kayıtta ise kırmızı
                            .frame(width: 50, height: 50)
                            .shadow(radius: 2)
                        Image(systemName: isRecording ? "mic.fill" : "mic.circle")
                            .foregroundColor(Color(UIColor.systemBlue))
                            .font(.system(size: 20, weight: .bold))
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isRecording {
                                print("🎙️ Ses kaydı başlatılıyor...")
                                startRecording()
                            }
                        }
                        .onEnded { _ in
                            print("🛑 Ses kaydı durduruluyor...")
                            stopRecording()
                        }
                )
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }

    // Ses Kaydını Başlat
    private func startRecording() {
        isRecording = true
        Task {
            await viewModel.startRecording()
        }
    }

    // Ses Kaydını Durdur
    private func stopRecording() {
        Task {
            isRecording = false
            if let audioURL = await viewModel.stopRecording() {
                do {
                    let transcription = try await WhisperService.transcribe(audioFileURL: audioURL)
                    print("✅ Transkripsiyon: \(transcription)")
                    userQuery = transcription
                    submitQuery()
                } catch {
                    alertMessage = "Ses tanıma işlemi başarısız: \(error.localizedDescription)"
                    print("❌ Hata: \(error.localizedDescription)")
                    showAlert = true
                }
            } else {
                alertMessage = "Ses kaydı sırasında bir hata oluştu."
                print("❌ Hata: Ses kaydı alınamadı.")
                showAlert = true
            }
        }
    }

    // Sorguyu İşleme Fonksiyonu
    public func submitQuery() {
        let trimmedQuery = userQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        userQuery = "" // Input alanını temizle

        Task {
            let validationResult = viewModel.validateQuery(trimmedQuery)
            if !validationResult.isValid {
                alertMessage = validationResult.message
                isCriticalError = validationResult.isCritical
                showAlert = true
                return
            }

            messages.append((query: trimmedQuery, response: "")) // Sorguyu listeye ekle
            await viewModel.processPrompt(userQuery: trimmedQuery)

            if let index = messages.lastIndex(where: { $0.query == trimmedQuery }) {
                messages[index].response = viewModel.finalResponse
            }
        }
    }
}

// Color Uzantısı
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        scanner.currentIndex = hex.hasPrefix("#") ? hex.index(after: hex.startIndex) : hex.startIndex
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        self.init(
            red: Double((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgbValue & 0x0000FF) / 255.0
        )
    }
}
