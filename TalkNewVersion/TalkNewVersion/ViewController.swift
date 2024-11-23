import UIKit
import SendBirdCalls

class ViewController: UIViewController {
    // Kullanıcı girişi için metin alanları ve butonlar
    @IBOutlet weak var userIdTextField: UITextField!
    @IBOutlet weak var authenticateButton: UIButton!
    @IBOutlet weak var callerIdTextField: UITextField!
    
    // Kullanıcılar ve erişim tokenlerini tutan bir sözlük
    private let userTokens = [
        "Fatih": "782ede29ad4c39a16dae55ee77049bb8bb35ac4b",
        "Hakan": "5f5df8561cbc40b90018dadc582b215ad0030320"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Doğrulama butonuna tıklama eylemini ekler
        self.authenticateButton.addTarget(self, action: #selector(authenticate), for: .touchUpInside)
    }
    
    // Çağrı başlatma butonuna tıklanınca çalışır
    @IBAction func didTapDialButton(_ sender: Any) {
        // Arayan kullanıcı kimliğini alır ve doğrular
        guard let callerId = callerIdTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !callerId.isEmpty else {
            print("Çağrı yapan kimliği gerekli")
            return
        }
        
        // Çağrı başlatma parametreleri oluşturulur
        let dialParams = DialParams(calleeId: callerId, isVideoCall: true)
        
        // SendBird üzerinden çağrı başlatılır
        SendBirdCall.dial(with: dialParams) { [weak self] call, error in
            if let error = error {
                print("Çağrı başlatılamadı: \(error.localizedDescription)")
                return
            }
            
            guard let call = call else {
                print("Çağrı oluşturulamadı.")
                return
            }
            
            // Çağrı başlatılırsa, görüşme ekranı açılır
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let callingVC = storyboard.instantiateViewController(withIdentifier: "CallingViewController") as? CallingViewController {
                callingVC.modalPresentationStyle = .fullScreen
                callingVC.call = call
                self?.present(callingVC, animated: true, completion: nil)
            }
        }
    }
    
    // Kullanıcı doğrulaması yapılır
    @objc func authenticate() {
        // Kullanıcı kimliği ve erişim tokenini doğrular
        guard let userId = userIdTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !userId.isEmpty,
              let accessToken = userTokens[userId] else {
            print("Kullanıcı kimliği gerekli ve tanımlı bir kullanıcı ile eşleşmeli")
            return
        }
        
        // Doğrulama parametreleri oluşturulur
        let authenticateParams = AuthenticateParams(userId: userId, accessToken: accessToken)
        
        // SendBird doğrulaması başlatılır
        SendBirdCall.authenticate(with: authenticateParams) { [weak self] (user, error) in
            guard let self = self else { return }
            guard let user = user, error == nil else {
                print("Doğrulama başarısız: \(error?.localizedDescription ?? "Bilinmeyen hata")")
                return
            }
            
            print("Başarıyla doğrulandı: \(user.userId), Erişim Tokeni: \(accessToken)")
            self.authenticateButton.setTitle("Çıkış Yap", for: .normal)
            self.userIdTextField.isHidden = true
            self.authenticateButton.removeTarget(self, action: #selector(self.authenticate), for: .touchUpInside)
            self.authenticateButton.addTarget(self, action: #selector(self.deauthenticate), for: .touchUpInside)
            
            // Bağlantının doğru çalıştığını test etmek için bir doğrulama isteği gönderir
            self.verifyAPIConnection()
        }
    }

    // SendBird bağlantısını doğrulamak için basit bir test işlevi
    func verifyAPIConnection() {
        guard let currentUser = SendBirdCall.currentUser else {
            print("Geçerli bir kullanıcı yok")
            return
        }
        
        print("Bağlantı aktif. Geçerli kullanıcı: \(currentUser.userId)")
    }
    
    // Çıkış yapma işlemi
    @objc func deauthenticate() {
        // SendBird hesabından çıkış yapılır
        SendBirdCall.deauthenticate { [weak self] (error) in
            guard let self = self else { return }
            guard error == nil else {
                print("Çıkış işlemi başarısız: \(error?.localizedDescription ?? "Bilinmeyen hata")")
                return
            }
            // Çıkış başarılıysa, giriş arayüzü güncellenir
            self.authenticateButton.setTitle("Giriş Yap", for: .normal)
            self.userIdTextField.isHidden = false
            self.authenticateButton.removeTarget(self, action: #selector(self.deauthenticate), for: .touchUpInside)
            self.authenticateButton.addTarget(self, action: #selector(self.authenticate), for: .touchUpInside)
            print("SendBirdCalls'dan başarıyla çıkış yapıldı")
        }
    }
}
