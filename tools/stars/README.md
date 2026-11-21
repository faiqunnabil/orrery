# Stars

Builds `godot/data/stars.json`, the naked-eye star catalog and constellation figures drawn behind the solar system.

## Requirements

- [uv](https://docs.astral.sh/uv/). The script uses only the Python standard library.

## Usage

From this directory:

```
uv run prepare_stars.py              # stars brighter than magnitude 6.5
uv run prepare_stars.py --limit 5.5  # a smaller catalog
```

The sources are downloaded once into `cache/` from pinned commits and checked against their SHA-256 digests:

| Source | Use | License |
|---|---|---|
| [HYG Database](https://github.com/astronexus/HYG-Database) v4.1 by David Nash | Right ascension, declination, visual magnitude, and B−V color index of each star | CC BY-SA 4.0 |
| [Stellarium](https://github.com/Stellarium/stellarium/tree/master/skycultures/modern) modern sky culture | Constellation lines as sequences of Hipparcos numbers | CC BY-SA 4.0 |

The output keeps J2000 equatorial coordinates in degrees, sorted from brightest to faintest, and turns each constellation line into a list of coordinates so the game does not need the Hipparcos numbers. Because it is derived from both sources, `stars.json` is shared under CC BY-SA 4.0.

In the game, `render/star_field.gd` converts each star to the ecliptic render frame, sizes and brightens it from its magnitude, and colors it from its B−V index through an estimated temperature. The Milky Way panorama is sampled in galactic coordinates by `render/shaders/galactic_sky.gdshader`, so its stars line up with the catalog.
