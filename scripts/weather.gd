extends RefCounted
## The weather layer: how much cloud there is and how strongly it is drawn, the wind that
## carries it east, the hurricanes (which track west and curl away from the equator), and
## lightning flickering in the storms. It only keeps the numbers; globe.gdshader draws it.

const MAX_STORMS := 6

## 0 clear skies to 1 overcast.
var cover := 0.42
## How strongly the cloud layer is drawn (0 hides it).
var opacity := 0.85
## 0 still to 1 normal to 4 a gale (everything moves faster).
var wind := 1.0
var lightning := true
## Each [latitude, longitude, size in radians].
var storms: Array = []

## How far the clouds have drifted (radians) and how far the storms have turned.
var drift := 0.0
var turn := 0.0
## Where lightning is flashing (a direction) and how bright.
var flash := Vector4(0.0, 0.0, 1.0, 0.0)

var _next_flash := 2.0
var _flash_at := Vector3.FORWARD
var _flash_t := -1.0


func add_storm(lat: float, lon: float, size := -1.0) -> void:
	if storms.size() >= MAX_STORMS:
		storms.pop_front()
	storms.append([lat, lon, size if size > 0.0 else randf_range(0.24, 0.38)])


## A few hurricanes where they really form: over the warm seas either side of the equator.
func random_storms(count: int) -> void:
	storms.clear()
	var seas := [[15.0, -45.0], [16.0, -110.0], [17.0, 140.0], [14.0, 88.0], [-15.0, 65.0], [-16.0, 160.0], [-14.0, -170.0]]
	seas.shuffle()
	for i in mini(count, MAX_STORMS):
		add_storm(seas[i][0] + randf_range(-5.0, 5.0), seas[i][1] + randf_range(-15.0, 15.0))


func step(delta: float) -> void:
	drift += delta * 0.025 * wind
	turn += delta * (0.4 + 0.6 * wind)
	for s: Array in storms:
		# trade winds push them west; nearer the poles they curl away and slow
		s[1] = wrapf(s[1] - delta * 0.5 * wind * (1.0 - smoothstep(20.0, 38.0, absf(s[0]))), -180.0, 180.0)
		if absf(s[0]) < 36.0:
			s[0] += signf(s[0] if s[0] != 0.0 else 1.0) * delta * 0.12 * wind
	_lightning(delta)


func storm_vectors() -> PackedVector4Array:
	var out := PackedVector4Array()
	for s: Array in storms:
		var v := _vec(s[0], s[1])
		out.append(Vector4(v.x, v.y, v.z, s[2]))
	while out.size() < MAX_STORMS:
		out.append(Vector4(0.0, 0.0, 1.0, 1.0))
	return out


func _lightning(delta: float) -> void:
	if _flash_t >= 0.0:
		_flash_t += delta
		# a flicker: two quick strokes and a fade
		var k := 0.0
		if _flash_t < 0.07:
			k = 1.0
		elif _flash_t < 0.13:
			k = 0.25
		elif _flash_t < 0.2:
			k = 0.9
		else:
			k = maxf(0.0, 1.0 - (_flash_t - 0.2) / 0.25) * 0.5
		flash = Vector4(_flash_at.x, _flash_at.y, _flash_at.z, k)
		if _flash_t > 0.45:
			_flash_t = -1.0
			flash.w = 0.0
		return
	if not lightning:
		return
	# storms flash far more than ordinary cloud, and more cloud means more of it
	var rate := storms.size() * 1.2 + cover * 1.5
	_next_flash -= delta * rate
	if _next_flash > 0.0:
		return
	_next_flash = randf_range(0.4, 1.6)
	if not storms.is_empty() and randf() < 0.7:
		var s: Array = storms.pick_random()
		# somewhere in the storm's arms (degrees out from the eye)
		var r := rad_to_deg(s[2]) * randf_range(0.15, 0.7)
		var a := randf() * TAU
		_flash_at = _vec(s[0] + r * sin(a), s[1] + r * cos(a) / maxf(cos(deg_to_rad(s[0])), 0.2))
	else:
		# thunderstorms are mostly a thing of the tropics
		_flash_at = _vec(randfn(0.0, 22.0), randf_range(-180.0, 180.0))
	_flash_t = 0.0


func save() -> Dictionary:
	return {"cover": cover, "opacity": opacity, "wind": wind, "lightning": lightning, "storms": storms}


func load_from(d: Dictionary) -> void:
	cover = d.get("cover", cover)
	opacity = d.get("opacity", opacity)
	wind = d.get("wind", wind)
	lightning = d.get("lightning", lightning)
	storms = d.get("storms", storms).duplicate(true)


static func _vec(lat: float, lon: float) -> Vector3:
	var a := deg_to_rad(lat)
	var o := deg_to_rad(lon)
	return Vector3(cos(a) * sin(o), sin(a), cos(a) * cos(o))
