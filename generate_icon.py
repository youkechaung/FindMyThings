from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os
from math import sin, cos, pi

def create_gradient(width, height, color1, color2):
    base = Image.new('RGB', (width, height), color1)
    top = Image.new('RGB', (width, height), color2)
    mask = Image.new('L', (width, height))
    mask_data = []
    for y in range(height):
        mask_data.extend([int(255 * (1 - y/height))] * width)
    mask.putdata(mask_data)
    base.paste(top, (0, 0), mask)
    return base

def create_app_icon():
    size = 1024
    # 创建渐变背景 - 使用现代的蓝紫色渐变
    image = create_gradient(size, size, (88, 86, 214), (45, 149, 255))
    draw = ImageDraw.Draw(image)
    
    # 创建搜索图标
    margin = size // 4
    circle_size = size // 2
    circle_thickness = size // 20
    
    # 绘制搜索图标的圆环
    for i in range(circle_thickness):
        draw.ellipse(
            [margin + i, margin + i, 
             margin + circle_size - i, margin + circle_size - i],
            outline=(255, 255, 255),
        )
    
    # 绘制搜索图标的手柄
    handle_start = (margin + circle_size * 0.7, margin + circle_size * 0.7)
    handle_end = (size - margin, size - margin)
    for i in range(circle_thickness):
        draw.line(
            [handle_start[0] + i, handle_start[1] + i,
             handle_end[0], handle_end[1]],
            fill=(255, 255, 255),
            width=circle_thickness
        )
    
    # 添加光晕效果
    image = image.filter(ImageFilter.GaussianBlur(radius=2))
    
    # 确保目标目录存在
    icon_dir = os.path.join(os.path.dirname(__file__), "找得到", "Assets.xcassets", "AppIcon.appiconset")
    os.makedirs(icon_dir, exist_ok=True)
    
    # 保存图标
    icon_path = os.path.join(icon_dir, "icon-1024@1x.png")
    image.save(icon_path, "PNG")
    print(f"Icon saved to: {icon_path}")

if __name__ == "__main__":
    create_app_icon()
