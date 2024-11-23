import UIKit
import SendBirdCalls
import AVFoundation

var recentCallId: String = ""

class CallingViewController: UIViewController {
    var call: DirectCall!
    private var localVideoView: SendBirdVideoView!
    private var remoteVideoView: SendBirdVideoView!
    
    private let endButton = UIButton(type: .system)
    
    // Karşı tarafın ses durumunu gösterecek bir UILabel
    private let remoteAudioStatusLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.textColor = .red
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let call = call else {
            print("Hata: Çağrı nesnesi boş.")
            dismiss(animated: true, completion: nil)
            return
        }
        
        print("Çağrı başlatılıyor")
        call.delegate = self
        
        // Mikrofonun sesini açıyoruz
        call.unmuteMicrophone()
        
        // Videoyu başlatıyoruz
        call.startVideo()

        requestMicrophonePermission()
        setupAudioSession()
        setupViews()
        setupEndButton()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    private func requestMicrophonePermission() {
        AVAudioApplication.requestRecordPermission { granted in
            if !granted {
                print("Mikrofon izni verilmedi.")
                // Kullanıcıya izin vermesi gerektiğini bildirin
            } else {
                print("Mikrofon izni verildi.")
            }
        }
    }

    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            print("AVAudioSession yapılandırılıyor")
            // Ses oturum ayarlarını yapıyoruz
            try audioSession.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setMode(.videoChat)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            print("AVAudioSession başarıyla yapılandırıldı ve etkinleştirildi.")
            
        } catch {
            print("AVAudioSession yapılandırılamadı: \(error.localizedDescription)")
        }
    }

    private func stopAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            print("AVAudioSession devre dışı bırakılıyor")
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("AVAudioSession başarıyla devre dışı bırakıldı.")
        } catch {
            print("AVAudioSession devre dışı bırakılamadı: \(error.localizedDescription)")
        }
    }
    
    private func setupViews() {
        // Remote ve local video görünümlerini ayarlıyoruz
        remoteVideoView = SendBirdVideoView(frame: view.frame)
        view.embed(remoteVideoView)
        remoteVideoView.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        
        setupLocalVideoView()
        setupRemoteAudioStatusLabel() // Yeni eklenen ses durumu label'ı için çağrı
        
        call.updateRemoteVideoView(remoteVideoView)
        call.updateLocalVideoView(localVideoView)
    }
    
    private func setupRemoteAudioStatusLabel() {
        view.addSubview(remoteAudioStatusLabel)
        remoteAudioStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            remoteAudioStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            remoteAudioStatusLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -150)
        ])
    }

    private func setupLocalVideoView() {
        print("Yerel video görünümü oluşturuluyor")
        localVideoView = SendBirdVideoView()
        localVideoView.translatesAutoresizingMaskIntoConstraints = false
        localVideoView.backgroundColor = .black.withAlphaComponent(0.6)
        localVideoView.layer.cornerRadius = 8
        localVideoView.clipsToBounds = true
        localVideoView.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        view.addSubview(localVideoView)
        
        NSLayoutConstraint.activate([
            localVideoView.widthAnchor.constraint(equalToConstant: 120),
            localVideoView.heightAnchor.constraint(equalToConstant: 160),
            localVideoView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            localVideoView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
        print("Yerel video görünümü başarıyla oluşturuldu")
    }
    
    private func setupEndButton() {
        print("Çağrıyı sonlandırma butonu yapılandırılıyor")
        endButton.setTitle("End Call", for: .normal)
        endButton.tintColor = .red
        endButton.translatesAutoresizingMaskIntoConstraints = false
        endButton.addTarget(self, action: #selector(didTapEndCallButton), for: .touchUpInside)
        
        view.addSubview(endButton)
        
        NSLayoutConstraint.activate([
            endButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            endButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100)
        ])
        print("Çağrıyı sonlandırma butonu başarıyla yapılandırıldı")
    }
    
    @objc private func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        if interruptionType == .ended {
            setupAudioSession()
            print("Ses kesintisinden sonra ses oturumu yeniden etkinleştirildi.")
        } else if interruptionType == .began {
            print("Ses kesintisi başladı.")
        }
    }
    
    @objc private func didTapEndCallButton() {
        call.end()
        stopAudioSession()
        print("Çağrı sonlandırıldı.")
    }
}

// SendBirdCalls delegate uygulaması
extension CallingViewController: DirectCallDelegate {
    func didConnect(_ call: DirectCall) {
        recentCallId = call.callId
        print("Çağrı bağlandı ve mikrofon etkinleştirildi.")
        call.unmuteMicrophone()
    }
    
    func didEnd(_ call: DirectCall) {
        stopAudioSession()
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: true, completion: {
                print("Çağrı başarıyla tamamlandı.")
            })
        }
    }
    
    // Karşı tarafın ses durumu değişikliklerini dinleyen metod
    func didRemoteAudioSettingsChange(_ call: DirectCall) {
        if call.isRemoteAudioEnabled {
            remoteAudioStatusLabel.text = "Karşı taraf sesi açık."
            remoteAudioStatusLabel.isHidden = false
        } else {
            remoteAudioStatusLabel.text = "Karşı taraf sessizde."
            remoteAudioStatusLabel.isHidden = false
        }
    }
}

// UIView için embed yardımı
extension UIView {
    func embed(_ subview: UIView) {
        addSubview(subview)
        subview.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            subview.leadingAnchor.constraint(equalTo: leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: trailingAnchor),
            subview.topAnchor.constraint(equalTo: topAnchor),
            subview.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
