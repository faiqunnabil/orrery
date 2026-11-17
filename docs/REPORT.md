# Orrery — Technical & Computer Graphics Report

**Course:** Computer Graphics (Final Project)
**Team:** Sepak Takraw
- Muhamad Fahry Pratama Putra (`245150207111046`) — Team Lead
- Muhammad Atha Tsaqif (`245150201111002`)
- Muhammad Hafizh Faiqunnabil (`245150201111031`)
- Alexander William Sinjaya (`245150200111044`)

**Engine & Target:** Godot 4.7.2 (GDScript, GL Compatibility / OpenGL 3.3), Windows & Linux (64-bit, offline)

---

## 1. Executive Summary

**Orrery** is an interactive 3D solar system explorer and gravitational N-body simulator built to serve learners across elementary, secondary, and university levels through switchable **Explorer** and **Scientist** depth modes. All astronomical catalogs, textures, synthesized voice-over narrations, procedural music, and sound effects are bundled offline into standalone executables.

From a computer graphics perspective, the primary engineering challenge is rendering scenes spanning astronomical scales—from planetary craters and ocean glints at thousands of kilometers to outer-planet orbits billions of kilometers away—using single-precision GPU hardware without depth-buffer fighting or vertex jitter, while running smoothly on modest integrated GPUs under the **GL Compatibility** (OpenGL 3.3) renderer.

---

## 2. System Architecture

The codebase separates double-precision physics and astronomical models from rendering and user interface presentation:

| Layer | Directory | Responsibility |
|---|---|---|
| Core simulation & state | `godot/core/` | Double-precision `DVec3`, Keplerian solver, N-body integrators, catalogs, persistent settings (`Quality`, `Preferences`, `InputBindings`, `Audio`, `ScreenCapture`) |
| Rendering pipeline | `godot/render/` | Scale mapping, floating-origin renderers, distance-shell projection, `BodyVisual` shells, `CameraRig`, `OrbitTrail`, `SandboxTrail`, `AsteroidBelt`, `ReferenceRings`, GLSL spatial shaders |
| Application modes | `godot/modes/` | `MainMenu`, shared `SpaceScene`, `ExploreMode` (tours & quizzes), `SandboxMode` (N-body placement & launch) |
| User interface | `godot/ui/` | Programmatic `OrreryTheme`, `Hud` (controls, diagnostics overlay, toasts), `InfoPanel`, `SandboxPanel`, `SettingsPanel`, `TourPanel`, `QuizPanel`, `CreditsPanel` |
| Data & offline tools | `godot/data/`, `tools/` | JSON catalogs (`bodies.json`, `tours.json`, `quizzes.json`, `credits.json`) and reproducible `uv` generators for narration (`tools/tts`), music/SFX (`tools/audio`), and USGS planetary mosaics (`tools/textures`) |

---

## 3. Coordinate Transforms, Floating Origin & Depth Shell

Standard 32-bit `float` coordinates lose sub-meter precision at planetary distances, producing visible camera and mesh jitter. Orrery addresses this in three stages:

### 3.1 Astronomical-to-Render Basis Transform
Astronomical coordinates are computed in the J2000 ecliptic frame in kilometers (`DVec3`, 64-bit IEEE floats) and mapped into Godot's Y-up right-handed render frame via `ScaleMapper.offset_to_render` (`godot/render/scale_mapper.gd`) and `BodyDefinition._render_axis` (`godot/core/body_definition.gd`):
$$(x, y, z)_{\text{ecliptic}} \mapsto (x, z, -y)_{\text{render}}$$

