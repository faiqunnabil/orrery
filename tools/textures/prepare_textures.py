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


@dataclass(frozen=True)
class Elevation:
    body: str
    url: str
    shape: tuple[int, int]
    dtype: str
    meters_per_unit: float
    radius_km: float
    land_only: bool = False


ELEVATIONS = [
    Elevation(
        "moon",
        "https://pds-geosciences.wustl.edu/lro/lro-l-lola-3-rdr-v1/lrolol_1xxx/data/lola_gdr/cylindrical/img/ldem_16.img",
        (2880, 5760),
        "<i2",
        0.5,
        1737.4,
    ),
    Elevation(
        "mars",
        "https://pds-geosciences.wustl.edu/mgs/mgs-m-mola-5-megdr-l3-v1/mgsl_300x/meg016/megt90n000eb.img",
        (2880, 5760),
        ">i2",
        1.0,
        3389.5,
    ),
    Elevation(
        "earth",
        "https://www.ngdc.noaa.gov/mgg/global/relief/ETOPO5/TOPO/ETOPO5/ETOPO5.DAT",
        (2160, 4320),
        ">i2",
        1.0,
        6371.0,
        True,
    ),
]
NORMAL_TARGET_SLOPE = 0.35
NORMAL_MIN_COS_LATITUDE = 0.05
NORMAL_POLAR_FADE_DEGREES = (70.0, 85.0)
NORMAL_SUFFIX = "_normal"

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
    parser.add_argument(
        "--normals",
        action="store_true",
        help="Build tangent-space normal maps from LOLA, MOLA, and ETOPO5 elevation data instead",
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


def fetch_url(url: str, cache: Path) -> Path:
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / url.rsplit("/", 1)[-1]
    if not target.exists():
        print(f"Downloading {target.name}")
        partial = target.with_suffix(target.suffix + ".part")
        with urllib.request.urlopen(url) as response, partial.open("wb") as handle:
            for chunk in iter(lambda: response.read(DOWNLOAD_CHUNK), b""):
                handle.write(chunk)
        partial.rename(target)
    return target


def build_normal_map(entry: Elevation, source: Path, output: Path) -> None:
    heights = np.fromfile(source, dtype=entry.dtype).reshape(entry.shape).astype(np.float32) * entry.meters_per_unit
    if entry.land_only:
        heights = np.maximum(heights, 0.0)
    heights = resize_plane(heights, OUTPUT_SIZE)
    heights = np.roll(heights, OUTPUT_SIZE[0] // 2, axis=1)
    rows, columns = heights.shape
    latitude = np.radians(90.0 - (np.arange(rows) + 0.5) * 180.0 / rows)
    radius_m = entry.radius_km * 1000.0
    east_step = radius_m * np.maximum(np.cos(latitude), NORMAL_MIN_COS_LATITUDE) * (2.0 * np.pi / columns)
    north_step = radius_m * np.pi / rows
    east_slope = (np.roll(heights, -1, axis=1) - np.roll(heights, 1, axis=1)) / (2.0 * east_step[:, np.newaxis])
    padded = np.pad(heights, ((1, 1), (0, 0)), mode="edge")
    north_slope = (padded[:-2] - padded[2:]) / (2.0 * north_step)
    fade = np.clip(
        (NORMAL_POLAR_FADE_DEGREES[1] - np.degrees(np.abs(latitude)))
        / (NORMAL_POLAR_FADE_DEGREES[1] - NORMAL_POLAR_FADE_DEGREES[0]),
        0.0,
        1.0,
    )[:, np.newaxis]
    east_slope *= fade
    north_slope *= fade
    slope = np.sqrt(east_slope ** 2 + north_slope ** 2)
    exaggeration = NORMAL_TARGET_SLOPE / max(float(np.percentile(slope, 99.0)), 1.0e-6)
    normal = np.stack([-exaggeration * east_slope, -exaggeration * north_slope, np.ones_like(heights)], axis=2)
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    pixels = ((normal * 0.5 + 0.5) * 255.0 + 0.5).astype(np.uint8)
    target = output / f"{entry.body}{NORMAL_SUFFIX}.png"
    Image.fromarray(pixels, mode="RGB").save(target, optimize=True)
    print(f"Wrote {target.name}, relief exaggerated {exaggeration:.1f}x")


def main() -> int:
    arguments = parse_arguments()
    if arguments.normals:
        for entry in ELEVATIONS:
            if arguments.only is None or entry.body in arguments.only:
                build_normal_map(entry, fetch_url(entry.url, arguments.cache), arguments.output)
        return 0
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
