import Foundation
import UIKit
import Vision
import VisionKit
import CoreImage.CIFilterBuiltins
import ImageIO // New import
import CoreGraphics // New import
import UniformTypeIdentifiers // Add this import

// Response structures for AI API
struct ChatResponse: Codable {
    let choices: [ChatChoice]
}

struct ChatChoice: Codable {
    let message: ChatMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

class AIService {
    static let shared = AIService()
    private let apiKey = "sk-yIkBArpEqL1qpI3vj5p0vh0dR1Z6BI7YaBRnTmdVDvho3cYH"
    private let baiduApiKey = "QcVAOZv3rkRoRxI1liYoicJV"
    private let baiduAppId = "119869976"
    private var baiduAccessToken: String?
    private var lastRequestTime: Date?
    private let minimumRequestInterval: TimeInterval = 1 // 1秒
    private var retryCount = 0
    private let maxRetries = 3
    
    private init() {
        // 初始化时获取百度 API 访问令牌
        getBaiduAccessToken()
    }
    
    // 获取百度 API 访问令牌
    private func getBaiduAccessToken() {
        // 使用您提供的访问令牌
        let accessToken = "24.461d6ebeb2622a6677e65335c17d5025.2592000.1758850651.282335-119869976"
        
        // 直接设置，不使用异步
        self.baiduAccessToken = accessToken
        print("百度 API 访问令牌设置成功")
    }
    
    private func canMakeRequest() -> Bool {
        if let lastRequest = lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
            return timeSinceLastRequest >= minimumRequestInterval
        }
        return true
    }
    
