import Foundation

struct Tuning: Codable, Identifiable, Hashable, Equatable {
    var id = UUID() // JSON'da olmayan benzersiz kimlik
    let name: String
    let description: String
    let tuning: [StringNote]
    
    // id özelliğini JSON çözümlemesinden hariç tutmak için CodingKeys
    private enum CodingKeys: String, CodingKey {
        case name, description, tuning
    }
}

struct StringNote: Codable, Identifiable, Hashable, Equatable {
    var id = UUID() // JSON'da olmayan benzersiz kimlik
    let string: Int
    let note: String
    let frequency: Double
    
    private enum CodingKeys: String, CodingKey {
        case string, note, frequency
    }
}
