# Orrery — Product Requirements Document

| | |
|---|---|
| **Status** | v1.0, reflects release 1.0.0 |
| **Course** | Computer Graphics (Final Project) |
| **Team** | Sepak Takraw |
| **Engine** | Godot 4.7.2 (standard, GDScript), Compatibility renderer |
| **Platforms** | PC — Windows and Linux (64-bit) |
| **Presentation** | 3D |
| **Duration** | 4 weeks |

---

## 1. Overview

Orrery is an interactive, real-time 3D solar system application. It combines two experiences in one product:

- **Explore** — a guided, accurate tour of the Sun, planets, major moons, and dwarf planets, with adjustable scale and time.
- **Sandbox** — a gravity simulator where users place, launch, and remove bodies and observe how orbits respond.

The name refers to the orrery, a mechanical model of the solar system. Orrery brings that idea into an interactive digital form.

## 2. Goals

1. Deliver an interactive computer graphics application that satisfies the course requirements (see §9).
2. Teach core concepts of orbital motion and gravity through direct manipulation rather than text alone.
3. Serve a wide audience, from elementary school students to university students in astronomy and physics, within a single application.
4. Run on modest hardware, since many students do not own high-end devices.
5. Demonstrate a broad set of computer graphics techniques (see §8).

### Non-goals

- Not a scientific-grade ephemeris or mission-planning tool.
- No multiplayer, accounts, or any network functionality.
- No VR support. The team has no VR hardware to develop or verify it.
- No macOS support.
- No procedural generation of exoplanetary systems in the initial release.

## 3. Target Users

| Persona | Needs | Implication |
|---|---|---|
| **Young learner** (elementary – middle school) | Visual, playful, low reading load | Simple controls, large UI, short plain-language facts, voice-over |
| **High school student** | Concepts behind the visuals (orbits, gravity, seasons) | Guided tours, labeled quantities, simple what-if experiments |
| **University student** (astronomy / physics) | Real units, orbital parameters, reproducible behavior | Precise readouts, selectable integrators, adjustable parameters |

To serve all three without overwhelming any of them, the UI exposes **two depth levels**, switchable at any time:

- **Explorer** — simplified labels and descriptions, everyday units, minimal numbers.
- **Scientist** — full numeric readouts (mass, radius, orbital elements, velocity, energy), scientific units, and advanced simulation controls.

## 4. Purpose and Presentation

| Course requirement | Orrery |
|---|---|
| Purpose (min. 1) | Education, information, entertainment |
| Presentation (min. 1) | 3D |
| Platform (min. 1) | PC (Windows, Linux) |

## 5. Functional Requirements

Priority: **P0** = must have, **P1** = should have, **P2** = stretch. Every requirement below is implemented. The notes record how.

### 5.1 Solar System Simulation

| ID | Requirement | Priority | Status | Notes |
|---|---|---|---|---|
| F-01 | Render the Sun, eight planets, and Earth's Moon with textured spheres and correct relative axial tilt and rotation | P0 | Done | IAU pole and prime-meridian models, checked against NAIF pck00011 and subsolar points |
| F-02 | Simulate orbital motion from real initial conditions, embedded offline | P0 | Done | JPL Keplerian elements in `data/bodies.json` |
| F-03 | Display orbit trails for every body, with adjustable length | P0 | Done | Short, Medium, or Long |
| F-04 | Time control: pause, play, reverse, and adjustable speed multiplier | P0 | Done | Plus jump to the current date in Explore. Dates are shown at the system's current UTC offset, which is applied to every date, so daylight saving changes in the past or future are not reflected |
| F-05 | Distance and body-size scale toggle (compressed view vs. true scale) | P0 | Done | |
| F-06 | Major moons (Galilean moons, Titan) and dwarf planets (Pluto, Ceres) | P1 | Done | Io, Europa, Ganymede, Callisto, Titan, Ceres, Pluto. Positions agree with JPL Horizons to within 0.4° |
| F-07 | Asteroid belt rendered with instancing | P1 | Done | 1,500 to 10,000 instances by preset, Kepler motion solved on the GPU |

### 5.2 Explore Mode

