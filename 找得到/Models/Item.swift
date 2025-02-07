import Foundation
import SwiftUI

struct Item: Identifiable, Codable {
    var id = UUID()
    var name: String
    var description: String
    var location: String
    var imageData: Data?
    var isInUse: Bool
    var dateCreated: Date
    
    init(name: String = "", description: String = "", location: String = "", imageData: Data? = nil) {
        self.name = name
        self.description = description
        self.location = location
        self.imageData = imageData
        self.isInUse = false
        self.dateCreated = Date()
    }
}
