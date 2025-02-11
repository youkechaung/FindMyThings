import SwiftUI
import PhotosUI

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var itemManager: ItemManager
    @StateObject private var locationManager = LocationManager.shared
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedLocation: Location?
    @State private var category = ""
    @State private var estimatedPrice = 0.0
    @State private var isLoadingCategory = false
    @State private var isLoadingPrice = false
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var showingLocationPicker = false
    @State private var imageSource: ImageSource = .photoLibrary
    
    private enum ImageSource {
        case photoLibrary, camera
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称", text: $name)
                        .onChange(of: name) { oldValue, newValue in
                            if !newValue.isEmpty && !description.isEmpty {
                                suggestCategory()
                            }
                        }
                    TextField("描述", text: $description)
                        .onChange(of: description) { oldValue, newValue in
                            if !newValue.isEmpty && !name.isEmpty {
                                suggestCategory()
                            }
                        }
                    Button {
                        showingLocationPicker = true
                    } label: {
                        HStack {
                            Text(selectedLocation?.fullPath ?? "选择位置")
                                .foregroundColor(selectedLocation == nil ? .gray : .primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    if isLoadingCategory {
                        HStack {
                            Text("正在分析物品类别...")
                            Spacer()
                            ProgressView()
                        }
                    } else if !category.isEmpty {
                        HStack {
                            Text("类别")
                            Spacer()
                            Text(category)
                                .foregroundColor(.gray)
                        }
                        Button("重新分析类别") {
                            suggestCategory()
                        }
                    }
                    
                    if isLoadingPrice {
                        HStack {
                            Text("正在估算价格...")
                            Spacer()
                            ProgressView()
                        }
                    } else if estimatedPrice > 0 {
                        HStack {
                            Text("预估价格")
                            Spacer()
                            Text("¥\(String(format: "%.2f", estimatedPrice))")
                                .foregroundColor(.gray)
                        }
                        Button("重新估算价格") {
                            estimatePrice()
                        }
                    }
                }
                
                Section("图片") {
                    HStack {
                        Spacer()
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                        } else {
                            VStack {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("添加图片")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(height: 200)
                        }
                        Spacer()
                    }
                    .onTapGesture {
                        showingImagePicker = true
                    }
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
                        let imageData = selectedImage?.jpegData(compressionQuality: 0.8)
                        let item = Item(
                            name: name,
                            description: description,
                            location: selectedLocation?.fullPath ?? "",
                            category: category,
                            estimatedPrice: estimatedPrice,
                            imageData: imageData
                        )
                        itemManager.addItem(item)
                        dismiss()
                    }
                    .disabled(name.isEmpty || selectedLocation == nil)
                }
            }
            .actionSheet(isPresented: $showingImagePicker) {
                ActionSheet(
                    title: Text("选择图片来源"),
                    buttons: [
                        .default(Text("拍照")) {
                            imageSource = .camera
                            showingCamera = true
                            showingImagePicker = false
                        },
                        .default(Text("从相册选择")) {
                            imageSource = .photoLibrary
                            showingPhotoLibrary = true
                            showingImagePicker = false
                        },
                        .cancel()
                    ]
                )
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(image: $selectedImage)
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                ImagePicker(image: $selectedImage)
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedLocation: $selectedLocation)
            }
        }
    }
    
    private func suggestCategory() {
        guard !isLoadingCategory else { return }
        guard !name.isEmpty && !description.isEmpty else { return }
        
        isLoadingCategory = true
        category = ""  // 清空旧的类别
        estimatedPrice = 0  // 清空旧的价格
        
        let tempItem = Item(name: name, description: description)
        print("开始分析物品类别: \(name)")
        
        AIService.shared.suggestCategory(for: tempItem) { suggestedCategory in
            DispatchQueue.main.async {
                print("收到类别建议: \(suggestedCategory ?? "nil")")
                isLoadingCategory = false
                
                if let category = suggestedCategory {
                    self.category = category
                    // 获取到类别后估算价格
                    self.estimatePrice()
                }
            }
        }
    }
    
    private func estimatePrice() {
        guard !isLoadingPrice else { return }
        guard !category.isEmpty else { return }
        
        isLoadingPrice = true
        estimatedPrice = 0  // 清空旧的价格
        
        let tempItem = Item(
            name: name,
            description: description,
            category: category
        )
        
        print("开始估算物品价格: \(name)")
        AIService.shared.estimatePrice(for: tempItem) { estimatedValue in
            DispatchQueue.main.async {
                print("收到价格估算: \(estimatedValue ?? 0.0)")
                isLoadingPrice = false
                
                if let price = estimatedValue {
                    self.estimatedPrice = price
                }
            }
        }
    }
}

// Removed CameraView and ImagePicker as they are now in Components folder