| ID | Requirement | Priority | Status | Notes |
|---|---|---|---|---|
| F-10 | Free-flight camera with smooth acceleration and speed scaled to distance from nearest body | P0 | Done | Keyboard, mouse, and touchpad. See §5.6 |
| F-11 | Select any body to focus the camera on it and open an information panel | P0 | Done | Click, double click, number keys, or Tab cycling |
| F-12 | Information panel adapts to the active depth level (Explorer / Scientist) | P0 | Done | |
| F-13 | Guided tours with step-by-step camera paths and on-screen narration text | P1 | Done | Four tours: Grand Tour, Earth and Moon, Sense of Scale, Moons and Dwarf Planets |
| F-14 | Optional labels, orbit lines, and distance/scale reference markers | P1 | Done | Distance rings up to 40 AU |
| F-15 | Short quiz mode tied to tour content | P2 | Done | One quiz per tour and depth level in `data/quizzes.json`, offered when a tour ends |

### 5.3 Sandbox Mode

| ID | Requirement | Priority | Status | Notes |
|---|---|---|---|---|
| F-20 | Mutual N-body gravity simulation among all active bodies | P0 | Done | |
| F-21 | Add a body (choose mass and radius), set position, and launch it with an initial velocity vector | P0 | Done | Place, then drag to launch |
| F-22 | Remove, edit, or freeze existing bodies | P0 | Done | Mass, radius, and color are editable |
| F-23 | Reset to the default solar system or to a saved preset | P0 | Done | Plus a saved snapshot of the current state |
| F-24 | Collision handling: merge bodies with conservation of momentum | P1 | Done | Swept contact test so fast bodies cannot pass through each other |
| F-25 | Presets (e.g. binary star, extra planet, rogue star flyby) | P1 | Done | Solar system, binary star, extra planet, rogue star flyby |
| F-26 | Selectable integrator (Velocity Verlet / RK4) and time step for Scientist level | P1 | Done | Adaptive or fixed time step. The adaptive Verlet mode sub-steps moon systems (§7.3) |
| F-27 | Live readouts of total energy and angular momentum to illustrate numerical drift | P2 | Done | Physics tab at the Scientist level, with a resettable baseline |
| F-28 | Maximum body count enforced per quality preset | P0 | Done | 32, 64, and 128 bodies |

### 5.4 Application Shell

| ID | Requirement | Priority | Status | Notes |
|---|---|---|---|---|
| F-30 | Main menu: Explore, Sandbox, Settings, Credits, Quit | P0 | Done | |
| F-31 | **Credits screen** listing every team member's name and student ID (NIM), reachable from the main menu | P0 | Done | |
| F-32 | Credits also list third-party assets with author and license, and disclose that narration audio is synthesized | P0 | Done | Driven by `data/credits.json` |
| F-33 | Settings: resolution/fullscreen, audio volumes, key bindings | P1 | Done | Key rebinding refuses conflicting keys |
| F-34 | Pause menu available in both modes | P0 | Done | |
| F-35 | Persist user settings locally in the platform's user data directory | P1 | Done | `user://settings.cfg` |
| F-36 | Graphics quality presets (Low / Medium / High) and a render resolution scale slider | P0 | Done | See §6.2 |

### 5.5 Audio and Narration

| ID | Requirement | Priority | Status | Notes |
|---|---|---|---|---|
| F-40 | Background music with separate volume control and mute | P1 | Done | |
| F-41 | Sound effects for UI interaction and sandbox actions (place, launch, merge, remove) | P1 | Done | |
| F-42 | Voice-over narration for guided tours, played alongside on-screen text | P1 | Done | Every tour step at both depth levels |
| F-43 | Narration text is always displayed, and voice-over can be disabled independently | P0 | Done | |
| F-44 | Separate volume sliders for music, effects, and narration | P1 | Done | Music ducks while narration plays |

Narration is a narrator voice only. No animated character is planned.

### 5.6 Additions Beyond the Original Scope

These features were not in the original requirements and were added during development.

