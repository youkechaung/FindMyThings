import Foundation
import Supabase
import UIKit // Add this import

class SupabaseService: ObservableObject { // Conform to ObservableObject
    let client: Supabase.SupabaseClient

    init() {
        let SUPABASE_URL = "https://jtvmjaumvehtzfegivgx.supabase.co"
        let SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0dm1qYXVtdmVodHpmZWdpdmd4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU5NTMzMTAsImV4cCI6MjA3MTUyOTMxMH0.shDGUAKpH1RvMYg1_iHmTej2lOldqicpQx91Hi9eYEI"

        print("初始化 Supabase 客户端...")
        print("URL: \(SUPABASE_URL)")
        print("Key: \(SUPABASE_KEY.prefix(20))...")
        
        self.client = SupabaseClient(
            supabaseURL: URL(string: SUPABASE_URL)!,
            supabaseKey: SUPABASE_KEY
        )
        
        print("Supabase 客户端初始化完成")
    }
    
    // 测试网络连接（仅在需要时手动调用）
    public func testNetworkConnection() async {
        print("开始测试网络连接...")
        
        guard let url = URL(string: "https://jtvmjaumvehtzfegivgx.supabase.co") else {
            print("无效的URL")
            return
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                print("网络连接测试成功，状态码: \(httpResponse.statusCode)")
            }
        } catch {
            print("网络连接测试失败: \(error)")
            if let urlError = error as? URLError {
                print("URLError 代码: \(urlError.code.rawValue)")
                print("URLError 描述: \(urlError.localizedDescription)")
            }
        }
    }
    
    func uploadImage(imageData: Data, fileName: String) async throws -> String {
        // 压缩图片数据
        guard let image = UIImage(data: imageData) else {
            throw ImageUploadError.invalidImageData
        }
        guard let compressedImageData = image.jpegData(compressionQuality: 0.7) else {
            throw ImageUploadError.compressionFailed
        }
        
        let bucket = client.storage.from("item_images") // 假设有一个 bucket 叫 "item_images"
        let path = "\(UUID().uuidString)-\(fileName)"
        
        // 上传压缩后的文件
        let _ = try await bucket.upload(path: path, file: compressedImageData)
        
        // 获取公有 URL
        let url = try await bucket.getPublicURL(path: path)
        return url.absoluteString
    }
    
    enum ImageUploadError: Error, LocalizedError {
        case invalidImageData
        case compressionFailed
        case other(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidImageData: return "Invalid image data."
            case .compressionFailed: return "Image compression failed."
            case .other(let error): return error.localizedDescription
            }
        }
    }
    
    // User info structure for easyfind_userinfo table
    struct UserInfo: Codable {
        let user_id: String
        let user_name: String?
        let phone_number: String?
        let email: String?
        let created_at: String?
        let updated_at: String?
    }
    
    // MARK: - 应用内用户管理方法
    
    // 创建新用户
    func createUser(user: AppUser) async throws {
        print("Creating new user: \(user.email)")
        // 使用 upsert 来处理可能的重复插入
        _ = try await client.database
            .from("easyfind_userinfo")
            .upsert(user)
            .execute()
        print("Successfully created user: \(user.email)")
    }
    
    // 根据邮箱获取用户
    func getUserByEmail(email: String) async throws -> AppUser? {
        print("Fetching user by email: \(email)")
        let users: [AppUser] = try await client.database
            .from("easyfind_userinfo")
            .select()
            .eq("email", value: email)
            .execute()
            .value
        
        print("Found \(users.count) users with email: \(email)")
        return users.first
    }
    
    // 根据用户ID获取用户
    func getUserByID(userID: UUID) async throws -> AppUser? {
        print("Fetching user by ID: \(userID)")
        let users: [AppUser] = try await client.database
            .from("easyfind_userinfo")
            .select()
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
        
        print("Found \(users.count) users with ID: \(userID)")
        return users.first
    }
    
    // 更新用户信息
    func updateUser(user: AppUser) async throws {
        print("Updating user: \(user.email)")
        _ = try await client.database
            .from("easyfind_userinfo")
            .update(user)
            .eq("id", value: user.id.uuidString)
            .execute()
        print("Successfully updated user: \(user.email)")
    }
    
    // 删除用户
    func deleteUser(userID: UUID) async throws {
        print("Deleting user: \(userID)")
        _ = try await client.database
            .from("easyfind_userinfo")
            .delete()
            .eq("id", value: userID.uuidString)
            .execute()
        print("Successfully deleted user: \(userID)")
    }
    
    // Fetch user info from easyfind_userinfo table
    func fetchUserInfo(userID: UUID) async throws -> UserInfo? {
        print("Fetching user info for user: \(userID)")
        let userInfos: [UserInfo] = try await client.database
            .from("easyfind_userinfo")
            .select()
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
        
        print("Fetched user info: \(userInfos.first?.user_name ?? "No name")")
        return userInfos.first
    }

    // New: Fetch items for a specific user
    func fetchItems(userID: UUID) async throws -> [Item] {
        print("Fetching items for user: \(userID)")
        let items: [Item] = try await client.database
            .from("items")
            .select()
            .eq("user_id", value: userID.uuidString) // Filter by user_id
            .order("created_at", ascending: false)
            .execute()
            .value
        print("Fetched \(items.count) items for user \(userID).")
        return items
    }

    // New: Save (upsert) multiple items for a specific user
    func saveItems(items: [Item], userID: UUID) async throws {
        print("Saving \(items.count) items for user: \(userID)")
        // Ensure each item has the correct userID before upserting
        let itemsWithUserID = items.map { item -> Item in
            var mutableItem = item
            mutableItem.userID = userID
            return mutableItem
        }

        _ = try await client.database
            .from("items")
            .upsert(itemsWithUserID)
            .execute()
        print("Successfully saved (upserted) items for user \(userID).")
    }

    // Existing: Upload single item (already modified to include userID, etc.)
    func uploadItem(item: Item) async throws { // Renamed from addItem to uploadItem for clarity with Supabase
        print("Uploading single item to Supabase: \(item.name)")
        _ = try await client.database
            .from("items")
            .insert(item)
            .execute()
        print("Successfully uploaded item: \(item.name)")
    }

    // Existing: Update single item
    func updateItem(item: Item, userID: UUID) async throws {
        print("Updating single item in Supabase: \(item.name)")
        _ = try await client.database
            .from("items")
            .update(item)
            .eq("id", value: item.id.uuidString)
            .eq("user_id", value: userID.uuidString) // Ensure user owns the item
            .execute()
        print("Successfully updated item: \(item.name)")
    }

    // Existing: Delete single item
    func deleteItem(item: Item, userID: UUID) async throws {
        print("Deleting single item from Supabase: \(item.name)")
        _ = try await client.database
            .from("items")
            .delete()
            .eq("id", value: item.id.uuidString)
            .eq("user_id", value: userID.uuidString) // Ensure user owns the item
            .execute()
        print("Successfully deleted item: \(item.name)")
    }
}
