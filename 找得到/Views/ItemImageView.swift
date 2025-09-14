import SwiftUI
import UIKit

struct ItemImageView: View {
    let imageURL: String?
    let itemID: UUID
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if isLoading {
                ProgressView()
                    .frame(maxHeight: 300)
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
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let imageURL = imageURL, !imageURL.isEmpty else {
            return
        }
        
        // 生成图片缓存文件名
        let imageName = "item_\(itemID.uuidString).jpg"
        
        // 首先检查本地缓存
        if let cachedImage = ImageCacheManager.shared.getImage(withName: imageName) {
            self.image = cachedImage
            return
        }
        
        // 如果是Base64编码的图片数据
        if imageURL.hasPrefix("data:image") || !imageURL.hasPrefix("http") {
            // 尝试解析Base64数据
            let base64String = imageURL.hasPrefix("data:image") ? String(imageURL.split(separator: ",").last ?? "") : imageURL
            if let imageData = Data(base64Encoded: base64String),
               let uiImage = UIImage(data: imageData) {
                self.image = uiImage
                // 保存到本地缓存
                ImageCacheManager.shared.saveImage(uiImage, withName: imageName)
                return
            }
        }
        
        // 从网络下载图片
        isLoading = true
        ImageCacheManager.shared.downloadAndCacheImage(from: imageURL, withName: imageName) { downloadedImage in
            self.image = downloadedImage
            self.isLoading = false
        }
    }
}

struct ItemImageView_Previews: PreviewProvider {
    static var previews: some View {
        ItemImageView(imageURL: "https://example.com/image.jpg", itemID: UUID())
            .previewLayout(.sizeThatFits)
            .padding()
    }
}