| Feature | Description |
|---|---|
| Mouse and touchpad camera | Left drag or a two-finger swipe orbits the focused body, and a two-finger swipe moves the camera in free flight. Pinch or Ctrl + scroll zooms, and Shift + scroll changes flight speed. Touchpad scrolling is detected automatically, and Settings offers Auto, Orbit, Zoom, or Move for scrolling. Pinch gestures suppress accidental swipes |
| Binding-driven help | The F3 help overlay groups controls by Camera, Bodies, Time, View, and App, shows each key as a key cap, and follows the active key bindings |
| Interface scale | 100%, 115%, or 130% (N-06). The view panel can collapse to give body information more room |
| Interface design system | One theme defines every color, spacing step, and button role: a single blue accent for the primary action, success, warning, and danger colors, separate toggle and segmented styles, the Inter typeface with tabular numbers, Lucide icons, and a visible keyboard focus ring. Text and controls meet WCAG AA contrast. Panels at the bottom of the screen stay clear of the side columns, and the main menu shows a rotating Earth |
| Colorblind-safe orbit palette | Okabe–Ito colors for orbit trails (N-06) |
| Tabbed sandbox panel | Bodies, World, and Physics tabs. Physics is shown only at the Scientist level |
| Presentation tools | Fullscreen toggle (F11), screenshots without the interface (F12), a performance overlay with frame time, draw calls, primitives, and video memory (F4), and a cinematic auto-orbit (F9) that also starts after 20 seconds without input while a body is focused |
| Build and launch scripts | `build.sh` exports both release builds and can install the export templates. `run.sh` launches the project from source on Linux |
| Application identity | An application icon and a boot splash built from the Orrery emblem by `tools/branding`, and version 1.0.0 in the executable metadata and on the credits screen |
| Automated tests | 163 checks in `tests/` drive the real application: input, camera controls, menus, the sandbox panel, quizzes, key bindings, accessibility, sandbox accuracy and speed, eclipses, level of detail, texture tiers, and the time zone display. `tests/run_tests.sh` runs them and restores the user's settings |
| Continuous integration and releases | The CI workflow runs the import and every test on each push to `dev` and each pull request into `main`, which only accepts pull requests that pass it. Pushing a version tag runs the Release workflow, which exports both builds and publishes a GitHub release. `tools/release.sh` sets the version and creates the tag |

## 6. Non-Functional Requirements

| ID | Requirement | Status |
|---|---|---|
| N-01 | **Standalone**: a single exported build per platform that runs without installation, with all assets bundled | Done. Data is embedded in the executable |
| N-02 | **Fully offline**: no network access of any kind at runtime, including speech synthesis | Done |
| N-03 | **Language**: all in-app text, narration, and documentation are in English | Done |
| N-04 | **Cross-platform**: Windows 10/11 (x86_64) and Linux (x86_64, mainstream distributions) with feature parity | Done. Verified on Windows and on the team's Linux laptop |
| N-05 | Simulation remains numerically stable at the maximum supported time speed and body count | Done. Adaptive time step and a per-frame CPU budget |
| N-06 | Accessibility: scalable UI text, colorblind-safe palette for orbit trails, no flashing effects, captions for all narration | Done |
| N-07 | All third-party assets must have a license permitting inclusion and redistribution | Done. See `assets/LICENSES.md` |
| N-08 | **Low-spec support** per the targets below | Partly verified. See §6.1 |

### 6.1 Hardware Targets

| Tier | Specification | Expectation |
|---|---|---|
| **Minimum** | 64-bit dual-core CPU, 4 GB RAM, integrated GPU supporting OpenGL 3.3, 1280×720 | 30 FPS on **Low** preset |
| **Recommended** | Any laptop from roughly the last 5 years with integrated graphics, 8 GB RAM, 1920×1080 | 60 FPS on **Medium** preset |
| **High** | Dedicated GPU | 60 FPS on **High** preset |

Sandbox body caps per preset are Low 32, Medium 64, and High 128.

The team's development machines are high-spec, so the minimum tier cannot be validated directly. It is approximated by forcing the application onto integrated graphics where available, lowering the render scale, and running the Linux build on the Mesa llvmpipe software renderer in WSL, which reached about 39 FPS at Medium. Treat the minimum tier as validated only on a genuinely low-spec device, if one becomes available.

### 6.2 Quality Presets

