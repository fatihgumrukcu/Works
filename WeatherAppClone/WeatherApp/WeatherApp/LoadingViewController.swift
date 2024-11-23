import UIKit

class LoadingViewController: UIViewController {
    
    @IBOutlet weak var logoImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Logo animasyonu
        animateLogo()
    }

    func animateLogo() {
        logoImageView.alpha = 0 // Başlangıçta görünmez
        UIView.animate(withDuration: 1.0, animations: {
            self.logoImageView.alpha = 1 // Görünür hale getir
            self.logoImageView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2) // Logo büyüsün
        }) { _ in
            UIView.animate(withDuration: 1.0, animations: {
                self.logoImageView.transform = CGAffineTransform.identity // Boyutunu eski haline getir
            }) { _ in
                // Ana ekrana geçiş
                self.performSegue(withIdentifier: "showMainScreen", sender: nil)
            }
        }
    }
}
