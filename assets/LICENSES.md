# Asset License Register

Every third-party asset bundled with Orrery is recorded here and surfaced in the in-app credits.

| Asset | Type | Author | Source URL | License | Date Retrieved | Notes |
|---|---|---|---|---|---|---|
| Sun, Mercury, Venus surface, Earth day / night / clouds / specular, Moon, Mars, Jupiter, Saturn, Uranus, Neptune textures (2K) | Texture | Solar System Scope | https://www.solarsystemscope.com/textures/ | CC BY 4.0 | 2026-11-08 | Derived from NASA elevation and imagery data. Attribution required |
| Saturn ring alpha texture (2K) | Texture | Solar System Scope | https://www.solarsystemscope.com/textures/ | CC BY 4.0 | 2026-11-08 | Attribution required |
| Stars and Milky Way panorama (2K) | Texture | Solar System Scope | https://www.solarsystemscope.com/textures/ | CC BY 4.0 | 2026-11-08 | Attribution required |
| Sun, Mercury, Venus surface, Earth day / night / clouds, Moon, Mars, Jupiter, Saturn, and Stars and Milky Way textures (4K, High preset) | Texture | Solar System Scope | https://www.solarsystemscope.com/textures/ | CC BY 4.0 | 2026-11-19 | Downsampled from the 8K maps to 4096 × 2048 by `tools/textures/prepare_textures.py --high`. Attribution required |
| Io, Europa, Ganymede, Callisto global mosaics (Voyager and Galileo SSI) | Texture source | USGS Astrogeology Science Center, NASA/JPL | https://planetarymaps.usgs.gov/mosaic/ | Public domain | 2026-11-12 | Downsampled to 2K and recentered on longitude 0 by `tools/textures/prepare_textures.py`. Europa and Callisto are tinted from grayscale; gaps are filled with blurred surroundings |
| Titan global mosaic (Cassini ISS, PIA19658) | Texture source | USGS Astrogeology Science Center, NASA/JPL-Caltech/Space Science Institute | https://planetarymaps.usgs.gov/mosaic/ | Public domain | 2026-11-12 | Tinted orange with reduced contrast to suggest the haze seen in visible light |
| Ceres global mosaic (Dawn FC, DLR) | Texture source | USGS Astrogeology Science Center, NASA/JPL-Caltech/UCLA/MPS/DLR/IDA | https://planetarymaps.usgs.gov/mosaic/ | Public domain (NASA mission data) | 2026-11-12 | Tinted from grayscale |
| Pluto global mosaic (New Horizons LORRI and MVIC, July 2017) | Texture source | USGS Astrogeology Science Center, NASA/JHUAPL/SwRI | https://planetarymaps.usgs.gov/mosaic/ | Public domain | 2026-11-12 | Tinted from grayscale. The unimaged southern hemisphere is filled with an even tone |
| Inter typeface 4.1 (Regular, Medium, SemiBold) | Font | Rasmus Andersson and The Inter Project Authors | https://github.com/rsms/inter | SIL Open Font License 1.1 | 2026-11-20 | License text bundled as `godot/assets/fonts/OFL.txt` |
| Lucide icons 0.460.0 (32 icons) | Icon | Lucide Contributors, portions by Cole Bemis (Feather, MIT) | https://lucide.dev | ISC | 2026-11-20 | Stroke color set to white so the theme can tint them. License text bundled as `godot/assets/icons/LICENSE.txt` |
| Orrery emblem (`assets/branding/orrery_emblem.jpg`) | Icon and splash source | Orrery team | Provided by the team | MIT, same as the project | 2026-11-20 | Converted to `godot/icon.png`, `godot/icon.ico`, and `godot/assets/branding/splash.png` by `tools/branding/prepare_branding.py` |
| Moon elevation (LRO LOLA LDEM_16) | Normal map source | NASA/GSFC, LRO Lunar Orbiter Laser Altimeter team | https://pds-geosciences.wustl.edu/missions/lro/lola.htm | Public domain | 2026-11-20 | Converted to `moon_normal.png` by `tools/textures/prepare_textures.py --normals` |
| Mars elevation (MGS MOLA MEGDR, 16 pixels per degree) | Normal map source | NASA/JPL/GSFC, MGS Mars Orbiter Laser Altimeter team | https://pds-geosciences.wustl.edu/missions/mgs/megdr.html | Public domain | 2026-11-20 | Converted to `mars_normal.png` |
| Earth elevation (ETOPO5, 5 arc-minute) | Normal map source | NOAA National Geophysical Data Center | https://www.ngdc.noaa.gov/mgg/global/etopo5.HTML | Public domain | 2026-11-20 | Land relief only, converted to `earth_normal.png` |

## Generated Assets

| Asset | Tool | Model and License | Voice | Notes |
|---|---|---|---|---|
| Narration voice-over (`godot/assets/audio/narration/`) | kokoro-onnx (MIT) | Kokoro-82M v1.0, Apache-2.0, https://huggingface.co/hexgrad/Kokoro-82M | `af_bella` | Synthetic speech generated offline during development. The in-app credits must state that the narration is synthesized |
| Background music (`godot/assets/audio/music/space_ambient.ogg`) | `tools/audio/generate_audio.py` (procedural synthesis with NumPy) | MIT, same as the project. No third-party samples or models | n/a | Generated offline during development by the Orrery team |
| Sound effects click, place, launch, merge, remove (`godot/assets/audio/effects/`) | `tools/audio/generate_audio.py` (procedural synthesis with NumPy) | MIT, same as the project. No third-party samples or models | n/a | Generated offline during development by the Orrery team |

## Data Sources

| Data | Source | Notes |
|---|---|---|
| Planetary Keplerian elements and rates (1800 AD – 2050 AD) | NASA JPL Solar System Dynamics, "Keplerian Elements for Approximate Positions of the Major Planets", https://ssd.jpl.nasa.gov/planets/approx_pos.html | Public domain. The Earth entry is the Earth–Moon barycenter |
| Physical parameters and rotation poles | NASA Planetary Fact Sheets and IAU Working Group on Cartographic Coordinates and Rotational Elements | Public domain |
| Lunar mean orbital elements | Meeus, Astronomical Algorithms, mean elements of the Moon's orbit | Reference values |
| Galilean moon mean orbital elements | NASA JPL Solar System Dynamics, "Planetary Satellite Mean Elements", https://ssd.jpl.nasa.gov/sats/elem/ | Public domain. Referred to the local Laplace planes, epoch J2000 |
| Titan orbital elements | NASA JPL Horizons, osculating elements relative to Saturn's equator at J2000, https://ssd.jpl.nasa.gov/horizons/ | Public domain |
| Ceres and Pluto orbital elements and physical parameters | NASA JPL Small-Body Database, https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html | Public domain. Osculating heliocentric elements propagated as fixed Keplerian orbits |
