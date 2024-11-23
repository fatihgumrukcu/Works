import UIKit
import SendBirdCalls
import PushKit
import AVFoundation
import CallKit

@main //Kamerayla artirilmis gerceklik,//Bolt.New // code kontrolu nasil daha iyi yapilabilirdi.
class AppDelegate: UIResponder, UIApplicationDelegate, PKPushRegistryDelegate, SendBirdCallDelegate, CXProviderDelegate {
    
    // BÖLÜM: Özellikler
    
    var window: UIWindow?
    var voipRegistry: PKPushRegistry?
    private let applicationId = "F99B20E6-EF54-4B02-A78B-4F20CD9E3C43"
    private var voipToken: Data?
    private var callKitProvider: CXProvider?
    private let callKitCallController = CXCallController()
    private var activeCall: DirectCall? // Mevcut çağrı
    
    // BÖLÜM: Uygulama Başlatma
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        SendBirdCall.configure(appId: applicationId)
        SendBirdCall.addDelegate(self, identifier: "AppDelegate")
        
        configureCallKit()
        checkMicrophonePermission()
        setupVoIPPushNotifications()
        
        if let currentUser = SendBirdCall.currentUser {
            print("Kullanıcı zaten giriş yapmış: \(currentUser.userId)")
            registerVoIPPushTokenIfNeeded()
        }
        
