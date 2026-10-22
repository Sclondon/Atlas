extends Control
## Atlas: the globe (globe.gd) with a bar of buttons along the bottom that open the
## panels: PLACES (your journeys and their stops), WEATHER (clouds, wind, hurricanes, lightning,
## aurora), SKY (the sun's clock and how the Earth is drawn), and GO, which plays the journey.
##
## Phone first: the panel opens over the bottom half of a tall screen and the globe moves up
## into the half above it; on a wide screen the panel opens down the right-hand side instead.
## Everything is saved in user://earth.json as it changes.

const UI := preload("res://scripts/ui_kit.gd")
const Places := preload("res://scripts/places.gd")
const Globe := preload("res://scripts/globe.gd")

const SAVE := "user://earth.json"
const DAYS := ["Thu", "Fri", "Sat", "Sun", "Mon", "Tue", "Wed"]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
## How fast the clock can run: [button, seconds of sky a second].
const RATES := [["Pause", 0.0], ["Real", 1.0], ["Fast", 1800.0], ["Faster", 14400.0]]

var globe: Globe
## Each {"name", "stops": [{"name", "lat", "lon"}]}.
var journeys: Array = []
var current := 0

## What a tap on the globe does: "" (says where it is), "stop" (adds a stop) or "storm".
var _mode := ""
var _open := ""
var _catalogue := false
var _search := ""

var _bar: HBoxContainer
var _bar_buttons := {}
var _go: Button
var _sheet: PanelContainer
var _sheet_title: Label
var _scroll: ScrollContainer
var _body: VBoxContainer
var _title: Label
var _clock: Label
var _caption: Label
var _subcaption: Label
var _hint: Label
var _hint_left := 0.0
var _caption_tween: Tween
var _area_tween: Tween
var _save_in := -1.0
# the sky panel's controls, kept up to date as the clock runs
var _clock_big: Label
var _hour_slider: HSlider
var _day_slider: HSlider
var _rate_buttons: Array[Button] = []


func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	globe = Globe.new()
	add_child(globe)
	globe.tapped.connect(_on_tapped)
	globe.pin_tapped.connect(_on_pin_tapped)
	globe.arrived.connect(_on_arrived)
	globe.leg_started.connect(_on_leg_started)
	globe.journey_done.connect(_on_journey_done)
	_build_overlay()
	_build_sheet()
	_build_bar()
	globe.blocked = func(at: Vector2) -> bool:
		return (_sheet.visible and _sheet.get_global_rect().has_point(at)) or _bar.get_global_rect().has_point(at)
	_load()
	_use_journey(current)
	resized.connect(_layout)
	_layout()
	var s: Dictionary = journeys[current].stops[0] if not journeys[current].stops.is_empty() else {"lat": 25.0, "lon": -40.0}
	globe.look_at_spot(s.lat, s.lon, true)


# ------------------------------------------------------------------ building the screen

func _build_overlay() -> void:
	_title = UI.label("ATLAS", 34, UI.GOLD)
	_title.position = Vector2(22, 14)
	add_child(_title)
	_clock = UI.label("", 20, Color(UI.PAPER, 0.85), 6)
	_clock.position = Vector2(24, 58)
	add_child(_clock)
	_caption = UI.label("", 54, Color.WHITE, 14)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.modulate.a = 0.0
	add_child(_caption)
	_subcaption = UI.label("", 24, UI.GOLD, 8)
	_subcaption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subcaption.modulate.a = 0.0
	add_child(_subcaption)
	_hint = UI.label("", 22, Color.WHITE, 8)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.modulate.a = 0.0
	add_child(_hint)


func _build_bar() -> void:
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 10)
	add_child(_bar)
	for item: Array in [["places", "Places"], ["weather", "Weather"], ["sky", "Sky"]]:
		var id: String = item[0]
		var b := UI.toggle(item[1], false, func(_on: bool) -> void: _toggle_sheet(id), Vector2(0, 84))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 28)
		_bar.add_child(b)
		_bar_buttons[id] = b
	_go = UI.button("GO", _toggle_play, Vector2(0, 84))
	_go.icon = UI.icon("play")
	_go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_go.add_theme_font_size_override("font_size", 28)
	_go.add_theme_stylebox_override("normal", UI.card(UI.RED, UI.INK, 2, 8))
	_go.add_theme_stylebox_override("hover", UI.card(UI.RED.lightened(0.12), UI.INK, 2, 8))
	_go.add_theme_color_override("font_color", Color.WHITE)
	_go.add_theme_color_override("font_hover_color", Color.WHITE)
	_bar.add_child(_go)