| Setting | Low | Medium | High |
|---|---|---|---|
| Maximum sphere tessellation (segments × rings) | 40 × 20 | 64 × 32 | 128 × 64 |
| Orbit trail resolution (points) | 48 | 96 | 192 |
| Bloom / glow | Off | On | On |
| Anti-aliasing (MSAA) | Off | 2× | 4× |
| Default render scale | 75% | 100% | 100% |
| Shader detail | Simplified: no clouds, relief, ocean specular, ring shadows, or eclipse shadows | Full | Full |
| Asteroid belt instances | 1,500 | 4,000 | 10,000 |
| Sandbox body cap | 32 | 64 | 128 |
| Texture resolution | 1K, reduced at load time | 2K | 4K for the Sun, Mercury, Venus, Earth, the Moon, Mars, Jupiter, Saturn, and the sky. 2K for the rest |

The render scale can be adjusted from 50% to 100% on every preset. Orbit trail length is a separate preference.

Notes on the presets:

- **Level of detail.** The tessellation in the table is a cap. Each body uses the coarsest sphere whose silhouette error stays under half a pixel on screen (§8), so distant bodies use as few as 16 segments.
- **Textures.** Body and sky textures carry mipmaps and are stored with VRAM compression (S3TC), so a 2K texture needs about 1.4 MB of video memory instead of 11 MB, and a 4K texture about 6 MB instead of 43 MB. The Low preset halves every body texture when it is loaded, which cuts its video memory by another three quarters. The sky keeps its 2K texture on Low because it fills the screen.
- **Shadows** use analytic tests in the shaders instead of shadow maps: Saturn casts a shadow on its rings, the rings cast a shadow on Saturn, and planets and moons cast eclipse shadows on each other. All are disabled on Low.

## 7. Technical Approach

### 7.1 Engine, Renderer, and Language

- Godot 4.7.2 with GDScript. No GDExtension was needed.
- **Compatibility renderer** (OpenGL 3.3) is the single supported renderer. It runs on older integrated GPUs and avoids the Vulkan driver variability seen on Linux. Using one renderer also keeps the test matrix small.
- Custom spatial shaders, instancing, and bloom were confirmed to work on this renderer in week 1.
- On Linux the project prefers the Wayland display server. Godot falls back to X11 when Wayland is not available.

### 7.2 Numerical Precision

Godot's `Vector3` is single-precision by default, which causes jitter at solar-system distances. Strategy:

- Simulation state is held in double-precision values and kept independent from scene nodes.
- Render positions are derived by scaling and re-centering relative to the camera (floating origin).
- Distant objects are drawn on a depth shell, which keeps the near and far clip planes usable at solar-system scale.
- Simulation and rendering are separate modules; the renderer only reads simulation state.

### 7.3 Simulation

Two models share the same body data:

- **Explore mode** propagates every body analytically along its Keplerian orbit. This is exact at any time speed, supports reversing and jumping in time at no cost, and keeps cost linear in the number of bodies.
  - Planets use the NASA JPL Keplerian elements and rates, valid 1800 AD – 2050 AD.
  - The Moon uses the main periodic terms of Meeus' lunar theory (Astronomical Algorithms, chapter 47), converted from the ecliptic of date to the J2000 ecliptic. Lunar and solar eclipses from 2024 to 2026 occur within 2 minutes of their published times.
  - The Galilean moons use JPL satellite mean elements, rotated from their Laplace plane into the ecliptic. Titan uses JPL Horizons elements in Saturn's equator frame, because the published node convention for Saturn's moons did not match Horizons.
  - Ceres and Pluto use JPL Small-Body Database orbits.
