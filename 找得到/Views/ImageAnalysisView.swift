import SwiftUI
import PhotosUI
import UIKit

struct ImageAnalysisView: View {
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var imageSource: ImageSource = .photoLibrary
    @State private var analysisResult: String = ""
    @State private var isAnalyzing = false
    
    private enum ImageSource {
        case photoLibrary, camera
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 图片显示区域
                    Group {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .cornerRadius(10)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 200)
                                
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                    Text("点击选择图片")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .onTapGesture {
                        showingImagePicker = true
                    }
                    
                    // 分析结果显示区域
                    if isAnalyzing {
                        ProgressView("正在分析图片...")
                    } else if !analysisResult.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("分析结果")
                                .font(.headline)
                            Text(analysisResult)
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .navigationTitle("图片分析")
            .navigationBarTitleDisplayMode(.inline)
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
                    .onDisappear {
                        if selectedImage != nil {
                            analyzeImage()
                        }
                    }
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                ImagePicker(image: $selectedImage)
                    .onDisappear {
                        if selectedImage != nil {
                            analyzeImage()
                        }
                    }
            }
        }
    }
    
    private func analyzeImage() {
        guard let image = selectedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        
        isAnalyzing = true
        analysisResult = ""
        
        AIService.shared.analyzeImage(imageData) { result in
            DispatchQueue.main.async {
                isAnalyzing = false
                if let result = result {
                    analysisResult = result
                } else {
                    analysisResult = "图片分析失败，请重试"
                }
            }
        }
    }
}