    private func handleRateLimitError(completion: @escaping (String?) -> Void) {
        retryCount += 1
        if retryCount <= maxRetries {
            print("达到速率限制，等待后重试（第 \(retryCount) 次）...")
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(retryCount * 5)) {
                self.retryCount = 0
                self.performWebSearch(query: "重试请求", systemPrompt: "重试系统提示", completion: completion)
            }
        } else {
            print("达到最大重试次数")
            retryCount = 0
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
    
    private func performRequest(request: URLRequest, completion: @escaping (Data?, Error?) -> Void) {
        guard canMakeRequest() else {
            let timeToWait = minimumRequestInterval - (lastRequestTime?.timeIntervalSinceNow ?? minimumRequestInterval)
            print("请求太频繁，需要等待 \(Int(timeToWait)) 秒")
            DispatchQueue.global().asyncAfter(deadline: .now() + timeToWait) {
                self.performRequest(request: request, completion: completion)
            }
            return
        }
        
        print("发送请求...")
        if let url = request.url?.absoluteString {
            print("请求 URL: \(url)")
        }
        
        print("请求头:")
        request.allHTTPHeaderFields?.forEach { key, value in
            print("\(key): \(value)")
        }
        
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("请求体: \(bodyString)")
        }
        
        lastRequestTime = Date()
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("请求失败: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("响应数据: \(responseString)")
            }
            
            completion(data, nil)
        }
        task.resume()
    }

    func performWebSearch(query: String, systemPrompt: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://api.moonshot.cn/v1/chat/completions") else {
            print("Invalid URL")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "moonshot-v1-8k",
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": query
                ]
            ],
            "temperature": 0.7,
            "stream": false
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("发送请求到 AI 服务...")
            print("系统提示：\(systemPrompt)")
            print("用户问题：\(query)")
        } catch {
            print("Failed to serialize request body: \(error)")
            completion(nil)
            return
        }
        
        performRequest(request: request) { data, error in
            if let error = error {
                print("AI 服务请求失败: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            guard let data = data else {
                print("AI 服务返回空数据")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // 打印原始响应数据以便调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("AI 服务响应：\(responseString)")
            }
            
            do {
                let response = try JSONDecoder().decode(ChatResponse.self, from: data)
                if let content = response.choices.first?.message.content {
                    print("AI 回答：\(content)")
                    DispatchQueue.main.async {
                        completion(content)
                    }
                } else {
                    print("AI 响应中没有内容")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            } catch {
                print("解析 AI 响应失败: \(error)")
                print("原始数据: \(String(data: data, encoding: .utf8) ?? "无法解码")")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    func suggestCategory(for item: Item, completion: @escaping (String?) -> Void) {
        let query = """
        物品名称：\(item.name)
        物品描述：\(item.description)
        请根据以上信息，给出一个最合适的物品类别。
        """
        
        let systemPrompt = """
        你是一个物品分类助手。你的任务是根据物品的名称和描述，给出一个合适的类别标签。
        
        规则：
        1. 只返回类别名称，不要包含任何解释或其他文字
        2. 类别应该简单且实用，例如：电子产品、文具、书籍、衣物、餐具、工具等
        3. 如果无法确定类别，返回"其他"
        4. 不要在类别中包含标点符号
        """
        
        performWebSearch(query: query, systemPrompt: systemPrompt) { response in
            print("分类原始响应：\(response ?? "nil")")
            // 清理响应文本，只保留类别名称
            let category = response?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: CharacterSet.letters.union(.decimalDigits).inverted)
                .joined()
            
            print("处理后的类别：\(category ?? "nil")")
            completion(category)
        }
    }

    func estimatePrice(for item: Item, completion: @escaping (Double?) -> Void) {
        let query = """
        物品名称：\(item.name)
        物品描述：\(item.description)
        物品类别：\(item.category)
        请根据以上信息，估算这个物品的大致价格。
        """
        
        let systemPrompt = """
        你是一个物品估价助手。你的任务是根据物品的信息，估算它的市场价格。
        
        规则：
        1. 只返回数字金额，不要包含任何货币符号、单位或其他文字
        2. 如果无法估算，返回0
        3. 价格应该是合理的市场价格
        4. 只返回数字，例如：299.99
        """

        performWebSearch(query: query, systemPrompt: systemPrompt) { result in
            print("价格原始响应：\(result ?? "nil")")
            // 清理响应文本，只保留数字
            let priceString = result?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: CharacterSet.decimalDigits.union(.init(charactersIn: ".")).inverted)
                .joined()
            
            print("处理后的价格字符串：\(priceString ?? "nil")")
            
            if let priceString = priceString,
               let price = Double(priceString) {
                print("最终价格：\(price)")
                completion(price)
            } else {
                print("无法解析价格，返回0")
                completion(0.0)
            }
        }
    }

    func analyzeImage(_ imageData: Data, completion: @escaping (String?) -> Void) {
        guard let base64String = imageData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("图片编码失败")
            completion(nil)
            return
        }
        
        let query = "这张图片里有什么？请特别描述图片中的颜色。"
        let systemPrompt = """
        你是一个图片分析助手，专门帮助色弱用户识别图片中的内容和颜色。
        
        请按照以下格式描述图片：
        1. 首先描述图片的主要内容和场景
        2. 详细描述主要物体的颜色，包括：
           - 具体的颜色名称（如：深红色、淡蓝色等）
           - 颜色的明暗程度
           - 颜色的饱和度
        3. 如果图片中有多个物体，请分别描述它们的颜色
        4. 如果有特别醒目或重要的颜色，要特别强调
        
        示例回答：
        "这是一件T恤衫。主体是淡蓝色（天蓝色），饱和度较低，整体偏亮。
        衣领是深蓝色，与主体形成明显对比。
        胸前的图案是深红色（酒红色），饱和度高，非常醒目。"
        """
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": [
                ["type": "text", "text": query],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64String)"]]
            ]]
        ]
        
        let requestBody: [String: Any] = [
            "model": "moonshot-v1-8k-vision-preview",
            "messages": messages
        ]
        
        guard let url = URL(string: "https://api.moonshot.cn/v1/chat/completions") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("发送图片分析请求")
        } catch {
            print("请求体序列化失败: \(error)")
            completion(nil)
            return
        }
        
        performRequest(request: request) { data, error in
            if let error = error {
                print("图片分析请求失败: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("没有收到数据")
                completion(nil)
                return
            }
            
            if let responseJSON = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let choices = responseJSON["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                print("收到图片分析结果")
                completion(content)
            } else {
                print("响应解析失败")
                completion(nil)
            }
        }
    }

    func analyzeItem(imageData: Data, completion: @escaping (String, String, String, Double) -> Void) {
        guard let base64String = imageData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("图片编码失败")
            completion("未知物品", "无法分析物品", "其他", 0.0)
            return
        }
        
        let query = """
        请分析这个物品的图片，并按以下格式返回信息：

        名称：直接返回物品名称，不要加任何符号或修饰词
        描述：详细描述物品的外观、材质、状况等
        类别：给出最合适的物品类别
        价格：估算物品的价格，单位人民币，只返回数字

        请确保返回的格式严格按照上述模板，每个部分单独一行。
        """
        
        let systemPrompt = """
        你是一个物品分析助手，专门帮助用户分析物品的详细信息。
        请仔细观察图片中的物品，给出准确的名称、详细的描述、合适的类别和合理的价格估算。
        名称必须简洁，只返回最基本的物品名称，不要加任何符号或修饰词。
        描述要详细具体，包括物品的外观特征、材质、状况等。
        类别必须选择以下广泛类别之一：电子产品、衣服、家具、厨具、运动用品、化妆品、工具、玩具、书籍、文具、其他。
        不要使用过于具体的类别，如"相机"应该归类为"电子产品"，"T恤"应该归类为"衣服"。
        价格估算要合理，考虑物品的品质和市场价值。
        """
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": [
                ["type": "text", "text": query],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64String)"]]
            ]]
        ]
        
        let requestBody: [String: Any] = [
            "model": "moonshot-v1-8k-vision-preview",
            "messages": messages
        ]
        
        guard let url = URL(string: "https://api.moonshot.cn/v1/chat/completions") else {
            completion("未知物品", "无法分析物品", "其他", 0.0)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion("未知物品", "无法分析物品", "其他", 0.0)
            return
        }
        
        performRequest(request: request) { data, error in
            guard let data = data,
                  let response = try? JSONDecoder().decode(ChatResponse.self, from: data),
                  let content = response.choices.first?.message.content else {
                DispatchQueue.main.async {
                    completion("未知物品", "无法分析物品", "其他", 0.0)
                }
                return
            }
            
            // 解析返回的内容
            let lines = content.components(separatedBy: .newlines)
            var itemName = "未知物品"
            var description = "无法分析物品"
            var category = "其他"
            var price: Double = 0.0
            
            for line in lines {
                if line.hasPrefix("名称：") {
                    itemName = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("描述：") {
                    description = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("类别：") {
                    let detailedCategory = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    category = self.mapToBroaderCategory(detailedCategory: detailedCategory)
                } else if line.hasPrefix("价格：") {
                    if let priceStr = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).first {
                        price = Double(priceStr) ?? 0.0
                    }
                }
            }
            
            DispatchQueue.main.async {
                completion(itemName, description, category, price)
            }
        }
    }
    
    func generateItemsPrompt(_ items: [Item]) -> String {
        // 创建物品信息摘要
        let itemsList = items.map { item in
            """
            - \(item.name)：
              位置：\(item.location)
              价格：\(String(format: "%.2f", item.estimatedPrice))元
              状态：\(item.isInUse ? "使用中" : "可用")
              描述：\(item.description)
              分类：\(item.category)
            """
        }.joined(separator: "\n")
        
        // 创建系统提示
        return """
        你是一个智能助手，帮助用户管理和查找他们的物品。根据以下物品信息回答用户的问题：

        物品列表：
        \(itemsList)

        统计信息：
        - 物品总数：\(items.count)件
        - 总价值：\(String(format: "%.2f", items.reduce(0) { $0 + $1.estimatedPrice }))元
        - 使用中物品：\(items.filter { $0.isInUse }.count)件
        - 可用物品：\(items.filter { !$0.isInUse }.count)件
        - 位置分布：\(Dictionary(grouping: items) { $0.location }.map { "\($0.key): \($0.value.count)件" }.joined(separator: "、"))

        请用简短的语言回答用户的问题。如果问题涉及具体物品，请提供该物品的位置、价格和使用状态等信息。
        """
    }
    
    func queryAboutItems(_ query: String, items: [Item], completion: @escaping (String?) -> Void) {
        let systemPrompt = generateItemsPrompt(items)
        performWebSearch(query: query, systemPrompt: systemPrompt, completion: completion)
    }
    
    // 辅助函数：将详细类别映射到更广泛的类别
    private func mapToBroaderCategory(detailedCategory: String) -> String {
        let lowercasedCategory = detailedCategory.lowercased()
        
        switch lowercasedCategory {
        case "相机", "手机", "电脑", "平板", "电视", "耳机", "充电器", "智能手表", "打印机", "显示器", "音响":
            return "电子产品"
        case "衬衫", "裤子", "裙子", "外套", "毛衣", "T恤", "连衣裙", "鞋子", "帽子", "围巾", "手套":
            return "衣服"
        case "椅子", "桌子", "床", "沙发", "柜子", "书架", "灯具", "置物架":
            return "家具"
        case "锅", "碗", "碟", "杯子", "餐具", "厨具", "刀具", "烤箱", "微波炉":
            return "厨具"
        case "哑铃", "跑步机", "瑜伽垫", "篮球", "足球", "网球拍", "运动服":
            return "运动用品"
        case "口红", "粉底", "香水", "眼影", "护肤品", "化妆刷":
            return "化妆品"
        case "锤子", "螺丝刀", "扳手", "电钻", "测量工具":
            return "工具"
        case "乐高", "模型", "玩偶", "棋盘游戏", "遥控玩具":
            return "玩具"
        case "小说", "漫画", "杂志", "教科书", "笔记本":
            return "书籍"
        case "钢笔", "铅笔", "橡皮", "尺子", "剪刀", "胶水", "文件袋":
            return "文具"
        default:
            // 如果没有匹配到更广泛的类别，返回原始类别或默认的“其他”
            return detailedCategory.isEmpty ? "其他" : detailedCategory
        }
    }
    
    // 新增：图片分割和批量识别功能 - 使用百度多主体检测 API
    func segmentAndAnalyzeImage(_ image: UIImage, completion: @escaping ([SegmentedItem]) -> Void) {
        // 使用百度多主体检测 API
        detectMultipleObjects(from: image) { objects in
            let segmentedItems = objects.enumerated().map { index, object in
                // 根据检测到的位置裁剪图片
                let croppedImage = self.cropImage(image: image, rect: object.location)
                
                return SegmentedItem(
                    id: UUID(),
                    image: croppedImage,
                    name: object.name,
                    description: "检测到的\(object.name)",
                    category: self.mapToBroaderCategory(detailedCategory: object.name),
                    estimatedPrice: 0.0, // 价格需要单独估算
                    confidence: object.score,
                    itemNumber: ""
                )
            }
            completion(segmentedItems)
        }
    }

    // ===== Baidu API Image Processing Helpers (from testmyself.swift) =====

    private func loadCGImage(from data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    private func imageSize(of data: Data) -> (w: Int, h: Int)? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (w, h)
    }

    private func cropToMaxAspect(_ img: CGImage, maxAspect: CGFloat) -> CGImage {
        let w = CGFloat(img.width), h = CGFloat(img.height)
        let ratio = max(w/h, h/w)
        guard ratio > maxAspect else { return img } // Already satisfied

        // Need to crop to the maximum allowed ratio, centered
        if w/h > maxAspect {
            let targetW = maxAspect * h
            let x = (w - targetW) / 2.0
            let rect = CGRect(x: Int(x), y: 0, width: Int(targetW), height: Int(h))
            return img.cropping(to: rect) ?? img
        } else {
            let targetH = maxAspect * w
            let y = (h - targetH) / 2.0
            let rect = CGRect(x: 0, y: Int(y), width: Int(w), height: Int(targetH))
            return img.cropping(to: rect) ?? img
        }
    }

    private func resize(_ img: CGImage, minShort: CGFloat, maxLong: CGFloat) -> CGImage {
        // Calculate scaling factor: short side >= 64, long side <= 4096
        let w = CGFloat(img.width), h = CGFloat(img.height)
        let shortSide = min(w, h)
        let longSide = max(w, h)

        var scaleUp: CGFloat = 1.0
        if shortSide < minShort { scaleUp = minShort / shortSide }

        var scaleDown: CGFloat = 1.0
        if longSide > maxLong { scaleDown = maxLong / longSide }

        // Combine scale factors
        let finalScale = min(max(scaleUp, 1.0), scaleDown)

        let newW = max(1, Int(round(w * finalScale)))
        let newH = max(1, Int(round(h * finalScale)))

        guard newW != img.width || newH != img.height else { return img }

        // Redraw to scale using CoreGraphics
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = newW * bytesPerPixel
        guard let ctx = CGContext(data: nil,
                                  width: newW,
                                  height: newH,
                                  bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return img }

        ctx.interpolationQuality = .high
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: newW, height: newH))
        return ctx.makeImage() ?? img
    }

    private func encodeJPEG(_ img: CGImage, quality: CGFloat) -> Data? {
        #if canImport(UniformTypeIdentifiers)
        let utType = UTType.jpeg.identifier as CFString
        #else
        let utType = "public.jpeg" as CFString
        #endif
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, utType, 1, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(dest, img, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    private func percentEncodeBase64(_ base64: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        return base64.addingPercentEncoding(withAllowedCharacters: allowed) ?? base64
    }

    private func buildFormBody(imageBase64: String) -> Data? {
        let encoded = percentEncodeBase64(imageBase64)
        if encoded.contains("%2F") || encoded.contains("%2B") || encoded.contains("%3D") {
            print("✅ Base64 已严格 percent-encoding（包含 %2F/%2B/%3D）")
        } else {
            print("⚠️ 注意：encoded 未发现 %2F/%2B/%3D（注意对比）")
        }
        let bodyString = "image=\(encoded)"
        return bodyString.data(using: .utf8)
    }

    private func lengthInBytes(_ s: String) -> Int { s.lengthOfBytes(using: .utf8) }

    // Constants for Baidu API from testmyself.swift
    private let baiduMaxBytes: Int = 4 * 1024 * 1024           // 4MB
    private let baiduMinShortSide: CGFloat = 64
    private let baiduMaxLongSide: CGFloat = 4096
    private let baiduMaxAspect: CGFloat = 3.0                   // 3:1
    private let baiduInitialJPEGQuality: CGFloat = 0.9
    private let baiduMinJPEGQuality: CGFloat = 0.2

    // 使用百度多主体检测 API (Replacement from testmyself.swift)
    private func detectMultipleObjects(from image: UIImage, completion: @escaping ([BaiduObject]) -> Void) {
        guard let accessToken = baiduAccessToken else {
            print("百度 API 访问令牌未获取")
            DispatchQueue.main.async { completion([]) }
            return
        }

        guard let originalData = image.jpegData(compressionQuality: 1.0) ?? image.pngData() else {
            print("❌ 错误：无法获取原始图片数据")
            DispatchQueue.main.async { completion([]) }
            return
        }

        // Decode to CGImage
        guard var cgImage = loadCGImage(from: originalData) else {
            print("❌ 错误：无法解码为 CGImage（图片可能损坏或格式不支持）")
            DispatchQueue.main.async { completion([]) }
            return
        }

        // Print original image size
        print("📐 原始尺寸：\(cgImage.width) x \(cgImage.height)")

        // Constrain aspect ratio <= 3:1 (center crop if necessary)
        cgImage = cropToMaxAspect(cgImage, maxAspect: baiduMaxAspect)

        // Size constraints: minShortSide >= 64, maxLongSide <= 4096 (resize if necessary)
        cgImage = resize(cgImage, minShort: baiduMinShortSide, maxLong: baiduMaxLongSide)
        print("📐 处理后尺寸：\(cgImage.width) x \(cgImage.height)")

        // Encode as JPEG and control volume (start with 0.9 quality)
        var quality = baiduInitialJPEGQuality
        var jpegData: Data? = encodeJPEG(cgImage, quality: quality)

        if jpegData == nil {
            print("❌ 错误：JPEG 编码失败")
            DispatchQueue.main.async { completion([]) }
            return
        }

        // Loop to reduce quality to ensure Base64 and urlencode are both < 4MB
        while true {
            guard let data = jpegData else {
                print("❌ 错误：JPEG 数据为 nil")
                DispatchQueue.main.async { completion([]) }
                return
            }
            let base64 = data.base64EncodedString() // No data:image/... header
            let base64Bytes = lengthInBytes(base64)

            // Construct x-www-form-urlencoded
            guard let formData = buildFormBody(imageBase64: base64) else {
                print("❌ 错误：构造表单请求体失败")
                DispatchQueue.main.async { completion([]) }
                return
            }
            let urlEncodedBytes = formData.count

            print("📦 当前质量：\(String(format: "%.2f", quality)) | Base64: \(base64Bytes)B | URL Encoded: \(urlEncodedBytes)B")

            if base64Bytes <= baiduMaxBytes && urlEncodedBytes <= baiduMaxBytes {
                // Meet 4MB dual constraints, send request
                var urlComps = URLComponents(string: "https://aip.baidubce.com/rest/2.0/image-classify/v1/multi_object_detect")!
                urlComps.queryItems = [URLQueryItem(name: "access_token", value: accessToken)]
                guard let url = urlComps.url else {
                    print("❌ 错误：URL 拼接失败")
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
                request.httpBody = formData

                // Log: Confirm percent-encoded (should see %2B/%2F/%3D)
                if let q = String(data: formData, encoding: .utf8) {
                    print("🧪 表单前60字符：\(q.prefix(60))")
                    if q.contains("%2B") { print("✅ 已正确编码 '+'") }
                    if q.contains("%2F") { print("✅ 已正确编码 '/'") }
                    if q.contains("%3D") { print("✅ 已正确编码 '='") }
                }

                print("🚀 发送请求到：\(url.absoluteString)")

                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        print("❌ 请求失败: \(error)")
                        DispatchQueue.main.async { completion([]) }
                        return
                    }

                    guard let data = data else {
                        print("⚠️ 没有收到数据")
                        DispatchQueue.main.async { completion([]) }
                        return
                    }

                    if let http = response as? HTTPURLResponse {
                        print("📡 HTTP 状态码：\(http.statusCode)")
                    }
                    print("📦 响应大小：\(data.count) 字节")
                    do {
                        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                        print("百度 API 响应: \(json ?? [:])")

                        guard let result = json?["result"] as? [[String: Any]] else {
                            print("解析结果失败: 'result' 字段不存在或格式错误")
                            DispatchQueue.main.async { completion([]) }
                            return
                        }

                        let objects = result.compactMap { BaiduObject(from: $0) }
                        DispatchQueue.main.async {
                            completion(objects)
                        }
                    } catch {
                        print("JSON 解析失败: \(error)")
                        if let txt = String(data: data, encoding: .utf8) {
                            print("📜 原始响应文本：\(txt)")
                        }
                        DispatchQueue.main.async { completion([]) }
                    }
                }.resume()
                return // Exit the while loop after sending request
            }

            // If over limit, reduce quality and try again
            quality -= 0.1
            if quality < baiduMinJPEGQuality {
                print("❌ 无法满足 4MB 限制（即便质量降到 \(baiduMinJPEGQuality) 仍超过），请尝试更低分辨率图片。")
                DispatchQueue.main.async { completion([]) }
                return // Exit the function
            }
            jpegData = encodeJPEG(cgImage, quality: quality)
        }
    }

    // 使用百度多主体检测 API
    private func detectMultipleObjects111(from image: UIImage, completion: @escaping ([BaiduObject]) -> Void) {
        guard let accessToken = baiduAccessToken else {
            print("百度 API 访问令牌未获取")
            completion([])
            return
        }

        // 检查并调整图片尺寸
        let processedImage = self.processImageForBaiduAPI(image)

        // 强制使用 JPEG 格式，固定压缩质量
        guard let imageData = processedImage.pngData() else {
            print("图片转换为 JPEG 失败")
            completion([])
            return
        }

        let base64String = imageData.base64EncodedString()
        print("Base64 字符串长度: \(base64String.count)")
        print("原始 Base64 前100个字符: \(String(base64String.prefix(100)))")
        print("原始 Base64 后100个字符: \(String(base64String.suffix(100)))")
        print("原始 Base64 字符: \(String(base64String))")

        // 检查大小限制
        var finalBase64String: String
        if base64String.count > 4 * 1024 * 1024 {
            print("图片太大，尝试更高压缩")
            guard let compressedData = processedImage.jpegData(compressionQuality: 0.3) else {
                print("图片压缩失败")
                completion([])
                return
            }
            let compressedBase64 = compressedData.base64EncodedString()
            if compressedBase64.count > 4 * 1024 * 1024 {
                print("图片仍然太大")
                completion([])
                return
            }
            finalBase64String = compressedBase64
        } else {
            finalBase64String = base64String
        }

        let urlString = "https://aip.baidubce.com/rest/2.0/image-classify/v1/multi_object_detect?access_token=\(accessToken)"
        guard let url = URL(string: urlString) else {
            print("URL 创建失败")
            completion([])
            return
        }



   

        let encodedBase64 = finalBase64String.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? finalBase64String
        let bodyString = "image=\(encodedBase64)"

        print("发送请求，Base64 长度: \(finalBase64String.count)")
        print("URL 编码后长度: \(encodedBase64.count)")
        print("请求体长度: \(bodyString.count)")

    
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyString.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("请求失败: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }

            guard let data = data else {
                print("没有收到数据")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }

        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            print("百度 API 响应: \(json ?? [:])")

            guard let result = json?["result"] as? [[String: Any]] else {
                print("解析结果失败")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }

            let objects = result.compactMap { BaiduObject(from: $0) }
            DispatchQueue.main.async {
                completion(objects)
            }
        } catch {
            print("JSON 解析失败: \(error)")
            DispatchQueue.main.async {
                completion([])
            }
        }
    }.resume()
}

