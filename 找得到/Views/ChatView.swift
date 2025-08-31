import SwiftUI

struct ChatView: View {
    @Binding var messages: [Message]
    @Binding var newMessage: String
    @Binding var isLoading: Bool
    @Binding var isRecording: Bool
    @Environment(\.dismiss) private var dismiss
    let onSend: () -> Void
    let onRecord: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        NavigationView {
            ZStack {
                // 渐变背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.1),
                        Color.purple.opacity(0.05),
                        Color.white
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 欢迎消息（如果没有消息）
                    if messages.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "message.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.blue)
                            
                            Text("智能管家")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("我是您的智能物品管理助手\n可以帮您查找、分类和管理物品")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                FeatureCard(
                                    icon: "magnifyingglass",
                                    title: "查找物品",
                                    description: "快速定位您的物品位置"
                                )
                                
                                FeatureCard(
                                    icon: "folder",
                                    title: "分类管理",
                                    description: "智能分类和整理物品"
                                )
                                
                                FeatureCard(
                                    icon: "chart.bar",
                                    title: "统计分析",
                                    description: "查看物品使用情况和价值"
                                )
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 60)
                        Spacer()
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(messages) { message in
                                        MessageBubble(message: message)
                                            .id(message.id)
                                    }
                                    
                                    if isLoading {
                                        HStack {
                                            Spacer()
                                            VStack(spacing: 8) {
                                                ProgressView()
                                                    .scaleEffect(1.2)
                                                Text("正在思考...")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.vertical, 16)
                                            .padding(.horizontal, 20)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(20)
                                            Spacer()
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }
                            .onChange(of: messages) { _ in
                                if let lastMessage = messages.last {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                            .onAppear {
                                scrollProxy = proxy
                            }
                        }
                    }
                    
                    // 输入区域
                    VStack(spacing: 0) {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                        
                        HStack(spacing: 12) {
                            // 语音按钮
                            Button(action: onRecord) {
                                Image(systemName: isRecording ? "mic.fill" : "mic")
                                    .font(.title2)
                                    .foregroundColor(isRecording ? .red : .blue)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(isRecording ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                                    )
                            }
                            .disabled(isFocused)
                            .scaleEffect(isRecording ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: isRecording)
                            
                            // 输入框
                            HStack {
                                TextField("输入您的问题...", text: $newMessage)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .disabled(isLoading || isRecording)
                                    .focused($isFocused)
                                    .submitLabel(.send)
                                    .onSubmit {
                                        if !newMessage.isEmpty && !isLoading {
                                            onSend()
                                        }
                                    }
                                
                                if !newMessage.isEmpty {
                                    Button(action: {
                                        newMessage = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 25)
                                            .stroke(isFocused ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
                                    )
                            )
                            
                            // 发送按钮
                            Button(action: onSend) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(newMessage.isEmpty || isLoading ? .gray : .blue)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(newMessage.isEmpty || isLoading ? Color.gray.opacity(0.1) : Color.blue.opacity(0.1))
                                    )
                            }
                            .disabled(newMessage.isEmpty || isLoading)
                            .scaleEffect(newMessage.isEmpty || isLoading ? 1.0 : 1.0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                    }
                }
            }
            .navigationTitle("智能管家")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            })
        }
    }
}

// MARK: - FeatureCard

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

struct ChatView_Preview: PreviewProvider {
    static var previews: some View {
        ChatView(
            messages: .constant([Message(content: "Hello", isUser: true)]),
            newMessage: .constant(""),
            isLoading: .constant(false),
            isRecording: .constant(false),
            onSend: {},
            onRecord: {}
        )
    }
}
