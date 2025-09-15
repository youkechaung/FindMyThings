import Foundation
import SwiftUI
import Supabase
import UIKit
import Combine

@MainActor
class ItemManager: ObservableObject {
    @Published var items: [Item] = []
    @Published var categoryOrder: [String] = [] // 添加类别排序
    private let saveKey = "SavedItems"
    private let categoriesKey = "SavedCategories"
    private let categoryOrderKey = "CategoryOrder"
    private let nextItemNumberKey = "NextItemNumber" // 添加下一个物品编号的存储键
    
    private let authService: AuthService
    private let supabaseService: SupabaseService
    private var authStateChangeTask: Task<Void, Never>?
    
    // 默认类别
    private let defaultCategories = [
        "电子产品",
        "衣服",
        "家具",
        "书籍",
        "厨具",
        "运动用品",
        "化妆品",
        "工具",
        "玩具",
        "其他"
    ]
    
    // 用户使用过的类别（包括默认类别）
    @Published var usedCategories: [String] = []
    
    init(authService: AuthService, supabaseService: SupabaseService) {
        self.authService = authService
        self.supabaseService = supabaseService
        
        // Load initial data
        loadCategories()
        loadCategoryOrder()
        ensureDefaultCategories()
        
        // Set up auth state observation
        authStateChangeTask = Task { [weak self] in
            guard let self = self else { return }
            // Create a reference to the publisher on the main thread
            let isAuthenticatedPublisher = self.authService.$isAuthenticated
            // Observe the publisher
            for await isAuthenticated in isAuthenticatedPublisher.values {
                // 避免重复处理相同的认证状态
                if isAuthenticated != self.authService.isAuthenticated {
                    await self.handleAuthStateChange()
                }
            }
        }
        
        // 优先从本地加载
        loadLocalItems()
        
        // 如果本地没有数据且用户已登录，则从Supabase加载
        if authService.isAuthenticated && items.isEmpty {
            Task { await loadItemsFromSupabase() }
        }
        
        assignItemNumbers()
        updateCategoriesFromExistingItems()
    }
    
    deinit {
        authStateChangeTask?.cancel()
    }