### 3.2 Dual Scale Mapping
`ScaleMapper` provides two runtime-switchable mappings:
- **True Scale (`TRUE_SCALE`)**: Linear mapping of `1` render unit per `1,000 km` (`TRUE_SCALE_UNIT_KM = 1000.0`).
- **Compressed Scale (`COMPRESSED`)**: Keeps all bodies legible simultaneously:
  - Body radius: $R_{\text{render}} = \left(\frac{R_{\text{km}}}{6371.0}\right)^{0.5}$
  - Heliocentric orbit distance: $d_{\text{render}} = 10.0 + 18.0 \cdot d_{\text{AU}}^{0.55}$
  - Satellite orbit distance: $d_{\text{render}} = R_{\text{parent}} \cdot \left(1.4 + 1.8 \cdot \log_{10}\!\left(\max\left(\frac{d_{\text{km}}}{R_{\text{parent,km}}}, 1\right)\right)\right)$

### 3.3 Floating Origin & Perspective Depth Shell
In `SolarSystemRenderer.update` (`godot/render/solar_system_renderer.gd`) and `SandboxRenderer.update` (`godot/render/sandbox_renderer.gd`), every body position is subtracted from the 64-bit `camera_position` **before** converting to single-precision `Vector3`, anchoring the scene origin at the camera (`(0, 0, 0)`).

To bound the Z-buffer depth range across extreme distance ratios:
- `near_plane = clamp(nearest_surface_distance * 0.05, 0.001, 1.0e6)`
- `shell = near_plane * 1.0e5` (`MAX_DEPTH_RATIO = 1.0e5`)
- `far_plane = shell * 1.5` (`FAR_MARGIN = 1.5`)
- Any object farther than `shell` is pulled onto the spherical shell with shrink factor $s = \min(1.0, \text{shell} / d)$, scaling both its relative position and radius by $s$ so its subtended solid angle remains unchanged while staying cleanly inside `[near_plane, far_plane]`.

---

## 4. Custom Shaders & Lighting Pipeline

All shaders target Godot's **GL Compatibility** (`shader_type spatial`, OpenGL 3.3) so visuals are consistent across integrated and dedicated GPUs.

### 4.1 Planetary Surfaces (`godot/render/shaders/body_surface.gdshader`)
Uses `render_mode unshaded, cull_back` with an analytic directional Sun vector computed per frame relative to each planet:
- **Day/Night Terminator & City Lights**: Smooth terminator transition via `smoothstep(-0.1, 0.1, dot(N, L))`, combining Lambertian diffuse illumination (`0.25 + 0.75 * lambert`) on the lit hemisphere with ambient (`0.04`) and additive `night_texture` emission (`earth_nightmap.jpg`, strength `1.3`) on the night hemisphere.
- **Ocean Specular Glint (Blinn-Phong + Schlick Fresnel)**: For Earth (`earth_specular.jpg`), a dual-lobe specular highlight (`shininess = 60.0` glint + `sheen_shininess = 6.0` broad sheen) modulated by `fresnel = 0.02 + 0.98 * (1 - max(dot(V, H), 0))^5` produces realistic sunlight reflections across oceans while keeping continents matte.
- **Screen-Space Footprint-Adaptive Bump Mapping**: `relief_normal()` derives surface slopes from the albedo luminance height field (`0.299R + 0.587G + 0.114B`) across tangent and binormal vectors. Using `fwidth(uv)` widens finite-difference sampling automatically with camera distance (clamped to `max_relief_footprint = 8.0`) to prevent aliasing/shimmering on distant worlds, with a zero-length guard near sphere poles. Applied to cratered/rocky worlds (Mercury, Moon, Mars, Ceres, Pluto, Io, Europa, Ganymede, Callisto).
- **Analytic Ring Shadows on Planet**: `ring_transmittance()` intersects the ray from each surface fragment toward the Sun with Saturn's equatorial ring plane (`MODEL_MATRIX[1].xyz`) and attenuates direct sunlight by `1.0 - alpha * 0.9` using `saturn_ring.png`.

