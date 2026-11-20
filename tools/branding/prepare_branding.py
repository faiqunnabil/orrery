import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
BACKGROUND_THRESHOLD = 60
GLOW_MARGIN = 0.06
ICON_CANVAS_RATIO = 1.02
ICON_SIZE = 1024
ICON_CORNER_RATIO = 0.22
ICO_SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
PROJECT_ICON_SIZE = 512
SPLASH_SIZE = (720, 520)
SPLASH_EMBLEM_WIDTH = 460
SPLASH_WORDMARK = "Orrery"
SPLASH_WORDMARK_SIZE = 56
SPLASH_WORDMARK_GAP = 18
SPLASH_TEXT_COLOR = (230, 235, 245)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build the application icon and boot splash from the Orrery emblem.")
    parser.add_argument("--source", type=Path, default=REPOSITORY_ROOT / "assets/branding/orrery_emblem.jpg")
    parser.add_argument("--godot", type=Path, default=REPOSITORY_ROOT / "godot")
    return parser.parse_args()


def emblem_box(image: Image.Image) -> tuple[int, int, int, int]:
    mask = image.convert("L").point(lambda value: 255 if value > BACKGROUND_THRESHOLD else 0)
    left, top, right, bottom = mask.getbbox()
    margin = int(max(right - left, bottom - top) * GLOW_MARGIN)
    return max(left - margin, 0), max(top - margin, 0), min(right + margin, image.width), min(bottom + margin, image.height)


def background_color(image: Image.Image) -> tuple[int, int, int]:
    return image.convert("RGB").getpixel((0, 0))


def centered_canvas(emblem: Image.Image, size: tuple[int, int], color: tuple[int, int, int], offset_y: int = 0) -> Image.Image:
    canvas = Image.new("RGB", size, color)
    canvas.paste(emblem, ((size[0] - emblem.width) // 2, (size[1] - emblem.height) // 2 + offset_y))
    return canvas


def build_icon(emblem: Image.Image, color: tuple[int, int, int]) -> Image.Image:
    side = int(max(emblem.width, emblem.height) * ICON_CANVAS_RATIO)
    square = centered_canvas(emblem, (side, side), color).resize((ICON_SIZE, ICON_SIZE), Image.Resampling.LANCZOS)
    mask = Image.new("L", (ICON_SIZE, ICON_SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, ICON_SIZE - 1, ICON_SIZE - 1), int(ICON_SIZE * ICON_CORNER_RATIO), fill=255)
    icon = square.convert("RGBA")
    icon.putalpha(mask)
    return icon


def build_splash(emblem: Image.Image, color: tuple[int, int, int]) -> Image.Image:
    scale = SPLASH_EMBLEM_WIDTH / emblem.width
    small = emblem.resize((SPLASH_EMBLEM_WIDTH, int(emblem.height * scale)), Image.Resampling.LANCZOS)
    font = ImageFont.truetype(str(REPOSITORY_ROOT / "godot/assets/fonts/inter_semibold.ttf"), SPLASH_WORDMARK_SIZE)
    text_box = font.getbbox(SPLASH_WORDMARK)
    text_height = text_box[3] - text_box[1]
    block = small.height + SPLASH_WORDMARK_GAP + text_height
    splash = Image.new("RGB", SPLASH_SIZE, color)
    top = (SPLASH_SIZE[1] - block) // 2
    splash.paste(small, ((SPLASH_SIZE[0] - small.width) // 2, top))
    text_width = text_box[2] - text_box[0]
    origin = ((SPLASH_SIZE[0] - text_width) // 2 - text_box[0], top + small.height + SPLASH_WORDMARK_GAP - text_box[1])
    ImageDraw.Draw(splash).text(origin, SPLASH_WORDMARK, font=font, fill=SPLASH_TEXT_COLOR)
    return splash


def main() -> int:
    arguments = parse_arguments()
    source = Image.open(arguments.source).convert("RGB")
    color = background_color(source)
    emblem = source.crop(emblem_box(source))
    icon = build_icon(emblem, color)
    icon.resize((PROJECT_ICON_SIZE, PROJECT_ICON_SIZE), Image.Resampling.LANCZOS).save(arguments.godot / "icon.png")
    icon.save(arguments.godot / "icon.ico", sizes=ICO_SIZES)
    branding = arguments.godot / "assets/branding"
    branding.mkdir(parents=True, exist_ok=True)
    build_splash(emblem, color).save(branding / "splash.png")
    print(f"Background color {color}, emblem {emblem.size}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
