import SwiftUI
import UIKit

// MARK: - 加载器
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var itemID: UUID?
    
    init(itemID: UUID) {
        loadImageFromCache(itemID: itemID)
    }
    
    func loadImageFromCache(itemID: UUID) {
        // 如果已经加载过相同ID的图片，直接返回
        if self.itemID == itemID && self.image != nil {
            return
        }
        
        self.itemID = itemID
        
        // 生成图片缓存文件名
        let imageName = "item_\(itemID.uuidString).jpg"
        
        // 检查缓存（内存 + 磁盘）
        if let cachedImage = ImageCacheManager.shared.getImage(withName: imageName) {
            self.image = cachedImage
            return
        }
        
        // 没有缓存 → 默认图
        self.image = nil
    }
}

// MARK: - 视图
struct ItemImageView: View {
    @StateObject private var imageLoader: ImageLoader
    
    init(itemID: UUID) {
        _imageLoader = StateObject(wrappedValue: ImageLoader(itemID: itemID))
    }
    
    var body: some View {
        Group {
            if let image = imageLoader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            } else {
                // 默认图片（不会频繁闪烁）
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(maxHeight: 300)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.largeTitle)
                    )
            }
        }
    }
}

struct ItemImageView_Previews: PreviewProvider {
    static var previews: some View {
        ItemImageView(itemID: UUID())
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
