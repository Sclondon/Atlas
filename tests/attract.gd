extends SceneTree
## Plays the arcade preview: the Raiders journey in stormy weather, the night side coming up
## over Asia. Record it with Movie Maker (the window size comes from an override.cfg):
##   godot --path . --audio-driver Dummy --fixed-fps 30 --write-movie out.avi -s tests/attract.gd


func _initialize() -> void:
	if FileAccess.file_exists("user://earth.json"):
		DirAccess.remove_absolute("user://earth.json")
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _run() -> void:
	while current_scene == null or not current_scene.is_node_ready():
		await process_frame
	var main: Control = current_scene
	var globe = main.globe
	globe.auto_spin = false
	globe.sim_time = Time.get_unix_time_from_datetime_string("2026-10-21T14:00:00")
	# (the sun goes west with the journey, so every stop is reached by day)
	globe.time_rate = 3000.0
	globe.weather.cover = 0.5
	globe.weather.wind = 1.6
	globe.weather.random_storms(4)
	globe.look_at_spot(-5.0, -95.0, true)
	globe.zoom = 1.0
	await create_timer(1.2).timeout
	globe.speed = 1.6
	main._toggle_play()
	await globe.journey_done
	await create_timer(2.0).timeout
	quit()
