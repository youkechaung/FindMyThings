import Foundation
import UIKit

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
    private var lastRequestTime: Date?
    private let minimumRequestInterval: TimeInterval = 1 // 1秒
    private var retryCount = 0
    private let maxRetries = 3
    
    private init() {
        // 初始化时不再获取百度 API 访问令牌
    }
    
    // 百度 API 访问令牌相关代码已移除
    
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
        物品类别：\(item.categoryLevel1)
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
            var categoryLevel1 = "其他"
            var price: Double = 0.0
            
            for line in lines {
                if line.hasPrefix("名称：") {
                    itemName = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
                } else if line.hasPrefix("描述：") {
                    description = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("类别：") {
                    let detailedCategory = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    categoryLevel1 = self.mapToBroaderCategory(detailedCategory: detailedCategory)
                } else if line.hasPrefix("价格：") {
                    if let priceStr = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).first {
                        price = Double(priceStr) ?? 0.0
                    }
                }
            }
            
            DispatchQueue.main.async {
                completion(itemName, description, categoryLevel1, price)
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
              一级分类：\(item.categoryLevel1)
              \(item.categoryLevel2.map { "二级分类：\($0)" } ?? "")
              \(item.categoryLevel3.map { "三级分类：\($0)" } ?? "")
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
    
    // 新增：图片分割和批量识别功能 - 使用 Kimi Vision API
    func segmentAndAnalyzeImage(_ image: UIImage, completion: @escaping ([SegmentedItem]) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("图片转换为 JPEG 失败")
            completion([])
            return
        }
        
        let base64String = imageData.base64EncodedString()
        let query = "请识别图片中的所有独立物品，为每个物品提供名称、详细描述、最合适的类别和估算价格（只返回数字，人民币单位）。详细描述应包括物品的外观、颜色、材质和状况等关键信息。请将每个物品的信息按照名称：[名称]、描述：[描述]、类别：[类别]、价格：[价格] 的格式单独列出，用换行符分隔。"
        let systemPrompt = "你是一个专业的物品分析助手，能够识别图片中的多个物品并提供详细信息。请务必为每个物品提供详细的描述。"
        
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
            print("URL 创建失败")
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("请求体序列化失败: \(error)")
            completion([])
            return
        }
        
        performRequest(request: request) { data, error in
            guard let data = data,
                  let response = try? JSONDecoder().decode(ChatResponse.self, from: data),
                  let content = response.choices.first?.message.content else {
                print("Kimi API 响应解析失败或无内容")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            print("Kimi API 原始响应: \(content)")
            
            var segmentedItems: [SegmentedItem] = []
            let itemBlocks = content.components(separatedBy: "名称：")
            
            for block in itemBlocks where !block.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                var itemName = ""
                var itemDescription = ""
                var itemCategory = "其他"
                var itemPrice: Double = 0.0
                
                let lines = block.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                
                for line in lines {
                    if line.hasPrefix("描述：") {
                        itemDescription = String(line.dropFirst("描述：".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if line.hasPrefix("类别：") {
                        let rawCategory = String(line.dropFirst("类别：".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                        itemCategory = self.mapToBroaderCategory(detailedCategory: rawCategory)
                    } else if line.hasPrefix("价格：") {
                        if let priceStr = String(line.dropFirst("价格：".count)).trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespaces).first {
                            itemPrice = Double(priceStr) ?? 0.0
                        }
                    }
                }
                
                // 'block' starts with the item name since we split by '名称：'
                let firstLineOfBlock = lines.first(where: { !$0.isEmpty }) ?? ""
                itemName = firstLineOfBlock.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
                
                // 如果名称为空，则不添加此物品
                if !itemName.isEmpty {
                    segmentedItems.append(SegmentedItem(
                        id: UUID(),
                        croppedImageData: imageData, // 使用原始图片数据
                        name: itemName,
                        description: itemDescription,
                        categoryLevel1: itemCategory, // Using itemCategory as level1
                        categoryLevel2: nil,
                        categoryLevel3: nil,
                        estimatedPrice: itemPrice,
                        confidence: 1.0, // Kimi 不直接提供置信度，默认为1.0
                        itemNumber: ""
                    ))
                }
            }
            DispatchQueue.main.async {
                completion(segmentedItems)
            }
        }
    }
}

// 分割物品的数据模型
struct SegmentedItem: Identifiable {
    let id: UUID
    let croppedImageData: Data? // Use Data for cropped image
    let name: String
    let description: String
    var categoryLevel1: String
    var categoryLevel2: String?
    var categoryLevel3: String?
    let estimatedPrice: Double
    let confidence: Double
    let itemNumber: String
}