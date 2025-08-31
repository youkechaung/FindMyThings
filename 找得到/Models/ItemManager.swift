import Foundation
import SwiftUI

class ItemManager: ObservableObject {
    @Published var items: [Item] = []
    @Published var categoryOrder: [String] = [] // 添加类别排序
    private let saveKey = "SavedItems"
    private let categoriesKey = "SavedCategories"
    private let categoryOrderKey = "CategoryOrder"
    private let nextItemNumberKey = "NextItemNumber" // 添加下一个物品编号的存储键
    
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
    
    init() {
        loadItems()
        loadCategories()
        loadCategoryOrder()
        // 确保默认类别存在
        ensureDefaultCategories()
        // 为现有物品分配编号（如果没有编号）
        assignItemNumbers()
        // 根据现有物品更新类别列表，确保所有类别都被加载
        updateCategoriesFromExistingItems()
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
            saveItems()
        }
    }
    
    // MARK: - 基本操作
    
    func addItem(_ item: Item) {
        var newItem = item
        // 如果物品没有编号，自动生成
        if newItem.itemNumber.isEmpty {
            newItem.itemNumber = generateItemNumber()
        }
        items.append(newItem)
        saveItems()
        
        // 确保新物品的类别也被添加到usedCategories和categoryOrder中
        if !newItem.category.isEmpty {
            addCategory(newItem.category)
        }
    }
    
    func updateItem(_ item: Item) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveItems()
        }
    }
    
    func deleteItem(_ item: Item) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
            saveItems()
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
            item.category.localizedCaseInsensitiveContains(query) ||
            item.itemNumber.localizedCaseInsensitiveContains(query)
        }
    }
    
    // MARK: - 分类管理
    
    // 获取所有分类
    func getAllCategories() -> [String] {
        Array(Set(items.map { $0.category })).sorted()
    }
    
    // 按分类分组物品（按排序顺序）
    func getItemsByCategory() -> [(category: String, items: [Item])] {
        let groupedItems = Dictionary(grouping: items) { $0.category.isEmpty ? "未分类" : $0.category }
        
        // 按排序顺序返回结果
        return categoryOrder.compactMap { category in
            guard let items = groupedItems[category] else { return nil }
            return (category: category, items: items.sorted { $0.itemNumber < $1.itemNumber })
        }
    }
    
    // 按位置分组物品
    func getItemsByLocation() -> [(location: String, items: [Item])] {
        Dictionary(grouping: items) { $0.location }
            .map { (location: $0.key, items: $0.value.sorted { $0.itemNumber < $1.itemNumber }) }
            .sorted { $0.location < $1.location }
    }
    
    // 获取分类及其物品数量
    func getCategoryItemCounts() -> [(category: String, count: Int)] {
        Dictionary(grouping: items) { $0.category.isEmpty ? "未分类" : $0.category }
            .map { (category: $0.key, count: $0.value.count) }
            .sorted { $0.category < $1.category }
    }
    
    // 按分类获取总价值
    func getTotalValueByCategory() -> [(category: String, value: Double)] {
        Dictionary(grouping: items) { $0.category.isEmpty ? "未分类" : $0.category }
            .map { (category: $0.key, value: $0.value.reduce(0) { $0 + $1.estimatedPrice }) }
            .sorted { $0.category < $1.category }
    }
    
    // 按位置查询物品
    func itemsInLocation(_ location: String) -> [Item] {
        items.filter { $0.location.localizedCaseInsensitiveContains(location) }
    }
    
    // 获取所有位置
    func getAllLocations() -> [String] {
        Array(Set(items.map { $0.location })).sorted()
    }
    
    // 获取位置及其物品数量
    func getLocationItemCounts() -> [(location: String, count: Int)] {
        Dictionary(grouping: items) { $0.location }
            .map { (location: $0.key, count: $0.value.count) }
            .sorted { $0.location < $1.location }
    }
    
    // 获取总价值
    func getTotalValue() -> Double {
        items.reduce(0) { $0 + $1.estimatedPrice }
    }
    

    
    // 按位置获取总价值
    func getTotalValueByLocation() -> [(location: String, value: Double)] {
        Dictionary(grouping: items) { $0.location }
            .map { (location: $0.key, value: $0.value.reduce(0) { $0 + $1.estimatedPrice }) }
            .sorted { $0.location < $1.location }
    }
    
    // 获取最贵的物品
    func getMostValuableItems(limit: Int = 5) -> [Item] {
        Array(items.sorted { $0.estimatedPrice > $1.estimatedPrice }.prefix(limit))
    }
    
    // MARK: - 物品分析功能
    
    func getInfrequentlyUsedItems(threshold: Int = 30) -> [Item] {
        // 获取超过指定天数未使用的物品
        items.filter { $0.idleDays >= threshold }
            .sorted { $0.idleDays > $1.idleDays }
    }
    
    func getItemsNeedingMaintenance() -> [Item] {
        // 获取需要保养的物品
        items.filter { $0.needsMaintenance }
    }
    
    func getItemsByValueAndLocation() -> [(location: String, items: [Item])] {
        // 按位置分组并按价值排序
        Dictionary(grouping: items) { $0.location }
            .map { (location: $0.key, items: $0.value.sorted { $0.estimatedPrice > $1.estimatedPrice }) }
            .sorted { $0.items.map { $0.estimatedPrice }.reduce(0, +) > $1.items.map { $0.estimatedPrice }.reduce(0, +) }
    }
    
    func getUsageEfficiency() -> (highUsage: [Item], lowUsage: [Item], unused: [Item]) {
        let sortedItems = items.sorted { $0.usageFrequency > $1.usageFrequency }
        let total = Double(items.count)
        let highThreshold = total * 0.3 // 前30%
        let lowThreshold = total * 0.7 // 后30%
        
        return (
            highUsage: Array(sortedItems.prefix(Int(highThreshold))),
            lowUsage: Array(sortedItems.suffix(Int(total - lowThreshold))),
            unused: items.filter { $0.useCount == 0 }
        )
    }
    
    // MARK: - 物品状态更新
    
    func recordMaintenance(for item: Item) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = items[index]
            updatedItem.recordMaintenance()
            items[index] = updatedItem
            saveItems()
        }
    }
    
    func processComplexQuery(_ query: String) -> String? {
        let normalizedQuery = query.lowercased()
        
        // 处理闲置物品查询
        if normalizedQuery.contains("很少") || normalizedQuery.contains("闲置") {
            let infrequentItems = getInfrequentlyUsedItems()
            if infrequentItems.isEmpty {
                return "目前没有长期闲置的物品"
            }
            let itemsDesc = infrequentItems.map {
                "\($0.name)（\($0.idleDays)天未使用，价值\(String(format: "%.2f", $0.estimatedPrice))元）"
            }.joined(separator: "、")
            return "建议关注这些较少使用的物品：\(itemsDesc)"
        }
        
        // 处理使用效率查询
        if normalizedQuery.contains("使用效率") || normalizedQuery.contains("使用情况") {
            let efficiency = getUsageEfficiency()
            let highUsageDesc = efficiency.highUsage.prefix(3).map { 
                "\($0.name)（平均每天使用\(String(format: "%.1f", $0.usageFrequency))次）" 
            }.joined(separator: "、")
            let lowUsageDesc = efficiency.lowUsage.prefix(3).map { 
                "\($0.name)（平均每天使用\(String(format: "%.1f", $0.usageFrequency))次）" 
            }.joined(separator: "、")
            return """
                使用频率最高的物品：\(highUsageDesc)
                使用频率最低的物品：\(lowUsageDesc)
                从未使用的物品数量：\(efficiency.unused.count)个
                """
        }
        
        // 处理保养查询
        if normalizedQuery.contains("保养") || normalizedQuery.contains("维护") || normalizedQuery.contains("更换") {
            let maintenanceItems = getItemsNeedingMaintenance()
            if maintenanceItems.isEmpty {
                return "目前没有需要保养的物品"
            }
            let itemsDesc = maintenanceItems.map { $0.name }.joined(separator: "、")
            return "这些物品需要保养：\(itemsDesc)"
        }
        
        // 处理价值分布查询
        if normalizedQuery.contains("价值") && normalizedQuery.contains("分布") {
            let valueByLocation = getItemsByValueAndLocation()
            let distributionDesc = valueByLocation.map { location, items in
                let totalValue = items.map { $0.estimatedPrice }.reduce(0, +)
                let topItems = items.prefix(2).map { $0.name }.joined(separator: "、")
                return "\(location)（总价值\(String(format: "%.2f", totalValue))元，最贵的物品：\(topItems)）"
            }.joined(separator: "\n")
            return "物品价值分布如下：\n\(distributionDesc)"
        }
        
        return nil
    }
    
    // MARK: - 类别管理
    
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
        } else {
            categoryOrder = defaultCategories
        }
    }
    
    // 保存类别排序
    private func saveCategoryOrder() {
        UserDefaults.standard.set(categoryOrder, forKey: categoryOrderKey)
    }
    
    // 确保默认类别存在
    private func ensureDefaultCategories() {
        for category in defaultCategories {
            if !usedCategories.contains(category) {
                usedCategories.append(category)
            }
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
            if !item.category.isEmpty {
                categoriesToAdd.insert(item.category)
            }
        }
        
        for category in categoriesToAdd {
            if !usedCategories.contains(category) {
                usedCategories.append(category)
            }
            if !categoryOrder.contains(category) {
                categoryOrder.append(category)
            }
        }
        saveCategories()
        saveCategoryOrder()
    }
    
    // 添加新类别
    func addCategory(_ category: String) {
        if !usedCategories.contains(category) {
            usedCategories.append(category)
            usedCategories.sort()
            categoryOrder.append(category)
            saveCategories()
            saveCategoryOrder()
        }
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
    func getAllAvailableCategories() -> [String] {
        return usedCategories
    }
    
    // 获取类别使用统计
    func getCategoryUsageStats() -> [(category: String, count: Int)] {
        Dictionary(grouping: items) { $0.category.isEmpty ? "未分类" : $0.category }
            .map { (category: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count } // 按使用次数排序
    }
    
    // MARK: - 持久化
    
    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: saveKey) {
            if let decoded = try? JSONDecoder().decode([Item].self, from: data) {
                items = decoded
            }
        }
    }
    
    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
}
