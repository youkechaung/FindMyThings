import SwiftUI
import UIKit

/// 键盘处理类，用于管理键盘的显示和隐藏状态
@MainActor
class KeyboardHandler: ObservableObject {
    /// 当前键盘高度
    @Published var keyboardHeight: CGFloat = 0
    
    /// 键盘动画持续时间
    @Published var keyboardAnimationDuration: Double = 0
    
    /// 键盘动画曲线
    @Published var keyboardAnimationCurve: UIView.AnimationCurve = .easeInOut
    
    /// 是否已设置通知观察者
    private var isObserving = false
    
    init() {
        setupObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 设置键盘通知观察者
    private func setupObservers() {
        guard !isObserving else { return }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        
        isObserving = true
    }
    
    /// 移除键盘通知观察者
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        isObserving = false
    }
    
    /// 处理键盘显示通知
    @objc private func keyboardWillShow(_ notification: Notification) {
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            keyboardHeight = keyboardFrame.height
        }
        
        if let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
            keyboardAnimationDuration = duration
        }
        
        if let curveValue = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int, 
           let curve = UIView.AnimationCurve(rawValue: curveValue) {
            keyboardAnimationCurve = curve
        }
    }
    
    /// 处理键盘隐藏通知
    @objc private func keyboardWillHide(_ notification: Notification) {
        if let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
            keyboardAnimationDuration = duration
        }
        
        if let curveValue = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int, 
           let curve = UIView.AnimationCurve(rawValue: curveValue) {
            keyboardAnimationCurve = curve
        }
        
        keyboardHeight = 0
    }
}