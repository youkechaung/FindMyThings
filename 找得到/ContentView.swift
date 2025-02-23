//
//  ContentView.swift
//  找得到
//
//  Created by chloe on 2025/2/7.
//

import SwiftUI
import Speech
import AVFoundation

struct ContentView: View {
    @EnvironmentObject private var itemManager: ItemManager
    @State private var showingAddItem = false
    @State private var showingImageAnalysis = false
    @State private var searchText = ""
    @State private var messages: [Message] = []
    @State private var newMessage = ""
    @State private var isLoading = false
    @State private var isRecording = false
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var showingSpeechAlert = false
    @State private var speechAlertMessage = ""
    @State private var keyboardHeight: CGFloat = 0
    
    // 语音相关属性
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let audioEngine = AVAudioEngine()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchBar(text: $searchText)
                    .padding()
                
                ItemListView(
                    items: itemManager.searchItems(query: searchText),
                    itemManager: itemManager
                )
                .ignoresSafeArea(.keyboard)
                
                ChatView(
                    messages: $messages,
                    newMessage: $newMessage,
                    isLoading: $isLoading,
                    isRecording: $isRecording,
                    onSend: sendMessage,
                    onRecord: toggleRecording
                )
                .ignoresSafeArea(.keyboard)
            }
            .navigationTitle("找得到")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    AddButton(
                        showingAddItem: $showingAddItem,
                        showingImageAnalysis: $showingImageAnalysis
                    )
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView()
            }
            .sheet(isPresented: $showingImageAnalysis) {
                ImageAnalysisView()
                    .environmentObject(itemManager)
            }
            .alert("语音识别", isPresented: $showingSpeechAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(speechAlertMessage)
            }
            .onAppear {
                requestSpeechAuthorization()
                setupKeyboardNotifications()
            }
            .onDisappear {
                removeKeyboardNotifications()
            }
        }
    }
    
    private func requestSpeechAuthorization() {
        // 检查是否已经有权限
        if speechRecognizer?.isAvailable == true {
            return
        }
        
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    break
                case .denied:
                    speechAlertMessage = "请在设置中允许语音识别权限"
                    showingSpeechAlert = true
                case .restricted:
                    speechAlertMessage = "设备不支持语音识别"
                    showingSpeechAlert = true
                case .notDetermined:
                    speechAlertMessage = "请允许语音识别权限"
                    showingSpeechAlert = true
                @unknown default:
                    speechAlertMessage = "语音识别出现未知错误"
                    showingSpeechAlert = true
                }
            }
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        guard let recognizer = speechRecognizer else {
            speechAlertMessage = "语音识别不可用"
            showingSpeechAlert = true
            return
        }
        
        guard recognizer.isAvailable else {
            speechAlertMessage = "语音识别当前不可用"
            showingSpeechAlert = true
            return
        }
        
        // 停止任何正在进行的语音合成
        if SpeechManager.shared.synthesizer.isSpeaking {
            SpeechManager.shared.synthesizer.stopSpeaking(at: .immediate)
        }
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("设置音频会话失败: \(error.localizedDescription)")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            speechAlertMessage = "无法创建语音识别请求"
            showingSpeechAlert = true
            return
        }
        
        let inputNode = audioEngine.inputNode
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                DispatchQueue.main.async {
                    self.newMessage = result.bestTranscription.formattedString
                    if result.isFinal {
                        // 如果识别完成，自动发送消息
                        self.sendMessage()
                    }
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                DispatchQueue.main.async {
                    self.isRecording = false
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            speechAlertMessage = "无法启动语音识别"
            showingSpeechAlert = true
            return
        }
    }
    
    private func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
        isRecording = false
    }
    
    private func sendMessage() {
        guard !newMessage.isEmpty else { return }
        print("发送消息：\(newMessage)")
        
        let userMessage = Message(content: newMessage, isUser: true)
        messages.append(userMessage)
        
        // 保存当前消息内容并清空输入
        let currentMessage = newMessage
        let isVoiceMessage = isRecording // 记录是否是语音消息
        newMessage = ""
        isLoading = true
        
        // 处理用户的问题
        processUserQuery(currentMessage) { response in
            DispatchQueue.main.async {
                print("准备回复：\(response)")
                
                let assistantMessage = Message(content: response, isUser: false)
                self.messages.append(assistantMessage)
                
                // 只有在用户使用语音时才用语音回答
                if isVoiceMessage {
                    SpeechManager.shared.speak(response)
                }
                
                self.isLoading = false
            }
        }
    }
    
    private func processUserQuery(_ query: String, completion: @escaping (String) -> Void) {
        print("处理用户查询：\(query)")
        let normalizedQuery = query.lowercased()
        
        // 只处理以"管家"开头的查询
        guard normalizedQuery.hasPrefix("管家") else {
            // 准备物品信息
            let systemPrompt = """
            你是一个智能助手，帮助用户管理和查找他们的物品。根据以下物品信息回答用户的问题：

            物品列表：
            \(itemManager.items.map { item in
                """
                - \(item.name)：
                  位置：\(item.location)
                  价格：\(String(format: "%.2f", item.estimatedPrice))元
                  状态：\(item.isInUse ? "使用中" : "可用")
                  描述：\(item.description)
                  分类：\(item.category)
                """
            }.joined(separator: "\n"))

            统计信息：
            - 物品总数：\(itemManager.items.count)件
            - 总价值：\(String(format: "%.2f", itemManager.getTotalValue()))元
            - 使用中物品：\(itemManager.getInUseItems().count)件
            - 可用物品：\(itemManager.getAvailableItems().count)件
            - 位置分布：\(Dictionary(grouping: itemManager.items) { $0.location }.map { "\($0.key): \($0.value.count)件" }.joined(separator: "、"))

            请用简短的语言回答用户的问题。如果问题涉及具体物品，请提供该物品的位置、价格和使用状态等信息。
            """
            
            print("开始调用 AI 服务...")
            
            AIService.shared.performWebSearch(query: query, systemPrompt: systemPrompt) { result in
                print("收到 AI 服务响应：\(result ?? "nil")")
                completion(result ?? "抱歉，我暂时无法回答这个问题。请稍后再试。")
            }
            return
        }
        
        // 移除"管家"前缀后的查询内容
        let actualQuery = String(normalizedQuery.dropFirst(2))
        var response: String?
        
        // 首先尝试使用复杂查询处理
        response = itemManager.processComplexQuery(actualQuery)
        if response != nil {
            completion(response!)
            return
        }
        
        // 处理总价值查询
        if actualQuery.contains("总价值") || actualQuery.contains("总共值") {
            let totalValue = itemManager.getTotalValue()
            response = "所有物品的总价值为 \(String(format: "%.2f", totalValue)) 元"
        }
        
        // 处理位置物品数量查询
        else if actualQuery.contains("多少个") || actualQuery.contains("几个") {
            for location in itemManager.getAllLocations() {
                if actualQuery.contains(location.lowercased()) {
                    let items = itemManager.itemsInLocation(location)
                    let inUseItems = itemManager.getInUseItemsInLocation(location)
                    response = "\(location)总共有\(items.count)个物品，其中\(inUseItems.count)个正在使用中"
                    break
                }
            }
        }
        
        // 处理使用状态查询
        else if actualQuery.contains("正在用") || actualQuery.contains("使用中") || actualQuery.contains("在用") {
            let inUseItems = itemManager.getInUseItems()
            if inUseItems.isEmpty {
                response = "目前没有正在使用的物品"
            } else {
                let itemsDesc = inUseItems.map { "\($0.name)（在\($0.location)）" }.joined(separator: "、")
                response = "正在使用的物品有：\(itemsDesc)"
            }
        }
        
        // 处理可用状态查询
        else if actualQuery.contains("可以用") || actualQuery.contains("能用") || actualQuery.contains("空闲") {
            let availableItems = itemManager.getAvailableItems()
            if availableItems.isEmpty {
                response = "目前所有物品都在使用中"
            } else {
                let itemsDesc = availableItems.map { "\($0.name)（在\($0.location)）" }.joined(separator: "、")
                response = "可以使用的物品有：\(itemsDesc)"
            }
        }
        
        // 处理位置总价值查询
        else if actualQuery.contains("值多少") || actualQuery.contains("价值") {
            for location in itemManager.getAllLocations() {
                if actualQuery.contains(location.lowercased()) {
                    let locationValue = itemManager.getTotalValueByLocation()
                        .first { $0.location.lowercased() == location.lowercased() }?.value ?? 0
                    let items = itemManager.itemsInLocation(location)
                    let inUseItems = itemManager.getInUseItemsInLocation(location)
                    response = "\(location)的物品总价值为 \(String(format: "%.2f", locationValue)) 元，共有\(items.count)个物品，其中\(inUseItems.count)个正在使用中"
                    break
                }
            }
        }
        
        // 处理最贵物品查询
        else if actualQuery.contains("最贵") || actualQuery.contains("价值最高") {
            let valuableItems = itemManager.getMostValuableItems(limit: 3)
            if !valuableItems.isEmpty {
                let itemsDesc = valuableItems.map { 
                    "\($0.name)（\(String(format: "%.2f", $0.estimatedPrice))元，\($0.isInUse ? "使用中" : "可用")）" 
                }.joined(separator: "、")
                response = "最贵的物品是：\(itemsDesc)"
            }
        }
        
        // 处理位置查询
        else {
            for item in itemManager.items {
                let itemName = item.name.lowercased()
                if actualQuery.contains(itemName) && 
                   (actualQuery.contains("在哪") || 
                    actualQuery.contains("位置") || 
                    actualQuery.contains("找") || 
                    actualQuery.contains("where")) {
                    let status = item.isInUse ? "正在使用中" : "可以使用"
                    response = "\(item.name)在\(item.location)，价值\(String(format: "%.2f", item.estimatedPrice))元，\(status)"
                    break
                }
            }
        }
        
        completion(response ?? "抱歉，我不知道。您可以这样问我：\n1. 管家，XX在哪里\n2. 管家，XX有多少个物品\n3. 管家，物品总价值\n4. 管家，XX的物品总价值\n5. 管家，最贵的物品\n6. 管家，哪些物品正在使用中\n7. 管家，哪些物品可以使用")
    }
    
    // 添加键盘通知处理
    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }
    
    private func removeKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - 子视图