func _build_sheet() -> void:
	_sheet = PanelContainer.new()
	_sheet.visible = false
	add_child(_sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_sheet.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	_sheet_title = UI.label("", 34, UI.GOLD)
	_sheet_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_sheet_title)
	head.add_child(UI.icon_button("x", _close_sheet, Vector2(56, 52)))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	_scroll.add_child(_body)


func _layout() -> void:
	var s := size
	var tall := s.y >= s.x * 1.05
	var bar_h := 84.0
	var bar_top := s.y - bar_h - 14.0
	_bar.position = Vector2(14, bar_top)
	_bar.size = Vector2(minf(s.x - 28.0, 760.0), bar_h)
	_bar.position.x = (s.x - _bar.size.x) * 0.5
	var globe_area := Rect2(0, 80, s.x, bar_top - 80)
	if tall:
		var h := clampf(s.y * 0.46, 380.0, 720.0)
		_sheet.position = Vector2(10, bar_top - h - 10.0)
		_sheet.size = Vector2(s.x - 20.0, h)
		if _sheet.visible:
			globe_area = Rect2(0, 80, s.x, _sheet.position.y - 80)
	else:
		var w := clampf(s.x * 0.42, 420.0, 600.0)
		_sheet.position = Vector2(s.x - w - 10.0, 10)
		_sheet.size = Vector2(w, bar_top - 20.0)
		if _sheet.visible:
			globe_area = Rect2(0, 80, _sheet.position.x, bar_top - 80)
			_bar.size.x = minf(_sheet.position.x - 28.0, 760.0)
			_bar.position.x = 14.0
	if _area_tween:
		_area_tween.kill()
	if globe.area.size == Vector2.ZERO:
		globe.area = globe_area
	else:
		_area_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_area_tween.tween_property(globe, "area", globe_area, 0.35)
	var cap_w := globe_area.size.x - 40.0
	_caption.position = Vector2(globe_area.position.x + 20.0, 96)
	_caption.size = Vector2(cap_w, 0)
	_subcaption.position = Vector2(globe_area.position.x + 20.0, 166)
	_subcaption.size = Vector2(cap_w, 0)
	_hint.position = Vector2(globe_area.position.x + 30.0, 100)
	_hint.size = Vector2(globe_area.size.x - 60.0, 0)


# ------------------------------------------------------------------ the panels

func _toggle_sheet(id: String) -> void:
	if _open == id:
		_close_sheet()
		return
	globe.stop()
	_set_go()
	_open = id
	_catalogue = false
	_set_mode("")
	_sheet.visible = true
	for key: String in _bar_buttons:
		(_bar_buttons[key] as Button).set_pressed_no_signal(key == id)
	_rebuild()
	_layout()


func _close_sheet() -> void:
	_open = ""
	_sheet.visible = false
	_set_mode("")
	globe.highlight = -1
	for key: String in _bar_buttons:
		(_bar_buttons[key] as Button).set_pressed_no_signal(false)
	_layout()


func _rebuild() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_rate_buttons.clear()
	_clock_big = null
	match _open:
		"places":
			_sheet_title.text = "Places" if not _catalogue else "Pick a place"
			if _catalogue:
				_build_catalogue()
			else:
				_build_places()
		"weather":
			_sheet_title.text = "Weather"
			_build_weather()
		"sky":
			_sheet_title.text = "Sky"
			_build_sky()


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_body.add_child(row)
	return row


