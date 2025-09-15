import SwiftUI
import PhotosUI
import Photos
import AVFoundation

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var itemManager: ItemManager
    @EnvironmentObject private var supabaseService: SupabaseService // Add SupabaseService
    @EnvironmentObject private var authService: AuthService // Add AuthService
    @StateObject private var locationManager = LocationManager.shared
    
    @State private var name = ""
    @State private var description = ""
    @State private var categoryLevel1 = "" // Changed from category
    @State private var categoryLevel2: String? = nil // New
    @State private var categoryLevel3: String? = nil // New
    @State private var selectedLocation: Location?
    @State private var estimatedPrice = 0.0
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingImageSourcePicker = false
    @State private var showingLocationPicker = false
    @State private var isAnalyzing = false
    @State private var inputMethod: InputMethod = .manual
    @State private var showingCategoryPicker = false
    @State private var newCategory = ""
    @State private var showingAddCategory = false
    @State private var isSaving = false // New: Track saving state
    @State private var showingSaveErrorAlert = false // New: Control save error alert
    @State private var saveErrorMessage = "" // New: Store save error message
    
    @State private var detectedItems: [SegmentedItem] = [] // New: Store detected items
    @State private var selectedDetectedItemIDs: Set<UUID> = [] // New: Store selected item IDs
    @State private var editingSegmentedItem: SegmentedItem? // New: Store item being edited
    
    enum InputMethod {
        case manual
        case aiRecognition
    }
    
    // 计算将要生成的编号
    private var previewItemNumber: String {
        // 获取当前最大编号并加1
        let currentMax = itemManager.items.map { item in
            if let number = Int(item.itemNumber) {
                return number
            }
            return 0
        }.max() ?? 0
        return String(format: "%06d", currentMax + 1)
    }
    
    // 计算保存按钮是否禁用
    private var isSaveButtonDisabled: Bool {
        if isSaving {
            return true
        }
        if inputMethod == .manual {
            return name.isEmpty
        } else { // .aiRecognition
            return selectedDetectedItemIDs.isEmpty
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("输入方式", selection: $inputMethod) {
                        Text("手动输入").tag(InputMethod.manual)
                        Text("AI识别").tag(InputMethod.aiRecognition)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // 物品图片部分
                imageSelectionSection()
                
                if inputMethod == .aiRecognition && !detectedItems.isEmpty {
                    aiRecognitionSection()
                }
                
                if isAnalyzing {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("正在分析物品...")
                            Spacer()
                        }
                    }
                } else if inputMethod == .manual || detectedItems.isEmpty {
                    manualInputSection()
                }
                
                Section {
                    Button(action: {
                        showingLocationPicker = true
                    }) {
                        HStack {
                            Text(selectedLocation?.fullPath ?? "选择位置")
                                .foregroundColor(selectedLocation == nil ? .blue : .primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("存放位置")
                }
            }
            .navigationTitle("添加物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        Task {
                            if inputMethod == .manual {
                                await saveManualItem()
                            } else if inputMethod == .aiRecognition {
                                await saveSelectedItems()
                            }
                        }
                    }
                    .disabled(isSaveButtonDisabled) // Use the new computed property here
                    .onAppear {
                        print("保存按钮 disabled 状态检查：")
                        print("  name.isEmpty: \(name.isEmpty)")
                        print("  inputMethod == .manual: \(inputMethod == .manual)")
                        print("  selectedDetectedItemIDs.isEmpty: \(selectedDetectedItemIDs.isEmpty)")
                        print("  isSaving: \(isSaving)")
                        let isDisabled = isSaveButtonDisabled
                        print("  最终 disabled 状态: \(isDisabled)")
                    }
                }
            }
            .actionSheet(isPresented: $showingImageSourcePicker) {
                ActionSheet(
                    title: Text("选择图片来源"),
                    buttons: [
                        .default(Text("拍照")) {
                            showingCamera = true
                        },
                        .default(Text("从相册选择")) {
                            showingImagePicker = true
                        },
                        .cancel()
                    ]
                )
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(image: $selectedImage)
                    .onDisappear {
                        print("相机sheet消失，selectedImage: \(selectedImage != nil)")
                        if let image = selectedImage, inputMethod == .aiRecognition {
                            analyzeItem()
                        }
                    }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
                    .onDisappear {
                        print("相册sheet消失，selectedImage: \(selectedImage != nil)")
                        if let image = selectedImage, inputMethod == .aiRecognition {
                            analyzeItem()
                        }
                    }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedLocation: $selectedLocation)
            }
            .sheet(isPresented: $showingCategoryPicker) {
                CategoryPickerView(selectedCategoryLevel1: $categoryLevel1, selectedCategoryLevel2: $categoryLevel2, selectedCategoryLevel3: $categoryLevel3, itemManager: itemManager)
                    .environmentObject(supabaseService)
            }
            .sheet(item: $editingSegmentedItem) { item in
                SegmentedItemEditView(
                    item: item,
                    itemManager: itemManager,
                    onSave: { updatedItem in
                        if let index = detectedItems.firstIndex(where: { $0.id == updatedItem.id }) {
                            detectedItems[index] = updatedItem
                        }
                        // 确保更新后的物品如果被选中，仍然保持选中状态
                        if selectedDetectedItemIDs.contains(updatedItem.id) {
                            selectedDetectedItemIDs.insert(updatedItem.id)
                        }
                    }
                )
                .environmentObject(supabaseService)
            }
            .alert("添加新类别", isPresented: $showingAddCategory) {
                TextField("类别名称", text: $newCategory)
                Button("取消", role: .cancel) { }
                Button("添加") {
                    if !newCategory.isEmpty {
                        itemManager.addCategory(level1: newCategory)
                        categoryLevel1 = newCategory
                        newCategory = ""
                    }
                }
            } message: {
                Text("请输入新的类别名称")
            }
            .alert("保存失败", isPresented: $showingSaveErrorAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
        }
    }
    
    // MARK: - Helper Views
    @ViewBuilder
    private func imageSelectionSection() -> some View {
        Section {
            VStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(10)
                    
                    HStack {
                        Button("更换图片") {
                            showingImagePicker = true
                        }
                        .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Button("删除图片") {
                            selectedImage = nil
                        }
                        .foregroundColor(.red)
                    }
                    .padding(.top, 8)
                } else {
                    HStack(spacing: 16) {
                        Button(action: {
                            print("点击了相册按钮")
                            let status = PHPhotoLibrary.authorizationStatus()
                            print("相册权限状态: \(status.rawValue)")
                            showingImageSourcePicker = true
                        }) {
                            VStack {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text("相册")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            print("点击了拍照按钮")
                            let status = AVCaptureDevice.authorizationStatus(for: .video)
                            print("相机权限状态: \(status.rawValue)")
                            showingImageSourcePicker = true
                        }) {
                            VStack {
                                Image(systemName: "camera")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                Text("拍照")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                }
            }
        } header: {
            Text("物品图片")
        }
    }

    @ViewBuilder
    private func aiRecognitionSection() -> some View {
        Section {
            HStack {
                Text("检测到物品数量：")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(detectedItems.count) 个")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            ForEach(detectedItems) { item in
                HStack {
                    if let imageData = item.croppedImageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .cornerRadius(5)
                    } else {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.caption2)
                            )
                    }
                    
                    VStack(alignment: .leading) {
                        Text(item.name)
                            .font(.headline)
                        Text(item.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Text("编号: \(item.itemNumber)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Spacer()
                            if item.estimatedPrice > 0 {
                                Text("¥\(String(format: "%.0f", item.estimatedPrice))")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Toggle(isOn: Binding(
                        get: { selectedDetectedItemIDs.contains(item.id) },
                        set: { isSelected in
                            if isSelected {
                                selectedDetectedItemIDs.insert(item.id)
                            } else {
                                selectedDetectedItemIDs.remove(item.id)
                            }
                        }
                    )) {
                        Text("选择")
                    }
                    .labelsHidden()
                }
                .padding(.vertical, 4)
                .onTapGesture {
                    editingSegmentedItem = item
                }
            }
        } header: {
            Text("检测到的物品")
        }
    }

    @ViewBuilder
    private func manualInputSection() -> some View {
        Section {
            TextField("名称", text: $name)
                .disabled(isAnalyzing)
        }
        
        Section {
            TextEditor(text: $description)
                .frame(minHeight: 100)
                .disabled(isAnalyzing)
        } header: {
            Text("物品描述")
        }
        
        Section {
            HStack {
                Text(categoryLevel1.isEmpty ? "选择类别" : categoryLevel1)
                    .foregroundColor(categoryLevel1.isEmpty ? .blue : .primary)
                Spacer()
                Button("选择") {
                    showingCategoryPicker = true
                }
                .foregroundColor(.blue)
            }
        } header: {
            Text("物品类别")
        } footer: {
            if !categoryLevel1.isEmpty {
                Text("将生成编号：\(previewItemNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        
        Section {
            HStack {
                Text("¥")
                TextField("估算价格", value: $estimatedPrice, format: .number)
                    .keyboardType(.decimalPad)
                    .disabled(isAnalyzing)
            }
        } header: {
            Text("估算价格")
        }
    }
    
    private func analyzeItem() {
        guard let image = selectedImage else {
            return
        }
        
        isAnalyzing = true
        detectedItems = [] // Clear previous detections
        selectedDetectedItemIDs = []

        AIService.shared.segmentAndAnalyzeImage(image) { items in
            // 为每个分割的物品生成正确的编号
            var updatedItems: [SegmentedItem] = []
            for item in items {
                let newItemNumber = self.itemManager.generateItemNumber()
                let updatedItem = SegmentedItem(
                    id: item.id,
                    croppedImageData: item.croppedImageData,
                    name: item.name,
                    description: item.description,
                    categoryLevel1: item.categoryLevel1, // Use categoryLevel1
                    categoryLevel2: item.categoryLevel2, // Use categoryLevel2
                    categoryLevel3: item.categoryLevel3, // Use categoryLevel3
                    estimatedPrice: item.estimatedPrice,
                    confidence: item.confidence,
                    itemNumber: newItemNumber
                )
                updatedItems.append(updatedItem)
            }
            self.detectedItems = updatedItems
            self.isAnalyzing = false
            // Automatically select all detected items for batch adding
            for item in updatedItems {
                self.selectedDetectedItemIDs.insert(item.id)
            }
            print("检测到 \(updatedItems.count) 个物品")
        }
    }
    
    private func saveSelectedItems() async {
        print("saveSelectedItems 被调用")
        isSaving = true
        let locationPath = selectedLocation?.fullPath ?? ""
        var hasError = false
        
        // 立即保存所有物品到本地并关闭界面，上传操作在后台进行
        for itemID in selectedDetectedItemIDs {
            guard let detectedItem = detectedItems.first(where: { $0.id == itemID }) else { continue }
            
            // 将图片数据转换为Base64字符串，用于本地存储
            var itemImageURL: String? = nil
            if let imageData = detectedItem.croppedImageData {
                itemImageURL = imageData.base64EncodedString()
            }
            
            let item = Item(
                itemNumber: detectedItem.itemNumber,
                name: detectedItem.name,
                location: locationPath,
                description: detectedItem.description,
                categoryLevel1: detectedItem.categoryLevel1,
                categoryLevel2: detectedItem.categoryLevel2,
                categoryLevel3: detectedItem.categoryLevel3,
                estimatedPrice: detectedItem.estimatedPrice,
                imageURL: itemImageURL,
                userID: authService.currentUser?.id,
                userName: nil,
                phoneNumber: nil
            )
            
            do {
                // 因为addItem方法已经优化为立即返回，所以这里可以继续执行
                try await itemManager.addItem(item)
                print("物品已保存到本地: \(detectedItem.name)")
            } catch {
                print("保存物品到本地失败: \(error.localizedDescription)")
                saveErrorMessage = "保存物品 \(detectedItem.name) 失败：\(error.localizedDescription)"
                hasError = true
            }
        }
        
        // 立即关闭界面，不等待上传完成
        dismiss()
        
        // 在后台处理错误提示（如果有）
        Task { @MainActor in
            isSaving = false
            
            if hasError && !showingSaveErrorAlert {
                showingSaveErrorAlert = true
            }
        }
    }
    
    private func saveManualItem() async {
        print("saveManualItem 被调用")
        isSaving = true
        let locationPath = selectedLocation?.fullPath ?? ""
        var itemImageURL: String? = nil

        // 将图片数据转换为Base64字符串，用于本地存储
        if let selectedImage = selectedImage, let imageData = selectedImage.jpegData(compressionQuality: 0.8) {
            itemImageURL = imageData.base64EncodedString()
        }
        
        let item = Item(
            itemNumber: previewItemNumber,
            name: name,
            location: locationPath,
            description: description,
            categoryLevel1: categoryLevel1,
            categoryLevel2: categoryLevel2,
            categoryLevel3: categoryLevel3,
            estimatedPrice: estimatedPrice,
            imageURL: itemImageURL,
            userID: authService.currentUser?.id,
            userName: nil,
            phoneNumber: nil
        )
        
        do {
            // 因为addItem方法已经优化为立即返回，所以这里可以在调用后立即关闭界面
            try await itemManager.addItem(item)
            print("手动添加的物品已保存到本地: \(name)")
        } catch {
            print("保存手动添加的物品失败: \(error.localizedDescription)")
            saveErrorMessage = "保存物品失败：\(error.localizedDescription)"
            
            // 在后台处理错误提示
            Task { @MainActor in
                showingSaveErrorAlert = true
                isSaving = false
            }
        }
        
        // 立即关闭界面，不等待上传完成
        dismiss()
        
        // 确保isSaving状态被重置
        Task { @MainActor in
            if !showingSaveErrorAlert {
                isSaving = false
            }
        }
    }
}

// MARK: - CategoryPickerView

struct CategoryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategoryLevel1: String
    @Binding var selectedCategoryLevel2: String?
    @Binding var selectedCategoryLevel3: String?
    @ObservedObject var itemManager: ItemManager
    @EnvironmentObject private var supabaseService: SupabaseService // Add SupabaseService
    @State private var showingAddCategory = false
    @State private var newCategory = ""
    
    @State private var currentCategoryLevel = 1 // 1: level1, 2: level2, 3: level3
    @State private var currentParentCategory: String? = nil
    
    var body: some View {
        NavigationView {
            List {
                if currentCategoryLevel == 1 {
                    Section {
                        ForEach(itemManager.getAllAvailableCategories(), id: \.self) { category in
                            Button(action: {
                                selectedCategoryLevel1 = category
                                selectedCategoryLevel2 = nil
                                selectedCategoryLevel3 = nil
                                dismiss()
                            }) {
                                HStack {
                                    Text(category)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedCategoryLevel1 == category {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("选择一级类别")
                    }
                    
                    Section {
                        Button(action: {
                            showingAddCategory = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                                Text("添加新一级类别")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                } else if currentCategoryLevel == 2 {
                    // 二级类别选择 (目前 ItemManager 尚未支持，这里先留空或显示占位)
                    Text("目前不支持二级分类，请选择一级分类。")
                } else if currentCategoryLevel == 3 {
                    // 三级类别选择 (目前 ItemManager 尚未支持，这里先留空或显示占位)
                    Text("目前不支持三级分类，请选择一级分类。")
                }
            }
            .navigationTitle(navigationTitleForCurrentLevel())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentCategoryLevel > 1 {
                        Button("返回") {
                            currentCategoryLevel -= 1
                            // 根据返回的层级重置父类别
                            if currentCategoryLevel == 1 { currentParentCategory = nil }
                            // 暂时不处理更复杂的父类别重置逻辑
                        }
                    } else {
                        Button("取消") {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("添加新类别", isPresented: $showingAddCategory) {
                TextField("类别名称", text: $newCategory)
                Button("取消", role: .cancel) { }
                Button("添加") {
                    if !newCategory.isEmpty {
                        // 根据当前层级添加类别
                        if currentCategoryLevel == 1 {
                            itemManager.addCategory(level1: newCategory)
                            selectedCategoryLevel1 = newCategory
                            selectedCategoryLevel2 = nil
                            selectedCategoryLevel3 = nil
                        } else if currentCategoryLevel == 2 {
                            // TODO: Implement adding level 2 category
                        } else if currentCategoryLevel == 3 {
                            // TODO: Implement adding level 3 category
                        }
                        newCategory = ""
        dismiss()
                    }
                }
            } message: {
                Text("请输入新的类别名称")
            }
        }
    }
    
    private func navigationTitleForCurrentLevel() -> String {
        switch currentCategoryLevel {
        case 1: return "选择一级类别"
        case 2: return "选择二级类别"
        case 3: return "选择三级类别"
        default: return "选择类别"
        }
    }
}
