//
//  File.swift
//
//  Created by chloe on 2025/8/30.
//

import Foundation
import ImageIO
import CoreGraphics
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

// ===== 配置 =====
let accessToken = "24.461d6ebeb2622a6677e65335c17d5025.2592000.1758850651.282335-119869976"
let endpoint = "https://aip.baidubce.com/rest/2.0/image-classify/v1/multi_object_detect"
let imagePath = "/Users/chloe/Desktop/testjpg.jpg"

// 限制
let maxBytes: Int = 4 * 1024 * 1024           // 4MB
let minShortSide: CGFloat = 64
let maxLongSide: CGFloat = 4096
let maxAspect: CGFloat = 3.0                   // 3:1
let initialJPEGQuality: CGFloat = 0.9
let minJPEGQuality: CGFloat = 0.2

// ===== 工具函数 =====

func loadCGImage(from data: Data) -> CGImage? {
    guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

func imageSize(of data: Data) -> (w: Int, h: Int)? {
    guard let src = CGImageSourceCreateWithData(data as CFData, nil),
          let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
          let w = props[kCGImagePropertyPixelWidth] as? Int,
          let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
    return (w, h)
}

func cropToMaxAspect(_ img: CGImage, maxAspect: CGFloat) -> CGImage {
    let w = CGFloat(img.width), h = CGFloat(img.height)
    let ratio = max(w/h, h/w)
    guard ratio > maxAspect else { return img } // 已满足

    // 需要居中裁剪到最大允许比例
    if w/h > maxAspect {
        let targetW = maxAspect * h
        let x = (w - targetW) / 2.0
        let rect = CGRect(x: Int(x), y: 0, width: Int(targetW), height: Int(h))
        return img.cropping(to: rect) ?? img
    } else {
        let targetH = maxAspect * w
        let y = (h - targetH) / 2.0
        let rect = CGRect(x: 0, y: Int(y), width: Int(w), height: Int(targetH))
        return img.cropping(to: rect) ?? img
    }
}

func resize(_ img: CGImage, minShort: CGFloat, maxLong: CGFloat) -> CGImage {
    // 计算缩放因子：既要 >= 64 的短边，也要 <= 4096 的长边
    let w = CGFloat(img.width), h = CGFloat(img.height)
    let shortSide = min(w, h)
    let longSide = max(w, h)

    var scaleUp: CGFloat = 1.0
    if shortSide < minShort { scaleUp = minShort / shortSide }

    var scaleDown: CGFloat = 1.0
    if longSide > maxLong { scaleDown = maxLong / longSide }

    // 先放大以满足最短边，再缩小以满足最长边（或相反），取综合比例
    let scale = min(max(scaleUp, 1.0), scaleDown)

    // 如果 scaleDown < 1，则说明需要缩小；如果 scaleUp > 1，需要放大。
    // 有时二者会互相制约，这里再综合一次：
    let finalScale = min(max(scaleUp, scaleDown), max(scaleUp, scaleDown))

    let newW = max(1, Int(round(w * finalScale)))
    let newH = max(1, Int(round(h * finalScale)))

    guard newW != img.width || newH != img.height else { return img }

    // 用 CoreGraphics 重绘缩放
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerPixel = 4
    let bytesPerRow = newW * bytesPerPixel
    guard let ctx = CGContext(data: nil,
                              width: newW,
                              height: newH,
                              bitsPerComponent: 8,
                              bytesPerRow: bytesPerRow,
                              space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return img }

    ctx.interpolationQuality = .high
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: newW, height: newH))
    return ctx.makeImage() ?? img
}

