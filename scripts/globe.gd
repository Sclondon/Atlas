extends Control
## The Earth, filling the screen: drag to spin it (it carries on turning when flicked), pinch or
## scroll to zoom. On it go the stops of the journey in hand, as pins, joined by red lines.
##
## `play` runs the journey the way the travel maps in Indiana Jones do: the globe turns to each
## stop in turn while a red line draws itself across to the next one behind a little plane.
##
## The picture is shaders/globe.gdshader on a ColorRect behind this control; the pins, lines
## and plane are drawn over it here.

## A tap on the globe that was not on a pin.
signal tapped(lat: float, lon: float)
signal pin_tapped(index: int)
## Playing: the line sets out from stop `index` for the next one.
signal leg_started(index: int)
## Playing: the line has reached stop `index` (0 is the start).
signal arrived(index: int)
signal journey_done

const UI := preload("res://scripts/ui_kit.gd")
const Places := preload("res://scripts/places.gd")
const Weather := preload("res://scripts/weather.gd")
const LINE := Color(0.85, 0.13, 0.1)
const ZOOM_MIN := 0.55
const ZOOM_MAX := 7.0

## The stops, in order: each {"name", "lat", "lon"}.
var stops: Array = []
## Draw the whole route when the journey is not being played.
var show_route := true
var show_names := true
## Pins, names and lines are drawn this many times bigger.
var ui_scale := 1.0
## The part of the screen the globe sits in the middle of (the rest is under the open panel).
var area := Rect2()
## Turns slowly by itself when left alone.
var auto_spin := false
## The stop picked in the list (ringed), or -1.
var highlight := -1
var weather := Weather.new()
## How fast the journey plays.
var speed := 1.0

## The clock the sun is set by (seconds since 1970, UTC) and how fast it runs (1 is real time).
var sim_time := Time.get_unix_time_from_system()
var time_rate := 1.0
var night := true
var city_lights := true
var aurora := true
var old_map := false
var grid := false
var pixel := 2.0

## Where the middle of the view is looking (degrees), and how close.
var view_lat := 25.0
var view_lon := -40.0
var zoom := 1.0

var playing := false

var _zoom_to := 1.0
var _target := Vector2.INF  # (longitude, latitude) being turned to, after look_at_spot
var _spin := Vector2.ZERO  # degrees a second, (longitude, latitude), after a flick
var _touches := {}
var _pinch := 0.0
var _press_at := Vector2.ZERO
var _press_time := 0
var _dragged := false
var _last_drag := 0

# playing the journey: how many legs are drawn in full, whether the next is being drawn and
# how far along it is, and how long to wait at a stop before setting out again
var _done_legs := 0
var _moving := false
var _progress := 0.0
var _hold := 0.0
var _user_zoom := 1.0
var _t := 0.0

var _earth: ColorRect
var _mat: ShaderMaterial
var _m := Basis.IDENTITY
var _c := Vector2.ZERO
var _r := 100.0
var _pins: Array[Vector2] = []  # where each stop's pin was drawn (Vector2.INF if round the back)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/globe.gdshader")
	_mat.set_shader_parameter("day_map", preload("res://textures/earth_day.jpg"))
	_mat.set_shader_parameter("night_map", preload("res://textures/earth_night.jpg"))
	_earth = ColorRect.new()
	_earth.material = _mat
	_earth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# behind this control's own drawing, so the lines and pins go on top of the Earth
	_earth.show_behind_parent = true
	add_child(_earth)


# ------------------------------------------------------------------ looking about

## Turns to look at a spot (smoothly, unless `now`).
func look_at_spot(lat: float, lon: float, now := false) -> void:
	_target = Vector2(lon, clampf(lat, -80.0, 80.0))
	_spin = Vector2.ZERO
	if now:
		view_lat = _target.y
		view_lon = _target.x
		_target = Vector2.INF


func zoom_by(k: float) -> void:
	_zoom_to = clampf(_zoom_to * k, ZOOM_MIN, ZOOM_MAX)


