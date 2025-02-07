import Foundation

struct Location: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var parent: UUID?
    var children: [Location] = []
    
    var fullPath: String {
        var path = [name]
        var currentParent = parent
        var visited = Set<UUID>() // 防止循环引用
        
        while let parentId = currentParent,
              !visited.contains(parentId) {
            visited.insert(parentId)
            if let parentLocation = LocationManager.shared.getLocation(by: parentId) {
                path.insert(parentLocation.name, at: 0)
                currentParent = parentLocation.parent
            } else {
                break
            }
        }
        
        return path.joined(separator: " - ")
    }
}