### 4.2 Rings, Atmospheres & Clouds
- **Planetary Rings (`planet_ring.gdshader`)**: Anulus mesh (`RING_SEGMENTS = 128`) with `cull_disabled, depth_draw_never, blend_mix`. Evaluates analytic sphere-shadow occlusion cast by Saturn onto its rings (`along > 0.0 && dot(to_center, to_center) - along^2 < R^2`) and attenuates transmission (`back_light = 0.65`) when viewed from the unlit face of the ring plane.
- **Atmospheric Scattering (`atmosphere.gdshader`)**: Concentric outer shell (`1.0 + thickness`, `blend_add`) integrating analytic ray-sphere optical path length for both exterior and interior camera positions, raised to `density_falloff = 1.6`, combined with twilight wrapping and terminator forward scattering (`pow(max(dot(ray, light), 0.0), 8.0)`).
- **Cloud Layer (`cloud_layer.gdshader`)**: Concentric alpha-blended sphere shell at `altitude = 0.006` for Earth with reduced night-side opacity (`0.35`).

### 4.3 Solar Emission, Halo & Post-Processing
- **Solar Photosphere (`sun_surface.gdshader`)**: Scrolls solar texture UVs (`scroll_speed = 0.004`), applies physical limb darkening (`mix(0.45, 1.0, pow(dot(N, V), 0.5))`), and outputs HDR intensities (`emission_strength = 1.5`) that trigger the environment's HDR glow/bloom (`glow_intensity = 0.8`, `glow_bloom = 0.4`, `glow_hdr_threshold = 0.3`).
- **Corona Halo (`sun_halo.gdshader`)**: Camera-facing billboard quad (`INV_VIEW_MATRIX` rotation override in vertex shader) with additive radial falloff (`pow(radial, 2.4)`).

---

## 5. GPU Instancing & Dynamic Geometry

### 5.1 GPU-Driven Asteroid Belt (`godot/render/asteroid_belt.gd`, `asteroid_belt.gdshader`)
Rather than updating thousands of CPU transform matrices every frame, `AsteroidBelt` populates a single `MultiMeshInstance3D` once with `1,500` (Low), `4,000` (Medium), or `10,000` (High) asteroids:
- **Kirkwood Gaps**: Rejection sampling depletes orbital semi-major axes around Jovian resonances (`2.502, 2.825, 2.958, 3.279 AU`).
- **GPU Kepler Solver**: Periods are quantized to integer harmonics of `PHASE_PERIOD_DAYS = 8388608.0`, and simulation phase is split into `phase_coarse` + `phase_fine` uniforms so 32-bit GPU floats retain smooth sub-frame motion. Each vertex invocation solves 4 Newton-Raphson iterations of Kepler's equation, transforms into either `COMPRESSED` or `TRUE_SCALE` heliocentric space, clamps minimum angular radius (`0.0011` rad) for visibility, applies depth-shell shrinking, and computes per-vertex Lambertian shading—rendering all rocks in **1 draw call**.

### 5.2 Orbit Trails (`OrbitTrail` & `SandboxTrail`)
- `OrbitTrail` (`godot/render/orbit_trail.gd`) renders `ImmediateMesh` `PRIMITIVE_LINE_STRIP` curves with vertex-alpha fade (`0.95` at body head down to `0.0`).
- Uses a fixed-size circular cache (`_slot_indices`, `_slot_points`) of Keplerian samples so only newly stepped segments are recomputed as simulation time advances.
- `SandboxTrail` (`godot/render/sandbox_trail.gd`) records trajectories relative to each body's dynamic Hill-sphere parent.

---

## 6. Orbital & N-Body Simulation

### 6.1 Analytic Ephemerides (Explore Mode)
- `Kepler.ecliptic_position` (`godot/core/kepler.gd`) solves $M = E - e \sin E$ via Newton-Raphson (`MAX_ITERATIONS = 16`, `TOLERANCE = 1e-12`).
- Planetary elements & century rates come from NASA JPL Solar System Dynamics (`1800 AD – 2050 AD`); Earth–Moon uses Meeus lunar mean elements around the barycenter; Galilean moons and Titan rotate from local Laplace/equatorial frames into the ecliptic; Pluto and Ceres use JPL SBDB osculating elements.
- Body axial poles and spins follow IAU Cartographic Coordinates (`BodyDefinition.orientation`).

