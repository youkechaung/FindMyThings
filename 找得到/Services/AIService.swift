import Foundation

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
    
    private func canMakeRequest() -> Bool {
        if let lastRequest = lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
            return timeSinceLastRequest >= minimumRequestInterval
        }
        return true
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
        lastRequestTime = Date()
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("请求失败: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Response status code: \(httpResponse.statusCode)")
            }
            
            completion(data, nil)
        }
        task.resume()
    }

    func performWebSearch(query: String, systemPrompt: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://api.moonshot.cn/v1/chat/completions") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": query]
        ]
        
        let requestBody: [String: Any] = [
            "model": "moonshot-v1-8k",
            "messages": messages
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(nil)
            return
        }
        
        performRequest(request: request) { data, error in
            guard let data = data,
                  let response = try? JSONDecoder().decode(ChatResponse.self, from: data),
                  let content = response.choices.first?.message.content else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            DispatchQueue.main.async {
                completion(content)
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

    func analyzeItem(name: String, imageData: Data, completion: @escaping (String, String, Double) -> Void) {
        guard let base64String = imageData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("图片编码失败")
            completion("无法分析物品", "其他", 0.0)
            return
        }
        
        let query = """
        这是一个名为"\(name)"的物品。请根据图片分析这个物品，并按以下格式返回信息：

        描述：[详细描述物品的外观、材质、状况等]
        类别：[给出最合适的物品类别]
        价格：[估算物品的价格，单位人民币，只返回数字]

        请确保返回的格式严格按照上述模板，每个部分单独一行。
        """
        
        let systemPrompt = """
        你是一个物品分析助手，专门帮助用户分析物品的详细信息。
        请仔细观察图片中的物品，结合物品名称，给出准确的描述、合适的类别和合理的价格估算。
        描述要详细具体，包括物品的外观特征、材质、状况等。
        类别要简洁准确，选择最合适的分类。
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
            completion("无法分析物品", "其他", 0.0)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion("无法分析物品", "其他", 0.0)
            return
        }
        
        performRequest(request: request) { data, error in
            guard let data = data,
                  let response = try? JSONDecoder().decode(ChatResponse.self, from: data),
                  let content = response.choices.first?.message.content else {
                DispatchQueue.main.async {
                    completion("无法分析物品", "其他", 0.0)
                }
                return
            }
            
            // 解析返回的内容
            let lines = content.components(separatedBy: "\n")
            var description = "无法分析物品"
            var category = "其他"
            var price: Double = 0.0
            
            for line in lines {
                if line.starts(with: "描述：") {
                    description = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                } else if line.starts(with: "类别：") {
                    category = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                } else if line.starts(with: "价格：") {
                    let priceText = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    let digits = priceText.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    price = Double(digits) ?? 0.0
                }
            }
            
            DispatchQueue.main.async {
                completion(description, category, price)
            }
        }
    }
}