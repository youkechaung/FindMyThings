import SwiftUI

struct ChatView: View {
    @Binding var messages: [Message]
    @Binding var newMessage: String
    @Binding var isLoading: Bool
    @Binding var isRecording: Bool
    let onSend: () -> Void
    let onRecord: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty {
                            EmptyMessageView()
                        }
                        
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
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
                .onChange(of: messages) { _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    scrollProxy = proxy
                }
            }
            
            Divider()
            
            HStack(spacing: 8) {
                TextField("问问AI助手...", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isLoading || isRecording)
                    .focused($isFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        if !newMessage.isEmpty && !isLoading {
                            onSend()
                        }
                    }
                
                Button(action: onRecord) {
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .font(.title2)
                        .foregroundColor(isRecording ? .red : .blue)
                }
                .disabled(isFocused)
                
                Button(action: onSend) {
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
}

#Preview {
    ChatView(
        messages: .constant([Message(content: "Hello", isUser: true)]),
        newMessage: .constant(""),
        isLoading: .constant(false),
        isRecording: .constant(false),
        onSend: {},
        onRecord: {}
    )
}
