extends SceneTree
## Prints where the sun, moon and planets are for a date, as right ascension and declination, to
## check against an almanac:
##   godot --headless --path . -s tests/check_sky.gd -- --date=2026-10-22T00:00:00

const Globe := preload("res://scripts/globe.gd")
const NAMES := ["Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"]


func _initialize() -> void:
	var date := "2026-10-22T00:00:00"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--date="):
			date = a.substr(7)
	var g := Globe.new()
	g.sim_time = Time.get_unix_time_from_datetime_string(date)
	var gmst := g.sidereal()
	var sun := g.subsolar()
	_say("Sun", Globe.Places.vec(sun.x, sun.y), gmst)
	_say("Moon", g.moon_dir(), gmst)
	var ps: Array = g.planets()
	for i in NAMES.size():
		var d: Vector4 = ps[0][i]
		_say(NAMES[i], Vector3(d.x, d.y, d.z), gmst)
	g.free()
	quit()


## Prints a direction in the Earth's frame as right ascension (hours) and declination.
func _say(what: String, v: Vector3, gmst: float) -> void:
	var ra := fposmod(atan2(v.x, v.z) + gmst, TAU) / TAU * 24.0
	var dec := rad_to_deg(asin(clampf(v.y, -1.0, 1.0)))
	print("%-8s RA %5.2fh  Dec %+6.1f" % [what, ra, dec])
