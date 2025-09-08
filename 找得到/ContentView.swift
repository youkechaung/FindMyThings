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
    @EnvironmentObject private var authService: AuthService // Add AuthService
    @EnvironmentObject private var supabaseService: SupabaseService // Add SupabaseService
    @State private var showingAddItem = false
    @State private var showingImageAnalysis = false
    @State private var showingChat = false
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
        Group {
            // 正常的认证状态检查
            if authService.isAuthenticated {
                // 临时简化版本，避免复杂的UI导致卡死
                // VStack(spacing: 20) {
                //     Text("登录成功！")
                //         .font(.largeTitle)
                //         .foregroundColor(.green)
                //         .padding()
                    
                //     Text("欢迎使用找得到")
                //         .font(.headline)
                //         .foregroundColor(.secondary)
                //         .padding()
                    
                //     VStack(spacing: 15) {
                //         Button("添加物品") {
                //             showingAddItem = true
                //         }
                //         .foregroundColor(.white)
                //         .frame(maxWidth: .infinity)
                //         .frame(height: 50)
                //         .background(Color.blue)
                //         .cornerRadius(12)
                        
                //         Button("图片分析") {
                //             showingImageAnalysis = true
                //         }
                //         .foregroundColor(.blue)
                //         .frame(maxWidth: .infinity)
                //         .frame(height: 50)
                //         .background(Color.blue.opacity(0.1))
                //         .cornerRadius(12)
                        
                //         Button("退出登录") {
                //             Task {
                //                 await authService.signOut()
                //             }
                //         }
                //         .foregroundColor(.white)
                //         .frame(maxWidth: .infinity)
                //         .frame(height: 50)
                //         .background(Color.red)
                //         .cornerRadius(12)
                //     }
                //     .padding(.horizontal, 30)
                    
                //     Spacer()
                // }
                // .padding()
                // .sheet(isPresented: $showingAddItem) {
                //     AddItemView()
                //         .environmentObject(itemManager)
                //         .environmentObject(supabaseService)
                // }
                // .sheet(isPresented: $showingImageAnalysis) {
                //     ImageAnalysisView()
                //         .environmentObject(itemManager)
                //         .environmentObject(supabaseService)
                // }
                
                // 原始复杂UI暂时注释掉，避免卡死
                
                TabView {
                    // 主页 - 物品管理
                    HomeView(
                        searchText: $searchText,
                        itemManager: itemManager,
                        authService: authService,
                        showingAddItem: $showingAddItem,
                        showingImageAnalysis: $showingImageAnalysis
                    )
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("首页")
                    }
                    
                    // 搜索页面
                    SearchView(itemManager: itemManager)
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("搜索")
                    }
                    
                    // 统计页面
                    StatsView(itemManager: itemManager)
                    .tabItem {
                        Image(systemName: "chart.bar.fill")
                        Text("统计")
                    }
                    
                    // 聊天页面
                    ChatTabView(
                        messages: $messages,
                        newMessage: $newMessage,
                        isLoading: $isLoading,
                        isRecording: $isRecording,
                        onSend: sendMessage,
                        onRecord: toggleRecording
                    )
                    .tabItem {
                        Image(systemName: "message.fill")
                        Text("管家")
                    }
                    
                    // 设置页面
                    SettingsView(itemManager: itemManager)
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text("设置")
                    }
                }
                .accentColor(.blue)
            .fullScreenCover(isPresented: $showingChat) {
                ChatView(
                    messages: $messages,
                    newMessage: $newMessage,
                    isLoading: $isLoading,
                    isRecording: $isRecording,
                    onSend: sendMessage,
                    onRecord: toggleRecording
                )
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
                
            } else {
                LoginView()
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
            \(self.itemManager.items.map { item in
                """
                - \(item.name)：
                  位置：\(item.location)
                  价格：\(String(format: "%.2f", item.estimatedPrice))元
                  状态：\(item.isInUse ? "使用中" : "可用")
                  描述：\(item.description)
                  分类：\(item.categoryLevel1)
                """
            }.joined(separator: "\n"))

            统计信息：
            - 物品总数：\(self.itemManager.items.count)件
            - 总价值：\(String(format: "%.2f", self.itemManager.getTotalValue()))元
            - 使用中物品：\(self.itemManager.getInUseItems().count)件
            - 可用物品：\(self.itemManager.getAvailableItems().count)件
            - 位置分布：\(Dictionary(grouping: self.itemManager.items) { $0.location }.map { "\($0.key): \($0.value.count)件" }.joined(separator: "、"))

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
        response = self.itemManager.processComplexQuery(actualQuery)
        if response != nil {
            completion(response!)
            return
        }
        
        // 处理总价值查询
        if actualQuery.contains("总价值") || actualQuery.contains("总共值") {
            let totalValue = self.itemManager.getTotalValue()
            response = "所有物品的总价值为 \(String(format: "%.2f", totalValue)) 元"
        }
        
        // 处理位置物品数量查询
        else if actualQuery.contains("多少个") || actualQuery.contains("几个") {
            for location in self.itemManager.getAllLocations() {
                if actualQuery.contains(location.lowercased()) {
                    let items = self.itemManager.itemsInLocation(location)
                    let inUseItems = self.itemManager.getInUseItemsInLocation(location)
                    response = "\(location)总共有\(items.count)个物品，其中\(inUseItems.count)个正在使用中"
                    break
                }
            }
        }
        
        // 处理使用状态查询
        else if actualQuery.contains("正在用") || actualQuery.contains("使用中") || actualQuery.contains("在用") {
            let inUseItems = self.itemManager.getInUseItems()
            if inUseItems.isEmpty {
                response = "目前没有正在使用的物品"
            } else {
                let itemsDesc = inUseItems.map { "\($0.name)（在\($0.location)）" }.joined(separator: "、")
                response = "正在使用的物品有：\(itemsDesc)"
            }
        }
        
        // 处理可用状态查询
        else if actualQuery.contains("可以用") || actualQuery.contains("能用") || actualQuery.contains("空闲") {
            let availableItems = self.itemManager.getAvailableItems()
            if availableItems.isEmpty {
                response = "目前所有物品都在使用中"
            } else {
                let itemsDesc = availableItems.map { "\($0.name)（在\($0.location)）" }.joined(separator: "、")
                response = "可以使用的物品有：\(itemsDesc)"
            }
        }
        
        // 处理位置总价值查询
        else if actualQuery.contains("值多少") || actualQuery.contains("价值") {
            for location in self.itemManager.getAllLocations() {
                if actualQuery.contains(location.lowercased()) {
                    let locationValue = self.itemManager.getTotalValueByLocation()
                        .first { $0.location.lowercased() == location.lowercased() }?.value ?? 0
                    let items = self.itemManager.itemsInLocation(location)
                    let inUseItems = self.itemManager.getInUseItemsInLocation(location)
                    response = "\(location)的物品总价值为 \(String(format: "%.2f", locationValue)) 元，共有\(items.count)个物品，其中\(inUseItems.count)个正在使用中"
                    break
                }
            }
        }
        
        // 处理最贵物品查询
        else if actualQuery.contains("最贵") || actualQuery.contains("价值最高") {
            let valuableItems = self.itemManager.getMostValuableItems(limit: 3)
            if !valuableItems.isEmpty {
                let itemsDesc = valuableItems.map { 
                    "\($0.name)（\(String(format: "%.2f", $0.estimatedPrice))元，\($0.isInUse ? "使用中" : "可用")）" 
                }.joined(separator: "、")
                response = "最贵的物品是：\(itemsDesc)"
            }
        }
        
        // 处理位置查询
        else {
            for item in self.itemManager.items {
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

// MARK: - HomeView

struct HomeView: View {
    @Binding var searchText: String
    @ObservedObject var itemManager: ItemManager
    @ObservedObject var authService: AuthService
    @EnvironmentObject private var supabaseService: SupabaseService // Add SupabaseService
    @Binding var showingAddItem: Bool
    @Binding var showingImageAnalysis: Bool
    @State private var showingBatchAdd = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 8)
                
                // 分类网格
                CategoryListView(
                    items: itemManager.searchItems(query: searchText),
                    itemManager: itemManager
                )
            }
            .navigationTitle("物品管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAddItem = true }) {
                            Label("添加新物品", systemImage: "square.and.pencil")
                        }
                        Button(action: { showingImageAnalysis = true }) {
                            Label("单个物品分析", systemImage: "camera")
                        }
                        Button(action: { showingBatchAdd = true }) {
                            Label("批量添加", systemImage: "photo.on.rectangle.angled")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView()
                    .environmentObject(itemManager)
            }
            .sheet(isPresented: $showingImageAnalysis) {
                ImageAnalysisView()
                    .environmentObject(itemManager)
            }
            .sheet(isPresented: $showingBatchAdd) {
                BatchAddItemsView()
                    .environmentObject(itemManager)
                    .environmentObject(authService)
                    .environmentObject(supabaseService)
            }
        }
    }
}