## The spot on the Earth under a point on the screen, or Vector2.INF off the globe.
func spot_at(screen: Vector2) -> Vector2:
	var p := (screen - _c) / _r
	p.y = -p.y
	var r2 := p.length_squared()
	if r2 > 1.0:
		return Vector2.INF
	var world := _m.transposed() * Vector3(p.x, p.y, sqrt(1.0 - r2))
	return Places.lat_lon(world)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_press_at = event.position
				_press_time = Time.get_ticks_msec()
				_dragged = false
				_spin = Vector2.ZERO
				_target = Vector2.INF
			else:
				_dragged = true
				_pinch = _pinch_span()
		else:
			_touches.erase(event.index)
			if _touches.is_empty() and not _dragged and Time.get_ticks_msec() - _press_time < 600:
				_tap(event.position)
			# flicked: keep turning, unless the finger had stopped before it was lifted
			if Time.get_ticks_msec() - _last_drag > 80:
				_spin = Vector2.ZERO
			if _touches.size() == 1:
				_pinch = 0.0
		accept_event()
	elif event is InputEventScreenDrag:
		if not _touches.has(event.index):
			return
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var span := _pinch_span()
			if _pinch > 0.0:
				zoom = clampf(zoom * span / _pinch, ZOOM_MIN, ZOOM_MAX)
				_zoom_to = zoom
			_pinch = span
		else:
			if event.position.distance_to(_press_at) > 10.0 * ui_scale:
				_dragged = true
			if _dragged:
				var d: Vector2 = event.relative
				var turn := Vector2(-d.x, d.y) / _r * (180.0 / PI)
				_turn(turn)
				var dt := maxf((Time.get_ticks_msec() - _last_drag) / 1000.0, 0.008)
				_spin = _spin.lerp(turn / dt, 0.5)
				_last_drag = Time.get_ticks_msec()
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(1.12)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.0 / 1.12)
			accept_event()
	elif event is InputEventMagnifyGesture:
		zoom = clampf(zoom * event.factor, ZOOM_MIN, ZOOM_MAX)
		_zoom_to = zoom


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_EQUAL, KEY_KP_ADD:
				zoom_by(1.25)
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_by(0.8)


func _pinch_span() -> float:
	var at: Array = _touches.values()
	return maxf((at[0] as Vector2).distance_to(at[1]), 1.0)


func _turn(by: Vector2) -> void:
	view_lon = wrapf(view_lon + by.x, -180.0, 180.0)
	view_lat = clampf(view_lat + by.y, -85.0, 85.0)


func _tap(at: Vector2) -> void:
	# the nearest pin to the tap, if it is close enough
	var best := -1
	var best_d := 34.0 * ui_scale
	for i in _pins.size():
		if _pins[i] == Vector2.INF:
			continue
		var d := minf(_pins[i].distance_to(at), (_pins[i] + Vector2(0.0, -22.0 * ui_scale)).distance_to(at))
		if d < best_d:
			best_d = d
			best = i
	if best != -1:
		pin_tapped.emit(best)
		return
	var spot := spot_at(at)
	if spot != Vector2.INF:
		tapped.emit(spot.x, spot.y)


# ------------------------------------------------------------------ the journey

func play() -> void:
	if stops.size() < 2:
		return
	playing = true
	_done_legs = 0
	_moving = false
	_hold = 1.3
	_user_zoom = _zoom_to
	_zoom_to = clampf(_zoom_to, 1.2, 1.6)
	_spin = Vector2.ZERO
	arrived.emit(0)


func stop() -> void:
	if not playing:
		return
	playing = false
	_zoom_to = _user_zoom


func _vec(i: int) -> Vector3:
	return Places.vec(stops[i].lat, stops[i].lon)


func _leg_angle(i: int) -> float:
	return _vec(i).angle_to(_vec(i + 1))


