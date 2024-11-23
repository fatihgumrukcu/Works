import AVFoundation

class AudioRecorder: NSObject {
    private var audioRecorder: AVAudioRecorder?

    func startRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFileURL = documentsPath.appendingPathComponent("recording.m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFileURL, settings: settings)
            audioRecorder?.record()
        } catch {
            print("⚠️ Ses kaydı başlatılamadı: \(error.localizedDescription)")
        }
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        return audioRecorder?.url // Kaydedilen ses dosyasının URL'sini döndür
    }
}
