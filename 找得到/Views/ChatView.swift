import SwiftUI

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
}

struct ChatView: View {
    @State private var messages: [Message] = []
    @State private var newMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 12) {
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
            
            Divider()
            
            HStack(spacing: 8) {
                TextField("输入消息...", text: $newMessage)
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
            .padding()
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
        """
        
        AIService.shared.performWebSearch(query: userInput, systemPrompt: systemPrompt) { response in
            DispatchQueue.main.async {
                isLoading = false
                if let response = response {
                    let aiMessage = Message(content: response, isUser: false)
                    messages.append(aiMessage)
                } else {
                    let errorMessage = Message(content: "抱歉，我现在无法回答。请稍后再试。", isUser: false)
                    messages.append(errorMessage)
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            Text(message.content)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(message.isUser ? .white : .primary)
                .cornerRadius(20)
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = message.content
                    }) {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                }
            
            if !message.isUser { Spacer() }
        }
    }
}

#Preview {
    ChatView()
}
