import argparse
import hashlib
import sys
import urllib.request
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import tifffile
from PIL import Image

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SOURCE_URL = "https://asc-pds-services.s3.us-west-2.amazonaws.com/mosaic/"
HIGH_SOURCE_URL = "https://www.solarsystemscope.com/textures/download/"
OUTPUT_SIZE = (2048, 1024)
HIGH_OUTPUT_SIZE = (4096, 2048)
HIGH_SUFFIX = "_4k"
JPEG_QUALITY = 90
STRETCH_PERCENTILES = (0.5, 99.5)
DOWNLOAD_CHUNK = 1 << 20


@dataclass(frozen=True)
class Map:
    body: str
    source: str
    center_longitude: float
    dark: tuple[int, int, int] | None = None
    bright: tuple[int, int, int] | None = None
    contrast: float = 1.0


MAPS = [
    Map("io", "Io_GalileoSSI-Voyager_Global_Mosaic_ClrMerge_1km.tif", 0.0),
    Map("europa", "Europa_Voyager_GalileoSSI_global_mosaic_500m.tif", 180.0, (107, 83, 64), (243, 237, 225)),
    Map("ganymede", "Ganymede_Voyager_GalileoSSI_Global_ClrMosaic_1435m.tif", 180.0),
    Map("callisto", "Callisto_Voyager_GalileoSSI_global_mosaic_1km.tif", 180.0, (46, 39, 34), (201, 191, 178)),
    Map("titan", "Titan_ISS_P19658_Mosaic_Global_4km.tif", 180.0, (169, 104, 43), (232, 176, 104), 0.35),
    Map("ceres", "Ceres_Dawn_FC_DLR_global_20ppd_Oct2015.tif", 180.0, (42, 42, 42), (181, 179, 175)),
    Map("pluto", "Pluto_NewHorizons_Global_Mosaic_300m_Jul2017_8bit.tif", 180.0, (74, 46, 31), (243, 227, 207)),
]


HIGH_RESOLUTION = {
    "bodies/sun": "8k_sun.jpg",
    "bodies/mercury": "8k_mercury.jpg",
    "bodies/venus_surface": "8k_venus_surface.jpg",
    "bodies/earth_daymap": "8k_earth_daymap.jpg",
    "bodies/earth_nightmap": "8k_earth_nightmap.jpg",
    "bodies/earth_clouds": "8k_earth_clouds.jpg",
    "bodies/moon": "8k_moon.jpg",
    "bodies/mars": "8k_mars.jpg",
    "bodies/jupiter": "8k_jupiter.jpg",
    "bodies/saturn": "8k_saturn.jpg",
    "sky/stars_milky_way": "8k_stars_milky_way.jpg",
}


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Download USGS global mosaics and convert them into body textures.")
    parser.add_argument("--cache", type=Path, default=Path(__file__).resolve().parent / "cache")
    parser.add_argument("--output", type=Path, default=REPOSITORY_ROOT / "godot/assets/textures/bodies")
    parser.add_argument("--only", nargs="*", default=None, help="Body ids to process")
    parser.add_argument(
        "--high",
        action="store_true",
        help="Build the 4K textures of the High preset from Solar System Scope 8K maps instead",
    )
    parser.add_argument("--textures", type=Path, default=REPOSITORY_ROOT / "godot/assets/textures")
    return parser.parse_args()


def md5_of(path: Path) -> str:
    digest = hashlib.md5()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(DOWNLOAD_CHUNK), b""):
            digest.update(chunk)
    return digest.hexdigest()


def fetch(source: str, cache: Path) -> Path:
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / source
    with urllib.request.urlopen(SOURCE_URL + source + ".md5") as response:
        expected = response.read().decode().split()[0]
    if target.exists() and md5_of(target) == expected:
        return target
    print(f"Downloading {source}")
    with urllib.request.urlopen(SOURCE_URL + source) as response, target.open("wb") as handle:
        for chunk in iter(lambda: response.read(DOWNLOAD_CHUNK), b""):
            handle.write(chunk)
    if md5_of(target) != expected:
        target.unlink()
        raise RuntimeError(f"Checksum mismatch for {source}")
    return target


def read_channels(path: Path) -> np.ndarray:
    data = tifffile.imread(path)
    if data.ndim == 2:
        return data[:, :, np.newaxis]
    if data.shape[0] in (3, 4) and data.shape[0] < data.shape[-1]:
        data = np.moveaxis(data, 0, -1)
    return data[:, :, :3]


def resize_plane(plane: np.ndarray, size: tuple[int, int]) -> np.ndarray:
    return np.asarray(Image.fromarray(plane.astype(np.float32), mode="F").resize(size, Image.Resampling.BOX))


