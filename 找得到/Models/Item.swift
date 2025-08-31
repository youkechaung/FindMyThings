import Foundation

struct Item: Identifiable, Codable, Equatable {
    let id: UUID
    var itemNumber: String // 物品编号
    var name: String
    var location: String
    var description: String
    var category: String
    var estimatedPrice: Double
    var isInUse: Bool
    var lastUsedDate: Date?
    var useCount: Int
    var purchaseDate: Date?
    var maintenanceInterval: TimeInterval? // 保养间隔（秒）
    var lastMaintenanceDate: Date?
    var imageData: Data?
    var dateCreated: Date
    
    init(id: UUID = UUID(), itemNumber: String = "", name: String, location: String, description: String = "", category: String = "", estimatedPrice: Double = 0, isInUse: Bool = false, imageData: Data? = nil) {
        self.id = id
        self.itemNumber = itemNumber
        self.name = name
        self.location = location
        self.description = description
        self.category = category
        self.estimatedPrice = estimatedPrice
        self.isInUse = isInUse
        self.useCount = 0
        self.purchaseDate = Date()
        self.imageData = imageData
        self.dateCreated = Date()
    }
    
    // 计算使用频率（次数/天）
    var usageFrequency: Double {
        guard let purchaseDate = purchaseDate else { return 0 }
        let days = Date().timeIntervalSince(purchaseDate) / (24 * 3600)
        return days > 0 ? Double(useCount) / days : 0
    }
    
    // 检查是否需要保养
    var needsMaintenance: Bool {
        guard let interval = maintenanceInterval,
              let lastMaintenance = lastMaintenanceDate else {
            return false
        }
        return Date().timeIntervalSince(lastMaintenance) >= interval
    }
    
    // 计算闲置天数
    var idleDays: Int {
        guard let lastUsed = lastUsedDate else {
            return Int(Date().timeIntervalSince(purchaseDate ?? Date()) / (24 * 3600))
        }
        return Int(Date().timeIntervalSince(lastUsed) / (24 * 3600))
    }
    
    // 更新使用状态
    mutating func updateUsage(isInUse: Bool) {
        self.isInUse = isInUse
        if isInUse {
            self.lastUsedDate = Date()
            self.useCount += 1
        }
    }
    
    // 记录保养
    mutating func recordMaintenance() {
        self.lastMaintenanceDate = Date()
    }
}