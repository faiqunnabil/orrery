import argparse
import csv
import hashlib
import json
import sys
import urllib.request
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
CACHE = Path(__file__).resolve().parent / "cache"
OUTPUT = REPOSITORY_ROOT / "godot" / "data" / "stars.json"
SOURCES = {
    "hygdata_v41.csv": (
        "https://raw.githubusercontent.com/astronexus/HYG-Database/3bf37f4b2d5460e1278286320d1d62fab9b493c1/hyg/CURRENT/hygdata_v41.csv",
        "d9f69fd86bbf90a4e4d52b4c5c53eacfa6dfc0bfdef85bfd94f095e0bebe4ebd",
    ),
    "modern_index.json": (
        "https://raw.githubusercontent.com/Stellarium/stellarium/daace2add6a1bf886e8ee1934f51e9c69f818d18/skycultures/modern/index.json",
        "1f2f5ffd6c9e25a7d0dcfdbf1f756e2db03dd3b8ed4ec016a2839b09f6b0fe1e",
    ),
}
MAGNITUDE_LIMIT = 6.5
DEFAULT_COLOR_INDEX = 0.6
HOURS_TO_DEGREES = 15.0
DOWNLOAD_CHUNK = 1 << 20


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build godot/data/stars.json from the HYG catalog and Stellarium constellation figures.")
    parser.add_argument("--limit", type=float, default=MAGNITUDE_LIMIT, help="Faintest visual magnitude to keep")
    return parser.parse_args()


def fetch(name: str) -> Path:
    url, expected = SOURCES[name]
    path = CACHE / name
    if not path.exists():
        CACHE.mkdir(exist_ok=True)
        print(f"Downloading {url}")
        with urllib.request.urlopen(url) as response, open(path, "wb") as output:
            while chunk := response.read(DOWNLOAD_CHUNK):
                output.write(chunk)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != expected:
        path.unlink()
        raise SystemExit(f"{name}: checksum {digest} does not match {expected}")
    return path


def read_catalog(path: Path) -> tuple[list[list[float]], dict[int, list[float]]]:
    stars = []
    by_hip = {}
    with open(path, newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            if row["proper"] == "Sol":
                continue
            ra = float(row["ra"]) * HOURS_TO_DEGREES
            dec = float(row["dec"])
            magnitude = float(row["mag"])
            if row["hip"]:
                by_hip[int(row["hip"])] = [ra, dec]
            if magnitude > ARGUMENTS.limit:
                continue
            color_index = float(row["ci"]) if row["ci"] else DEFAULT_COLOR_INDEX
            stars.append([round(ra, 4), round(dec, 4), round(magnitude, 2), round(color_index, 2)])
    stars.sort(key=lambda star: star[2])
    return stars, by_hip


def read_figures(path: Path, by_hip: dict[int, list[float]]) -> list[dict]:
    culture = json.loads(path.read_text(encoding="utf-8"))
    figures = []
    for constellation in culture["constellations"]:
        polylines = []
        for line in constellation["lines"]:
            points = [[round(by_hip[hip][0], 4), round(by_hip[hip][1], 4)] for hip in line if isinstance(hip, int) and hip in by_hip]
            if len(points) >= 2:
                polylines.append(points)
        name = constellation.get("common_name", {})
        figures.append({
            "id": constellation["id"].split()[-1],
            "name": name.get("native", name.get("english", "")),
            "lines": polylines,
        })
    return figures


def main() -> int:
    stars, by_hip = read_catalog(fetch("hygdata_v41.csv"))
    figures = read_figures(fetch("modern_index.json"), by_hip)
    data = {
        "magnitude_limit": ARGUMENTS.limit,
        "stars": stars,
        "constellations": figures,
    }
    OUTPUT.write_text(json.dumps(data, separators=(",", ":")) + "\n", encoding="utf-8", newline="\n")
    segments = sum(len(line) - 1 for figure in figures for line in figure["lines"])
    print(f"{len(stars)} stars to magnitude {ARGUMENTS.limit}, {len(figures)} constellations, {segments} line segments")
    print(f"Wrote {OUTPUT.relative_to(REPOSITORY_ROOT)} ({OUTPUT.stat().st_size // 1024} KB)")
    return 0


ARGUMENTS = parse_arguments()

if __name__ == "__main__":
    sys.exit(main())
