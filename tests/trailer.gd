extends SceneTree
## A 10 second trailer with no words on screen: the UI and the journey's captions hidden, four
## shots cut together. Record it with Movie Maker at 1280x720 (an override.cfg with those window
## sizes in the project while it runs):
##   godot --path . --audio-driver Dummy --fixed-fps 30 --write-movie out.avi -s tests/trailer.gd

const Places := preload("res://scripts/places.gd")


func _initialize() -> void:
	if FileAccess.file_exists("user://earth.json"):
		DirAccess.remove_absolute("user://earth.json")
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _t(iso: String) -> float:
	return Time.get_unix_time_from_datetime_string(iso)


func _run() -> void:
	while current_scene == null or not current_scene.is_node_ready():
		await process_frame
	var main: Control = current_scene
	var globe = main.globe
	main._hide_ui(true)
	main._show_ui.visible = false
	main._caption.visible = false
	main._subcaption.visible = false
	globe.auto_spin = false
	globe.weather.cover = 0.5
	globe.weather.wind = 2.0
	globe.weather.random_storms(4)
	globe.stops = []
	globe.show_names = false

	# 1. a flick of the globe, the day sweeping round it, storms turning, the moon going by
	globe.sim_time = _t("2026-10-21T14:00:00")
	globe.time_rate = 5400.0
	globe.look_at_spot(18.0, -10.0, true)
	globe.zoom = 0.85
	globe._zoom_to = 1.05
	globe._spin = Vector2(-170.0, 0.0)
	await create_timer(2.3).timeout

	# 2. the journey: the red line drawing itself behind the plane, the globe turning to follow
	globe.stops = [
		{"name": "San Francisco", "lat": 37.77, "lon": -122.42},
		{"name": "Honolulu", "lat": 21.31, "lon": -157.86},
		{"name": "Manila", "lat": 14.6, "lon": 120.98},
		{"name": "Nepal", "lat": 27.72, "lon": 85.32},
	]
	globe.sim_time = _t("2026-10-21T22:00:00")
	globe.time_rate = 3000.0
	globe.look_at_spot(37.77, -122.42, true)
	globe.speed = 3.0
	globe.play()
	await create_timer(3.7).timeout
	globe.stop()

	# 3. night over Canada: the aurora's curtains standing up off the edge of the world
	globe.stops = []
	globe.sim_time = _t("2026-12-21T07:30:00")
	globe.time_rate = 120.0
	globe.moon = false
	globe.look_at_spot(38.0, -100.0, true)
	globe.zoom = 1.35
	globe._zoom_to = 1.25
	globe._spin = Vector2(-6.0, 0.0)
	await create_timer(2.2).timeout

	# 4. pulling back: the whole Earth, the moon beside it, the Milky Way behind
	globe.sim_time = _t("2026-10-21T15:00:00")
	globe.time_rate = 900.0
	globe.moon = true
	var m: Vector2 = Places.lat_lon(globe.moon_dir())
	globe.look_at_spot(m.x * 0.5, m.y - 45.0, true)
	globe.zoom = 1.4
	globe._zoom_to = 0.8
	await create_timer(1.8).timeout
	quit()
