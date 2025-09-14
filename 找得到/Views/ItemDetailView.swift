import SwiftUI

struct ItemDetailView: View {
    @State private var editedItem: Item
    @ObservedObject var itemManager: ItemManager
    @StateObject private var locationManager = LocationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var showingLocationPicker = false
    @State private var selectedLocation: Location?
    @State private var showingCategoryPicker = false
    @EnvironmentObject private var supabaseService: SupabaseService // Add SupabaseService
    
    init(item: Item, itemManager: ItemManager) {
        _editedItem = State(initialValue: item)
        self.itemManager = itemManager
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 物品图片部分
                if let imageURL = editedItem.imageURL {
                    // 尝试将imageURL作为URL处理
                    if let url = URL(string: imageURL) {
                        AsyncImage(url: url) {
                            image in image
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } placeholder: {
                            ProgressView()
                                .frame(maxHeight: 300)
                        }
                    } 
                    // 如果不是URL，尝试将其作为Base64编码的图片数据处理
                    else if let imageData = Data(base64Encoded: imageURL),
                           let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } 
                    // 如果都不是，显示占位符
                    else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(maxHeight: 300)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.largeTitle)
                            )
                    }
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(maxHeight: 300)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                                .font(.largeTitle)
                        )
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
                        
                        Button(action: {
                            showingCategoryPicker = true
                        }) {
                            HStack {
                                Text(editedItem.categoryLevel1.isEmpty ? "选择类别" : editedItem.categoryLevel1)
                                    .foregroundColor(editedItem.categoryLevel1.isEmpty ? .blue : .primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                        .buttonStyle(.bordered)
                        
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
                        
                        // 显示物品编号
                        HStack {
                            Text("编号：\(editedItem.itemNumber)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                            Spacer()
                        }
                        
                        if !editedItem.categoryLevel1.isEmpty {
                            Text(editedItem.categoryLevel1)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                        }
                        // Optionally display level 2 and 3 categories if they exist
                        if let level2 = editedItem.categoryLevel2, !level2.isEmpty {
                            Text("二级分类：\(level2)")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.05))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                        }
                        if let level3 = editedItem.categoryLevel3, !level3.isEmpty {
                            Text("三级分类：\(level3)")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.05))
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
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryPickerView(selectedCategoryLevel1: $editedItem.categoryLevel1, selectedCategoryLevel2: $editedItem.categoryLevel2, selectedCategoryLevel3: $editedItem.categoryLevel3, itemManager: itemManager)
                .environmentObject(supabaseService) // Pass supabaseService as environment object
        }
    }
}

struct ItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let supabaseService = SupabaseService()
        let authService = AuthService(supabaseService: supabaseService)
        let itemManager = ItemManager(authService: authService, supabaseService: supabaseService)
        
        return NavigationView {
            ItemDetailView(item: Item(
                name: "示例物品",
                location: "书房",
                description: "这是一个示例物品",
                categoryLevel1: "电子产品", // Use categoryLevel1
                categoryLevel2: nil, // Add categoryLevel2
                categoryLevel3: nil, // Add categoryLevel3
                estimatedPrice: 100.0,
                imageURL: nil
            ), itemManager: itemManager)
        }
    }
}
