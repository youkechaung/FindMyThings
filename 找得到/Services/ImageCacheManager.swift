import Foundation
import UIKit

class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // 获取文档目录下的图片缓存文件夹
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsDirectory.appendingPathComponent("ImageCache", isDirectory: true)
        
        // 创建缓存目录（如果不存在）
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    /// 保存图片到本地缓存
    func saveImage(_ image: UIImage, withName name: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        let fileURL = cacheDirectory.appendingPathComponent(name)
        do {
            try data.write(to: fileURL)
            print("图片已保存到本地缓存: \(name)")
        } catch {
            print("保存图片到本地缓存失败: \(error)")
        }
    }
    
    /// 从本地缓存获取图片
    func getImage(withName name: String) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent(name)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("本地缓存中未找到图片: \(name)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let image = UIImage(data: data)
            print("从本地缓存加载图片: \(name)")
            return image
        } catch {
            print("从本地缓存加载图片失败: \(error)")
            return nil
        }
    }
    
    /// 检查图片是否存在于本地缓存
    func imageExists(withName name: String) -> Bool {
        let fileURL = cacheDirectory.appendingPathComponent(name)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// 从URL下载图片并保存到本地缓存
    func downloadAndCacheImage(from urlString: String, withName name: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        // 检查是否已缓存
        if let cachedImage = getImage(withName: name) {
            completion(cachedImage)
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, let image = UIImage(data: data), error == nil else {
                print("下载图片失败: \(error?.localizedDescription ?? "未知错误")")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // 保存到本地缓存
            self.saveImage(image, withName: name)
            
            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
    }
    
    /// 清除所有缓存图片
    func clearCache() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                try fileManager.removeItem(at: fileURL)
            }
            print("图片缓存已清除")
        } catch {
            print("清除图片缓存失败: \(error)")
        }
    }
    
    /// 获取缓存大小
    func getCacheSize() -> Int64 {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            var totalSize: Int64 = 0
            
            for fileURL in fileURLs {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            }
            
            return totalSize
        } catch {
            print("获取缓存大小失败: \(error)")
            return 0
        }
    }
}