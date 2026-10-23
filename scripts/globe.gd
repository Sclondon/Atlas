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
const ZOOM_MIN := 0.3
const ZOOM_MAX := 7.0
## How far out the moon is drawn, in Earth radii.
const MOON_DISTANCE := 3.2

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
var moon := true
var planets_on := true
var old_map := false
var grid := false
var pixel := 2.0
## Salmon Run 2's lower-resolution map, hard-edged (the chunky, chibi look).
var low_res := false

## Where the middle of the view is looking (degrees), and how close.
var view_lat := 25.0
var view_lon := -40.0
var zoom := 1.0

var playing := false

var _zoom_to := 1.0
var _target := Vector2.INF  # (longitude, latitude) being turned to, after look_at_spot
var _spin := Vector2.ZERO  # degrees a second, (longitude, latitude), after a flick
var _touches := {}
var _ignored := {}  # fingers that went down on the panels
## Says whether a point on the screen is over something laid on the globe (a panel, the bar).
var blocked: Callable = func(_at: Vector2) -> bool: return false
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
var _focus_from := -1.0  # the zoom to go back to after `focus`
var _t := 0.0

var _earth: ColorRect
var _mat: ShaderMaterial
var _m := Basis.IDENTITY
var _c := Vector2.ZERO
var _r := 100.0
var _pins: Array[Vector2] = []  # where each stop's pin was drawn (Vector2.INF if round the back)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/globe.gdshader")
	_mat.set_shader_parameter("day_map", preload("res://textures/earth_day.jpg"))
	_mat.set_shader_parameter("night_map", preload("res://textures/earth_night.jpg"))
	_mat.set_shader_parameter("day_low", preload("res://textures/earth_day_low.png"))
	_mat.set_shader_parameter("night_low", preload("res://textures/earth_night_low.png"))
	_mat.set_shader_parameter("star_map", preload("res://textures/starmap_nasa.jpg"))
	_mat.set_shader_parameter("moon_map", preload("res://textures/moon_lroc.jpg"))
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


## Turns to stop `i` and goes in close on it; `unfocus` goes back out to where it was.
func focus(i: int) -> void:
	highlight = i
	look_at_spot(stops[i].lat, stops[i].lon)
	if _focus_from < 0.0:
		_focus_from = _zoom_to
	_zoom_to = 3.2


func unfocus() -> void:
	if _focus_from > 0.0:
		_zoom_to = _focus_from
		_focus_from = -1.0


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


## Touches are read here rather than in _gui_input, so they reach the globe however the browser
## delivers them: some phones (iPhone Chrome) lose the finger going down, so a drag or a lift
## from a finger never seen pressing is taken up as if it had been. Fingers that go down on the
## panels or the bar (see `blocked`) are left to them.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if blocked.call(event.position):
				_ignored[event.index] = true
				return
			_ignored.erase(event.index)
			_press(event.index, event.position)
		else:
			if _ignored.has(event.index):
				_ignored.erase(event.index)
				return
			var known: bool = _touches.has(event.index)
			if not known and (_touches.size() > 0 or blocked.call(event.position)):
				return
			_touches.erase(event.index)
			# (a lift with no press seen is a tap too)
			if _touches.is_empty() and not _dragged and (not known or Time.get_ticks_msec() - _press_time < 600):
				_tap(event.position)
			# flicked: keep turning, unless the finger had stopped before it was lifted
			if Time.get_ticks_msec() - _last_drag > 80:
				_spin = Vector2.ZERO
			if _touches.size() == 1:
				_pinch = 0.0
			_dragged = _dragged and not _touches.is_empty()
	elif event is InputEventScreenDrag:
		if _ignored.has(event.index):
			return
		if not _touches.has(event.index):
			if blocked.call(event.position):
				return
			_press(event.index, event.position - event.relative)
			_dragged = true
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
	elif event is InputEventMouseButton and event.pressed and not blocked.call(event.position):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(1.12)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.0 / 1.12)
	elif event is InputEventMagnifyGesture:
		zoom = clampf(zoom * event.factor, ZOOM_MIN, ZOOM_MAX)
		_zoom_to = zoom


func _press(index: int, at: Vector2) -> void:
	_touches[index] = at
	if _touches.size() == 1:
		_press_at = at
		_press_time = Time.get_ticks_msec()
		_dragged = false
		_spin = Vector2.ZERO
		_target = Vector2.INF
	else:
		_dragged = true
		_pinch = _pinch_span()


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
		# (longer where there is a photo to look at)
		_hold = 2.8 if str(stops[_done_legs].get("photo", "")) != "" else 1.4
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