## Seconds to draw leg `i` at speed 1: longer legs take longer, but not in proportion.
func _leg_time(i: int) -> float:
	return 1.1 + sqrt(_leg_angle(i)) * 1.6


func _advance(delta: float) -> void:
	if _hold > 0.0:
		_hold -= delta * speed
		if _hold <= 0.0:
			if _done_legs >= stops.size() - 1:
				playing = false
				_zoom_to = _user_zoom
				journey_done.emit()
				return
			_moving = true
			_progress = 0.0
			leg_started.emit(_done_legs)
		return
	_progress = minf(_progress + delta * speed / _leg_time(_done_legs), 1.0)
	if _progress >= 1.0:
		_moving = false
		_done_legs += 1
		_hold = 1.4
		arrived.emit(_done_legs)


## Where the head of the line is (or the stop it is waiting at).
func _head() -> Vector3:
	if _moving:
		return great_circle(_vec(_done_legs), _vec(_done_legs + 1), _ease(_progress))
	return _vec(mini(_done_legs, stops.size() - 1))


static func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


## The point `t` of the way along the shortest way round the Earth from a to b.
static func great_circle(a: Vector3, b: Vector3, t: float) -> Vector3:
	var angle := a.angle_to(b)
	if angle < 0.0001:
		return a
	var axis := a.cross(b)
	if axis.length() < 0.0001:
		# (exactly the other side of the world: any way round will do; go over the top)
		axis = a.cross(Vector3.UP if absf(a.y) < 0.9 else Vector3.RIGHT)
	return a.rotated(axis.normalized(), angle * t)


# ------------------------------------------------------------------ each frame

func _process(delta: float) -> void:
	_t += delta
	weather.step(delta)
	sim_time += delta * time_rate
	if playing and not stops.is_empty():
		_advance(delta)
		if playing:
			var head := Places.lat_lon(_head())
			var k := 1.0 - exp(-delta * 3.5)
			view_lon = rad_to_deg(lerp_angle(deg_to_rad(view_lon), deg_to_rad(head.y), k))
			view_lat = lerpf(view_lat, clampf(head.x * 0.85, -70.0, 70.0), k)
			# pull back for long legs, in close at the stops
			var want := 1.6 if not _moving else clampf(1.7 - _leg_angle(_done_legs) * 0.4, 1.0, 1.6)
			_zoom_to = lerpf(_zoom_to, want, 1.0 - exp(-delta * 1.5))
	elif _target != Vector2.INF:
		var k := 1.0 - exp(-delta * 5.0)
		view_lon = rad_to_deg(lerp_angle(deg_to_rad(view_lon), deg_to_rad(_target.x), k))
		view_lat = lerpf(view_lat, _target.y, k)
		if absf(angle_difference(deg_to_rad(view_lon), deg_to_rad(_target.x))) < 0.002 and absf(view_lat - _target.y) < 0.1:
			_target = Vector2.INF
	elif _touches.is_empty():
		_turn(_spin * delta)
		_spin *= exp(-delta * 2.5)
		if auto_spin and _spin.length() < 3.0:
			_turn(Vector2(5.0 * delta / zoom, 0.0))
	_keys(delta)
	zoom = lerpf(zoom, _zoom_to, 1.0 - exp(-delta * 8.0)) if _touches.size() < 2 else zoom
	queue_redraw()


func _keys(delta: float) -> void:
	var dir := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_down", "ui_up"))
	if dir != Vector2.ZERO and get_viewport().gui_get_focus_owner() == null:
		_turn(dir * 70.0 * delta / zoom)
		_target = Vector2.INF


## Where the sun is overhead (degrees), from the clock: the season tilts it north and south
## of the equator, and it goes round once a day.
func subsolar() -> Vector2:
	var d := Time.get_datetime_dict_from_unix_time(int(sim_time))
	var day_of_year := float(Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day}) \
			- Time.get_unix_time_from_datetime_dict({"year": d.year, "month": 1, "day": 1})) / 86400.0
	var hours := fposmod(sim_time, 86400.0) / 3600.0
	var tilt := 23.44 * sin(TAU * (day_of_year - 80.0) / 365.25)
	return Vector2(tilt, wrapf(-(hours - 12.0) * 15.0, -180.0, 180.0))