        return true
    }
    
    // BÖLÜM: Uygulama Kapanma
    
    func applicationWillTerminate(_ application: UIApplication) {
        print("Uygulama kapanıyor, mevcut çağrılar sonlandırılacak.")
        
        // Aktif çağrı varsa, çağrıyı sonlandır
        if let ongoingCall = activeCall {
            // SendBird Calls: Çağrıyı sonlandır
            ongoingCall.end()
            
            // CallKit: Çağrının sonlandırıldığını raporla
            if let uuid = ongoingCall.callUUID {
                let endReason: CXCallEndedReason = .remoteEnded // Veya uygun başka bir neden
                callKitProvider?.reportCall(with: uuid, endedAt: Date(), reason: endReason)
            }
            
            // CallKit: Çağrıyı sonlandırmak için işlemi iste
            let endCallAction = CXEndCallAction(call: ongoingCall.callUUID ?? UUID())
            let transaction = CXTransaction(action: endCallAction)
            
            callKitCallController.request(transaction) { error in
                if let error = error {
                    print("Çağrı sonlandırılamadı: \(error.localizedDescription)")
                } else {
                    print("Çağrı başarılı bir şekilde sonlandırıldı.")
                }
            }
            
            // Aktif çağrıyı temizle
            activeCall = nil
        } else {
            print("Sonlandırılacak aktif çağrı yok.")
        }
    }
    
    // Diğer bölümler (CallKit Ayarları, Mikrofon İzni Kontrolü, VoIP Bildirimleri vb.) aynı kalır.
    
    // BÖLÜM: CallKit Ayarları
    
    func configureCallKit() {
        let configuration = CXProviderConfiguration(localizedName: "TalkApp")
        configuration.supportsVideo = true
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]
        
        callKitProvider = CXProvider(configuration: configuration)
        callKitProvider?.setDelegate(self, queue: nil)
    }
    // BÖLÜM: Mikrofon İzni Kontrolu
    func checkMicrophonePermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("Mikrofon izni verildi.")
                    } else {
                        print("Mikrofon izni reddedildi, ayarlardan izin vermeniz gerekiyor.")
                    }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("Mikrofon izni verildi.")
                    } else {
                        print("Mikrofon izni reddedildi, ayarlardan izin vermeniz gerekiyor.")
                    }
                }
            }
        }
    }
    // BÖLÜM: VoIP Bildirimleri
    private func setupVoIPPushNotifications() {
        voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]
        print("VoIP push bildirimleri ayarlandı.")
    }
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        print("VoIP cihaz token'ı alındı.")
        voipToken = pushCredentials.token
        registerVoIPPushTokenIfNeeded()
    }
    func registerVoIPPushTokenIfNeeded() {
        guard let token = voipToken else {
            print("VoIP token alınamadı.")
            return
        }
        guard SendBirdCall.currentUser != nil else {
            print("Kullanıcı doğrulanmadı, VoIP Push Token kaydedilemedi.")
            return
        }
        SendBirdCall.registerVoIPPush(token: token, unique: true) { error in
            if let error = error {
                print("VoIP Push Token kaydedilemedi: \(error.localizedDescription)")
            } else {
                print("VoIP Push Token başarıyla kaydedildi.")
            }
        }
    }
    // BÖLÜM: Kullanıcı Kimlik Doğrulama
    func authenticateUser(with userId: String, accessToken: String) {
        let authenticateParams = AuthenticateParams(userId: userId, accessToken: accessToken)
        
        SendBirdCall.authenticate(with: authenticateParams) { user, error in
            if let error = error {
                print("Kullanıcı doğrulama hatası: \(error.localizedDescription)")
            } else if let user = user {
                print("Kullanıcı başarıyla doğrulandı: \(user.userId)")
                self.registerVoIPPushTokenIfNeeded()
            }
        }
    }
    // BÖLÜM: Gelen Çağrıyı İşleme
    func didStartRinging(_ call: DirectCall) {
        print("Gelen çağrı bildiriliyor.")
        activeCall = call
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: call.caller?.userId ?? "Bilinmeyen Çağrıcı")
        update.hasVideo = call.isVideoCall
        
        callKitProvider?.reportNewIncomingCall(with: UUID(), update: update) { error in
            if let error = error {
                print("Gelen çağrı bildirilemedi: \(error.localizedDescription)")
                call.end()
                self.activeCall = nil
            }
        }
    }
    // BÖLÜM: Görüşme Ekranına Geçiş
    private func presentCallingViewController(for call: DirectCall) {
        DispatchQueue.main.async {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let callingVC = storyboard.instantiateViewController(withIdentifier: "CallingViewController") as? CallingViewController {
                callingVC.call = call
                callingVC.modalPresentationStyle = .fullScreen
                UIViewController.topViewController?.present(callingVC, animated: true, completion: nil)
            }
        }
    }

    // BÖLÜM: Giden Çağrı Başlatma
    
    func startCall(to userId: String, isVideo: Bool) {
        let handle = CXHandle(type: .generic, value: userId)
        let startCallAction = CXStartCallAction(call: UUID(), handle: handle)
        startCallAction.isVideo = isVideo

        let transaction = CXTransaction(action: startCallAction)
        callKitCallController.request(transaction) { error in
            if let error = error {
                print("Giden çağrı başlatılamadı: \(error.localizedDescription)")
            } else {
                let dialParams = DialParams(calleeId: userId, isVideoCall: isVideo, callOptions: CallOptions())
                self.activeCall = SendBirdCall.dial(with: dialParams) { [weak self] call, error in
                    if let error = error {
                        print("Çağrı bağlanamadı: \(error.localizedDescription)")
                    } else if let call = call {
                        self?.activeCall = call
                        if isVideo {
                            self?.presentCallingViewController(for: call)
                        }
                    }
                }
            }
        }
    }
    
    // BÖLÜM: CXProviderDelegate Yöntemleri
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("Kullanıcı çağrıyı kabul etti.")
        if let call = activeCall {
            let acceptParams = AcceptParams(callOptions: CallOptions(isAudioEnabled: true, isVideoEnabled: call.isVideoCall))
            call.accept(with: acceptParams)
            if call.isVideoCall {
                presentCallingViewController(for: call)
            } else {
                print("Sesli arama yapılıyor, CallingViewController ekranına geçiş yapılmadı.")
            }
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("Çağrı sonlandırılıyor.")
        activeCall?.end()
        if let uuid = activeCall?.callUUID {
            let endReason: CXCallEndedReason = .remoteEnded
            callKitProvider?.reportCall(with: uuid, endedAt: Date(), reason: endReason)
        }
        activeCall = nil
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        print("Ses oturumu devre dışı bırakıldı.")
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: .allowBluetooth)
        try? AVAudioSession.sharedInstance().setActive(true)
        print("Ses oturumu etkinleştirildi.")
    }

    func providerDidReset(_ provider: CXProvider) {
        activeCall?.end()
        activeCall = nil
        print("CallKit sağlayıcısı sıfırlandı; tüm çağrılar sonlandırıldı.")
    }
}

// BÖLÜM: UIViewController Uzantısı

extension UIViewController {
    static var topViewController: UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        
        var topController = keyWindow.rootViewController
        while let presentedViewController = topController?.presentedViewController {
            topController = presentedViewController
        }
        return topController
    }
}
