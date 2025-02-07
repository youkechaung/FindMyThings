import Foundation

class LocationManager: ObservableObject {
    static let shared = LocationManager()
    
    @Published var locations: [Location] = []
    private let saveKey = "SavedLocations"
    
    init() {
        loadLocations()
    }
    
    func addLocation(_ name: String, parent: UUID? = nil) -> Location {
        let location = Location(name: name, parent: parent)
        locations.append(location)
        if let parentId = parent {
            if let index = locations.firstIndex(where: { $0.id == parentId }) {
                locations[index].children.append(location)
            }
        }
        saveLocations()
        return location
    }
    
    func getLocation(by id: UUID) -> Location? {
        locations.first { $0.id == id }
    }
    
    func getRootLocations() -> [Location] {
        locations.filter { $0.parent == nil }
    }
    
    func getChildren(of location: Location) -> [Location] {
        locations.filter { $0.parent == location.id }
    }
    
    private func saveLocations() {
        if let encoded = try? JSONEncoder().encode(locations) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadLocations() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Location].self, from: data) {
            locations = decoded
        }
    }
}
