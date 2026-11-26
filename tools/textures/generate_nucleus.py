import argparse
from pathlib import Path

import numpy as np
from PIL import Image

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = REPOSITORY_ROOT / "godot" / "assets" / "textures" / "bodies" / "halley_nucleus.jpg"
SIZE = (1024, 512)
SEED = 1986
OCTAVES = 6
BASE_FREQUENCY = 2.0
PERSISTENCE = 0.55
PIT_COUNT = 70
PIT_RADIUS_RANGE = (0.03, 0.14)
PIT_DEPTH = 0.35
VENT_COUNT = 5
VENT_RADIUS = 0.05
DARK = np.array([38.0, 34.0, 31.0])
LIGHT = np.array([118.0, 108.0, 98.0])
VENT = np.array([168.0, 162.0, 150.0])
JPEG_QUALITY = 90
CONTRAST_PERCENTILES = (2.0, 98.0)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate the procedural surface texture of the nucleus of Halley's Comet.")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--seed", type=int, default=SEED)
    return parser.parse_args()


def sphere_points(width: int, height: int) -> np.ndarray:
    longitude = (np.arange(width) + 0.5) / width * 2.0 * np.pi - np.pi
    latitude = np.pi / 2.0 - (np.arange(height) + 0.5) / height * np.pi
    lon, lat = np.meshgrid(longitude, latitude)
    return np.stack([np.cos(lat) * np.cos(lon), np.cos(lat) * np.sin(lon), np.sin(lat)], axis=-1)


def value_noise(points: np.ndarray, frequency: float, rng: np.random.Generator) -> np.ndarray:
    lattice_size = int(np.ceil(frequency * 2.0)) + 2
    lattice = rng.random((lattice_size, lattice_size, lattice_size))
    scaled = (points + 1.0) * frequency
    cell = np.floor(scaled).astype(int)
    fraction = scaled - cell
    smooth = fraction * fraction * (3.0 - 2.0 * fraction)
    result = np.zeros(points.shape[:-1])
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                weight = (
                    (smooth[..., 0] if dx else 1.0 - smooth[..., 0])
                    * (smooth[..., 1] if dy else 1.0 - smooth[..., 1])
                    * (smooth[..., 2] if dz else 1.0 - smooth[..., 2])
                )
                result += weight * lattice[cell[..., 0] + dx, cell[..., 1] + dy, cell[..., 2] + dz]
    return result


def fractal_noise(points: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    total = np.zeros(points.shape[:-1])
    amplitude = 1.0
    norm = 0.0
    frequency = BASE_FREQUENCY
    for _ in range(OCTAVES):
        total += amplitude * value_noise(points, frequency, rng)
        norm += amplitude
        amplitude *= PERSISTENCE
        frequency *= 2.0
    return total / norm


def random_directions(count: int, rng: np.random.Generator) -> np.ndarray:
    vectors = rng.normal(size=(count, 3))
    return vectors / np.linalg.norm(vectors, axis=1, keepdims=True)


def add_pits(height: np.ndarray, points: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    for center in random_directions(PIT_COUNT, rng):
        radius = rng.uniform(*PIT_RADIUS_RANGE)
        distance = np.arccos(np.clip(points @ center, -1.0, 1.0)) / radius
        bowl = np.where(distance < 1.0, (1.0 - distance * distance), 0.0)
        rim = np.exp(-((distance - 1.05) ** 2) / 0.01) * 0.25
        height = height - PIT_DEPTH * radius * 4.0 * bowl + PIT_DEPTH * radius * 2.0 * rim
    return height


def vent_mask(points: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    mask = np.zeros(points.shape[:-1])
    for center in random_directions(VENT_COUNT, rng):
        distance = np.arccos(np.clip(points @ center, -1.0, 1.0)) / VENT_RADIUS
        mask = np.maximum(mask, np.exp(-distance * distance))
    return mask


def main() -> int:
    arguments = parse_arguments()
    rng = np.random.default_rng(arguments.seed)
    width, height = SIZE
    points = sphere_points(width, height)
    surface = add_pits(fractal_noise(points, rng), points, rng)
    low, high = np.percentile(surface, CONTRAST_PERCENTILES)
    surface = np.clip((surface - low) / (high - low), 0.0, 1.0)
    shade = surface[..., None]
    color = DARK + (LIGHT - DARK) * shade
    vents = vent_mask(points, rng)[..., None]
    color = color + (VENT - color) * vents * 0.6
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(color, 0, 255).astype(np.uint8)).save(arguments.output, quality=JPEG_QUALITY)
    print(f"Wrote {arguments.output.relative_to(REPOSITORY_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