    private func handleAuthStateChange() async {
        print("Auth state changed. Current state: \(authService.isAuthenticated)")
        
        if authService.isAuthenticated {
            // 用户登录后，先检查本地是否有数据
            if items.isEmpty {
                print("Local items are empty, loading from Supabase.")
                await loadItemsFromSupabase()
            } else {
                print("Using local items, will sync with Supabase in background.")
                // 在后台异步同步本地数据到Supabase
                Task {
                    do {
                        if let userID = authService.currentUser?.id {
                            try await self.supabaseService.saveItems(items: self.items, userID: userID)
                            print("Local items synced with Supabase successfully.")
                        }
                    } catch {
                        print("Error syncing items to Supabase: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            print("User logged out, clearing remote items and loading local.")
            self.items = [] // Clear current items (already on main thread)
            loadLocalItems() // Load from UserDefaults or keep empty
        }
    }

    // MARK: - 编号管理
    
    // 获取下一个物品编号
    private func getNextItemNumber() -> Int {
        let currentNumber = UserDefaults.standard.integer(forKey: nextItemNumberKey)
        let nextNumber = currentNumber + 1
        UserDefaults.standard.set(nextNumber, forKey: nextItemNumberKey)
        return nextNumber
    }
    
    // 生成新的物品编号（全局唯一）
    func generateItemNumber() -> String {
        let number = getNextItemNumber()
        return String(format: "%06d", number) // 格式：000001
    }
    
    // 为现有物品生成编号（如果没有编号或格式不正确）
    func assignItemNumbers() {
        var hasChanges = false
        for i in 0..<items.count {
            let currentNumber = items[i].itemNumber
            // 检查编号是否为空或格式不正确（不是6位数字）
            if currentNumber.isEmpty || currentNumber.count != 6 || !currentNumber.allSatisfy({ $0.isNumber }) {
                items[i].itemNumber = generateItemNumber()
                hasChanges = true
            }
        }
        if hasChanges {
            // 只保存到本地，避免触发 Supabase 操作
            if let encoded = try? JSONEncoder().encode(items) {
                UserDefaults.standard.set(encoded, forKey: saveKey)
            }
            print("Assigned item numbers and saved locally.")
        }
    }
    
    // MARK: - 基本操作
    
    func addItem(_ item: Item) async throws {
        var newItem = item
        
        // 如果已认证，设置用户ID和用户信息
        if let userID = await authService.currentUser?.id {
            newItem.userID = userID
            
            // 获取用户信息（姓名和电话号码）
            do {
                if let userInfo = try await supabaseService.fetchUserInfo(userID: userID) {
                    newItem.userName = userInfo.user_name
                    newItem.phoneNumber = userInfo.phone_number
                    print("获取到用户信息: 姓名=\(userInfo.user_name ?? "无"), 电话=\(userInfo.phone_number ?? "无")")
                } else {
                    print("未找到用户信息，使用默认值")
                }
            } catch {
                print("获取用户信息失败: \(error.localizedDescription)")
                // 继续执行，不因为获取用户信息失败而中断
                // 设置默认值
                newItem.userName = nil
                newItem.phoneNumber = nil
            }
        }

        // 如果物品没有编号，自动生成
        if newItem.itemNumber.isEmpty {
            newItem.itemNumber = generateItemNumber()
        }
        
        // 立即保存到本地，提供快速响应
        DispatchQueue.main.async {
            self.items.append(newItem)
            self.saveItems()
            
            // 确保新物品的类别也被添加到usedCategories中
            if !newItem.categoryLevel1.isEmpty {
                self.addCategory(level1: newItem.categoryLevel1)
            }
        }
        
        // 在后台异步上传到云端，不阻塞主线程和返回
        if authService.isAuthenticated {
            Task.detached { // 使用detached确保任务不会因为调用者的作用域结束而取消
                do {
                    print("开始后台上传物品到云端: \(newItem.name)")
                    
                    var itemToUpload = newItem
                    
                    // 如果有图片数据，先上传图片
                    if let imageURLString = itemToUpload.imageURL {
                        // 检查是否是Base64编码的图片数据
                        if let imageData = Data(base64Encoded: imageURLString),
                           let originalImage = UIImage(data: imageData) {
                            print("开始上传图片: \(newItem.name)")
                            let imageFileName = "item_\(itemToUpload.id.uuidString).jpeg"
                            
                            // 保存到本地缓存
                            ImageCacheManager.shared.saveImage(originalImage, withName: imageFileName)
                            
                            let uploadedImageURL = try await self.supabaseService.uploadImage(
                                imageData: originalImage.jpegData(compressionQuality: 0.7)!, 
                                fileName: imageFileName
                            )
                            itemToUpload.imageURL = uploadedImageURL
                            print("图片上传完成: \(newItem.name), URL: \(uploadedImageURL)")
                            
                            // 更新本地数据中的图片URL
                            DispatchQueue.main.async {
                                if let index = self.items.firstIndex(where: { $0.id == itemToUpload.id }) {
                                    self.items[index].imageURL = uploadedImageURL
                                    self.saveItems()
                                }
                            }
                        }
                    }

                    // 上传物品到 Supabase
                    try await self.supabaseService.uploadItem(item: itemToUpload)
                    print("物品上传到云端完成: \(newItem.name)")

                } catch {
                    print("后台上传失败 - 物品: \(newItem.name), 错误: \(error.localizedDescription)")
                    // 可以在这里添加重试逻辑或错误通知
                }
            }
        }
    }
    
    func updateItem(_ item: Item) {
        DispatchQueue.main.async {
            if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                self.items[index] = item
                self.saveItems()
                
                // Update to Supabase if authenticated
                if let userID = self.authService.currentUser?.id {
                    print("Attempting to update item \(item.name) in Supabase...")
                    Task {
                        do {
                            try await self.supabaseService.updateItem(item: item, userID: userID)
                            print("Item updated in Supabase successfully: \(item.name)")
                        } catch {
                            print("Error updating item \(item.name) in Supabase: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    func deleteItem(_ item: Item) {
        DispatchQueue.main.async {
            if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                self.items.remove(at: index)
                self.saveItems()
                
                // Delete from Supabase if authenticated
                if let userID = self.authService.currentUser?.id {
                    print("Attempting to delete item \(item.name) from Supabase...")
                    Task {
                        do {
                            try await self.supabaseService.deleteItem(item: item, userID: userID)
                            print("Item deleted from Supabase successfully: \(item.name)")
                        } catch {
                            print("Error deleting item \(item.name) from Supabase: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 使用状态管理
    
    func toggleItemUse(_ item: Item) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = items[index]
            updatedItem.updateUsage(isInUse: !updatedItem.isInUse)
            items[index] = updatedItem
            saveItems()
        }
    }
    
    func getInUseItems() -> [Item] {
        items.filter { $0.isInUse }
    }
    
    func getAvailableItems() -> [Item] {
        items.filter { !$0.isInUse }
    }
    
    func getInUseItemsInLocation(_ location: String) -> [Item] {
        items.filter { $0.isInUse && $0.location.localizedCaseInsensitiveContains(location) }
    }
    
    // MARK: - 查询功能
    
    func searchItems(query: String) -> [Item] {
        guard !query.isEmpty else { return items }
        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(query) ||
            item.description.localizedCaseInsensitiveContains(query) ||
            item.location.localizedCaseInsensitiveContains(query) ||
            item.categoryLevel1.localizedCaseInsensitiveContains(query) || // Update for categoryLevel1
            item.categoryLevel2?.localizedCaseInsensitiveContains(query) == true ||
            item.categoryLevel3?.localizedCaseInsensitiveContains(query) == true ||
            item.itemNumber.localizedCaseInsensitiveContains(query)
        }
    }
    
    // MARK: - 分类管理
    
    // 加载保存的类别
    private func loadCategories() {
        if let savedCategories = UserDefaults.standard.stringArray(forKey: categoriesKey) {
            usedCategories = savedCategories
        } else {
            usedCategories = defaultCategories
        }
    }
    
    // 保存类别
    private func saveCategories() {
        UserDefaults.standard.set(usedCategories, forKey: categoriesKey)
    }
    
    // 加载类别排序
    private func loadCategoryOrder() {
        if let savedOrder = UserDefaults.standard.stringArray(forKey: categoryOrderKey) {
            categoryOrder = savedOrder
        }
    }
    
    // 保存类别排序
    private func saveCategoryOrder() {
        UserDefaults.standard.set(categoryOrder, forKey: categoryOrderKey)
    }
    
    // 确保默认类别存在
    private func ensureDefaultCategories() {
        for category in defaultCategories {
            // Use the new addCategory function
            addCategory(level1: category)
        }
        saveCategories()
        
        // 确保排序列表包含所有类别
        for category in usedCategories {
            if !categoryOrder.contains(category) {
                categoryOrder.append(category)
            }
        }
        saveCategoryOrder()
    }
    
    // 根据现有物品更新类别列表
    private func updateCategoriesFromExistingItems() {
        var categoriesToAdd: Set<String> = []
        for item in items {
            if !item.categoryLevel1.isEmpty {
                categoriesToAdd.insert(item.categoryLevel1)
            }
            if let level2 = item.categoryLevel2, !level2.isEmpty {
                categoriesToAdd.insert(level2)
            }
            if let level3 = item.categoryLevel3, !level3.isEmpty {
                categoriesToAdd.insert(level3)
            }
        }
        
        for category in categoriesToAdd {
            // Use the new addCategory function, treating all levels as level1 for now in usedCategories
            addCategory(level1: category)
        }
        usedCategories.sort()
        saveCategories()
        saveCategoryOrder()
    }
    
    // 添加新类别
    func addCategory(level1: String, level2: String? = nil, level3: String? = nil) {
        // Only add level1 to usedCategories for now to maintain compatibility with single-level picker
        if !level1.isEmpty && !usedCategories.contains(level1) {
            usedCategories.append(level1)
            usedCategories.sort()
            categoryOrder.append(level1)
            saveCategories()
            saveCategoryOrder()
        }
        // For now, level2 and level3 are not directly added to usedCategories or categoryOrder.
        // This will require a more complex hierarchical category management system.
    }
    
    // 重新排序类别
    func reorderCategories(from source: IndexSet, to destination: Int) {
        categoryOrder.move(fromOffsets: source, toOffset: destination)
        saveCategoryOrder()
    }
    
    // 移动类别到指定位置
    func moveCategory(_ category: String, to targetCategory: String) {
        guard let sourceIndex = categoryOrder.firstIndex(of: category),
              let targetIndex = categoryOrder.firstIndex(of: targetCategory),
              sourceIndex != targetIndex else { return }
        
        categoryOrder.remove(at: sourceIndex)
        categoryOrder.insert(category, at: targetIndex)
        saveCategoryOrder()
    }
    
    // 获取所有可用类别（包括默认类别和用户添加的类别）
    func getAllAvailableCategories(parentCategory: String? = nil) -> [String] {
        // For now, we only return top-level categories. This will be expanded for full three-level hierarchy.
        return usedCategories.sorted()
    }
    
    // 获取类别使用统计
    func getCategoryUsageStats() -> [(category: String, count: Int)] {
        // 这里需要汇总三级分类
        var categoryCounts: [String: Int] = [:]
        for item in items {
            categoryCounts[item.categoryLevel1, default: 0] += 1
            if let level2 = item.categoryLevel2, !level2.isEmpty {
                categoryCounts[level2, default: 0] += 1
            }
            if let level3 = item.categoryLevel3, !level3.isEmpty {
                categoryCounts[level3, default: 0] += 1
            }
        }
        return categoryCounts.map { (category: $0.key, count: $0.value) }
            .sorted(by: { $0.count > $1.count }) // 按使用次数排序
    }
    
    // MARK: - 持久化
    
    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: saveKey) {
            if let decoded = try? JSONDecoder().decode([Item].self, from: data) {
                items = decoded
            }
        }
    }

    private func loadLocalItems() {
        loadItems()
    }

    private func loadItemsFromSupabase() async {
        guard let userID = authService.currentUser?.id else {
            print("User not authenticated, skipping Supabase load")
            return
        }
        
        do {
            let fetchedItems = try await supabaseService.fetchItems(userID: userID)
            DispatchQueue.main.async {
                self.items = fetchedItems
                print("Loaded \(self.items.count) items from Supabase.")
                // 不在这里调用 assignItemNumbers，避免循环
                self.updateCategoriesFromExistingItems() // 在加载物品后更新类别列表
            }
        } catch {
            print("Error loading items from Supabase: \(error)")
            DispatchQueue.main.async {
                self.items = [] // Clear on error
            }
        }
    }
    
    @MainActor private func saveItems() {
        // Always save locally first for responsiveness
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
        print("Items saved locally.")

        // If authenticated, also save to Supabase asynchronously
        if let userID = authService.currentUser?.id {
            Task {
                do {
                    print("Attempting to save \(self.items.count) items to Supabase for user: \(userID)")
                    try await self.supabaseService.saveItems(items: self.items, userID: userID)
                    print("Items saved to Supabase successfully.")
                } catch {
                    print("Error saving items to Supabase: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - 统计方法
    
    // 获取总价值
    func getTotalValue() -> Double {
        return items.reduce(0) { $0 + $1.estimatedPrice }
    }
    
    // 获取所有位置
    func getAllLocations() -> [String] {
        return Array(Set(items.map { $0.location })).sorted()
    }
    
    // 获取指定位置的物品
    func itemsInLocation(_ location: String) -> [Item] {
        return items.filter { $0.location == location }
    }
    
    // 获取按位置分类的总价值
    func getTotalValueByLocation() -> [(location: String, value: Double)] {
        let grouped = Dictionary(grouping: items) { $0.location }
        return grouped.map { (location: $0.key, value: $0.value.reduce(0) { $0 + $1.estimatedPrice }) }
            .sorted(by: { $0.value > $1.value })
    }
    
    // 获取最贵重的物品
    func getMostValuableItems(limit: Int) -> [Item] {
        return items.sorted(by: { $0.estimatedPrice > $1.estimatedPrice }).prefix(limit).map { $0 }
    }
    
    // 处理复杂查询
    func processComplexQuery(_ query: String) -> String? {
        // 这里可以实现更复杂的查询逻辑
        // 目前返回 nil，让调用方处理
        return nil
    }
    
    // 获取类别物品数量统计
    func getCategoryItemCounts() -> [(category: String, count: Int)] {
        var categoryCounts: [String: Int] = [:]
        for item in items {
            categoryCounts[item.categoryLevel1, default: 0] += 1
        }
        return categoryCounts.map { (category: $0.key, count: $0.value) }
            .sorted(by: { $0.count > $1.count })
    }
    
    // 获取按类别分类的总价值
    func getTotalValueByCategory() -> [(category: String, value: Double)] {
        let grouped = Dictionary(grouping: items) { $0.categoryLevel1 }
        return grouped.map { (category: $0.key, value: $0.value.reduce(0) { $0 + $1.estimatedPrice }) }
            .sorted(by: { $0.value > $1.value })
    }
    
    // 获取使用效率统计
    func getUsageEfficiency() -> (highUsage: [Item], lowUsage: [Item], unused: [Item]) {
        let highUsage = items.filter { $0.isInUse }
        let lowUsage: [Item] = [] // 这里可以根据使用频率进一步分类
        let unused = items.filter { !$0.isInUse }
        return (highUsage: highUsage, lowUsage: lowUsage, unused: unused)
    }
    
    // 获取按类别分组的物品
    func getItemsByCategory() -> [(category: String, items: [Item])] {
        let grouped = Dictionary(grouping: items) { $0.categoryLevel1 }
        return grouped.map { (category: $0.key, items: $0.value) }
            .sorted(by: { $0.category < $1.category })
    }
    
    // 获取所有类别
    func getAllCategories() -> [String] {
        return usedCategories
    }
    
    // MARK: - 图片预加载功能
    
    /// 预加载所有物品的图片
    func preloadImages() async {
        print("开始预加载图片...")
        let itemsWithImages = items.filter { $0.imageURL != nil && !$0.imageURL!.isEmpty }
        print("需要预加载 \(itemsWithImages.count) 张图片")
        
        // 创建一个任务组来并发下载图片
        await withTaskGroup(of: Void.self) { group in
            for item in itemsWithImages {
                group.addTask {
                    await self.preloadImage(for: item)
                }
            }
            
            // 等待所有任务完成
            for await _ in group {
                // 任务完成
            }
        }
        
        print("图片预加载完成")
    }
    
    /// 预加载单个物品的图片
    private func preloadImage(for item: Item) async {
        guard let imageURLString = item.imageURL,
              let imageURL = URL(string: imageURLString) else {
            return
        }
        
        // 生成图片缓存文件名
        let imageFileName = "item_\(item.id.uuidString).jpg"
        
        // 检查图片是否已缓存
        if ImageCacheManager.shared.imageExists(withName: imageFileName) {
            print("图片已存在于缓存中: \(imageFileName)")
            return
        }
        
        // 下载并缓存图片
        print("开始下载图片: \(imageURLString)")
        await withCheckedContinuation { continuation in
            ImageCacheManager.shared.downloadAndCacheImage(from: imageURLString, withName: imageFileName) { image in
                if let image = image {
                    print("图片下载并缓存成功: \(imageFileName)")
                } else {
                    print("图片下载失败: \(imageURLString)")
                }
                continuation.resume()
            }
        }
    }
}
