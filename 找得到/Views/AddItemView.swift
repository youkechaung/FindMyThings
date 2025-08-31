import SwiftUI
import PhotosUI
import Photos
import AVFoundation

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var itemManager: ItemManager
    @StateObject private var locationManager = LocationManager.shared
    
    @State private var name = ""
    @State private var description = ""
    @State private var category = ""
    @State private var selectedLocation: Location?
    @State private var estimatedPrice = 0.0
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingImageSourcePicker = false
    @State private var showingLocationPicker = false
    @State private var isAnalyzing = false
    @State private var inputMethod: InputMethod = .aiRecognition
    @State private var showingCategoryPicker = false
    @State private var newCategory = ""
    @State private var showingAddCategory = false
    
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
                
                // 图片上传部分
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
                                    // 检查相册权限
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
                                    // 检查相机权限
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
                
                if isAnalyzing {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("正在分析物品...")
                            Spacer()
                        }
                    }
                } else {
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
                            Text(category.isEmpty ? "选择类别" : category)
                                .foregroundColor(category.isEmpty ? .blue : .primary)
                            Spacer()
                            Button("选择") {
                                showingCategoryPicker = true
                            }
                            .foregroundColor(.blue)
                        }
                    } header: {
                        Text("物品类别")
                    } footer: {
                        if !category.isEmpty {
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
                        saveItem()
                    }
                    .disabled(name.isEmpty || (inputMethod == .aiRecognition && selectedImage == nil))
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
                CategoryPickerView(selectedCategory: $category, itemManager: itemManager)
            }
            .alert("添加新类别", isPresented: $showingAddCategory) {
                TextField("类别名称", text: $newCategory)
                Button("取消", role: .cancel) { }
                Button("添加") {
                    if !newCategory.isEmpty {
                        itemManager.addCategory(newCategory)
                        category = newCategory
                        newCategory = ""
                    }
                }
            } message: {
                Text("请输入新的类别名称")
            }
        }
    }
    
    private func analyzeItem() {
        guard let image = selectedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        
        isAnalyzing = true
        AIService.shared.analyzeItem(imageData: imageData) { itemName, desc, cat, price in
            name = itemName
            description = desc
            category = cat
            estimatedPrice = price
            isAnalyzing = false
        }
    }
    
    private func saveItem() {
        let locationPath = selectedLocation?.fullPath ?? ""
        
        let imageData = selectedImage?.jpegData(compressionQuality: 0.8)
        
        let item = Item(
            name: name,
            location: locationPath,
            description: description,
            category: category,
            estimatedPrice: estimatedPrice,
            imageData: imageData
        )
        
        itemManager.addItem(item)
        dismiss()
    }
}

// MARK: - CategoryPickerView

struct CategoryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategory: String
    @ObservedObject var itemManager: ItemManager
    @State private var showingAddCategory = false
    @State private var newCategory = ""
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(itemManager.getAllAvailableCategories(), id: \.self) { category in
                        Button(action: {
                            selectedCategory = category
                            dismiss()
                        }) {
                            HStack {
                                Text(category)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedCategory == category {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("选择类别")
                }
                
                Section {
                    Button(action: {
                        showingAddCategory = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                            Text("添加新类别")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("选择类别")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                        itemManager.addCategory(newCategory)
                        selectedCategory = newCategory
                        newCategory = ""
                        dismiss()
                    }
                }
            } message: {
                Text("请输入新的类别名称")
            }
        }
    }
}