// ...
// MARK: - StatsCardView

struct StatsCardView: View {
    @ObservedObject var itemManager: ItemManager
    
    var body: some View {
        HStack(spacing: 16) {
            // 总价值
            StatItemView(
                icon: "yensign.circle.fill",
                title: "总价值",
                value: "¥\(String(format: "%.0f", itemManager.items.reduce(0) { $0 + $1.estimatedPrice }))",
                color: .green
            )
            
            // 物品数量
            StatItemView(
                icon: "cube.box.fill",
                title: "物品数量",
                value: "\(itemManager.items.count)件",
                color: .blue
            )
            
            // 使用中物品
            StatItemView(
                icon: "hand.raised.fill",
                title: "使用中",
                value: "\(self.itemManager.getInUseItems().count)件",
                color: .orange
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - StatItemView

struct StatItemView: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - SearchView

struct SearchView: View {
    @ObservedObject var itemManager: ItemManager
    @State private var searchText = ""
    @State private var selectedCategory = ""
    
    var filteredItems: [Item] {
        var items = itemManager.items
        
        if !searchText.isEmpty {
            items = items.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.description.localizedCaseInsensitiveContains(searchText) ||
                item.location.localizedCaseInsensitiveContains(searchText) ||
                item.itemNumber.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if !selectedCategory.isEmpty {
            items = items.filter { $0.categoryLevel1 == selectedCategory }
        }
        
        return items.sorted { $0.itemNumber < $1.itemNumber }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                SearchBar(text: $searchText)
                    .padding()
                
                // 类别筛选
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryFilterButton(
                            title: "全部",
                            isSelected: selectedCategory.isEmpty,
                            action: { selectedCategory = "" }
                        )
                        
                        ForEach(itemManager.getAllAvailableCategories(), id: \.self) { category in
                            CategoryFilterButton(
                                title: category,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
                
                // 搜索结果
                if filteredItems.isEmpty {
                    EmptyStateView(message: "没有找到相关物品")
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(filteredItems) { item in
                                NavigationLink(destination: ItemDetailView(item: item, itemManager: itemManager)) {
                                    ItemCardView(item: item, itemManager: itemManager)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("搜索物品")
        }
    }
}

// MARK: - CategoryFilterButton

struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

// MARK: - EmptyStateView

struct EmptyStateView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - StatsView

struct StatsView: View {
    @ObservedObject var itemManager: ItemManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 总览统计
                    OverviewStatsView(itemManager: itemManager)
                    
                    // 分类统计
                    CategoryStatsView(itemManager: itemManager)
                    
                    // 价值统计
                    ValueStatsView(itemManager: itemManager)
                    
                    // 使用情况统计
                    UsageStatsView(itemManager: itemManager)
                }
                .padding()
            }
            .navigationTitle("统计分析")
        }
    }
}

// MARK: - OverviewStatsView

struct OverviewStatsView: View {
    @ObservedObject var itemManager: ItemManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("总览")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCardView(
                    title: "物品总数",
                    value: "\(itemManager.items.count)",
                    icon: "cube.box.fill",
                    color: .blue
                )
                
                StatCardView(
                    title: "总价值",
                    value: "¥\(String(format: "%.0f", itemManager.getTotalValue()))",
                    icon: "yensign.circle.fill",
                    color: .green
                )
                
                StatCardView(
                    title: "使用中",
                    value: "\(self.itemManager.getInUseItems().count)",
                    icon: "hand.raised.fill",
                    color: .orange
                )
                
                StatCardView(
                    title: "分类数",
                    value: "\(itemManager.getAllCategories().count)",
                    icon: "folder.fill",
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - StatCardView

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - CategoryStatsView

struct CategoryStatsView: View {
    @ObservedObject var itemManager: ItemManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("分类统计")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(itemManager.getCategoryItemCounts(), id: \.category) { stat in
                    HStack {
                        Text(stat.category)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(stat.count)件")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - ValueStatsView

struct ValueStatsView: View {
    @ObservedObject var itemManager: ItemManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("价值分布")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(itemManager.getTotalValueByCategory(), id: \.category) { stat in
                    HStack {
                        Text(stat.category)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("¥\(String(format: "%.0f", stat.value))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - UsageStatsView

struct UsageStatsView: View {
    @ObservedObject var itemManager: ItemManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("使用情况")
                .font(.headline)
                .padding(.horizontal)
            
            let efficiency = itemManager.getUsageEfficiency()
            
            VStack(spacing: 16) {
                UsageGroupView(
                    title: "高频使用",
                    items: efficiency.highUsage,
                    color: .green
                )
                
                UsageGroupView(
                    title: "低频使用",
                    items: efficiency.lowUsage,
                    color: .orange
                )
                
                UsageGroupView(
                    title: "从未使用",
                    items: efficiency.unused,
                    color: .red
                )
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - UsageGroupView

struct UsageGroupView: View {
    let title: String
    let items: [Item]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                
                Spacer()
                
                Text("\(items.count)件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if items.isEmpty {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(items.prefix(3)) { item in
                    Text("• \(item.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if items.count > 3 {
                    Text("...还有\(items.count - 3)件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - ChatTabView

struct ChatTabView: View {
    @Binding var messages: [Message]
    @Binding var newMessage: String
    @Binding var isLoading: Bool
    @Binding var isRecording: Bool
    let onSend: () -> Void
    let onRecord: () -> Void
    
    var body: some View {
        ChatView(
            messages: $messages,
            newMessage: $newMessage,
            isLoading: $isLoading,
            isRecording: $isRecording,
            onSend: onSend,
            onRecord: onRecord
        )
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @ObservedObject var itemManager: ItemManager
    @EnvironmentObject var authService: AuthService // Add AuthService
    @State private var showingExportAlert = false
    @State private var showingImportAlert = false
    
    var body: some View {
        NavigationView {
        List {
                Section {
                    SettingsRowView(
                        icon: "square.and.arrow.up",
                        title: "导出数据",
                        action: { showingExportAlert = true }
                    )
                    
                    SettingsRowView(
                        icon: "square.and.arrow.down",
                        title: "导入数据",
                        action: { showingImportAlert = true }
                    )
                }
                
                Section {
                    SettingsRowView(
                        icon: "trash",
                        title: "清空所有数据",
                        isDestructive: true,
                        action: { }
                    )
                }
                
                Section {
                    SettingsRowView(
                        icon: "arrow.right.square",
                        title: "退出登录",
                        isDestructive: true,
                        action: {
                            Task { await authService.signOut() }
                        }
                    )
                } header: {
                    Text("账户")
                }
                
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
        }
        .alert("导出数据", isPresented: $showingExportAlert) {
            Button("确定") { }
            Button("取消", role: .cancel) { }
        } message: {
            Text("导出功能正在开发中")
        }
        .alert("导入数据", isPresented: $showingImportAlert) {
            Button("确定") { }
            Button("取消", role: .cancel) { }
        } message: {
            Text("导入功能正在开发中")
        }
    }
}

// MARK: - SettingsRowView

struct SettingsRowView: View {
    let icon: String
    let title: String
    let isDestructive: Bool
    let action: () -> Void
    
    init(icon: String, title: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isDestructive ? .red : .blue)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(isDestructive ? .red : .primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
    }
}

// MARK: - CategoryListView

struct CategoryListView: View {
    let items: [Item]
    let itemManager: ItemManager
    @State private var selectedCategory: String?
    @State private var draggedCategory: String?
    
    // 网格布局配置
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        Group {
            if let selectedCategory = selectedCategory,
               let categoryGroup = itemManager.getItemsByCategory().first(where: { $0.category == selectedCategory }) {
                // 显示选中类别的物品列表
                CategoryItemsView(
                    categoryGroup: categoryGroup,
                    itemManager: itemManager,
                    onBack: {
                        self.selectedCategory = nil
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            } else {
                // 显示分类网格
                CategoryGridView(
                    items: items,
                    itemManager: itemManager,
                    selectedCategory: $selectedCategory,
                    draggedCategory: $draggedCategory
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: selectedCategory)
    }
}

// MARK: - CategoryGridView

struct CategoryGridView: View {
    let items: [Item]
    let itemManager: ItemManager
    @Binding var selectedCategory: String?
    @Binding var draggedCategory: String?
    
    // 网格布局配置
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(itemManager.getItemsByCategory(), id: \.category) { categoryGroup in
                    CategoryCardView(
                        categoryGroup: categoryGroup,
                        itemManager: itemManager,
                        isSelected: selectedCategory == categoryGroup.category,
                        onTap: {
                            selectedCategory = categoryGroup.category
                        },
                        isDragging: draggedCategory == categoryGroup.category
                    )
                    .onDrag {
                        draggedCategory = categoryGroup.category
                        return NSItemProvider(object: categoryGroup.category as NSString)
                    }
                    .onDrop(of: [.text], delegate: DropViewDelegate(
                        draggedCategory: $draggedCategory,
                        targetCategory: categoryGroup.category,
                        itemManager: itemManager
                    ))
                }
            }
            .padding()
        }
    }
}

// MARK: - CategoryItemsView

struct CategoryItemsView: View {
    let categoryGroup: (category: String, items: [Item])
    let itemManager: ItemManager
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                        Text("返回")
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(categoryGroup.category)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text("\(categoryGroup.items.count)件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let categoryValue = itemManager.getTotalValueByCategory()
                            .first(where: { $0.category == categoryGroup.category })?.value {
                            Text("¥\(String(format: "%.0f", categoryValue))")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            // 物品网格
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(categoryGroup.items) { item in
                NavigationLink(destination: ItemDetailView(item: item, itemManager: itemManager)) {
                            ItemCardView(item: item, itemManager: itemManager)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - CategoryCardView

struct CategoryCardView: View {
    let categoryGroup: (category: String, items: [Item])
    let itemManager: ItemManager
    let isSelected: Bool
    let onTap: () -> Void
    let isDragging: Bool
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // 分类图标
                Image(systemName: getCategoryIcon(categoryGroup.category))
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                // 分类名称
                Text(categoryGroup.category)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                
                // 统计信息
                VStack(spacing: 4) {
                    Text("\(categoryGroup.items.count)件")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    
                    if let categoryValue = itemManager.getTotalValueByCategory()
                        .first(where: { $0.category == categoryGroup.category })?.value {
                        Text("¥\(String(format: "%.0f", categoryValue))")
                            .font(.caption)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .green)
                    }
                }
                
                // 选择指示器
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(12)
            .shadow(color: isSelected ? .blue.opacity(0.3) : .black.opacity(0.1), radius: isSelected ? 4 : 2, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : (isDragging ? 0.95 : 1.0))
        .opacity(isDragging ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.1), value: isDragging)
    }
    
    private func getCategoryIcon(_ category: String) -> String {
        switch category {
        case "电子产品":
            return "laptopcomputer"
        case "衣服":
            return "tshirt"
        case "家具":
            return "bed.double"
        case "书籍":
            return "book"
        case "厨具":
            return "fork.knife"
        case "运动用品":
            return "sportscourt"
        case "化妆品":
            return "paintbrush"
        case "工具":
            return "wrench.and.screwdriver"
        case "玩具":
            return "gamecontroller"
        case "其他":
            return "ellipsis.circle"
        default:
            return "cube.box"
        }
    }
}

// MARK: - ItemCardView

struct ItemCardView: View {
    let item: Item
    let itemManager: ItemManager
    
    var body: some View {
        VStack(spacing: 8) {
            // 物品图片
            if let imageURL = item.imageURL,
               let url = URL(string: imageURL) {
                AsyncImage(url: url) {
                    image in image
                    .resizable()
                    .scaledToFill()
                        .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    ProgressView()
                        .frame(height: 120)
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 120)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.title2)
                    )
            }
            
            VStack(spacing: 4) {
                // 物品名称
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                // 编号
                Text(item.itemNumber)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                
                // 位置和价格
                VStack(spacing: 2) {
                    Text(item.location)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    if item.estimatedPrice > 0 {
                        Text("¥\(String(format: "%.0f", item.estimatedPrice))")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                }
                
                // 使用状态
                if item.isInUse {
                    Text("使用中")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - CompactItemRowView

struct CompactItemRowView: View {
    let item: Item
    let itemManager: ItemManager
    
    var body: some View {
        HStack(spacing: 8) {
            if let imageURL = item.imageURL,
               let url = URL(string: imageURL) {
                AsyncImage(url: url) {
                    image in image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } placeholder: {
                    ProgressView()
                        .frame(width: 40, height: 40)
                }
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.caption2)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(item.location)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    if item.estimatedPrice > 0 {
                        Text("¥\(String(format: "%.0f", item.estimatedPrice))")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            Text(item.itemNumber)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - DropViewDelegate

struct DropViewDelegate: DropDelegate {
    @Binding var draggedCategory: String?
    let targetCategory: String
    let itemManager: ItemManager
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggedCategory = draggedCategory else { return false }
        
        // 执行类别移动
        itemManager.moveCategory(draggedCategory, to: targetCategory)
        
        self.draggedCategory = nil
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        return draggedCategory != targetCategory
    }
    
    func dropEntered(info: DropInfo) {
        // 可以在这里添加拖拽进入时的视觉反馈
    }
    
    func dropExited(info: DropInfo) {
        // 可以在这里添加拖拽离开时的视觉反馈
    }
}

struct AddButton: View {
    @Binding var showingAddItem: Bool
    @Binding var showingImageAnalysis: Bool
    
    var body: some View {
        Menu {
            Button(action: { showingAddItem = true }) {
                Label("添加新物品", systemImage: "square.and.pencil")
            }
            
            Button(action: { showingImageAnalysis = true }) {
                Label("物品分析", systemImage: "camera")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                Text("添加物品")
            }
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






