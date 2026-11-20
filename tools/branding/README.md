# Branding

Builds the application icon and the boot splash from the Orrery emblem in `assets/branding/orrery_emblem.jpg`.

## Requirements

- [uv](https://docs.astral.sh/uv/)

## Usage

From this directory:

```
uv run prepare_branding.py
```

| Output | Use |
|---|---|
| `godot/icon.png` | Project and window icon (512 × 512, rounded tile) |
| `godot/icon.ico` | Windows executable and native window icon (16 to 256 px) |
| `godot/assets/branding/splash.png` | Boot splash, shown on the emblem's background color |

The emblem is found by thresholding against the dark background, padded for its glow, and centered. The splash adds the "Orrery" wordmark in Inter SemiBold.