- **Sandbox mode** integrates mutual gravity numerically. Bodies start from state vectors derived from the same orbital elements.
  - Fixed-step simulation decoupled from frame rate, with sub-stepping at high time multipliers.
  - Default integrator: Velocity Verlet. RK4 available as an option. Both use Plummer softening.
  - With the adaptive Verlet step, moon systems are sub-stepped with multiple time stepping (r-RESPA): pairs whose dynamical time is far shorter than the rest, grouped into subsystems such as Jupiter and its moons, take many inner steps while all other forces act as half kicks at the outer step. The scheme stays symplectic. With every moon present it runs about 150 simulated days per second within the 5 ms budget, against about 10 before, with smaller position errors than single-step Verlet and a relative energy drift near 1e-9 after 30 days.
  - Pairwise gravity is O(n²), which is why body count is capped per quality preset.
  - The time step adapts to the shortest dynamical time among body pairs, so close encounters and tight orbits stay stable.
  - Each frame has a fixed CPU budget for simulation. When the requested time speed cannot be met within the budget, the effective speed drops gracefully and the HUD reports that the simulation speed is limited. This keeps the application responsive on low-spec devices (N-05, N-08).
  - Planets with moons start split about their barycenter, because the published planet elements describe the barycenter of each system.
  - Colliding bodies merge with conserved mass and momentum, using a swept contact test.
  - Orbit trails and launch references use the Hill sphere to choose the body each object orbits.
  - Total energy and angular momentum are computed in SI units for the conservation readouts (F-27).
- Rendering uses a single linear scale of 1 render unit per 1,000 km in true scale, with a minimum angular size so small bodies remain visible. The compressed view scales distances and sizes so every body stays visible, and places moons by their parent's radius.

All orbital and physical data is embedded in `data/bodies.json`, so no network access is needed.

### 7.4 Cross-Platform Notes

- Windows and Linux builds are exported from the same project using Godot export presets, either from the editor or with `build.sh`.
- Linux filesystems are case-sensitive. All resource paths must match file names exactly and use lowercase `snake_case`.
- User settings, snapshots, and screenshots are stored under `user://` only. No hard-coded absolute paths.
- Each release is smoke-tested on both platforms before delivery.

### 7.5 Audio Pipeline

- Narration is **pre-generated at development time** with a free, open-source, locally run text-to-speech engine, then bundled as compressed audio files. Nothing is synthesized at runtime, so the application stays fully offline and sounds identical on every platform.
- Engine: **Kokoro-82M** through `kokoro-onnx`. The model weights are Apache-2.0, the wrapper is MIT, and the model was trained on permissively licensed or non-copyrighted audio. It runs on CPU without internet once the model files are downloaded.
- Voice: `af_bella`, the highest-graded American English voice in the published voice list at the time of selection. The voice can be changed with a command-line argument.
- Narration scripts come from `godot/data/narration.json` (standalone clips) and from every guided-tour step in `godot/data/tours.json`, at both depth levels. Audio files are written to `godot/assets/audio/narration/` as OGG Vorbis, named after script IDs (`<tour>_<step>_<explorer|scientist>` for tours). A manifest of content fingerprints makes regeneration incremental and reproducible. Units and ratios such as "AU", "km", "W/m2", "K", and "3:2" are spelled out for speech only; captions keep the original text.
- Generation is run with `uv run generate_narration.py` from `tools/tts/`. Model files and the virtual environment are not committed.
- Music and effects are generated by the team with procedural synthesis in `tools/audio/` (`uv run generate_audio.py`). The generator uses fixed seeds, so its output is reproducible. It uses no third-party samples, so there is nothing to license.

### 7.6 Module Layout

```
orrery/
├── assets/          License register for every bundled third-party asset
├── docs/            Product requirements
├── godot/           Godot project
│   ├── core/        Simulation, orbit models, clock, catalogs, settings, input, audio manager
│   ├── data/        Orbital data, body info, tours, quizzes, presets, narration scripts, credits
│   ├── modes/       Main menu, Explore, Sandbox, and the shared scene base
│   ├── render/      Renderers, camera, trails, asteroid belt, reference rings, shaders
│   ├── ui/          Theme, HUD, panels, menus, credits
│   └── assets/      Runtime textures, music, effects, and narration bundled into the build
├── tools/           Offline generators for narration, audio, and textures
├── build.sh         Release export helper
└── run.sh           Linux launcher
```

## 8. Computer Graphics Techniques (Report Material)

