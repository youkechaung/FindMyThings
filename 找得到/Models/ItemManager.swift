import Foundation
import SwiftUI

class ItemManager: ObservableObject {
    @Published var items: [Item] = []
    private let saveKey = "SavedItems"
    
    init() {
        loadItems()
    }
    
    // MARK: - 基本操作
    
    func addItem(_ item: Item) {
        items.append(item)
        saveItems()
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
            item.category.localizedCaseInsensitiveContains(query)
        }
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
    
    // 按类别获取总价值
    func getTotalValueByCategory() -> [(category: String, value: Double)] {
        Dictionary(grouping: items) { $0.category }
            .map { (category: $0.key, value: $0.value.reduce(0) { $0 + $1.estimatedPrice }) }
            .sorted { $0.category < $1.category }
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