def masked_resize(channels: np.ndarray, size: tuple[int, int]) -> tuple[np.ndarray, np.ndarray]:
    mask = np.any(channels > 0, axis=2).astype(np.float32)
    weight = resize_plane(mask, size)
    planes = []
    for index in range(channels.shape[2]):
        total = resize_plane(channels[:, :, index].astype(np.float32) * mask, size)
        planes.append(np.divide(total, weight, out=np.zeros_like(total), where=weight > 1.0e-6))
    return np.stack(planes, axis=2), weight > 1.0e-6


def fill_gaps(image: np.ndarray, valid: np.ndarray) -> np.ndarray:
    if valid.all():
        return image
    height, width = valid.shape
    coarse_size = (max(width // 2, 1), max(height // 2, 1))
    weights = resize_plane(valid.astype(np.float32), coarse_size)
    coarse_planes = []
    for index in range(image.shape[2]):
        total = resize_plane(image[:, :, index] * valid, coarse_size)
        coarse_planes.append(np.divide(total, weights, out=np.zeros_like(total), where=weights > 1.0e-6))
    coarse = fill_gaps(np.stack(coarse_planes, axis=2), weights > 1.0e-6)
    upsampled = np.stack(
        [
            np.asarray(Image.fromarray(coarse[:, :, index], mode="F").resize((width, height), Image.Resampling.BILINEAR))
            for index in range(image.shape[2])
        ],
        axis=2,
    )
    return np.where(valid[:, :, np.newaxis], image, upsampled)


def fill_gaps_wrapped(image: np.ndarray, valid: np.ndarray) -> np.ndarray:
    width = image.shape[1]
    tiled = fill_gaps(np.concatenate([image] * 3, axis=1), np.concatenate([valid] * 3, axis=1))
    return tiled[:, width : 2 * width]


def stretch(image: np.ndarray, valid: np.ndarray) -> np.ndarray:
    low, high = np.percentile(image[valid], STRETCH_PERCENTILES)
    return np.clip((image - low) / max(high - low, 1.0e-6), 0.0, 1.0)


def colorize(gray: np.ndarray, entry: Map) -> np.ndarray:
    level = 0.5 + (gray[:, :, 0] - 0.5) * entry.contrast
    dark = np.array(entry.dark, dtype=np.float32) / 255.0
    bright = np.array(entry.bright, dtype=np.float32) / 255.0
    return dark + (bright - dark) * level[:, :, np.newaxis]


def convert(entry: Map, source: Path, output: Path) -> None:
    channels = read_channels(source)
    image, valid = masked_resize(channels, OUTPUT_SIZE)
    image = stretch(fill_gaps_wrapped(image, valid), valid)
    if entry.dark is not None:
        image = colorize(image, entry)
    elif image.shape[2] == 1:
        image = np.repeat(image, 3, axis=2)
    shift = int(round(OUTPUT_SIZE[0] * (entry.center_longitude / 360.0)))
    image = np.roll(image, shift, axis=1)
    pixels = (np.clip(image, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    output.mkdir(parents=True, exist_ok=True)
    Image.fromarray(pixels, mode="RGB").save(output / f"{entry.body}.jpg", quality=JPEG_QUALITY, optimize=True)
    print(f"Wrote {entry.body}.jpg, {100.0 * valid.mean():.1f}% covered by imagery")


def fetch_high(source: str, cache: Path) -> Path:
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / source
    if not target.exists():
        print(f"Downloading {source}")
        partial = target.with_suffix(".part")
        with urllib.request.urlopen(HIGH_SOURCE_URL + source) as response, partial.open("wb") as handle:
            for chunk in iter(lambda: response.read(DOWNLOAD_CHUNK), b""):
                handle.write(chunk)
        partial.rename(target)
    return target


def convert_high(name: str, source: Path, textures: Path) -> None:
    Image.MAX_IMAGE_PIXELS = None
    with Image.open(source) as image:
        resized = image.convert("RGB").resize(HIGH_OUTPUT_SIZE, Image.Resampling.LANCZOS)
    target = textures / f"{name}{HIGH_SUFFIX}.jpg"
    resized.save(target, quality=JPEG_QUALITY, optimize=True)
    print(f"Wrote {target.relative_to(textures)}")


def main() -> int:
    arguments = parse_arguments()
    if arguments.high:
        for name, source in HIGH_RESOLUTION.items():
            if arguments.only is None or name.split("/")[-1] in arguments.only:
                convert_high(name, fetch_high(source, arguments.cache), arguments.textures)
        return 0
    selected = [entry for entry in MAPS if arguments.only is None or entry.body in arguments.only]
    for entry in selected:
        convert(entry, fetch(entry.source, arguments.cache), arguments.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