| Technique | Where it is used | Status |
|---|---|---|
| Texture mapping | Every body surface, rings, sky | Done |
| Specular map with Blinn-Phong highlight and Fresnel term | Earth's oceans | Done |
| Bump mapping from albedo luminance | Rocky and icy bodies, with a footprint-aware step to avoid shimmer | Done |
| Normal maps from dedicated height data | The Moon, Mars, and Earth, from LRO LOLA, MGS MOLA, and NOAA ETOPO5 elevation. Slopes are measured on the sphere and stored in tangent space; other bodies use bump mapping from the albedo | Done |
| Mipmapping and texture resolution tiers | Body and sky textures: 1K on Low, 2K on Medium, 4K on High | Done |
| Lighting model (point light from the Sun, emissive Sun) | Day/night terminator with city lights, shading | Done |
| Custom shaders (spatial shader) | Atmosphere scattering, clouds, Saturn's rings, Sun surface and halo | Done |
| Analytic shadows | Planet shadow on the rings, ring shadow on the planet | Done |
| Eclipse shadows from an extended light source | Moons on planets and planets on moons, such as Io's shadow on Jupiter and the red Moon of a lunar eclipse. The Sun is treated as a disk, so the covered fraction of the disk gives a physically sized umbra and penumbra. Up to four occluders per body are chosen on the CPU each frame | Done |
| Alpha blending and transparency sorting | Rings, atmospheres, clouds, trails | Done |
| Post-processing (bloom/glow, tone mapping) | Sun glow, overall look | Done |
| Skybox / environment mapping | Starfield and Milky Way panorama | Done |
| GPU instancing with vertex-shader animation | Asteroid belt, with Kepler's equation solved per instance on the GPU | Done |
| Dynamic mesh generation | Orbit trails, sandbox trails, distance rings | Done |
| Camera systems and coordinate transforms | Floating origin, depth shell, focus-and-follow camera, smooth fly-to | Done |
| Level of detail | Screen-space error: each body uses the coarsest sphere whose silhouette error, about r·π²/(2n²) pixels for n segments, stays under half a pixel. Meshes are shared between bodies | Done |
| Quality scaling | Preset-driven shader, geometry, and instance counts | Done |

## 9. Course Deliverable Checklist

- [x] Interactive computer graphics application
- [x] Purpose: education, information, entertainment
- [x] Presentation: 3D
- [x] Platform: PC (Windows, Linux)
- [x] Credits screen with names and student IDs, accessible to the user
- [x] Standalone, no internet connection required
- [x] Technologies documented (§8). The course does not require a written report

## 10. Assets and Licensing

- Project source code: MIT license (`LICENSE`). Third-party assets keep their own licenses.
- Surface textures: Solar System Scope (CC BY 4.0) for the Sun, planets, Moon, Earth's specular map, rings, and sky. USGS Astrogeology global mosaics from NASA missions (public domain) for the Galilean moons, Titan, Ceres, and Pluto, prepared by `tools/textures`.
- Music and sound effects: generated by the team (§7.5), so no third-party license applies.
- Narration: Kokoro-82M (Apache-2.0) with the `af_bella` voice. The synthesized voice is disclosed in the credits.
- Typeface and icons: Inter (SIL Open Font License 1.1) and Lucide icons (ISC). Both license texts are bundled with the build.
- Every asset is recorded in `assets/LICENSES.md` with source URL, author, license, and date retrieved.
- All records are surfaced in the in-app credits (F-32).

## 11. Timeline

The project runs for a fixed **4 weeks**. The plan is expressed in weeks, not calendar dates.

| Week | Focus | Scope | Exit criteria | Status |
|---|---|---|---|---|
| **1** | Foundation and core simulation | Project setup, Compatibility renderer validation, precision strategy, full planet set, orbit trails, time controls, scale toggle, quality preset framework, TTS engine and voice selection, first Linux export | F-01 to F-05 and F-36 complete. Stable orbits with no jitter. Bloom and a custom shader confirmed on Compatibility. Linux build launches | Done |
| **2** | Explore mode and sandbox foundation | Body selection, info panels, depth levels, labels, tour framework with text narration, N-body engine, add / launch / remove bodies | F-10 to F-14 and F-20 to F-23 complete | Done |
| **3** | Sandbox completion, visuals, audio base | Collisions, presets, body caps, integrator choice, atmosphere and ring shaders, skybox, asteroid belt, audio manager, music, sound effects | F-24 to F-26, F-28, F-40, F-41, F-44 complete. Visual targets met on all presets | Done |
| **4** | Voice-over, shell, and release | Voice-over generation and integration, main menu, settings, credits, final exports for Windows and Linux, offline test, low-spec approximation test, final report | All P0 items done. P1 items done where schedule allows. Builds verified on Windows and Linux | Done. No written report is required |

