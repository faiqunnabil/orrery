# Body Texture Preparation

Builds the surface textures of Io, Europa, Ganymede, Callisto, Titan, Ceres, and Pluto from public-domain global mosaics published by the USGS Astrogeology Science Center. Generated files are bundled with the game.

With `--high`, it instead builds the 4K textures used by the High quality preset (`<name>_4k.jpg`) by downsampling the 8K maps of Solar System Scope (CC BY 4.0).

With `--normals`, it builds tangent-space normal maps (`<name>_normal.png`) for the Moon, Mars, and Earth from public-domain elevation models: LRO LOLA LDEM_16, MGS MOLA MEGDR at 16 pixels per degree, and NOAA ETOPO5 (land only). Slopes are measured on the sphere, faded near the poles where the grids converge, and exaggerated so the 99th percentile slope maps to 0.35. Red points east, green points north, and blue points up.

## Requirements

- [uv](https://docs.astral.sh/uv/)
- Internet access to download about 1 GB of GeoTIFF mosaics. Downloads are cached and verified against the published MD5 checksums.

## Usage

From this directory:

```
uv run prepare_textures.py
```

On Windows without a local Python, run it inside WSL or Linux with `UV_LINK_MODE=copy` when the repository is on a Windows drive.

| Option | Default | Purpose |
|---|---|---|
| `--cache` | `tools/textures/cache` | Download directory for the source mosaics |
| `--output` | `godot/assets/textures/bodies` | Destination for `<id>.jpg` |
| `--only` | all | Body ids to process, for example `--only io pluto` |
| `--high` | off | Build the 4K High preset textures from Solar System Scope 8K maps |
| `--normals` | off | Build normal maps from LOLA, MOLA, and ETOPO5 elevation data |
| `--textures` | `godot/assets/textures` | Destination root for the 4K textures |

## Processing

| Step | Purpose |
|---|---|
| Masked box downsampling to 2048 × 1024 | Averages only pixels that hold imagery, so missing data does not darken the result |
| Pyramid gap filling with horizontal wrap | Fills unimaged areas with blurred surroundings without a seam at the date line |
| Percentile stretch (0.5 % to 99.5 %) | Normalizes brightness across mosaics |
| Two-color tint | Colors grayscale mosaics (Europa, Callisto, Titan, Ceres, Pluto) with approximate true-color tones |
| Recentering | Moves longitude 0 to the image center to match the other body textures |

| Body | Source mosaic |
|---|---|
| Io | `Io_GalileoSSI-Voyager_Global_Mosaic_ClrMerge_1km.tif` |
| Europa | `Europa_Voyager_GalileoSSI_global_mosaic_500m.tif` |
| Ganymede | `Ganymede_Voyager_GalileoSSI_Global_ClrMosaic_1435m.tif` |
| Callisto | `Callisto_Voyager_GalileoSSI_global_mosaic_1km.tif` |
| Titan | `Titan_ISS_P19658_Mosaic_Global_4km.tif` |
| Ceres | `Ceres_Dawn_FC_DLR_global_20ppd_Oct2015.tif` |
| Pluto | `Pluto_NewHorizons_Global_Mosaic_300m_Jul2017_8bit.tif` |
