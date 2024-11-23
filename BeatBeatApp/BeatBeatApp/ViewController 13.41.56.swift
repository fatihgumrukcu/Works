import UIKit
import ShazamKit
import AVFoundation

class ViewController: UIViewController, SHSessionDelegate {

    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var songTitleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var artistImageView: UIImageView!

    var session: SHSession!
    var audioEngine: AVAudioEngine!
    var timer: Timer?
    var isAnimating = false // Animasyon kontrol değişkeni
    private var bufferCount = 0 // Buffer sayacı

    override func viewDidLoad() {
        super.viewDidLoad()

        logoImageView.image = UIImage(named: "beatlogo")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black
        
        session = SHSession()
        session.delegate = self
        requestMicrophonePermission() // Mikrofon izni iste

        // Logo üzerine tıklanma özelliğini ekle
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(logoTapped))
        logoImageView.isUserInteractionEnabled = true
        logoImageView.addGestureRecognizer(tapGesture)

        // İki kez dokunma özelliğini ekle
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTapGesture.numberOfTapsRequired = 2
        logoImageView.addGestureRecognizer(doubleTapGesture)

        // UI bileşenlerini gizle
        songTitleLabel.isHidden = true
        artistLabel.isHidden = true
        artistImageView.isHidden = true
    }

    // İki kez dokunma durumunu ele al
    @objc func handleDoubleTap() {
        print("İki kez dokunuldu, dinleme durduruluyor ve ana ekrana dönülüyor.")
        stopListening() // Dinlemeyi durdur
        self.navigationController?.popViewController(animated: true) // Ana sayfaya dön
    }

    func requestMicrophonePermission() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    print("Mikrofon izni verildi.")
                } else {
                    self.showAlert(title: "İzin Gerekli", message: "Mikrofon izni verilmedi.")
                }
            }
        }
    }

    func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            print("Audio session başarıyla yapılandırıldı.")
        } catch {
            print("Audio Session hatası: \(error.localizedDescription)")
        }
    }

    @objc func logoTapped() {
        print("Logo tıklandı, dinlemeye başla!")
        startListening()

        // Animasyonu başlat
        isAnimating = true
        animateLogo()

        // 1 dakika sonra dinlemeyi durdur
        timer = Timer.scheduledTimer(timeInterval: 60.0, target: self, selector: #selector(stopListening), userInfo: nil, repeats: false)
        print("Timer başlatıldı, 60 saniye bekleniyor.")
    }
    
    @objc func animateLogo() {
        guard isAnimating else { return } // Eğer animasyon durdurulduysa, bu fonksiyonu çık

        // Logoyu büyüt
        UIView.animate(withDuration: 0.5, animations: {
            self.logoImageView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        }) { _ in
            // Logoyu küçült
            UIView.animate(withDuration: 0.5, animations: {
                self.logoImageView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            }) { _ in
                // Tekrar animasyonu başlat
                self.animateLogo() // Sonsuz döngü için
            }
        }
    }

    func startListening() {
        configureAudioSession()
        
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, when in
            guard let self = self else { return }
            self.session.matchStreamingBuffer(buffer, at: when)
            if self.bufferCount % 10 == 0 {
                print("Buffer alınan veriler: \(buffer)")
                print("Buffer timestamp: \(when)")
                print("Buffer frameLength: \(buffer.frameLength)")
                print("Buffer format: \(buffer.format)")
            }
            self.bufferCount += 1
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            print("Dinlemeye başlandı.")
        } catch {
            print("Audio Engine başlatma hatası: \(error.localizedDescription)")
        }
    }

    @objc func stopListening() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        timer?.invalidate()
        print("Dinleme durduruldu.")

        // Animasyonu durdur
        isAnimating = false
        
        // UI güncellemelerini ana iş parçacığında yap
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.5, animations: {
                self.logoImageView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            })
        }
    }

    // Shazam ile eşleşme bulunduğunda
    func session(_ session: SHSession, didFind match: SHMatch) {
        print("Eşleşme bulundu! Medya öğeleri: \(match.mediaItems)")
        if let mediaItem = match.mediaItems.first {
            let songTitle = mediaItem.title ?? "Bilinmiyor"
            let artist = mediaItem.artist ?? "Bilinmiyor"
            let artworkURL = mediaItem.artworkURL

            print("Parça Adı: \(songTitle)")
            print("Sanatçı: \(artist)")

            // Dinlemeyi durdur
            stopListening()

            // UI güncellemesi
            DispatchQueue.main.async {
                self.songTitleLabel.text = songTitle
                self.artistLabel.text = artist
                
                // Sanatçı resmini yükle
                if let imageUrl = artworkURL {
                    self.loadArtistImage(from: imageUrl)
                }
                
                // Logoyu gizle
                self.logoImageView.isHidden = true
                
                // Bilgileri görünür yap
                self.songTitleLabel.isHidden = false
                self.artistLabel.isHidden = false
                self.artistImageView.isHidden = false
            }
        } else {
            print("Müzik algılandı, ancak medya öğesi bulunamadı. Match: \(match)")
        }
    }

    func loadArtistImage(from url: URL) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            DispatchQueue.main.async {
                self.artistImageView.image = UIImage(data: data)
            }
        }
        task.resume()
    }

    // Shazam ile eşleşme hatası olduğunda
    func session(_ session: SHSession, didFailWithError error: Error) {
        print("Eşleşme hatası: \(error.localizedDescription)")
    }

    // Alert fonksiyonu
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Tamam", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

struct MusicInfo {
    var title: String
    var artist: String
    var album: String
    var artistImageURL: URL?
}