func encodeJPEG(_ img: CGImage, quality: CGFloat) -> Data? {
    #if canImport(UniformTypeIdentifiers)
    let utType = UTType.jpeg.identifier as CFString
    #else
    let utType = "public.jpeg" as CFString
    #endif
    let data = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(data, utType, 1, nil) else { return nil }
    let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
    CGImageDestinationAddImage(dest, img, options as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { return nil }
    return data as Data
}

// 在工具函数区，加入这个严格的 percent-encoding 函数
func percentEncodeBase64(_ base64: String) -> String {
    // 只允许字母数字和 - _ . ~（RFC3986 unreserved characters）
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-_.~")
    // 这个会把 + / = 等都转成 %2B %2F %3D
    return base64.addingPercentEncoding(withAllowedCharacters: allowed) ?? base64
}

// 用更可靠的方法构造表单 body（替换原 buildFormBody）
func buildFormBody(imageBase64: String) -> Data? {
    let encoded = percentEncodeBase64(imageBase64)
    // 调试日志：查看是否包含必须的 %2F/%2B/%3D
    if encoded.contains("%2F") || encoded.contains("%2B") || encoded.contains("%3D") {
        print("✅ Base64 已严格 percent-encoding（包含 %2F/%2B/%3D）")
    } else {
        print("⚠️ 注意：encoded 未发现 %2F/%2B/%3D（注意对比）")
    }
    // 直接拼接 body（application/x-www-form-urlencoded）
    let bodyString = "image=\(encoded)"
    return bodyString.data(using: .utf8)
}


func lengthInBytes(_ s: String) -> Int { s.lengthOfBytes(using: .utf8) }

// ===== 主流程 =====

let fileURL = URL(fileURLWithPath: imagePath)
guard FileManager.default.fileExists(atPath: fileURL.path) else {
    print("❌ 错误：图片文件不存在：\(imagePath)")
    exit(1)
}

guard let originalData = try? Data(contentsOf: fileURL) else {
    print("❌ 错误：无法读取图片数据")
    exit(1)
}

// 打印原始图像尺寸
if let sz = imageSize(of: originalData) {
    print("📐 原始尺寸：\(sz.w) x \(sz.h)")
}

// 解码为 CGImage
guard var cgImage = loadCGImage(from: originalData) else {
    print("❌ 错误：无法解码为 CGImage（图片可能损坏或格式不支持）")
    exit(1)
}

// 限制宽高比 ≤ 3:1（必要时居中裁剪）
cgImage = cropToMaxAspect(cgImage, maxAspect: maxAspect)

// 尺寸约束：最短边 ≥64，最长边 ≤4096（必要时缩放）
cgImage = resize(cgImage, minShort: minShortSide, maxLong: maxLongSide)
print("📐 处理后尺寸：\(cgImage.width) x \(cgImage.height)")

// 以 JPEG 编码并控制体积（先用 0.9 质量）
var quality = initialJPEGQuality
var jpegData: Data? = encodeJPEG(cgImage, quality: quality)
guard jpegData != nil else {
    print("❌ 错误：JPEG 编码失败")
    exit(1)
}

// 循环降低质量，确保 Base64 与 urlencode 后都 < 4MB
while true {
    guard let data = jpegData else { break }
    let base64 = data.base64EncodedString() // 无 data:image/... 头
    let base64Bytes = lengthInBytes(base64)

    // 构造 x-www-form-urlencoded
    guard let formData = buildFormBody(imageBase64: base64) else {
        print("❌ 错误：构造表单请求体失败")
        exit(1)
    }
    let urlEncodedBytes = formData.count

    print("📦 当前质量：\(String(format: "%.2f", quality)) | Base64: \(base64Bytes)B | URL Encoded: \(urlEncodedBytes)B")

    if base64Bytes <= maxBytes && urlEncodedBytes <= maxBytes {
        // 满足 4MB 双重约束，发送请求
        var urlComps = URLComponents(string: endpoint)!
        urlComps.queryItems = [URLQueryItem(name: "access_token", value: accessToken)]
        guard let url = urlComps.url else {
            print("❌ 错误：URL 拼接失败")
            exit(1)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = formData

        // 日志：确认已百分号编码（看到 %2B/%2F/%3D 即可）
        if let q = String(data: formData, encoding: .utf8) {
            print("🧪 表单前60字符：\(q.prefix(60))")
            if q.contains("%2B") { print("✅ 已正确编码 '+'") }
            if q.contains("%2F") { print("✅ 已正确编码 '/'") }
            if q.contains("%3D") { print("✅ 已正确编码 '='") }
        }

        print("🚀 发送请求到：\(url.absoluteString)")

        // 同步等待（命令行环境）
        let sem = DispatchSemaphore(value: 1)
        sem.wait()
        URLSession.shared.dataTask(with: req) { data, resp, err in
            defer { sem.signal() }
            if let err = err {
                print("❌ 请求失败：\(err)")
                return
            }
            if let http = resp as? HTTPURLResponse {
                print("📡 HTTP 状态码：\(http.statusCode)")
            }
            guard let data = data else {
                print("⚠️ 无响应数据")
                return
            }
            print("📦 响应大小：\(data.count) 字节")
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                print("✅ 响应 JSON：\(json)")
            } else if let txt = String(data: data, encoding: .utf8) {
                print("📜 响应文本：\(txt)")
            }
        }.resume()

        // 等待 15s（或根据需要调整/改为更优雅的 RunLoop 方式）
        _ = sem.wait(timeout: .now() + 15)
        print("🎯 处理完成")
        exit(0)
    }

    // 若超限则降低质量再试
    quality -= 0.1
    if quality < minJPEGQuality {
        print("❌ 无法满足 4MB 限制（即便质量降到 \(minJPEGQuality) 仍超过），请尝试更低分辨率图片。")
        exit(1)
    }
    jpegData = encodeJPEG(cgImage, quality: quality)
}
