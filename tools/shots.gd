extends SceneTree
## Saves pictures of the main states to check the look by eye:
##   godot --path . --audio-driver Dummy --resolution 450x800 -s tools/shots.gd -- --out=<folder>
## (it uses a fresh save of its own, so it shows what a new player sees)

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


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)


func _run() -> void:
	await _wait(0.6)
	var main: Control = current_scene
	var globe = main.globe
	globe.sim_time = Time.get_unix_time_from_datetime_string("2026-10-21T15:00:00")
	globe.auto_spin = false
	globe.look_at_spot(30.0, -60.0, true)
	await _wait(0.5)
	await _shot("01_start")
	main._toggle_sheet("places")
	await _wait(0.6)
	await _shot("02_places")
	main._toggle_sheet("weather")
	await _wait(0.6)
	await _shot("03_weather")
	main._toggle_sheet("sky")
	await _wait(0.6)
	await _shot("04_sky")
	main._close_sheet()
	globe.old_map = true
	globe.grid = true
	await _wait(0.5)
	await _shot("05_old_map")
	globe.old_map = false
	globe.grid = false
	main._toggle_play()
	await _wait(2.4)
	await _shot("06_playing")
	globe.speed = 3.0
	await _wait(9.0)
	await _shot("07_playing_later")
	main._toggle_play()
	globe.look_at_spot(55.0, 20.0, true)
	globe.sim_time = Time.get_unix_time_from_datetime_string("2026-12-21T22:00:00")
	globe.zoom_by(2.0)
	await _wait(1.0)
	await _shot("08_night_europe")
	quit()
