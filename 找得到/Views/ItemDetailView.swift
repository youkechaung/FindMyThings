import SwiftUI

struct ItemDetailView: View {
    @State private var editedItem: Item
    @ObservedObject var itemManager: ItemManager
    @StateObject private var locationManager = LocationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var showingLocationPicker = false
    @State private var selectedLocation: Location?
    
    init(item: Item, itemManager: ItemManager) {
        _editedItem = State(initialValue: item)
        self.itemManager = itemManager
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let imageData = editedItem.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    if isEditing {
                        TextField("名称", text: $editedItem.name)
                            .font(.title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        HStack {
                            Text("¥")
                            TextField("估算价格", value: $editedItem.estimatedPrice, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        TextField("类别", text: $editedItem.category)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: {
                            showingLocationPicker = true
                        }) {
                            HStack {
                                Text(editedItem.location)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        TextEditor(text: $editedItem.description)
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    } else {
                        HStack {
                            Text(editedItem.name)
                                .font(.title)
                                .bold()
                            Spacer()
                            if editedItem.estimatedPrice > 0 {
                                Text("¥\(String(format: "%.2f", editedItem.estimatedPrice))")
                                    .font(.title2)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        if !editedItem.category.isEmpty {
                            Text(editedItem.category)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                        }
                        
                        Text("位置：\(editedItem.location)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        if !editedItem.description.isEmpty {
                            Text("描述")
                                .font(.headline)
                                .padding(.top, 8)
                            Text(editedItem.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        if editedItem.isInUse {
                            Text("物品正在使用中")
                                .font(.headline)
                                .foregroundColor(.red)
                                .padding(.top, 8)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("完成") {
                        itemManager.updateItem(editedItem)
                        isEditing = false
                    }
                } else {
                    Menu {
                        Button {
                            isEditing = true
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        
                        Button {
                            itemManager.toggleItemUse(editedItem)
                        } label: {
                            Label(editedItem.isInUse ? "归还" : "使用", 
                                  systemImage: editedItem.isInUse ? "arrow.uturn.backward" : "hand.raised")
                        }
                        
                        Button(role: .destructive) {
                            itemManager.deleteItem(editedItem)
                            dismiss()
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView(selectedLocation: Binding(
                get: { 
                    LocationManager.shared.findLocation(byPath: editedItem.location)
                },
                set: { newLocation in
                    if let location = newLocation {
                        editedItem.location = location.fullPath
                    }
                }
            ))
        }
    }
}

struct ItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ItemDetailView(item: Item(
                name: "示例物品",
                location: "书房",
                description: "这是一个示例物品",
                category: "电子产品",
                estimatedPrice: 100.0,
                imageData: nil
            ), itemManager: ItemManager())
        }
    }
}
