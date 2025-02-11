import SwiftUI
import PhotosUI

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var itemManager: ItemManager
    @StateObject private var locationManager = LocationManager.shared
    
    @State private var name = ""
    @State private var description = ""
    @State private var category = ""
    @State private var selectedLocation: Location?
    @State private var estimatedPrice = 0.0
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var showingLocationPicker = false
    @State private var isAnalyzing = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称", text: $name)
                }
                
                Section {
                    // 图片选择区域
                    VStack {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(10)
                        } else {
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                VStack {
                                    Image(systemName: "camera")
                                        .font(.largeTitle)
                                        .foregroundColor(.blue)
                                    Text("拍照或选择照片")
                                        .foregroundColor(.blue)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                    }
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
                        TextEditor(text: $description)
                            .frame(minHeight: 100)
                    } header: {
                        Text("物品描述")
                    }
                    
                    Section {
                        TextField("物品类别", text: $category)
                    } header: {
                        Text("物品类别")
                    }
                    
                    Section {
                        HStack {
                            Text("¥")
                            TextField("估算价格", value: $estimatedPrice, format: .number)
                                .keyboardType(.decimalPad)
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
                    .disabled(name.isEmpty || selectedLocation == nil || selectedImage == nil)
                }
            }
            .actionSheet(isPresented: $showingImagePicker) {
                ActionSheet(
                    title: Text("选择图片来源"),
                    buttons: [
                        .default(Text("拍照")) {
                            showingCamera = true
                        },
                        .default(Text("从相册选择")) {
                            showingPhotoLibrary = true
                        },
                        .cancel()
                    ]
                )
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(image: $selectedImage)
                    .onDisappear {
                        if let image = selectedImage {
                            analyzeItem()
                        }
                    }
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                ImagePicker(image: $selectedImage)
                    .onDisappear {
                        if let image = selectedImage {
                            analyzeItem()
                        }
                    }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedLocation: $selectedLocation)
            }
        }
    }
    
    private func analyzeItem() {
        guard let image = selectedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        
        isAnalyzing = true
        AIService.shared.analyzeItem(name: name, imageData: imageData) { desc, cat, price in
            description = desc
            category = cat
            estimatedPrice = price
            isAnalyzing = false
        }
    }
    
    private func saveItem() {
        guard let imageData = selectedImage?.jpegData(compressionQuality: 0.8),
              let location = selectedLocation?.fullPath else { return }
        
        let item = Item(
            name: name,
            description: description,
            location: location,
            category: category,
            estimatedPrice: estimatedPrice,
            imageData: imageData
        )
        
        itemManager.addItem(item)
        dismiss()
    }
}
