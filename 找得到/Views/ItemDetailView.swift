import SwiftUI

struct ItemDetailView: View {
    let item: Item
    @ObservedObject var itemManager: ItemManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let imageData = item.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(item.name)
                            .font(.title)
                            .bold()
                        Spacer()
                        if item.estimatedPrice > 0 {
                            Text("¥\(String(format: "%.2f", item.estimatedPrice))")
                                .font(.title2)
                                .foregroundColor(.green)
                        }
                    }
                    
                    if !item.category.isEmpty {
                        Text(item.category)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                    }
                    
                    Text("位置：\(item.location)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    if !item.description.isEmpty {
                        Text("描述")
                            .font(.headline)
                            .padding(.top, 8)
                        Text(item.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    if item.isInUse {
                        Text("物品正在使用中")
                            .font(.headline)
                            .foregroundColor(.red)
                            .padding(.top, 8)
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    itemManager.toggleItemUse(item)
                } label: {
                    Text(item.isInUse ? "归还" : "使用")
                        .foregroundColor(item.isInUse ? .red : .blue)
                }
            }
        }
    }
}

struct ItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ItemDetailView(item: Item(
                name: "示例物品",
                description: "这是一个示例物品",
                location: "书房",
                category: "电子产品",
                estimatedPrice: 100.0,
                imageData: nil
            ), itemManager: ItemManager())
        }
    }
}