## Where the sun is overhead (degrees latitude, longitude), from the clock: its place on the
## ecliptic (a low-precision almanac formula, good to a fraction of a degree), turned into the
## Earth's frame by sidereal time.
func subsolar() -> Vector2:
	var d := _days()
	var mean := deg_to_rad(280.460 + 0.9856474 * d)
	var anomaly := deg_to_rad(357.528 + 0.9856003 * d)
	var lam := mean + deg_to_rad(1.915) * sin(anomaly) + deg_to_rad(0.020) * sin(2.0 * anomaly)
	return _sky_to_earth(lam, 0.0)


## Which way the moon is from the middle of the Earth (in the Earth's frame), from the clock: its
## place on the sky by the same kind of formula (its main wobbles only).
func moon_dir() -> Vector3:
	var d := _days()
	var mean := deg_to_rad(218.316 + 13.176396 * d)
	var anomaly := deg_to_rad(134.963 + 13.064993 * d)
	var node := deg_to_rad(93.272 + 13.229350 * d)
	var lam := mean + deg_to_rad(6.289) * sin(anomaly)
	var beta := deg_to_rad(5.128) * sin(node)
	var at := _sky_to_earth(lam, beta)
	return Places.vec(at.x, at.y)


## Days since the J2000 epoch, from the clock.
func _days() -> float:
	return sim_time / 86400.0 + 2440587.5 - 2451545.0


## The planets' orbits (NASA JPL's "Approximate Positions of the Planets", good 1800-2050): for
## each, a (AU), e, I, L, longitude of perihelion, longitude of the node (degrees), and how each
## changes per century. The Earth (the Earth-moon barycentre) is the third.
const ORBITS := [
	[0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593,
		0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081],
	[0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255,
		0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418],
	[1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0,
		0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0],
	[1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891,
		0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343],
	[5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909,
		-0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106],
	[9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448,
		-0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794],
	[19.18916464, 0.04725744, 0.77263783, 313.23810451, 170.95427630, 74.01692503,
		-0.00196176, -0.00004397, -0.00242939, 428.48202785, 0.40805281, 0.04240589],
	[30.06992276, 0.00859048, 1.77004347, -55.12002969, 44.96476227, 131.78422574,
		0.00026291, 0.00005105, 0.00035372, 218.45945325, -0.32241464, -0.01262724],
]
## How big each planet is drawn in the sky (radians): far bigger than life, but in their order.
const PLANET_SIZES := [0.018, 0.027, 0.022, 0.065, 0.055, 0.032, 0.031]


## Where a planet is round the sun on the clock's date (AU, ecliptic: x to the spring equinox).
func _orbit_position(i: int) -> Vector3:
	var o: Array = ORBITS[i]
	var cent := _days() / 36525.0
	var a: float = o[0] + o[6] * cent
	var e: float = o[1] + o[7] * cent
	var tilt := deg_to_rad(o[2] + o[8] * cent)
	var mean_lon := deg_to_rad(o[3] + o[9] * cent)
	var peri := deg_to_rad(o[4] + o[10] * cent)
	var node := deg_to_rad(o[5] + o[11] * cent)
	var arg := peri - node
	var anomaly := wrapf(mean_lon - peri, -PI, PI)
	# Kepler's equation, by Newton's method
	var ecc := anomaly + e * sin(anomaly)
	for _n in 6:
		ecc -= (ecc - e * sin(ecc) - anomaly) / (1.0 - e * cos(ecc))
	var px := a * (cos(ecc) - e)
	var py := a * sqrt(1.0 - e * e) * sin(ecc)
	var cw := cos(arg)
	var sw := sin(arg)
	var cn := cos(node)
	var sn := sin(node)
	var ci := cos(tilt)
	return Vector3(
		(cw * cn - sw * sn * ci) * px + (-sw * cn - cw * sn * ci) * py,
		(cw * sn + sw * cn * ci) * px + (-sw * sn + cw * cn * ci) * py,
		(sw * sin(tilt)) * px + (cw * sin(tilt)) * py)


## A direction given in the ecliptic frame, as a direction in the Earth's own frame now.
func _ecliptic_to_earth(v: Vector3) -> Vector3:
	var at := _sky_to_earth(atan2(v.y, v.x), asin(clampf(v.z / maxf(v.length(), 1e-9), -1.0, 1.0)))
	return Places.vec(at.x, at.y)