Technique notes, screenshots, and asset records were captured as each feature landed, not left to week 4.

### 11.1 Scope Cut Order

If the schedule slips, features are cut in this order, first to last. P0 items are never cut.

1. F-15 Quiz mode
2. F-27 Energy and angular momentum readouts
3. F-07 Asteroid belt
4. F-06 Additional moons and dwarf planets
5. F-26 Selectable integrator
6. F-25 Sandbox presets
7. F-42 Voice-over (text narration remains)
8. F-24 Collision merging

No cut was needed. Every P0, P1, and P2 requirement shipped.

## 12. Risks

| Risk | Impact | Mitigation | Outcome |
|---|---|---|---|
| Floating-point jitter at large distances | Visual artifacts | Double-precision simulation and floating origin from M0 | Resolved |
| N-body instability at high time speed | Wrong or exploding orbits | Sub-stepping, Verlet, energy monitoring | Resolved with an adaptive time step, multiple time stepping for moon systems, and a CPU budget |
| Scope too large for 4 weeks | Incomplete product | Strict P0/P1/P2 prioritization, the cut order in §11.1, and Sandbox built on the week 1 core | Resolved |
| Mixed Godot versions in the team | Project corruption | Everyone pins Godot 4.7.2 | Resolved |
| Linux regressions go unnoticed | Broken Linux release | Export a Linux build in week 1 and re-test on the team's Linux laptop at the end of every week | Resolved. Tested in WSL and on the team's Linux laptop |
| Linux display server differences | Touchpad gestures or window behavior differ between X11 and Wayland | Prefer Wayland with X11 fallback, and scale touchpad deltas per display server | Resolved. Tested on the team's Linux laptop |
| Compatibility renderer lacks a needed feature | Visual targets not met | Validate shaders and post-processing in week 1 before committing to designs | Resolved |
| Low-spec target cannot be verified on real hardware | Unknown performance on weak devices | Preset system from week 1, and approximate low-spec conditions as described in §6.1 | Open |
| TTS voice license forbids redistribution | Cannot ship narration | Verify license before generating; record in `LICENSES.md` | Resolved |
| Build size grows from textures and audio | Hard to distribute | Compressed textures and OGG audio, track size each milestone | Resolved |
| Asset license issues | Disqualification risk | Track every asset in `LICENSES.md` from the first import | Resolved |

## 13. Engineering Conventions

- Source code contains no explanatory comments. Clarity comes from naming and structure.
- A comment is permitted only when it is professional and necessary, such as a non-obvious constraint, a units note, or a reference to a source of an algorithm or constant.
- Comments never narrate what the code does line by line.
- All identifiers, UI strings, commit messages, and documentation are in English.
- File and folder names inside the Godot project use lowercase `snake_case`.
- Work happens on the `dev` branch and reaches `main` through a pull request.

## 14. Open Questions

1. ~~Music and sound effect sources.~~ Resolved: team-generated procedural audio (§7.5).
2. Demo format required by the course. The course does not require a written report.

## 15. Known Limitations and Remaining Work

| Item | Type |
|---|---|
| Test on a genuinely low-spec device, if one becomes available | Verification |
| Re-test the 1.0.0 build on the team's Linux laptop, including the new interface, fonts, and icons | Verification |
| Mercury, the moons of Jupiter and Saturn, Ceres, and Pluto keep bump mapping from the albedo, because no complete global elevation model of them is small enough to bundle | Limitation |

## Appendix A — Credits

**Team Sepak Takraw**

| Name | Student ID (NIM) | Role |
|---|---|---|
| Muhamad Fahry Pratama Putra | 245150207111046 | Team Lead |
| Muhammad Atha Tsaqif | 245150201111002 | Member |
| Muhammad Hafizh Faiqunnabil | 245150201111031 | Member |
| Alexander William Sinjaya | 245150200111044 | Member |
