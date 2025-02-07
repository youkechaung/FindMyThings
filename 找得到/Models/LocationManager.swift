import Foundation

class LocationManager: ObservableObject {
    static let shared = LocationManager()
    
    @Published var locations: [Location] = []
    private let saveKey = "SavedLocations"
    
    init() {
        loadLocations()
        if locations.isEmpty {
            // 添加一些预设位置
            let study = addLocation("书房")
            let desk1 = addLocation("1号书桌", parent: study.id)
            let desk2 = addLocation("2号书桌", parent: study.id)
            
            addLocation("抽屉", parent: desk1.id)
            addLocation("桌面收纳盒", parent: desk1.id)
            addLocation("显示器底座", parent: desk1.id)
            
            addLocation("键盘托架", parent: desk2.id)
            addLocation("抽屉", parent: desk2.id)
            
            let bedroom = addLocation("卧室")
            let closet = addLocation("衣柜", parent: bedroom.id)
            
            addLocation("上层", parent: closet.id)
            addLocation("中层", parent: closet.id)
            addLocation("下层", parent: closet.id)
            
            let kitchen = addLocation("厨房")
            let cabinet = addLocation("橱柜", parent: kitchen.id)
            
            addLocation("调味料区", parent: cabinet.id)
            addLocation("餐具区", parent: cabinet.id)
            addLocation("锅具区", parent: cabinet.id)
        }
    }
    
    func addLocation(_ name: String, parent: UUID? = nil) -> Location {
        let location = Location(name: name, parent: parent)
        locations.append(location)
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
    
    func deleteLocation(_ location: Location) {
        // 递归删除所有子位置
        let children = getChildren(of: location)
        for child in children {
            deleteLocation(child)
        }
        locations.removeAll { $0.id == location.id }
        saveLocations()
    }
}
