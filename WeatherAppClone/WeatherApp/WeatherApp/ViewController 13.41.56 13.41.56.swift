import UIKit
import CoreLocation

struct WeatherInfo {
    let cityName: String
    let temperature: Double
    let condition: String
}



class ViewController: UIViewController, CLLocationManagerDelegate, UITableViewDataSource, UITableViewDelegate, UIPickerViewDataSource, UIPickerViewDelegate {

   
    @IBOutlet weak var appBimage: UIImageView!
    @IBOutlet weak var provincePickerView: UIPickerView!
    @IBOutlet weak var lonLabel: UILabel!
    @IBOutlet weak var latLabel: UILabel!
    @IBOutlet weak var weatherLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var provinceLabel: UILabel!
    @IBOutlet weak var degreeLabel: UILabel!
    @IBOutlet weak var provinceTable: UITableView!

    let locationManager = CLLocationManager()
    var weatherData: [WeatherInfo] = [] // İllere ait hava durumu verileri
    let provinces = ["İstanbul", "Ankara", "İzmir", "Bursa", "Antalya", "Adana"]

    override func viewDidLoad() {
        super.viewDidLoad()
       
        // Konum yöneticisini ayarla
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation() // Otomatik konum güncelleme başlat

        // TableView ve PickerView ayarları
        provinceTable.dataSource = self
        provinceTable.delegate = self
        provinceTable.backgroundColor = UIColor.clear

        provincePickerView.dataSource = self
        provincePickerView.delegate = self
        view.bringSubviewToFront(appBimage)
        // Türkiye'deki illerin hava durumunu çek (PickerView için kullanabilirsiniz)
        // fetchWeatherForProvinces() // Eğer sadece kullanıcı konumu kullanacaksanız bu satırı kaldırabilirsiniz.
   

    }

