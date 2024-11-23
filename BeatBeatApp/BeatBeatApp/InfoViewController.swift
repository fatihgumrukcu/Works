import UIKit

class InfoViewController: UIViewController {
    
    @IBOutlet weak var artistImageView: UIImageView!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var songTitleLabel: UILabel!

    var artistName: String?
    var songTitle: String?
    var artworkURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        artistLabel.text = artistName ?? "Bilinmiyor"
        songTitleLabel.text = songTitle ?? "Bilinmiyor"
        
        if let url = artworkURL {
            loadArtistImage(from: url)
        }
    }

    private func loadArtistImage(from url: URL) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            DispatchQueue.main.async {
                self.artistImageView.image = UIImage(data: data)
            }
        }
        task.resume()
    }
}
