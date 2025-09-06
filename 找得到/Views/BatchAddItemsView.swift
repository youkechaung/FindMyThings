import SwiftUI
import PhotosUI

struct BatchAddItemsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var itemManager: ItemManager
    @EnvironmentObject private var supabaseService: SupabaseService
    @EnvironmentObject private var authService: AuthService
    @StateObject private var locationManager = LocationManager.shared
    
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var isAnalyzing = false
    @State private var segmentedItems: [SegmentedItem] = []
    @State private var selectedItems: Set<UUID> = []
    @State private var selectedLocation: Location?
    @State private var showingLocationPicker = false
    @State private var showingSuccessAlert = false
    @State private var addedItemsCount = 0
    @State private var showingEditSheet = false
    @State private var editingItem: SegmentedItem?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if selectedImage == nil {
                    // 选择图片界面
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("批量添加物品")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("拍照或选择一张包含多个物品的图片\n系统将自动识别并分割每个物品")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo")
                                    Text("从相册选择")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                showingCamera = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "camera")
                                    Text("拍照上传")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isAnalyzing {
                    // 分析中界面
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("正在分析图片...")
                            .font(.headline)
                        
                        Text("系统正在识别和分割图片中的物品，请稍候")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 结果展示界面
                    ScrollView {
                        VStack(spacing: 16) {
                            // 原图预览
                            if let image = selectedImage {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("原图")
                                        .font(.headline)
                                        .padding(.horizontal)
                                    
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 200)
                                        .cornerRadius(12)
                                        .padding(.horizontal)
                                }
                            }
                            
                            // 分割结果
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("识别结果")
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    Button("全选") {
                                        selectedItems = Set(segmentedItems.map { $0.id })
                                    }
                                    .foregroundColor(.blue)
                                    
                                    Button("取消全选") {
                                        selectedItems.removeAll()
                                    }
                                    .foregroundColor(.blue)
                                }
                                .padding(.horizontal)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 12) {
                                                                    ForEach(segmentedItems) { item in
                                    SegmentedItemCard(
                                        item: item,
                                        isSelected: selectedItems.contains(item.id),
                                        onToggle: { isSelected in
                                            if isSelected {
                                                selectedItems.insert(item.id)
                                            } else {
                                                selectedItems.remove(item.id)
                                            }
                                        },
                                        onEdit: { item in
                                            editingItem = item
                                            showingEditSheet = true
                                        }
                                    )
                                }
                                }
                                .padding(.horizontal)
                            }
                            
                            // 位置选择
                            VStack(alignment: .leading, spacing: 8) {
                                Text("存放位置")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
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
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                                .padding(.horizontal)
                            }
                            
                            // 添加按钮
                            Button(action: {
                                Task {
                                    await addSelectedItems()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("添加选中物品 (\(selectedItems.count)个)")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedItems.isEmpty || selectedLocation == nil ? Color.gray : Color.blue)
                                .cornerRadius(12)
                            }
                            .disabled(selectedItems.isEmpty || selectedLocation == nil)
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                    }
                }
            }
            .navigationTitle("批量添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedImage != nil && !isAnalyzing {
                        Menu {
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                Label("从相册选择", systemImage: "photo")
                            }
                            Button(action: {
                                showingCamera = true
                            }) {
                                Label("拍照", systemImage: "camera")
                            }
                            Button(action: {
                                selectedImage = nil
                                segmentedItems = []
                                selectedItems.removeAll()
                            }) {
                                Label("清除", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
                    .onDisappear {
                        if let image = selectedImage {
                            analyzeImage(image)
                        }
                    }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(image: $selectedImage)
                    .onDisappear {
                        if let image = selectedImage {
                            analyzeImage(image)
                        }
                    }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedLocation: $selectedLocation)
            }
            .alert("添加成功", isPresented: $showingSuccessAlert) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("成功添加了 \(addedItemsCount) 个物品到系统中")
            }
            .sheet(isPresented: $showingEditSheet) {
                if let item = editingItem {
                    SegmentedItemEditView(
                        item: item,
                        itemManager: itemManager,
                        onSave: { updatedItem in
                            if let index = segmentedItems.firstIndex(where: { $0.id == updatedItem.id }) {
                                segmentedItems[index] = updatedItem
                            }
                        }
                    )
                }
            }
        }
    }
    
    private func analyzeImage(_ image: UIImage) {
        isAnalyzing = true
        
        AIService.shared.segmentAndAnalyzeImage(image) { items in
            DispatchQueue.main.async {
                // 为每个分割的物品生成正确的编号
                var updatedItems: [SegmentedItem] = []
                for (index, item) in items.enumerated() {
                    let newItemNumber = self.itemManager.generateItemNumber()
                    let updatedItem = SegmentedItem(
                        id: item.id,
                        croppedImageData: item.croppedImageData, // 使用 croppedImageData
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
                
                self.segmentedItems = updatedItems
                self.isAnalyzing = false
                
                // 默认选中所有物品
                self.selectedItems = Set(updatedItems.map { $0.id })
            }
        }
    }
    
    private func addSelectedItems() async {
        guard let location = selectedLocation?.fullPath else { return }

        var addedCount = 0

        for item in segmentedItems {
            if selectedItems.contains(item.id) {
                do {
                    // Upload image to Supabase Storage
                    guard let imageData = item.croppedImageData else {
                        print("Error: No image data for item \(item.name)")
                        continue
                    }
                    let fileName = UUID().uuidString + ".jpeg"
                    let imageURL = try await supabaseService.uploadImage(imageData: imageData, fileName: fileName)

                    let newItem = Item(
                        itemNumber: item.itemNumber,
                        name: item.name,
                        location: location,
                        description: item.description,
                        categoryLevel1: item.categoryLevel1, // Use categoryLevel1
                        categoryLevel2: item.categoryLevel2, // Use categoryLevel2
                        categoryLevel3: item.categoryLevel3, // Use categoryLevel3
                        estimatedPrice: item.estimatedPrice,
                        imageURL: imageURL,
                        userID: authService.user?.id
                    )

                    try await itemManager.addItem(newItem)
                    addedCount += 1
                } catch {
                    print("Error uploading image or adding item: \(error)")
                }
            }
        }

        addedItemsCount = addedCount
        showingSuccessAlert = true
    }
}

// MARK: - SegmentedItemCard

struct SegmentedItemCard: View {
    let item: SegmentedItem
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    let onEdit: (SegmentedItem) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // 选择按钮
            HStack {
                Spacer()
                Button(action: {
                    onToggle(!isSelected)
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .blue : .gray)
                }
            }
            
            // 物品图片
            if let imageData = item.croppedImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 100)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.title)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                    )
            }
            
            // 物品信息
            VStack(spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text(item.itemNumber)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
                
                // Display Category Level 1
                if !item.categoryLevel1.isEmpty {
                    Text(item.categoryLevel1)
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                // Optionally display Category Level 2
                if let level2 = item.categoryLevel2, !level2.isEmpty {
                    Text("二级分类: \(level2)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Optionally display Category Level 3
                if let level3 = item.categoryLevel3, !level3.isEmpty {
                    Text("三级分类: \(level3)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if item.estimatedPrice > 0 {
                    Text("¥\(String(format: "%.0f", item.estimatedPrice))")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            // 编辑按钮
            Button(action: {
                onEdit(item)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                    Text("编辑")
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - SegmentedItemEditView

struct SegmentedItemEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var itemManager: ItemManager
    @EnvironmentObject private var supabaseService: SupabaseService
    let item: SegmentedItem
    let onSave: (SegmentedItem) -> Void
    
    @State private var editedName: String
    @State private var editedCategoryLevel1: String // Changed from editedCategory
    @State private var editedCategoryLevel2: String?
    @State private var editedCategoryLevel3: String?
    @State private var editedDescription: String
    @State private var editedPrice: String
    @State private var editedItemNumber: String
    @State private var showingCategoryPicker = false
    
    init(item: SegmentedItem, itemManager: ItemManager, onSave: @escaping (SegmentedItem) -> Void) {
        self.item = item
        self.itemManager = itemManager
        self.onSave = onSave
        self._editedName = State(initialValue: item.name)
        self._editedCategoryLevel1 = State(initialValue: item.categoryLevel1) // Use categoryLevel1
        self._editedCategoryLevel2 = State(initialValue: item.categoryLevel2) // Use categoryLevel2
        self._editedCategoryLevel3 = State(initialValue: item.categoryLevel3) // Use categoryLevel3
        self._editedDescription = State(initialValue: item.description)
        self._editedPrice = State(initialValue: String(format: "%.0f", item.estimatedPrice))
        self._editedItemNumber = State(initialValue: item.itemNumber)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 物品图片
                    if let imageData = item.croppedImageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.largeTitle)
                            )
                    }
                    
                    VStack(spacing: 16) {
                        // 物品编号
                        VStack(alignment: .leading, spacing: 8) {
                            Text("物品编号")
                                .font(.headline)
                            TextField("输入物品编号", text: $editedItemNumber)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // 物品名称
                        VStack(alignment: .leading, spacing: 8) {
                            Text("物品名称")
                                .font(.headline)
                            TextField("输入物品名称", text: $editedName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // 分类
                        VStack(alignment: .leading, spacing: 8) {
                            Text("分类")
                                .font(.headline)
                            Button(action: {
                                showingCategoryPicker = true
                            }) {
                                HStack {
                                    Text(editedCategoryLevel1.isEmpty ? "选择分类" : editedCategoryLevel1)
                                        .foregroundColor(editedCategoryLevel1.isEmpty ? .blue : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        
                        // 描述
                        VStack(alignment: .leading, spacing: 8) {
                            Text("描述")
                                .font(.headline)
                            TextField("输入物品描述", text: $editedDescription)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // 预估价格
                        VStack(alignment: .leading, spacing: 8) {
                            Text("预估价格")
                                .font(.headline)
                            TextField("输入预估价格", text: $editedPrice)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("编辑物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(editedName.isEmpty)
                }
            }
            .sheet(isPresented: $showingCategoryPicker) {
                CategoryPickerView(
                    selectedCategoryLevel1: $editedCategoryLevel1,
                    selectedCategoryLevel2: $editedCategoryLevel2,
                    selectedCategoryLevel3: $editedCategoryLevel3,
                    itemManager: itemManager
                )
                .environmentObject(supabaseService)
            }
        }
    }
    
    private func saveChanges() {
        let updatedItem = SegmentedItem(
            id: item.id,
            croppedImageData: item.croppedImageData, // 使用原始图片的 Data
            name: editedName,
            description: editedDescription,
            categoryLevel1: editedCategoryLevel1, // Use editedCategoryLevel1
            categoryLevel2: editedCategoryLevel2, // Use editedCategoryLevel2
            categoryLevel3: editedCategoryLevel3, // Use editedCategoryLevel3
            estimatedPrice: Double(editedPrice) ?? 0,
            confidence: item.confidence,
            itemNumber: editedItemNumber
        )
        onSave(updatedItem)
        dismiss()
    }
}
