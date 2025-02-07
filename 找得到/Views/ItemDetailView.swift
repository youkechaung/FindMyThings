import SwiftUI

struct ItemDetailView: View {
    let item: Item
    
    var body: some View {
        List {
            if let imageData = item.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.vertical)
            }
            
            Section("基本信息") {
                LabeledContent("名称") {
                    Text(item.name)
                }
                LabeledContent("描述") {
                    Text(item.description)
                }
                LabeledContent("位置") {
                    Text(item.location)
                }
                LabeledContent("创建时间") {
                    Text(item.dateCreated, style: .date)
                }
                if item.isInUse {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("此物品正在使用中")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle("物品详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ItemDetailView(item: Item(
                name: "示例物品",
                description: "这是一个示例物品",
                location: "书房",
                imageData: nil
            ))
        }
    }
}
