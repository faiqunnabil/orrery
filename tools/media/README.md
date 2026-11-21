# Media

Captures the README screenshots of the newer features from the running application, so they can be refreshed whenever the interface changes.

## Usage

From the repository root:

```
GODOT=/path/to/godot tools/media/capture.sh
```

On Windows, run it from Git Bash and point `GODOT` at the console executable. The run opens a window, uses the High preset, and writes these files to `.github/media`:

| File | Scene |
|---|---|
| `tours.jpg` | The first stop of the Eclipses and Comets tour |
| `solar_eclipse.jpg` | The Moon's shadow on Earth on 12 August 2026, cropped to a square |
| `night_sky.jpg` | Orion with constellation figures and names |
| `comet.jpg` | Halley's Comet in March 1986 |
| `sandbox.jpg` | The Sandbox physics panel at the Scientist level |
| `gravity_well.jpg` | The gravity well under the binary star preset |
| `figure_eight.jpg` | The figure-eight preset after most of a period, cropped to a square |
| `challenges.jpg` | The Round trip challenge in progress |

Your saved settings are backed up before the run and restored afterwards. The older screenshots in `.github/media` were taken by hand.
