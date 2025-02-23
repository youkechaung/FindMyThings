import SwiftUI

struct EmptyMessageView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("你可以：")
                .font(.headline)
            Text("1. 问我物品在哪里\n2. 询问物品的使用状态\n3. 获取物品存放建议")
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .foregroundColor(.gray)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top)
    }
}
