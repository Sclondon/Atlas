# Atlas

A Godot 4.7 (GL Compatibility) toy, the Atlas cabinet on the Scareathon arcade, built phone-first. The Earth
hangs in space: Salmon Run 2's globe (NASA's Blue Marble under drifting cloud and hurricanes,
in big pixels) with Close Encounters' night side (the lights of towns) and rim of air. The sun
is real, so the night side moves across the globe as the clock runs.

- **Spin it**: drag (flick it and it keeps turning), pinch or scroll to zoom. Arrow keys and
  +/- on desktop.
- **Places**: your journeys, each a list of stops. Add stops by tapping the globe
  (**+ Tap globe**) or from a list of ~200 cities and landmarks (**+ From list**, with
  search). Rename stops, reorder them, delete them. Make as many journeys as you like; three
  come with it (Raiders of the Lost Ark, Around the World in 80 Days, a haunted grand tour).
- **GO**: plays the journey like the travel maps in Indiana Jones. The globe turns to each stop
  in turn while a red line draws itself across to the next behind a little plane, with the
  place's name across the top. Where a stop has a photo, it drops in like a print while the
  journey waits there. The arcs rise higher for longer legs; over the horizon they fade.
- **Tap a pin**: the globe goes in close on it and its card opens, with your photo of the place
  (**Add a photo** opens the phone's photo library, or a file picker on desktop; it is shrunk to
  1280 px and kept on that device in `user://photos`). Arrows step to the next and previous stop.
- **Weather**: presets (Clear, Fair, Stormy, Overcast), cloud cover, how strongly the cloud
  layer is drawn (0 hides it), wind (drift speed of clouds and storms), cloud height, hurricanes (tap the
  globe to start one, or Random / None; up to 6), lightning, and the northern and southern
  lights.
- **Sky**: the sun's clock (time of day, day of the year, Pause / Real / Fast / Faster, Back
  to now), the night side and city lights on or off, an **Old map** look (parchment land,
  pale seas, inked coasts), a **Chunky map** (Salmon Run 2's 1024 map with hard-edged texels), a
  latitude/longitude grid, big pixels, auto spin, and the **Moon**.
- **The eye** at the end of the bar (or H) hides everything but the Earth; the faint eye in the
  corner brings it back.

Behind the Earth is the real sky: NASA's Deep Star Maps (as in Close Encounters), turned by
Greenwich sidereal time so the stars stand where they truly are. The aurora is ray-marched: its
curtains stand up off the night side and show against space past the edge of the globe, and they
ripple, shimmer and pulse. The moon is a ray-traced ball (NASA's LRO map, from Close Encounters)
at its real place in the sky for the clock, near side to the Earth, with its phases and the
Earth's shadow on it in an eclipse; it is drawn 1.55 Earths out rather than 60, to be seen.

Everything is saved to `user://earth.json` (the browser's storage on the web) as it changes.

## Files

- `scripts/main.gd`: the bottom bar, the three panels, journey captions, taps, saving
- `scripts/globe.gd`: spinning and zooming, pins, the travel lines and plane, playing a
  journey, the sun's clock; feeds the shader
- `scripts/weather.gd`: cloud, wind, hurricanes (they track west and curl poleward) and
  lightning, as numbers for the shader
- `scripts/places.gd`: the list of places, the starting journeys, lat/lon helpers
- `scripts/ui_kit.gd`: fonts, colours, theme and widgets (after Salmon Run 2's)
- `shaders/globe.gdshader`: the whole Earth, drawn as a ray-traced sphere on a ColorRect
- `textures/earth_day.jpg`: NASA Blue Marble (land_shallow_topo_2048), public domain
- `textures/earth_night.jpg`: NASA Earth's City Lights, public domain
- `textures/earth_day_low.png`, `earth_night_low.png`: the chunky maps (Salmon Run 2's 1024 Blue Marble)
- `textures/starmap_nasa.jpg`: NASA Deep Star Maps 2020 (4K), public domain, from Close Encounters
- `tests/shots.gd`: saves pictures of the main states:
  `godot --path . --audio-driver Dummy --resolution 390x844 -s tests/shots.gd -- --out=<folder>`
- `tests/trailer.gd`: the 10 second trailer with no words (Movie Maker at 1280x720 via a temporary
  `override.cfg`); the arcade preview is it scaled to 960x540. `media/` (not committed) holds the cut.
- `scripts/photos.gd`: picking, shrinking, keeping and loading the player's photos
- `tests/check_input.gd`: checks a drag turns the globe and a tap adds a stop:
  `godot --headless --path . --audio-driver Dummy --resolution 450x800 -s tests/check_input.gd`

## Building

`godot --headless --path . --export-release Web build/index.html`

## Arcade

The Atlas cabinet (a normal cart, no leaderboard) iframes `https://sclondon.github.io/Atlas/build/index.html`.
Its preview film is recorded with `tests/attract.gd` under Movie Maker at 960x540 (put an `override.cfg`
with those window sizes in the project while recording, then remove it).
