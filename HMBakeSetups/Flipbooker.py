# Flipbooker Script v1.0
# Developed by Hamid.Memar (2024-2025)
# Usage : python3 ./Flipbooker.py "C:\Renders\Volume_LBF_000.png" 12 12

# Imports
import os
import re
import sys

# Pillow -> pip install pillow
from PIL import Image 

# Functions
def load_images(first_image_path):
    folder = os.path.dirname(first_image_path)
    base_name = os.path.basename(first_image_path)

    match = re.match(r"(.*?)(\d+)\.png", base_name)
    if not match:
        print("Filename doesn't match expected pattern like LBF_000.png")
        return []

    prefix, _ = match.groups()

    pattern = re.compile(rf"{re.escape(prefix)}(\d+)\.png")

    frame_files = sorted(
        [f for f in os.listdir(folder) if pattern.match(f)],
        key=lambda f: int(pattern.match(f).group(1))
    )

    images = []
    for file_name in frame_files:
        full_path = os.path.join(folder, file_name)
        try:
            img = Image.open(full_path)
            images.append(img)
        except Exception as e:
            print(f"Failed to load {full_path}: {e}")

    return images
def stitch_images(images, cols, rows, resize_to=None):
    if not images:
        print("No images loaded.")
        return None

    frame_w, frame_h = images[0].size
    canvas_w = cols * frame_w
    canvas_h = rows * frame_h

    print(f"Creating canvas of size {canvas_w}x{canvas_h}")
    output = Image.new('RGBA', (canvas_w, canvas_h), (0, 0, 0, 0))

    for i, img in enumerate(images):
        if i >= cols * rows:
            break
        x = (i % cols) * frame_w
        y = (i // cols) * frame_h
        output.paste(img, (x, y))

    if resize_to:
        output = output.resize(resize_to, Image.ANTIALIAS)
        print(f"Resized to {resize_to}")

    return output

# Entrypoint
if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage:\n  python flipbook.py <full_path_to_first_frame> <cols> <rows>")
        exit(-1)

    input_path = sys.argv[1]
    cols = int(sys.argv[2])
    rows = int(sys.argv[3])
    resize_to = None

    if len(sys.argv) == 6:
        resize_to = (int(sys.argv[4]), int(sys.argv[5]))

    images = load_images(input_path)
    flipbook = stitch_images(images, cols, rows, resize_to)

    if flipbook:
        out_path = os.path.join(os.path.dirname(input_path), "flipbook_output.png")
        flipbook.save(out_path)
        print(f"Flipbook Generated At {out_path}")
