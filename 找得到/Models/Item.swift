import Foundation

struct Item: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var location: String
    var category: String
    var estimatedPrice: Double
    var imageData: Data?
    var isInUse: Bool
    let dateCreated: Date
    
    init(name: String, description: String, location: String, category: String, estimatedPrice: Double, imageData: Data?) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.location = location
        self.category = category
        self.estimatedPrice = estimatedPrice
        self.imageData = imageData
        self.isInUse = false
        self.dateCreated = Date()
    }
}