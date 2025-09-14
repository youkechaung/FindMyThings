import UIKit

/// 全局输入助手禁用器
/// 用于解决 SystemInputAssistantView 约束冲突问题
@MainActor
class InputAssistantDisabler {
    static let shared = InputAssistantDisabler()
    
    private init() {
        setupGlobalInputAssistantDisabling()
    }
    
    /// 设置全局输入助手禁用
    private func setupGlobalInputAssistantDisabling() {
        // 禁用所有 UITextField 的输入助手
        UITextField.appearance().inputAssistantItem.leadingBarButtonGroups = []
        UITextField.appearance().inputAssistantItem.trailingBarButtonGroups = []
        
        // 禁用所有 UITextView 的输入助手
        UITextView.appearance().inputAssistantItem.leadingBarButtonGroups = []
        UITextView.appearance().inputAssistantItem.trailingBarButtonGroups = []
        
        // 禁用搜索栏的输入助手
        UISearchBar.appearance().inputAssistantItem.leadingBarButtonGroups = []
        UISearchBar.appearance().inputAssistantItem.trailingBarButtonGroups = []
        
        // 设置全局的输入助手高度为0
        DispatchQueue.main.async {
            self.setGlobalInputAssistantHeight()
        }
    }
    
    /// 设置全局输入助手高度
    private func setGlobalInputAssistantHeight() {
        // 通过 KVC 设置输入助手高度
        if let inputAssistantItemClass = NSClassFromString("UITextInputAssistantItem") {
            let heightKey = "assistantHeight"
            if inputAssistantItemClass.instancesRespond(to: NSSelectorFromString(heightKey)) {
                // 尝试设置高度为0
                UserDefaults.standard.set(0, forKey: "UIInputAssistantHeight")
            }
        }
    }
    
    /// 为特定的文本输入控件禁用输入助手
    func disableInputAssistant(for textInput: UITextInput) {
        if let textField = textInput as? UITextField {
            textField.inputAssistantItem.leadingBarButtonGroups = []
            textField.inputAssistantItem.trailingBarButtonGroups = []
        } else if let textView = textInput as? UITextView {
            textView.inputAssistantItem.leadingBarButtonGroups = []
            textView.inputAssistantItem.trailingBarButtonGroups = []
        }
    }
}
