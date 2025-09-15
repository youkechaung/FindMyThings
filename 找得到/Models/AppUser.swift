import Foundation

// 应用内用户模型
struct AppUser: Codable, Identifiable {
    let id: UUID
    let username: String
    let email: String
    let password: String // 直接存储密码
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case username = "user_name"
        case email
        case password
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: UUID = UUID(), username: String, email: String, password: String) {
        self.id = id
        self.username = username
        self.email = email
        self.password = password
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // 自定义编码方法，将 UUID 转换为数据库兼容的格式
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.uuidString, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(email, forKey: .email)
        // 将密码转换为字符串格式进行编码
        try container.encode(String(password), forKey: .password)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
    
    // 自定义解码方法，处理int8类型密码
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try container.decode(String.self, forKey: .id)
        self.id = UUID(uuidString: idString) ?? UUID()
        self.username = try container.decode(String.self, forKey: .username)
        self.email = try container.decode(String.self, forKey: .email)
        
        // 处理密码字段，可能为Int8或String类型
        if let passwordInt = try? container.decode(Int64.self, forKey: .password) {
            self.password = String(passwordInt)
        } else {
            self.password = try container.decode(String.self, forKey: .password)
        }
        
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

// 用户注册请求模型
struct UserRegistrationRequest: Codable {
    let username: String
    let email: String
    let password: String
}

// 用户登录请求模型
struct UserLoginRequest: Codable {
    let email: String
    let password: String
}

// 用户响应模型（不包含密码信息）
struct UserResponse: Codable {
    let id: UUID
    let username: String
    let email: String
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case username = "user_name"
        case email
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // 自定义编码方法，将 UUID 转换为数据库兼容的格式
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.uuidString, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(email, forKey: .email)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    // 自定义解码方法，将数据库中的值转换为 UUID
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try container.decode(String.self, forKey: .id)
        self.id = UUID(uuidString: idString) ?? UUID()
        self.username = try container.decode(String.self, forKey: .username)
        self.email = try container.decode(String.self, forKey: .email)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}
