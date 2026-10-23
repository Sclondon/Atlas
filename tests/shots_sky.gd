extends SceneTree
## Saves pictures of the sky round the Earth: the sun behind the globe's edge, Mars and Jupiter
## together, Saturn and its rings, and the moon out at its distance.
##   godot --path . --audio-driver Dummy --resolution 390x844 -s tests/shots_sky.gd -- --out=<folder>

const Places := preload("res://scripts/places.gd")

var out := "user://shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	if FileAccess.file_exists("user://earth.json"):
		DirAccess.remove_absolute("user://earth.json")
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _shot(name: String) -> void:
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)


## Turns the globe so that `target` (a direction from the Earth) shows in the sky `off` degrees
## to one side of it, and zooms out to `zoom`.
func _frame(globe, target: Vector3, off: float, zoom: float) -> void:
	# the sky shows what is behind the Earth, so look from the far side, a little to one side
	var behind: Vector2 = Places.lat_lon(-target)
	globe.look_at_spot(behind.x, behind.y + off, true)
	globe.zoom = zoom
	globe._zoom_to = zoom


func _run() -> void:
	while current_scene == null or not current_scene.is_node_ready():
		await process_frame
	var main: Control = current_scene
	var globe = main.globe
	main._hide_ui(true)
	globe.auto_spin = false
	globe.stops = []
	globe.sim_time = Time.get_unix_time_from_datetime_string("2026-10-22T00:00:00")
	globe.time_rate = 0.0
	var sun: Vector2 = globe.subsolar()
	_frame(globe, Places.vec(sun.x, sun.y), 36.0, 0.8)
	await _shot("s1_sun_behind")
	var ps: Array = globe.planets()
	var jup: Vector4 = ps[0][3]
	_frame(globe, Vector3(jup.x, jup.y, jup.z), 35.0, 0.6)
	await _shot("s2_mars_jupiter")
	var sat: Vector4 = ps[0][4]
	_frame(globe, Vector3(sat.x, sat.y, sat.z), 30.0, 0.6)
	await _shot("s3_saturn")
	var m: Vector2 = Places.lat_lon(globe.moon_dir())
	globe.look_at_spot(m.x * 0.4, m.y - 60.0, true)
	globe.zoom = 0.45
	globe._zoom_to = 0.45
	await _shot("s4_moon")
	quit()
