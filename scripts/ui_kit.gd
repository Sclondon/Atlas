extends RefCounted
## Shared fonts, colours and widget factories, after Salmon Run 2's look (the 1990s
## encyclopedia CD-ROM): a bookish serif for headings, a clean geometric sans for everything
## else, deep navy plates with cream paper buttons, and a few confident primary colours.

const GOLD := Color(0.98, 0.80, 0.25)
const TEAL := Color(0.38, 0.82, 0.80)
const OCHRE := Color(0.94, 0.64, 0.26)
const RED := Color(0.86, 0.2, 0.16)
## Outlines and text on paper
const INK := Color(0.06, 0.09, 0.2)
## Plates (panels) and the paper the buttons are cut from
const NAVY := Color(0.08, 0.13, 0.29)
const PAPER := Color(0.96, 0.93, 0.85)

## Little pictures for buttons, as SVG paths in a 24 x 24 box (the fonts have no arrows).
const ICONS := {
	"up": "M12 5 L20 15 L4 15 Z",
	"down": "M12 19 L20 9 L4 9 Z",
	"x": "M6 4 L12 10 L18 4 L20 6 L14 12 L20 18 L18 20 L12 14 L6 20 L4 18 L10 12 L4 6 Z",
	"play": "M7 4 L20 12 L7 20 Z",
	"stop": "M6 6 L18 6 L18 18 L6 18 Z",
}

static var _font: Font
static var _serif: Font
static var _theme: Theme
static var _icons := {}


static func font() -> Font:
	if _font == null:
		_font = _weighted("res://fonts/Jost.ttf", 600)
	return _font


static func serif() -> Font:
	if _serif == null:
		_serif = _weighted("res://fonts/LibreBaskerville.ttf", 700)
	return _serif


static func _weighted(path: String, weight: int) -> Font:
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {"wght": weight}
	return f


static func icon(name: String, col := INK, px := 34) -> Texture2D:
	var key := "%s/%s/%d" % [name, col.to_html(), px]
	if not _icons.has(key):
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 24 24"><path d="%s" fill="#%s"/></svg>' % [px, px, ICONS[name], col.to_html(false)]
		var img := Image.new()
		img.load_svg_from_string(svg)
		_icons[key] = ImageTexture.create_from_image(img)
	return _icons[key]


## Text that sits over the globe or on a navy plate. Big text is set in the serif.
static func label(text: String, size: int, col := Color.WHITE, outline := 8) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", serif() if size >= 36 else font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func flat(bg: Color, border := Color.TRANSPARENT, border_w := 0, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


## A flat style with a soft shadow under it, like a card lying on the page.
static func card(bg: Color, border: Color, border_w: int, radius := 6) -> StyleBoxFlat:
	var sb := flat(bg, border, border_w, radius)
	sb.shadow_color = Color(0.0, 0.02, 0.08, 0.45)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 26
	# buttons are cream paper with navy lettering; one that is switched on turns gold
	for kind: String in ["Button", "OptionButton"]:
		t.set_stylebox("normal", kind, card(PAPER, INK, 2, 8))
		t.set_stylebox("hover", kind, card(Color(1.0, 0.97, 0.88), TEAL.darkened(0.3), 2, 8))
		t.set_stylebox("focus", kind, StyleBoxEmpty.new())
		t.set_stylebox("pressed", kind, card(GOLD, INK, 3, 8))
		t.set_stylebox("hover_pressed", kind, card(GOLD.lightened(0.15), INK, 3, 8))
		t.set_stylebox("disabled", kind, card(Color(PAPER, 0.45), Color(INK, 0.5), 2, 8))
		for colour: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			t.set_color(colour, kind, INK)
		t.set_color("font_disabled_color", kind, Color(INK, 0.5))
		t.set_constant("outline_size", kind, 0)
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 8)
	# typing boxes: paper, a little lighter than the buttons
	t.set_stylebox("normal", "LineEdit", flat(Color(1.0, 0.98, 0.93), INK, 2, 6))
	t.set_stylebox("focus", "LineEdit", flat(Color(1.0, 0.98, 0.93), GOLD.darkened(0.2), 3, 6))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(INK, 0.45))
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("selection_color", "LineEdit", Color(GOLD, 0.6))
	# sliders: a cream groove with a gold knob big enough for a thumb
	var groove := flat(Color(PAPER, 0.35), Color.TRANSPARENT, 0, 6)
	groove.content_margin_top = 5
	groove.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", groove)
	var filled := flat(TEAL, Color.TRANSPARENT, 0, 6)
	filled.content_margin_top = 5
	filled.content_margin_bottom = 5
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var knob := _knob()
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob)
	t.set_constant("center_grabber", "HSlider", 1)
	# plates: deep navy with a cream rule round them
	t.set_stylebox("panel", "PanelContainer", card(Color(NAVY, 0.95), PAPER, 2, 12))
	t.set_stylebox("panel", "PopupMenu", card(NAVY, PAPER, 2, 8))
	t.set_stylebox("hover", "PopupMenu", flat(GOLD, Color.TRANSPARENT, 0, 4))
	t.set_color("font_color", "PopupMenu", PAPER)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_font_size("font_size", "PopupMenu", 28)
	t.set_constant("v_separation", "PopupMenu", 18)
	t.set_constant("scrollbar_width", "VScrollBar", 10)
	t.set_stylebox("scroll", "VScrollBar", flat(Color(PAPER, 0.12), Color.TRANSPARENT, 0, 5))
	t.set_stylebox("grabber", "VScrollBar", flat(Color(PAPER, 0.5), Color.TRANSPARENT, 0, 5))
	t.set_stylebox("grabber_highlight", "VScrollBar", flat(GOLD, Color.TRANSPARENT, 0, 5))
	t.set_stylebox("grabber_pressed", "VScrollBar", flat(GOLD, Color.TRANSPARENT, 0, 5))
	_theme = t
	return t


static func _knob() -> Texture2D:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40"><circle cx="20" cy="20" r="16" fill="#fbcc40" stroke="#0f1733" stroke-width="4"/></svg>'
	var img := Image.new()
	img.load_svg_from_string(svg)
	return ImageTexture.create_from_image(img)


static func button(text: String, on_press: Callable, min_size := Vector2(0, 60)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.pressed.connect(on_press)
	return b


## A button that stays in or out (gold when in).
static func toggle(text: String, on: bool, on_toggle: Callable, min_size := Vector2(0, 60)) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = on
	b.custom_minimum_size = min_size
	b.toggled.connect(on_toggle)
	return b


static func icon_button(name: String, on_press: Callable, min_size := Vector2(60, 60)) -> Button:
	var b := Button.new()
	b.icon = icon(name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = min_size
	b.pressed.connect(on_press)
	return b