// ... existing code ...

    

}

// 百度 API 返回的物体数据模型
struct BaiduObject {
    let name: String
    let score: Double
    let location: CGRect
    
    init?(from json: [String: Any]) {
        guard let name = json["name"] as? String,
              let location = json["location"] as? [String: Any],
              let left = location["left"] as? Int,
              let top = location["top"] as? Int,
              let width = location["width"] as? Int,
              let height = location["height"] as? Int else {
            return nil
        }
        
        // 处理 score，可能是字符串或数字
        let score: Double
        if let scoreString = json["score"] as? String {
            score = Double(scoreString) ?? 0.0
        } else if let scoreNumber = json["score"] as? Double {
            score = scoreNumber
        } else {
            score = 0.0
        }
        
        self.name = name
        self.score = score
        // 百度 API 返回的是绝对坐标
        self.location = CGRect(x: Double(left), y: Double(top), width: Double(width), height: Double(height))
    }
}

// 分割物品的数据模型
struct SegmentedItem: Identifiable {
    let id: UUID
    let image: UIImage
    let name: String
    let description: String
    let category: String
    let estimatedPrice: Double
    let confidence: Double
    let itemNumber: String
}

// MARK: - 工具函数扩展

extension UIImage {
    func pixelBuffer() -> CVPixelBuffer? {
        let size = CGSize(width: size.width, height: size.height)
        var pb: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault,
                            Int(size.width), Int(size.height),
                            kCVPixelFormatType_32BGRA,
                            attrs, &pb)
        guard let buffer = pb else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        context.draw(cgImage!, in: CGRect(origin: .zero, size: size))
        return buffer
    }
}