func _draw() -> void:
	if area.size == Vector2.ZERO:
		area = Rect2(Vector2.ZERO, size)
	_c = area.get_center()
	_r = minf(area.size.x, area.size.y) * 0.42 * zoom
	_m = Basis(Vector3.RIGHT, deg_to_rad(view_lat)) * Basis(Vector3.UP, -deg_to_rad(view_lon))
	_earth.position = Vector2.ZERO
	_earth.size = size
	_mat.set_shader_parameter("view", _m)
	_mat.set_shader_parameter("rect_size", size)
	_mat.set_shader_parameter("center", _c)
	_mat.set_shader_parameter("globe_radius", _r)
	_mat.set_shader_parameter("pixel", pixel)
	var sun := subsolar()
	_mat.set_shader_parameter("sun_dir", Places.vec(sun.x, sun.y))
	_mat.set_shader_parameter("night", 1.0 if night else 0.0)
	_mat.set_shader_parameter("city_lights", 1.0 if city_lights else 0.0)
	_mat.set_shader_parameter("aurora", 1.0 if aurora else 0.0)
	_mat.set_shader_parameter("old_map", 1.0 if old_map else 0.0)
	_mat.set_shader_parameter("grid", 1.0 if grid else 0.0)
	_mat.set_shader_parameter("cloud_cover", weather.cover)
	_mat.set_shader_parameter("cloud_opacity", weather.opacity)
	_mat.set_shader_parameter("cloud_drift", weather.drift)
	_mat.set_shader_parameter("storm_turn", weather.turn)
	_mat.set_shader_parameter("storm_count", weather.storms.size())
	_mat.set_shader_parameter("storms", weather.storm_vectors())
	_mat.set_shader_parameter("flash", weather.flash)

	_pins.clear()
	for i in stops.size():
		var q := _m * _vec(i)
		_pins.append(_c + Vector2(q.x, -q.y) * _r if q.z > 0.0 else Vector2.INF)
	# the route: every leg drawn so far, then the one being drawn
	var head_at := Vector2.INF
	var head_dir := Vector2.RIGHT
	for i in stops.size() - 1:
		if not playing:
			if show_route:
				_leg(i, 1.0)
		elif i < _done_legs:
			_leg(i, 1.0)
		elif i == _done_legs and _moving:
			var end := _leg(i, _ease(_progress))
			head_at = end[0]
			head_dir = end[1]
	# the pins: those not reached yet (playing) faint, the rest in gold, the picked one ringed
	var font := UI.font()
	for i in stops.size():
		if _pins[i] == Vector2.INF:
			continue
		var reached := not playing or i <= _done_legs
		var here := playing and not _moving and i == _done_legs
		if not reached:
			_dot(_pins[i])
			continue
		if i == highlight and not playing:
			var pulse := 1.0 + sin(_t * 5.0) * 0.12
			draw_arc(_pins[i], 20.0 * ui_scale * pulse, 0.0, TAU, 40, UI.INK, 7.0 * ui_scale)
			draw_arc(_pins[i], 20.0 * ui_scale * pulse, 0.0, TAU, 40, UI.GOLD, 3.5 * ui_scale)
		_pin(font, _pins[i], i + 1, UI.GOLD if not here else Color.WHITE, 1.15 if here else 1.0)
		if show_names and not playing:
			_name(font, _pins[i], stops[i].name)
	if head_at != Vector2.INF:
		_plane(head_at, head_dir)