    // MARK: - CLLocationManager Delegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            fetchWeather(lat: lat, lon: lon)
            locationManager.stopUpdatingLocation() // Konum güncellemelerini durdur
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        let okButton = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(okButton)
        self.present(alert, animated: true, completion: nil)
    }

    // MARK: - Weather Fetching

    func fetchWeather(lat: Double, lon: Double) {
        let urlString = "http://api.weatherapi.com/v1/current.json?key=33a86cf25dcb4130abf85352242409&q=\(lat),\(lon)&aqi=no"
        guard let url = URL(string: urlString) else { return }

        let session = URLSession.shared
        let task = session.dataTask(with: url) { (data, response, error) in
            if error != nil {
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Error", message: error?.localizedDescription, preferredStyle: .alert)
                    let okButton = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(okButton)
                    self.present(alert, animated: true, completion: nil)
                }
            } else {
                if let data = data {
                    do {
                        if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                            DispatchQueue.main.async {
                                self.updateUI(with: jsonResponse)
                            }
                        }
                    } catch {
                        print("Error parsing JSON")
                    }
                }
            }
        }
        task.resume()
    }

    func fetchWeatherForProvinces() {
        let provinces = ["Istanbul", "Ankara", "Izmir", "Bursa", "Antalya", "Adana"] // Örnek iller
        
        for province in provinces {
            let urlString = "http://api.weatherapi.com/v1/current.json?key=33a86cf25dcb4130abf85352242409&q=\(province)&aqi=no"
            guard let url = URL(string: urlString) else { continue }
            
            let session = URLSession.shared
            let task = session.dataTask(with: url) { (data, response, error) in
                if error != nil {
                    return
                }
                if let data = data {
                    do {
                        if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any],
                           let current = jsonResponse["current"] as? [String: Any],
                           let temp_c = current["temp_c"] as? Double,
                           let condition = current["condition"] as? [String: Any],
                           let text = condition["text"] as? String {
                            
                            let weatherInfo = WeatherInfo(cityName: province, temperature: temp_c, condition: text)
                            self.weatherData.append(weatherInfo)
                            
                            DispatchQueue.main.async {
                                self.provinceTable.reloadData()
                            }
                        }
                    } catch {
                        print("Error parsing JSON")
                    }
                }
            }
            task.resume()
        }
    }

    func updateUI(with jsonResponse: [String: Any]) {
        // Sabit olarak Türkiye'yi ayarlayın
        self.locationLabel.text = "Türkiye"
        
        if let location = jsonResponse["location"] as? [String: Any] {
            if let name = location["name"] as? String {
                self.provinceLabel.text = name // İlin ismini gösterin
            }
            if let lat = location["lat"] as? Double {
                self.latLabel.text = String(lat) // Latitude gösterimi
            }
            if let lon = location["lon"] as? Double {
                self.lonLabel.text = String(lon) // Longitude gösterimi
            }
        }

        if let current = jsonResponse["current"] as? [String: Any] {
            if let temp_c = current["temp_c"] as? Double {
                self.degreeLabel.text = String(temp_c) + "°C" // Sıcaklık bilgisini gösterin
            }
            if let condition = current["condition"] as? [String: Any],
               let _ = condition["text"] as? String {
                // Durumu güncelleyebilirsiniz, şimdilik kullanılmıyor
            }
        }
    }


    // MARK: - UIPickerView DataSource

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1 // Tek bir komponent
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return provinces.count // İl sayısı
    }

    // MARK: - UIPickerView Delegate

    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let title = provinces[row] // Seçilen il
        let attributedString = NSAttributedString(string: title, attributes: [
            NSAttributedString.Key.foregroundColor: UIColor.white, // Yazı rengi beyaz
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18, weight: .medium) // Yazı tipi ve boyutu
        ])
        return attributedString
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectedProvince = provinces[row] // Seçilen il
        
        // Seçilen ilin hava durumunu çek ve UI'yı güncelle
        fetchWeatherForSelectedProvince(province: selectedProvince)
    }

    func fetchWeatherForSelectedProvince(province: String) {
        let urlString = "http://api.weatherapi.com/v1/current.json?key=33a86cf25dcb4130abf85352242409&q=\(province)&aqi=no"
        guard let url = URL(string: urlString) else { return }

        let session = URLSession.shared
        let task = session.dataTask(with: url) { (data, response, error) in
            if error != nil {
                return
            }

            if let data = data {
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any],
                       let location = jsonResponse["location"] as? [String: Any],
                       let lat = location["lat"] as? Double,
                       let lon = location["lon"] as? Double,
                       let current = jsonResponse["current"] as? [String: Any],
                       let temp_c = current["temp_c"] as? Double,
                       let condition = current["condition"] as? [String: Any],
                       let conditionText = condition["text"] as? String {
                        
                        let weatherInfo = WeatherInfo(cityName: province, temperature: temp_c, condition: conditionText)
                        self.weatherData = [weatherInfo] // Tekil il verisi alındı
                        
                        DispatchQueue.main.async {
                            // Geçiş animasyonları
                            UIView.animate(withDuration: 0.5, animations: {
                                // Etiketlerin kaybolması
                                self.provinceLabel.alpha = 0
                                self.degreeLabel.alpha = 0
                                self.weatherLabel.alpha = 0
                                self.latLabel.alpha = 0
                                self.lonLabel.alpha = 0
                            }) { _ in
                                // Güncellemeleri yap
                                self.provinceLabel.text = province
                                self.degreeLabel.text = String(temp_c) + "°C" // Sıcaklık bilgisi
                                self.weatherLabel.text = conditionText // Hava durumu bilgisi
                                self.latLabel.text = String(lat) // Enlem bilgisi
                                self.lonLabel.text = String(lon) // Boylam bilgisi

                                // Etiketlerin yeniden görünmesi
                                UIView.animate(withDuration: 0.5) {
                                    self.provinceLabel.alpha = 1
                                    self.degreeLabel.alpha = 1
                                    self.weatherLabel.alpha = 1
                                    self.latLabel.alpha = 1
                                    self.lonLabel.alpha = 1
                                }
                            }
                        }
                    }
                } catch {
                    print("Error parsing JSON")
                }
            }
        }
        task.resume()
    }



    // MARK: - UITableView DataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return weatherData.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProvinceCell", for: indexPath)

        let weatherInfo = weatherData[indexPath.row]
        cell.textLabel?.text = "\(weatherInfo.cityName): \(weatherInfo.temperature)°C, \(weatherInfo.condition)"

        // Yazı tipini ve rengini ayarlama
        cell.textLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium) // Yazı tipini normal yap
        cell.textLabel?.textColor = .white // Yazı rengini beyaz yap
        cell.textLabel?.textAlignment = .center
        // Hücre arka planı ayarları
        cell.selectionStyle = .none
        cell.backgroundColor = UIColor.clear // Arka planı saydam yap

        return cell
    }

    // MARK: - UITableView Delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.textLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold) // Seçildiğinde yazıyı büyüt
        }
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.textLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium) // Seçim kaldırıldığında orijinal boyuta döndür
        }
    }
}