struct ItemListView: View {
    let items: [Item]
    let itemManager: ItemManager
    
    var body: some View {
        List {
            ForEach(items) { item in
                NavigationLink(destination: ItemDetailView(item: item, itemManager: itemManager)) {
                    ItemRowView(item: item, itemManager: itemManager)
                }
            }
            .onDelete { indexSet in
                // 处理删除
                indexSet.forEach { index in
                    let item = itemManager.items[index]
                    itemManager.deleteItem(item)
                }
            }
        }
    }
}

struct ItemRowView: View {
    let item: Item
    let itemManager: ItemManager
    
    var body: some View {
        HStack(spacing: 12) {
            if let imageData = item.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                Text(item.location)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    if !item.category.isEmpty {
                        Text(item.category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    if item.estimatedPrice > 0 {
                        Text("¥\(String(format: "%.2f", item.estimatedPrice))")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
                if item.isInUse {
                    Text("请放回原处，谢谢")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            Button {
                itemManager.toggleItemUse(item)
            } label: {
                Text(item.isInUse ? "归还" : "使用")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(item.isInUse ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                    .foregroundColor(item.isInUse ? .red : .blue)
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 8)
    }
}

struct AddButton: View {
    @Binding var showingAddItem: Bool
    @Binding var showingImageAnalysis: Bool
    
    var body: some View {
        Menu {
            Button(action: { showingAddItem = true }) {
                Label("添加物品", systemImage: "plus")
            }
            
            Button(action: { showingImageAnalysis = true }) {
                Label("图片分析", systemImage: "camera.viewfinder")
            }
        } label: {
            Image(systemName: "plus")
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("搜索物品...", text: $text)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
