import Foundation
import Supabase
import UIKit // Add this import

class SupabaseService: ObservableObject { // Conform to ObservableObject
    let client: Supabase.SupabaseClient

    init() {
        let SUPABASE_URL = "https://jtvmjaumvehtzfegivgx.supabase.co"
        let SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0dm1qYXVtdmVodHpmZWdpdmd4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU5NTMzMTAsImV4cCI6MjA3MTUyOTMxMH0.shDGUAKpH1RvMYg1_iHmTej2lOldqicpQx91Hi9eYEI"

        self.client = SupabaseClient(
            supabaseURL: URL(string: SUPABASE_URL)!,
            supabaseKey: SUPABASE_KEY
        )
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