### 6.2 Numerical N-Body Gravity (Sandbox Mode)
- `NBodySimulation` (`godot/core/nbody_simulation.gd`) stores `positions`, `velocities`, `gm`, and `radii` in flat `PackedFloat64Array` buffers with Plummer softening ($\epsilon = 0.5 (r_i + r_j)$).
- Supports **Velocity Verlet** (second-order symplectic integrator with strong long-term energy conservation) and **RK4** (fourth-order Runge-Kutta).
- Adaptive timestepping scales with the shortest pairwise dynamical time ($\Delta t = 0.02 \sqrt{r^3 / G(m_i + m_j)}$, clamped to `[1 s, 604800 s]`), enforces a `5,000 µs` per-frame CPU budget (`TIME_BUDGET_USEC`) so UI stays responsive on low-end CPUs, detects swept spherical collisions with momentum-conserving merges, and computes live total energy & angular momentum drift in Scientist mode.

---

## 7. Quality Scaling, Accessibility & Presentation Tools

### 7.1 Quality Tiers (`godot/core/quality_settings.gd`)
| Setting | Low | Medium (Default) | High |
|---|---|---|---|
| Sphere segments × rings | `40 × 20` | `64 × 32` | `128 × 64` |
| Trail points | `48` | `96` | `192` |
| Render scale | `0.75` (`75%`) | `1.0` (`100%`) | `1.0` (`100%`) |
| MSAA 3D | Disabled | `2X` | `4X` |
| HDR Bloom / Glow | Off | On | On |
| `full_detail` shaders & clouds | Off | On | On |
| Asteroid instances | `1,500` | `4,000` | `10,000` |
| Sandbox body cap | `32` | `64` | `128` |

### 7.2 Accessibility & Presentation Controls
- **Accessibility (`Preferences`)**: Explorer vs. Scientist depth toggle (`M`), Okabe–Ito colorblind-safe orbit palette, scalable UI (`100%`, `115%`, `130%`), full keyboard rebinding with conflict detection (`InputBindings`), and mandatory on-screen captions for synthesized Kokoro-82M narration (`Tools/tts`).
- **Demo & Inspection Controls**:
  - `F4` (`Hud.refresh_diagnostics`): Real-time FPS, frame/CPU time (ms), draw calls, primitives, VRAM usage, and active body/asteroid counts.
  - `F9` (`CameraRig.toggle_auto_orbit`): Cinematic auto-orbit (plus automatic activation after `20 s` idle when anchored).
  - `F11`: Instant fullscreen toggle persisted across sessions.
  - `F12` (`ScreenCapture`): Temporarily hides HUD for one frame (`RenderingServer.frame_post_draw`) and saves clean PNG captures to `screenshots/` (or `user://screenshots/` in exported builds).

---

## 8. Assets & Licensing Summary

Every third-party and generated asset is cataloged in [`assets/LICENSES.md`](../assets/LICENSES.md) and surfaced in the in-app Credits screen (`godot/data/credits.json`):
- **Planetary, Solar, Ring & Skybox Textures**: Solar System Scope (CC BY 4.0, derived from NASA imagery & elevation data).
- **Galilean Moons, Titan, Ceres & Pluto Mosaics**: USGS Astrogeology / NASA JPL / JHUAPL / DLR (Public Domain), downsampled & recentered via [`tools/textures`](../tools/textures).
- **Narration Audio**: Offline Kokoro-82M (`af_bella`, Apache-2.0) via `kokoro-onnx` (MIT) in [`tools/tts`](../tools/tts).
- **Background Music & SFX**: Procedurally synthesized by Team Sepak Takraw with NumPy in [`tools/audio`](../tools/audio).
