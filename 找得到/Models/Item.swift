import Foundation

struct Item: Identifiable, Codable, Equatable {
    let id: UUID
    var itemNumber: String // 物品编号
    var name: String
    var location: String
    var description: String
    var categoryLevel1: String // 一级分类
    var categoryLevel2: String? // 二级分类
    var categoryLevel3: String? // 三级分类
    var estimatedPrice: Double
    var isInUse: Bool
    var lastUsedDate: Date?
    var useCount: Int
    var purchaseDate: Date?
    var maintenanceInterval: TimeInterval? // 保养间隔（秒）
    var lastMaintenanceDate: Date?
    var imageURL: String? // Changed from imageData: Data?
    var createdAt: Date // Changed from dateCreated
    var userID: UUID? // New: Link to Supabase user ID
    var userName: String? // New: User name from easyfind_userinfo
    var phoneNumber: String? // New: Phone number from easyfind_userinfo

    enum CodingKeys: String, CodingKey {
        case id, name, location, description
        case itemNumber = "item_number" // Map itemNumber to item_number
        case estimatedPrice = "estimated_price" // Map estimatedPrice to estimated_price
        case isInUse = "is_in_use" // Map isInUse to is_in_use
        case lastUsedDate = "last_used_date" // Map lastUsedDate to last_used_date
        case useCount = "use_count" // Map useCount to use_count
        case purchaseDate = "purchase_date" // Map purchaseDate to purchase_date
        case maintenanceInterval = "maintenance_interval" // Map maintenanceInterval to maintenance_interval
        case lastMaintenanceDate = "last_maintenance_date" // Map lastMaintenanceDate to last_maintenance_date
        case imageURL = "image_url" // Map imageURL to image_url
        case createdAt = "created_at" // Map createdAt to created_at
        case userID = "user_id" // Map userID to user_id
        case userName = "user_name" // Map userName to user_name
        case phoneNumber = "phone_number" // Map phoneNumber to phone_number
        case categoryLevel1 = "category_level_1"
        case categoryLevel2 = "category_level_2"
        case categoryLevel3 = "category_level_3"
    }

    init(id: UUID = UUID(), itemNumber: String = "", name: String, location: String, description: String = "", categoryLevel1: String = "", categoryLevel2: String? = nil, categoryLevel3: String? = nil, estimatedPrice: Double = 0, isInUse: Bool = false, lastUsedDate: Date? = nil, useCount: Int = 0, purchaseDate: Date? = Date(), maintenanceInterval: TimeInterval? = nil, lastMaintenanceDate: Date? = nil, imageURL: String? = nil, userID: UUID? = nil, userName: String? = nil, phoneNumber: String? = nil) {
        self.id = id
        self.itemNumber = itemNumber
        self.name = name
        self.location = location
        self.description = description
        self.categoryLevel1 = categoryLevel1
        self.categoryLevel2 = categoryLevel2
        self.categoryLevel3 = categoryLevel3
        self.estimatedPrice = estimatedPrice
        self.isInUse = isInUse
        self.lastUsedDate = lastUsedDate
        self.useCount = useCount
        self.purchaseDate = purchaseDate
        self.maintenanceInterval = maintenanceInterval
        self.lastMaintenanceDate = lastMaintenanceDate
        self.imageURL = imageURL
        self.createdAt = Date()
        self.userID = userID
        self.userName = userName
        self.phoneNumber = phoneNumber
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