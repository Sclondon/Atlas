# Earth Simulator

A Godot 4.7 (GL Compatibility) toy for the Scareathon arcade, built phone-first. The Earth
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
  place's name across the top.
- **Weather**: presets (Clear, Fair, Stormy, Overcast), cloud cover, how strongly the cloud
  layer is drawn (0 hides it), wind (drift speed of clouds and storms), hurricanes (tap the
  globe to start one, or Random / None; up to 6), lightning, and the northern and southern
  lights.
- **Sky**: the sun's clock (time of day, day of the year, Pause / Real / Fast / Faster, Back
  to now), the night side and city lights on or off, an **Old map** look (parchment land,
  pale seas, inked coasts), a latitude/longitude grid, big pixels, auto spin.

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
- `tools/shots.gd`: saves pictures of the main states:
  `godot --path . --audio-driver Dummy --resolution 390x844 -s tools/shots.gd -- --out=<folder>`
- `tools/check_input.gd`: checks a drag turns the globe and a tap adds a stop:
  `godot --headless --path . --audio-driver Dummy --resolution 450x800 -s tools/check_input.gd`

## Building

`godot --headless --path . --export-release Web build/index.html`
