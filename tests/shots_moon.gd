extends SceneTree
## Pictures of the moon passing the edge of the Earth on the far side (behind its air, clouds and
## aurora) and on the near side (in front of them):
##   godot --path . --audio-driver Dummy --resolution 390x844 -s tests/shots_moon.gd -- --out=<folder>

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


func _run() -> void:
	while current_scene == null or not current_scene.is_node_ready():
		await process_frame
	var main: Control = current_scene
	var globe = main.globe
	main._hide_ui(true)
	globe.stops = []
	globe.auto_spin = false
	globe.time_rate = 0.0
	globe.sim_time = Time.get_unix_time_from_datetime_string("2026-10-22T00:00:00")
	globe.weather.height = 1.1
	var m: Vector3 = globe.moon_dir()
	# the camera turned so the moon sits just past the globe's edge, behind it and then in front
	# (the moon is 3.2 Earths out, so about 20 degrees off the line of sight puts it at the rim)
	for side: Array in [["m1_far", -1.0], ["m2_near", 1.0]]:
		var axis := m.cross(Vector3.UP).normalized()
		var eye: Vector3 = (m * side[1]).rotated(axis, deg_to_rad(19.5))
		var at: Vector2 = Places.lat_lon(eye)
		globe.look_at_spot(at.x, at.y, true)
		globe.zoom = 0.75
		globe._zoom_to = 0.75
		await create_timer(0.5).timeout
		root.get_texture().get_image().save_png("%s/%s.png" % [out, side[0]])
		print("shot ", side[0])
	quit()