## Draws leg `i` of the route as far as `upto` (0..1), skipping what is round the back, and
## returns where its head is on screen and which way it is heading there.
func _leg(i: int, upto: float) -> Array:
	var a := _vec(i)
	var b := _vec(i + 1)
	var angle := a.angle_to(b)
	# lifted off the ground in an arc, like a flight, higher for the longer legs
	var lift := 0.05 * minf(angle, 2.0)
	var steps := clampi(int(angle * _r / 6.0), 10, 400)
	var count := int(ceilf(steps * upto))
	var run := PackedVector2Array()
	var prev := Vector2.INF
	var head := Vector2.INF
	var dir := Vector2.RIGHT
	for s in count + 1:
		var t := minf(float(s) / steps, upto)
		var q := _m * (great_circle(a, b, t) * (1.006 + lift * sin(PI * t)))
		var at := _c + Vector2(q.x, -q.y) * _r
		# hidden only where the Earth is in front of it
		var seen := q.z > 0.0 or Vector2(q.x, q.y).length_squared() > 1.0
		if seen:
			run.append(at)
			if prev != Vector2.INF and at.distance_squared_to(prev) > 0.01:
				dir = (at - prev).normalized()
			head = at
		else:
			_line(run)
			run = PackedVector2Array()
			head = Vector2.INF
		prev = at
	_line(run)
	return [head, dir]


func _line(run: PackedVector2Array) -> void:
	if run.size() < 2:
		return
	draw_polyline(run, UI.INK, 9.0 * ui_scale, true)
	draw_polyline(run, LINE, 5.0 * ui_scale, true)


## A little plane at the head of the line, flying along it.
func _plane(at: Vector2, dir: Vector2) -> void:
	var k := 1.3 * ui_scale
	var shape := PackedVector2Array([
		Vector2(13, 0), Vector2(9, -2), Vector2(2, -2), Vector2(-4, -11), Vector2(-8, -11), Vector2(-4, -2),
		Vector2(-10, -2), Vector2(-13, -6), Vector2(-15, -6), Vector2(-13, 0), Vector2(-15, 6), Vector2(-13, 6),
		Vector2(-10, 2), Vector2(-4, 2), Vector2(-8, 11), Vector2(-4, 11), Vector2(2, 2), Vector2(9, 2),
	])
	var angle := dir.angle()
	var outline := PackedVector2Array()
	var body := PackedVector2Array()
	for p in shape:
		body.append(at + (p * k).rotated(angle))
		outline.append(at + (p * k * 1.0 + p.normalized() * 3.0 * ui_scale).rotated(angle))
	draw_colored_polygon(outline, UI.INK)
	draw_colored_polygon(body, Color.WHITE)


## A map pin: a round head with the stop's number in it, on a point that sits exactly on the place.
func _pin(font: Font, at: Vector2, number: int, col: Color, k: float) -> void:
	k *= ui_scale
	var head := at + Vector2(0.0, -26.0 * k)
	var hr := 13.0 * k
	draw_colored_polygon(PackedVector2Array([at + Vector2(0.0, 3.0 * k), head + Vector2(-hr - 2.5, 3.0 * k), head + Vector2(hr + 2.5, 3.0 * k)]), UI.INK)
	draw_circle(head, hr + 2.5 * ui_scale, UI.INK)
	draw_colored_polygon(PackedVector2Array([at, head + Vector2(-hr * 0.8, 4.0 * k), head + Vector2(hr * 0.8, 4.0 * k)]), col)
	draw_circle(head, hr, col)
	var fs := int(17.0 * k)
	draw_string(font, head + Vector2(-hr * 2.0, fs * 0.36), str(number), HORIZONTAL_ALIGNMENT_CENTER, hr * 4.0, fs, UI.INK)


func _dot(at: Vector2) -> void:
	draw_circle(at, 6.0 * ui_scale, UI.INK)
	draw_circle(at, 3.5 * ui_scale, Color(UI.PAPER, 0.7))


func _name(font: Font, at: Vector2, text: String) -> void:
	var fs := int(19.0 * ui_scale)
	var pos := at + Vector2(16.0 * ui_scale, -20.0 * ui_scale)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(7.0 * ui_scale), UI.INK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