extension AIService {
    private func processImageForBaiduAPI(_ image: UIImage) -> UIImage {
        let imageSize = image.size
        print("原始图片尺寸: \(imageSize.width) x \(imageSize.height)")
        
        // 百度 API 要求：最短边至少64px，最长边最大4096px，长宽比3:1以内
        let minSize: CGFloat = 64
        let maxSize: CGFloat = 4096
        let maxAspectRatio: CGFloat = 3.0
        
        var targetSize = imageSize
        
        // 检查长宽比
        let aspectRatio = imageSize.width / imageSize.height
        if aspectRatio > maxAspectRatio || aspectRatio < 1.0/maxAspectRatio {
            print("图片长宽比不符合要求，需要调整")
            if aspectRatio > maxAspectRatio {
                // 图片太宽，调整宽度
                targetSize.width = imageSize.height * maxAspectRatio
                targetSize.height = imageSize.height
            } else {
                // 图片太高，调整高度
                targetSize.height = imageSize.width * maxAspectRatio
                targetSize.width = imageSize.width
            }
        }
        
        // 检查尺寸限制
        if targetSize.width < minSize || targetSize.height < minSize {
            print("图片尺寸太小，需要放大")
            let scale = max(minSize / targetSize.width, minSize / targetSize.height)
            targetSize.width *= scale
            targetSize.height *= scale
        }
        
        // 确保图片不会太大，控制在合理范围内
        let maxDimension: CGFloat = 1024 // 限制最大尺寸为1024px
        if targetSize.width > maxDimension || targetSize.height > maxDimension {
            print("图片尺寸太大，需要缩小到 \(maxDimension)px 以内")
            let scale = min(maxDimension / targetSize.width, maxDimension / targetSize.height)
            targetSize.width *= scale
            targetSize.height *= scale
        }
        
        print("调整后图片尺寸: \(targetSize.width) x \(targetSize.height)")
        
        // 如果尺寸没有变化，直接返回原图
        if targetSize == imageSize {
            return image
        }
        
        // 调整图片尺寸，确保输出 JPEG 格式
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // 确保返回 JPEG 格式的图片
        // if let resizedImage = resizedImage,
        //    let jpegData = resizedImage.jpegData(compressionQuality: 0.9),
        //    let jpegImage = UIImage(data: jpegData) {
        //     return jpegImage
        // }
        
        return resizedImage ?? image
    }
    
    private func cropImage(image: UIImage, rect: CGRect) -> UIImage {
        let imageSize = image.size
        
        // 百度 API 返回的是绝对坐标，直接使用
        let cropRect = CGRect(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.width,
            height: rect.height
        )
        
        // 确保裁剪区域在图片范围内
        let safeRect = CGRect(
            x: max(0, cropRect.origin.x),
            y: max(0, cropRect.origin.y),
            width: min(cropRect.width, imageSize.width - cropRect.origin.x),
            height: min(cropRect.height, imageSize.height - cropRect.origin.y)
        )
        
        guard let cgImage = image.cgImage?.cropping(to: safeRect) else {
            return image // 如果裁剪失败，返回原图
        }
        
        return UIImage(cgImage: cgImage)
    }
}