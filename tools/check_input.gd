extends SceneTree
## Checks the globe's touch handling: a drag turns it, a tap in "+ Tap globe" mode adds a stop
## where it landed, and a tap on a pin picks it.
##   godot --headless --path . --audio-driver Dummy -s tools/check_input.gd


func _initialize() -> void:
	if FileAccess.file_exists("user://earth.json"):
		DirAccess.remove_absolute("user://earth.json")
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _touch(at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = at
	e.pressed = pressed
	root.push_input(e, true)


func _drag(at: Vector2, by: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = at
	e.relative = by
	root.push_input(e, true)


func _run() -> void:
	for i in 10:
		await process_frame
	var main: Control = current_scene
	var globe = main.globe
	globe.auto_spin = false
	globe.look_at_spot(0.0, 0.0, true)
	await process_frame
	var c: Vector2 = globe.area.get_center()
	var fails := 0
	# drag right: the globe turns west under the finger
	var lon0: float = globe.view_lon
	_touch(c, true)
	for i in 6:
		_drag(c + Vector2(10.0 * (i + 1), 0.0), Vector2(10.0, 0.0))
		await process_frame
	_touch(c + Vector2(60.0, 0.0), false)
	await process_frame
	print("drag turned the view from %.1f to %.1f" % [lon0, globe.view_lon])
	if not globe.view_lon < lon0 - 3.0:
		fails += 1
		print("FAIL: drag did not turn the globe")
	# tap to add a stop where the middle of the view is
	globe.look_at_spot(10.0, 20.0, true)
	await process_frame
	main._toggle_sheet("places")
	main._set_mode("stop")
	await create_timer(0.6).timeout
	await process_frame
	var before: int = globe.stops.size()
	c = globe.area.get_center()
	_touch(c, true)
	await process_frame
	_touch(c, false)
	await process_frame
	var added: Dictionary = globe.stops[-1] if globe.stops.size() > before else {}
	print("stops %d -> %d, added %s" % [before, globe.stops.size(), added])
	if globe.stops.size() != before + 1 or absf(added.get("lat", 99.0) - 10.0) > 1.0 or absf(added.get("lon", 99.0) - 20.0) > 1.0:
		fails += 1
		print("FAIL: tap did not add a stop at the middle of the view")
	print("ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(fails)