func _grow(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _note(text: String, col := Color(UI.PAPER, 0.75)) -> Label:
	var l := UI.label(text, 21, col, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(l)
	return l


func _slider(text: String, lo: float, hi: float, value: float, on_change: Callable) -> HSlider:
	_body.add_child(UI.label(text, 22, UI.PAPER, 0))
	var h := HSlider.new()
	h.min_value = lo
	h.max_value = hi
	h.step = (hi - lo) / 400.0
	h.value = value
	h.custom_minimum_size = Vector2(0, 44)
	h.value_changed.connect(on_change)
	_body.add_child(h)
	return h


# ---- places

func _journey() -> Dictionary:
	return journeys[current]


func _build_places() -> void:
	var row := _row()
	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(0, 60)
	pick.clip_text = true
	for j: Dictionary in journeys:
		pick.add_item(j.name)
	pick.select(current)
	pick.item_selected.connect(func(i: int) -> void:
		_use_journey(i)
		_dirty()
		_rebuild())
	row.add_child(_grow(pick))
	row.add_child(UI.button("New", _new_journey, Vector2(90, 60)))
	var bin := UI.icon_button("x", _delete_journey)
	bin.disabled = journeys.size() <= 1
	row.add_child(bin)
	var name_box := LineEdit.new()
	name_box.text = _journey().name
	name_box.placeholder_text = "Journey name"
	name_box.custom_minimum_size = Vector2(0, 58)
	name_box.text_changed.connect(func(t: String) -> void:
		_journey().name = t
		pick.set_item_text(current, t)
		_dirty())
	_body.add_child(name_box)

	row = _row()
	var tap := UI.toggle("+ Tap globe", _mode == "stop", func(on: bool) -> void: _set_mode("stop" if on else ""))
	tap.name = "TapStop"
	row.add_child(_grow(tap))
	row.add_child(_grow(UI.button("+ From list", func() -> void:
		_catalogue = true
		_search = ""
		_rebuild())))

	var stops: Array = _journey().stops
	if stops.is_empty():
		_note("No stops yet. Press + Tap globe and tap anywhere on the Earth, or pick from the list.")
	for i in stops.size():
		_stop_row(i)

	row = _row()
	row.add_child(_grow(UI.toggle("Route", globe.show_route, func(on: bool) -> void:
		globe.show_route = on
		_dirty())))
	row.add_child(_grow(UI.toggle("Names", globe.show_names, func(on: bool) -> void:
		globe.show_names = on
		_dirty())))
	row.add_child(_grow(UI.button("Clear", func() -> void:
		_journey().stops.clear()
		_use_journey(current)
		_dirty()
		_rebuild())))
	_slider("Journey speed", 0.3, 3.0, globe.speed, func(v: float) -> void:
		globe.speed = v
		_dirty())


func _stop_row(i: int) -> void:
	var stops: Array = _journey().stops
	var stop: Dictionary = stops[i]
	var row := _row()
	var num := UI.button(str(i + 1), func() -> void:
		globe.highlight = i
		globe.look_at_spot(stop.lat, stop.lon)
		_show_hint("%s\n%s" % [stop.name, Places.coords(stop.lat, stop.lon)], 2.5), Vector2(58, 58))
	num.add_theme_stylebox_override("normal", UI.card(UI.GOLD, UI.INK, 2, 29))
	num.add_theme_stylebox_override("hover", UI.card(UI.GOLD.lightened(0.2), UI.INK, 2, 29))
	row.add_child(num)
	var box := LineEdit.new()
	box.text = stop.name
	box.custom_minimum_size = Vector2(0, 58)
	box.text_changed.connect(func(t: String) -> void:
		stop.name = t
		_dirty())
	row.add_child(_grow(box))
	var up := UI.icon_button("up", func() -> void: _move_stop(i, -1), Vector2(54, 58))
	up.disabled = i == 0
	row.add_child(up)
	var down := UI.icon_button("down", func() -> void: _move_stop(i, 1), Vector2(54, 58))
	down.disabled = i == stops.size() - 1
	row.add_child(down)
	row.add_child(UI.icon_button("x", func() -> void:
		stops.remove_at(i)
		globe.highlight = -1
		_dirty()
		_rebuild(), Vector2(54, 58)))


func _move_stop(i: int, by: int) -> void:
	var stops: Array = _journey().stops
	var s: Dictionary = stops[i]
	stops.remove_at(i)
	stops.insert(i + by, s)
	globe.highlight = i + by
	_dirty()
	_rebuild()


func _build_catalogue() -> void:
	var row := _row()
	row.add_child(UI.button("Back", func() -> void:
		_catalogue = false
		_rebuild(), Vector2(100, 58)))
	var search := LineEdit.new()
	search.placeholder_text = "Search places"
	search.text = _search
	search.custom_minimum_size = Vector2(0, 58)
	row.add_child(_grow(search))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	_body.add_child(list)
	var fill := func() -> void:
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
		var want := _search.strip_edges().to_lower()
		for p: Array in Places.LIST:
			if want != "" and not (p[0] as String).to_lower().contains(want):
				continue
			var b := UI.button("%s   %s" % [p[0], Places.coords(p[1], p[2])], func() -> void:
				_add_stop(p[0], p[1], p[2])
				globe.look_at_spot(p[1], p[2])
				_show_hint("Added %s" % p[0], 1.6), Vector2(0, 56))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 22)
			list.add_child(b)
	search.text_changed.connect(func(t: String) -> void:
		_search = t
		fill.call())
	fill.call()


func _add_stop(stop_name: String, lat: float, lon: float) -> void:
	_journey().stops.append({"name": stop_name, "lat": lat, "lon": lon})
	globe.highlight = _journey().stops.size() - 1
	_set_go()
	_dirty()


func _new_journey() -> void:
	journeys.append({"name": "Journey %d" % (journeys.size() + 1), "stops": []})
	_use_journey(journeys.size() - 1)
	_dirty()
	_rebuild()


func _delete_journey() -> void:
	if journeys.size() <= 1:
		return
	journeys.remove_at(current)
	_use_journey(clampi(current, 0, journeys.size() - 1))
	_dirty()
	_rebuild()


func _use_journey(i: int) -> void:
	current = i
	globe.stop()
	globe.stops = journeys[i].stops
	globe.highlight = -1
	_set_go()


# ---- weather

func _build_weather() -> void:
	var w := globe.weather
	var row := _row()
	for preset: Array in [["Clear", 0.1, 0, 0.8], ["Fair", 0.42, 1, 1.0], ["Stormy", 0.58, 4, 1.8], ["Overcast", 0.82, 0, 1.2]]:
		row.add_child(_grow(UI.button(preset[0], func() -> void:
			w.cover = preset[1]
			w.wind = preset[3]
			w.opacity = maxf(w.opacity, 0.6)
			w.random_storms(preset[2])
			w.lightning = w.lightning or preset[2] > 0
			_dirty()
			_rebuild(), Vector2(0, 58))))
	_slider("Cloud cover", 0.0, 1.0, w.cover, func(v: float) -> void:
		w.cover = v
		_dirty())
	_slider("Cloud layer shown", 0.0, 1.0, w.opacity, func(v: float) -> void:
		w.opacity = v
		_dirty())
	_slider("Wind", 0.0, 4.0, w.wind, func(v: float) -> void:
		w.wind = v
		_dirty())
	_body.add_child(UI.label("Hurricanes: %d of %d" % [w.storms.size(), w.MAX_STORMS], 22, UI.PAPER, 0))
	row = _row()
	row.add_child(_grow(UI.toggle("+ Tap globe", _mode == "storm", func(on: bool) -> void: _set_mode("storm" if on else ""))))
	row.add_child(_grow(UI.button("Random", func() -> void:
		w.random_storms(3)
		_dirty()
		_rebuild())))
	row.add_child(_grow(UI.button("None", func() -> void:
		w.storms.clear()
		_dirty()
		_rebuild())))
	row = _row()
	row.add_child(_grow(UI.toggle("Lightning", w.lightning, func(on: bool) -> void:
		w.lightning = on
		_dirty())))
	row.add_child(_grow(UI.toggle("Aurora", globe.aurora, func(on: bool) -> void:
		globe.aurora = on
		_dirty())))
	_note("Hurricanes drift west on the trade winds and curl away from the equator. Lightning shows best on the night side; the northern and southern lights only there.")


# ---- sky

func _build_sky() -> void:
	_clock_big = UI.label("", 26, UI.GOLD, 0)
	_body.add_child(_clock_big)
	_hour_slider = _slider("Time of day (UTC)", 0.0, 24.0, 0.0, func(v: float) -> void:
		var day_start := floorf(globe.sim_time / 86400.0) * 86400.0
		globe.sim_time = day_start + v * 3600.0)
	_day_slider = _slider("Day of the year", 0.0, 364.0, 0.0, func(v: float) -> void:
		var d := Time.get_datetime_dict_from_unix_time(int(globe.sim_time))
		var year_start := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": 1, "day": 1})
		globe.sim_time = year_start + floorf(v) * 86400.0 + fposmod(globe.sim_time, 86400.0))
	var row := _row()
	for rate: Array in RATES:
		var b := UI.toggle(rate[0], is_equal_approx(globe.time_rate, rate[1]), func(_on: bool) -> void:
			globe.time_rate = rate[1]
			_sync_sky(), Vector2(0, 58))
		row.add_child(_grow(b))
		_rate_buttons.append(b)
	_body.add_child(UI.button("Back to now", func() -> void:
		globe.sim_time = Time.get_unix_time_from_system()
		globe.time_rate = 1.0
		_sync_sky()))
	row = _row()
	row.add_child(_grow(UI.toggle("Night side", globe.night, func(on: bool) -> void:
		globe.night = on
		_dirty())))
	row.add_child(_grow(UI.toggle("City lights", globe.city_lights, func(on: bool) -> void:
		globe.city_lights = on
		_dirty())))
	row = _row()
	row.add_child(_grow(UI.toggle("Old map", globe.old_map, func(on: bool) -> void:
		globe.old_map = on
		_dirty())))
	row.add_child(_grow(UI.toggle("Grid", globe.grid, func(on: bool) -> void:
		globe.grid = on
		_dirty())))
	row = _row()
	row.add_child(_grow(UI.toggle("Big pixels", globe.pixel > 1.0, func(on: bool) -> void:
		globe.pixel = 3.0 if on else 1.0
		_dirty())))
	row.add_child(_grow(UI.toggle("Auto spin", globe.auto_spin, func(on: bool) -> void:
		globe.auto_spin = on
		_dirty())))
	_sync_sky()


func _sync_sky() -> void:
	if _clock_big == null:
		return
	_clock_big.text = _time_text(globe.sim_time)
	_hour_slider.set_value_no_signal(fposmod(globe.sim_time, 86400.0) / 3600.0)
	var d := Time.get_datetime_dict_from_unix_time(int(globe.sim_time))
	var year_start := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": 1, "day": 1})
	_day_slider.set_value_no_signal((globe.sim_time - year_start) / 86400.0)
	for i in _rate_buttons.size():
		_rate_buttons[i].set_pressed_no_signal(is_equal_approx(globe.time_rate, RATES[i][1]))


func _time_text(t: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(t))
	var weekday: String = DAYS[posmod(int(floorf(t / 86400.0)), 7)]
	return "%s %d %s %d   %02d:%02d UTC" % [weekday, d.day, MONTHS[d.month - 1], d.year, d.hour, d.minute]


# ------------------------------------------------------------------ taps and the journey

func _set_mode(mode: String) -> void:
	_mode = mode
	match mode:
		"stop":
			_show_hint("Tap the Earth to add a stop", 0.0)
		"storm":
			_show_hint("Tap the Earth to start a hurricane", 0.0)


func _on_tapped(lat: float, lon: float) -> void:
	match _mode:
		"stop":
			var stop_name := _name_for(lat, lon)
			_add_stop(stop_name, lat, lon)
			_show_hint("Added %s. Tap again for another stop." % stop_name, 0.0)
			if _open == "places":
				_rebuild()
		"storm":
			globe.weather.add_storm(lat, lon)
			_show_hint("A hurricane gathers at %s" % Places.coords(lat, lon), 0.0)
			_dirty()
			if _open == "weather":
				_rebuild()
		_:
			_show_hint("%s\n%s" % [_name_for(lat, lon), Places.coords(lat, lon)], 2.2)


## What to call a spot: the place it is on, near, or else just where it is.
func _name_for(lat: float, lon: float) -> String:
	var near: Array = Places.nearest(lat, lon)
	var d: float = rad_to_deg(near[1])
	if d < 1.2:
		return near[0][0]
	if d < 6.0:
		return "Near %s" % near[0][0]
	return Places.coords(lat, lon)


func _on_pin_tapped(i: int) -> void:
	var s: Dictionary = globe.stops[i]
	globe.highlight = i
	_show_hint("%d. %s\n%s" % [i + 1, s.name, Places.coords(s.lat, s.lon)], 2.5)


func _toggle_play() -> void:
	if globe.playing:
		globe.stop()
		_fade_caption()
	else:
		if globe.stops.size() < 2:
			_show_hint("A journey needs at least two stops. Add some under Places.", 2.5)
			return
		_close_sheet()
		globe.play()
	_set_go()


func _set_go() -> void:
	if _go == null:
		return
	_go.text = "STOP" if globe.playing else "GO"
	_go.icon = UI.icon("stop" if globe.playing else "play", Color.WHITE)


func _on_arrived(i: int) -> void:
	_caption_text(globe.stops[i].name.to_upper(), "Stop %d of %d" % [i + 1, globe.stops.size()])


func _on_leg_started(i: int) -> void:
	_caption_text(_caption.text, "to %s" % globe.stops[i + 1].name)


func _on_journey_done() -> void:
	_set_go()
	_caption_text(_caption.text, "Journey's end")
	_fade_caption(2.5)


func _caption_text(text: String, sub: String) -> void:
	if _caption_tween:
		_caption_tween.kill()
	var new_place := text != _caption.text
	_caption.text = text
	_subcaption.text = sub
	_caption_tween = create_tween().set_parallel()
	if new_place:
		_caption.modulate.a = 0.0
	_caption_tween.tween_property(_caption, "modulate:a", 1.0, 0.3)
	_caption_tween.tween_property(_subcaption, "modulate:a", 1.0, 0.3)


func _fade_caption(after := 0.0) -> void:
	if _caption_tween:
		_caption_tween.kill()
	_caption_tween = create_tween().set_parallel()
	_caption_tween.tween_property(_caption, "modulate:a", 0.0, 0.6).set_delay(after)
	_caption_tween.tween_property(_subcaption, "modulate:a", 0.0, 0.6).set_delay(after)


## A line of words over the globe, for `seconds` (0 keeps it up until something else replaces it).
func _show_hint(text: String, seconds: float) -> void:
	_hint.text = text
	_hint.modulate.a = 1.0
	_hint_left = seconds if seconds > 0.0 else -1.0


func _process(delta: float) -> void:
	_clock.text = _time_text(globe.sim_time)
	if _open == "sky":
		_sync_sky()
	# the hint stays while its mode is on; otherwise it fades when its time is up
	if _hint_left > 0.0:
		_hint_left -= delta
	elif _hint_left < 0.0 and _mode == "":
		_hint_left = 0.0
	if _hint_left == 0.0 or globe.playing:
		_hint.modulate.a = move_toward(_hint.modulate.a, 0.0, delta * 2.5)
	_title.modulate.a = move_toward(_title.modulate.a, 0.0 if globe.playing else 1.0, delta * 3.0)
	_clock.modulate.a = _title.modulate.a
	if _save_in > 0.0:
		_save_in -= delta
		if _save_in <= 0.0:
			_save()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _open != "":
			_close_sheet()
		elif globe.playing:
			_toggle_play()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_toggle_play()


# ------------------------------------------------------------------ saving

func _dirty() -> void:
	_save_in = 1.0


func _save() -> void:
	var w := globe.weather
	var data := {
		"journeys": journeys,
		"current": current,
		"weather": w.save(),
		"view": {
			"night": globe.night, "city_lights": globe.city_lights, "aurora": globe.aurora,
			"old_map": globe.old_map, "grid": globe.grid, "pixel": globe.pixel,
			"auto_spin": globe.auto_spin, "speed": globe.speed,
			"show_route": globe.show_route, "show_names": globe.show_names,
		},
	}
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))


