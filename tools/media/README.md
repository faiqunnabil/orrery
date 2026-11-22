# Media

Captures every README screenshot from the running application, so they can be refreshed whenever the interface changes.

## Usage

From the repository root:

```
GODOT=/path/to/godot tools/media/capture.sh
```

On Windows, run it from Git Bash and point `GODOT` at the console executable. The run opens a window, uses the High preset, and writes these files to `.github/media`:

| File | Scene |
|---|---|
| `main_menu.jpg` | The main menu |
| `jupiter_system.jpg` | Jupiter and the Galilean moons with the information panel, used at the top of the README |
| `earth.jpg` | Earth with its day and night sides |
| `inner_system.jpg` | The inner solar system and the asteroid belt from above |
| `saturn.jpg`, `pluto.jpg` | Close views with Scientist-level information |
| `io_shadow.jpg` | Io and its shadow on Jupiter, cropped to a square |
| `lunar_eclipse.jpg` | The lunar eclipse of 3 March 2026 at true scale, cropped to a square |
| `solar_eclipse.jpg` | The Moon's shadow on Earth on 2 August 2027, cropped to a square |
| `quiz.jpg` | Quiz feedback after a wrong answer |
| `tours.jpg` | The first stop of the Eclipses and Comets tour |
| `night_sky.jpg` | Orion with constellation figures and names |
| `comet.jpg` | Halley's Comet in March 1986 |
| `sandbox.jpg` | The Sandbox physics panel at the Scientist level |
| `gravity_well.jpg` | The gravity well under the binary star preset |
| `figure_eight.jpg` | The figure-eight preset after most of a period, cropped to a square |
| `challenges.jpg` | The Round trip challenge in progress |

Your saved settings are backed up before the run and restored afterwards.
