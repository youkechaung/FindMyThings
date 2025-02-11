//
//  ContentView.swift
//  找得到
//
//  Created by chloe on 2025/2/7.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var itemManager = ItemManager()
    @State private var showingAddItem = false
    @State private var showingImageAnalysis = false
    @State private var searchText = ""
    @State private var messages: [Message] = []
    @State private var newMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchBar(text: $searchText)
                    .padding()
                
                List {
                    ForEach(itemManager.searchItems(query: searchText)) { item in
                        NavigationLink(destination: ItemDetailView(item: item, itemManager: itemManager)) {
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
                    .onDelete { indexSet in
                        indexSet.forEach { index in
                            let item = itemManager.items[index]
                            itemManager.deleteItem(item)
                        }
                    }
                }
                
                Divider()
                
                // 聊天区域
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                VStack(spacing: 8) {
                                    Text("👋 你好！我是AI助手")
                                        .font(.headline)
                                    Text("我可以帮你：")
                                        .font(.subheadline)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("• 给出物品存放建议")
                                        Text("• 帮你决定是否保留物品")
                                        Text("• 提供物品保养建议")
                                        Text("• 推荐物品使用方法")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal)
                                .padding(.top)
                            }
                            
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                            }
                            if isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding()
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                    }
                    .frame(height: 200)
                    
                    Divider()
                    
                    HStack(spacing: 8) {
                        TextField("问问AI助手...", text: $newMessage)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(isLoading)
                        
                        Button {
                            sendMessage()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(newMessage.isEmpty || isLoading ? .gray : .blue)
                        }
                        .disabled(newMessage.isEmpty || isLoading)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color.gray.opacity(0.05))
            }
            .navigationTitle("找得到")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingAddItem = true
                        }) {
                            Label("添加物品", systemImage: "plus")
                        }
                        
                        Button(action: {
                            showingImageAnalysis = true
                        }) {
                            Label("图片分析", systemImage: "camera.viewfinder")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView(itemManager: itemManager)
            }
            .sheet(isPresented: $showingImageAnalysis) {
                ImageAnalysisView()
            }
        }
    }
    
    private func sendMessage() {
        let userMessage = Message(content: newMessage, isUser: true)
        messages.append(userMessage)
        
        let userInput = newMessage
        newMessage = ""
        isLoading = true
        
        // 创建系统提示
        let systemPrompt = """
        你是一个友好的AI助手，可以帮助用户管理和整理他们的物品。
        你可以：
        1. 给出物品存放建议
        2. 帮助用户决定是否保留某些物品
        3. 提供物品保养和维护建议
        4. 推荐物品的使用方法
        5. 回答关于物品管理的任何问题
        请用简短、友好的方式回答。
        
        当前用户的物品列表：
        \(itemManager.items.map { "- \($0.name)（位置：\($0.location)）" }.joined(separator: "\n"))
        """
        
        AIService.shared.performWebSearch(query: userInput, systemPrompt: systemPrompt) { response in
            DispatchQueue.main.async {
                isLoading = false
                if let response = response {
                    let aiMessage = Message(content: response, isUser: false)
                    messages.append(aiMessage)
                } else {
                    // 重试一次
                    AIService.shared.performWebSearch(query: userInput, systemPrompt: systemPrompt) { retryResponse in
                        DispatchQueue.main.async {
                            if let retryResponse = retryResponse {
                                let aiMessage = Message(content: retryResponse, isUser: false)
                                messages.append(aiMessage)
                            } else {
                                let aiMessage = Message(content: "我没有收到回复。这可能是因为：\n1. API密钥可能已过期\n2. 网络连接不稳定\n请检查API密钥是否正确。", isUser: false)
                                messages.append(aiMessage)
                            }
                        }
                    }
                }
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
            TextField("搜索", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    ContentView()
}