func _load() -> void:
	var data: Variant = null
	if FileAccess.file_exists(SAVE):
		data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if data is Dictionary and data.get("journeys", []) is Array and not (data.journeys as Array).is_empty():
		for j: Variant in data.journeys:
			if j is Dictionary:
				var stops: Array = []
				for s: Variant in j.get("stops", []):
					if s is Dictionary and s.has("lat") and s.has("lon"):
						stops.append({"name": str(s.get("name", "")), "lat": float(s.lat), "lon": float(s.lon)})
				journeys.append({"name": str(j.get("name", "Journey")), "stops": stops})
		current = clampi(int(data.get("current", 0)), 0, journeys.size() - 1)
		globe.weather.load_from(data.get("weather", {}))
		var v: Dictionary = data.get("view", {})
		globe.night = v.get("night", globe.night)
		globe.city_lights = v.get("city_lights", globe.city_lights)
		globe.aurora = v.get("aurora", globe.aurora)
		globe.old_map = v.get("old_map", globe.old_map)
		globe.grid = v.get("grid", globe.grid)
		globe.pixel = v.get("pixel", globe.pixel)
		globe.auto_spin = v.get("auto_spin", globe.auto_spin)
		globe.speed = v.get("speed", globe.speed)
		globe.show_route = v.get("show_route", globe.show_route)
		globe.show_names = v.get("show_names", globe.show_names)
	if journeys.is_empty():
		for j: Dictionary in Places.JOURNEYS:
			var stops: Array = []
			for s: Array in j.stops:
				stops.append({"name": s[0], "lat": s[1], "lon": s[2]})
			journeys.append({"name": j.name, "stops": stops})
		current = 0
		globe.weather.random_storms(2)
		globe.auto_spin = true
