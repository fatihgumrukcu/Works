import SwiftUI
import Foundation
import AVFoundation
import Accelerate

class AudioManager: ObservableObject {
    var audioEngine = AVAudioEngine()
    @Published var frequency: Double = 30.0 // Varsayılan başlangıç frekansı 30 Hz
    @Published var noteName: String = "" // Algılanan notayı gösterecek
    @Published var tunings: [Tuning] = []
    @Published var targetFrequency: Double = 0.0
    @Published var tuningStatus: String = "Akort yapılıyor..."
    @Published var isTuned: Bool = false

    private var lastFrequencies: [Double] = [] // Frekans stabilizasyonu için

    init() {
        setupAudioSession()
        loadTunings()
    }
    
    // Ses oturumunun yapılandırılması
    func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(true)
        } catch {
            print("Ses oturumu yapılandırılamadı: \(error.localizedDescription)")
        }

        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                if granted {
                    self.configureAudioSession(session)
                } else {
                    print("Mikrofon izni reddedildi.")
                }
            }
        } else {
            session.requestRecordPermission { granted in
                if granted {
                    self.configureAudioSession(session)
                } else {
                    print("Mikrofon izni reddedildi.")
                }
            }
        }
    }
    
    // Akorların yüklenmesi
    func loadTunings() {
        if let path = Bundle.main.path(forResource: "Accord", ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let json = try JSONDecoder().decode([String: [Tuning]].self, from: data)
                self.tunings = json["tunings"] ?? []
            } catch {
                print("JSON verisi çözümlenemedi: \(error.localizedDescription)")
            }
        } else {
            print("JSON dosyası bulunamadı.")
        }
    }
    
    // Hedef frekansı ayarlamak
    func setTargetFrequency(for stringNote: StringNote) {
        targetFrequency = stringNote.frequency
    }
    
    // Hedef akor frekansını ayarlamak
    func setTargetTuning(_ tuning: Tuning) {
        if let firstStringNote = tuning.tuning.first {
            setTargetFrequency(for: firstStringNote)
        }
    }
    
    // Frekans takibini başlatmak
    func startTracking() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            let detectedFrequency = self.detectFrequency(from: buffer)
            DispatchQueue.main.async {
                // Gürültü filtreleme
                guard detectedFrequency > 20, detectedFrequency < 5000 else { return }
                
                // Frekans stabilizasyonu
                self.frequency = self.averageFrequency(detectedFrequency)
                
                // Algılanan notayı hesaplamak
                self.noteName = self.calculateNoteName(from: self.frequency)
                
                // Akor durumu güncelleme
                self.updateTuningStatus()
            }
        }
        do {
            try audioEngine.start()
        } catch {
            print("Ses motoru başlatılamadı: \(error.localizedDescription)")
            self.tuningStatus = "Ses motoru başlatılamadı."
        }
    }
    
    // Ses oturumunu yapılandırmak
    func configureAudioSession(_ session: AVAudioSession) {
        do {
            try session.setActive(true)
        } catch {
            print("Ses oturumu başlatılamadı: \(error.localizedDescription)")
        }
    }
    
    // Takibi durdurmak
    func stopTracking() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
    }
    
    // Frekans stabilizasyonu
    private func averageFrequency(_ newFrequency: Double) -> Double {
        lastFrequencies.append(newFrequency)
        if lastFrequencies.count > 10 { lastFrequencies.removeFirst() }
        return lastFrequencies.reduce(0, +) / Double(lastFrequencies.count)
    }
    
    // Akor durumu güncelleme
    private func updateTuningStatus() {
        let tolerance = 1.0 // Tolerans aralığı
        let difference = frequency - targetFrequency
        if abs(difference) < tolerance {
            tuningStatus = "Doğru akort!"
            isTuned = true
        } else if difference < 0 {
            tuningStatus = "Pes (Frekansı artır)"
            isTuned = false
        } else {
            tuningStatus = "Tiz (Frekansı düşür)"
            isTuned = false
        }
    }
    
    // FFT işlemi ile frekans algılama
    private func detectFrequency(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData?[0] else { return 0.0 }
        let frameCount = Int(buffer.frameLength)
        
        let log2n = UInt(round(log2(Double(frameCount))))
        let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        
        let real = UnsafeMutablePointer<Float>.allocate(capacity: frameCount / 2)
        let imag = UnsafeMutablePointer<Float>.allocate(capacity: frameCount / 2)
        defer { real.deallocate(); imag.deallocate() }
        
        var complexBuffer = DSPSplitComplex(realp: real, imagp: imag)
        channelData.withMemoryRebound(to: DSPComplex.self, capacity: frameCount) { pointer in
            vDSP_ctoz(pointer, 2, &complexBuffer, 1, vDSP_Length(frameCount / 2))
        }
        vDSP_fft_zrip(fftSetup!, &complexBuffer, 1, log2n, FFTDirection(FFT_FORWARD))
        
        var magnitudes = [Float](repeating: 0.0, count: frameCount / 2)
        vDSP_zvmags(&complexBuffer, 1, &magnitudes, 1, vDSP_Length(frameCount / 2))
        
        var maxMagnitude: Float = 0.0
        var maxIndex: vDSP_Length = 0
        vDSP_maxvi(&magnitudes, 1, &maxMagnitude, &maxIndex, vDSP_Length(frameCount / 2))
        
        let nyquistFrequency = 0.5 * Float(buffer.format.sampleRate)
        let binWidth = nyquistFrequency / Float(frameCount / 2)
        let frequency = Double(binWidth * Float(maxIndex))
        
        vDSP_destroy_fftsetup(fftSetup)
        return frequency
    }
    
    // Frekansa karşılık gelen nota ismi hesaplama
    func calculateNoteName(from frequency: Double) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let a4Frequency = 440.0
        let a4Index = 9 + 4 * 12 // A4 notasının endeksi
        
        guard frequency > 20, frequency < 5000 else { return "?" } // Geçerli aralık
        let noteIndex = Int(round(12 * log2(frequency / a4Frequency))) + a4Index
        guard noteIndex >= 0, noteIndex < noteNames.count * 12 else { return "?" }
        
        let octave = noteIndex / 12
        let noteName = noteNames[noteIndex % 12]
        
        return "\(noteName)\(octave)"
    }
}
