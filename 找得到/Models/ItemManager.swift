import Foundation
import SwiftUI

class ItemManager: ObservableObject {
    @Published var items: [Item] = []
    private let saveKey = "SavedItems"
    
    init() {
        loadItems()
    }
    
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
    
    func toggleItemUse(_ item: Item) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isInUse.toggle()
            saveItems()
        }
    }
    
    func searchItems(query: String) -> [Item] {
        guard !query.isEmpty else { return items }
        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(query) ||
            item.description.localizedCaseInsensitiveContains(query) ||
            item.location.localizedCaseInsensitiveContains(query)
        }
    }
    
    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Item].self, from: data) {
            items = decoded
        }
    }
}