## Each planet's direction from the Earth (with how big it is drawn) and the sun's direction
## from it, for the shader.
func planets() -> Array:
	var earth := _orbit_position(2)
	var dirs := PackedVector4Array()
	var suns := PackedVector4Array()
	var k := 0
	for i in ORBITS.size():
		if i == 2:
			continue
		var p := _orbit_position(i)
		var d := _ecliptic_to_earth(p - earth)
		var s := _ecliptic_to_earth(-p)
		dirs.append(Vector4(d.x, d.y, d.z, PLANET_SIZES[k]))
		suns.append(Vector4(s.x, s.y, s.z, 0.0))
		k += 1
	return [dirs, suns]


## A place on the ecliptic (longitude, latitude in radians) as the latitude and longitude on the
## Earth it stands over now.
func _sky_to_earth(lam: float, beta: float) -> Vector2:
	var tilt := deg_to_rad(23.44)
	var x := cos(beta) * cos(lam)
	var y := cos(beta) * sin(lam)
	var z := sin(beta)
	var ra := atan2(y * cos(tilt) - z * sin(tilt), x)
	var dec := asin(clampf(y * sin(tilt) + z * cos(tilt), -1.0, 1.0))
	return Vector2(rad_to_deg(dec), wrapf(rad_to_deg(ra - sidereal()), -180.0, 180.0))


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
	_mat.set_shader_parameter("low_res", low_res)
	var sun := subsolar()
	var sun_v := Places.vec(sun.x, sun.y)
	_mat.set_shader_parameter("sun_dir", sun_v)
	# the moon, brought in to MOON_DISTANCE Earths away to be seen (it is really 60), and how far
	# into the Earth's shadow it is: the real shadow, as wide as the moon is at the real distance
	var m := moon_dir()
	_mat.set_shader_parameter("moon", 1.0 if moon else 0.0)
	_mat.set_shader_parameter("moon_pos", m * MOON_DISTANCE)
	_mat.set_shader_parameter("moon_eclipse", 1.0 - smoothstep(0.008, 0.021, m.angle_to(-sun_v)))
	_mat.set_shader_parameter("planets_on", 1.0 if planets_on else 0.0)
	if planets_on:
		var ps := planets()
		_mat.set_shader_parameter("planet_dir", ps[0])
		_mat.set_shader_parameter("planet_sun", ps[1])
		# (Saturn's north pole points to right ascension 40.6, declination 83.5)
		_mat.set_shader_parameter("saturn_pole", Places.vec(83.54, wrapf(40.59 - rad_to_deg(sidereal()), -180.0, 180.0)))
	_mat.set_shader_parameter("cloud_height", weather.height)
	_mat.set_shader_parameter("sky_turn", sidereal())
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
	var lift := 0.06 + 0.12 * minf(angle, 2.0)
	var steps := clampi(int(angle * _r / 6.0), 10, 400)
	var count := int(ceilf(steps * upto))
	var run := PackedVector2Array()
	var run_behind := false
	var prev := Vector2.INF
	var head := Vector2.INF
	var dir := Vector2.RIGHT
	for s in count + 1:
		var t := minf(float(s) / steps, upto)
		var q := _m * (great_circle(a, b, t) * (1.006 + lift * sin(PI * t)))
		var at := _c + Vector2(q.x, -q.y) * _r
		# hidden only where the Earth is in front of it; where it arcs round the back of the
		# world, over the horizon, it is drawn faded, so it reads as going away
		var seen := q.z > 0.0 or Vector2(q.x, q.y).length_squared() > 1.0
		var behind := q.z < 0.0
		if seen and (run.is_empty() or behind == run_behind):
			run.append(at)
		elif seen:
			run.append(at)
			_line(run, run_behind)
			run = PackedVector2Array([at])
		else:
			_line(run, run_behind)
			run = PackedVector2Array()
		run_behind = behind
		if seen:
			if prev != Vector2.INF and at.distance_squared_to(prev) > 0.01:
				dir = (at - prev).normalized()
			head = at
		else:
			head = Vector2.INF
		prev = at
	_line(run, run_behind)
	return [head, dir]


func _line(run: PackedVector2Array, faded := false) -> void:
	if run.size() < 2:
		return
	var k := 0.35 if faded else 1.0
	draw_polyline(run, Color(UI.INK, k), 9.0 * ui_scale, true)
	draw_polyline(run, Color(LINE, k), 5.0 * ui_scale, true)


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


## How far the Earth has turned under the stars (Greenwich mean sidereal time, in radians), from
## the clock: the right ascension overhead at longitude 0.
func sidereal() -> float:
	var days := sim_time / 86400.0 + 2440587.5 - 2451545.0
	return deg_to_rad(fposmod(280.46061837 + 360.98564736629 * days, 360.0))
