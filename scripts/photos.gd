extends Node
## The player's own photos of places: picked from the phone's photo library (or a file on
## desktop), shrunk to at most MAX_SIDE pixels, and kept in user://photos (the browser's storage
## on the web, so they stay on that device). A stop keeps its photo's path under "photo"; a path
## under res:// is a photo shipped with the game.

## A photo was picked and saved: its path, for the stop that asked.
signal picked(path: String)

const DIR := "user://photos"
const MAX_SIDE := 1280

var _web_done: JavaScriptObject
var _dialog: FileDialog
var _cache := {}


## Opens the picker. On the web it is the browser's own (the photo library on a phone), which
## also shrinks the picture and turns it the right way up before it is handed over.
func pick() -> void:
	if OS.has_feature("web"):
		_web_done = JavaScriptBridge.create_callback(_on_web_photo)
		JavaScriptBridge.get_interface("window").atlasPhotoDone = _web_done
		JavaScriptBridge.eval("""
(function () {
	var input = document.createElement('input');
	input.type = 'file';
	input.accept = 'image/*';
	input.onchange = function () {
		var file = input.files && input.files[0];
		if (!file) return;
		var url = URL.createObjectURL(file);
		var img = new Image();
		img.onload = function () {
			var k = Math.min(1, %d / Math.max(img.naturalWidth, img.naturalHeight));
			var c = document.createElement('canvas');
			c.width = Math.round(img.naturalWidth * k);
			c.height = Math.round(img.naturalHeight * k);
			c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
			URL.revokeObjectURL(url);
			window.atlasPhotoDone(c.toDataURL('image/jpeg', 0.85));
		};
		img.src = url;
	};
	input.click();
})();
""" % MAX_SIDE, true)
		return
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.use_native_dialog = true
		_dialog.filters = PackedStringArray(["*.jpg, *.jpeg, *.png, *.webp ; Photos"])
		_dialog.file_selected.connect(func(path: String) -> void:
			var img := Image.load_from_file(path)
			if img != null and not img.is_empty():
				_keep(img))
		add_child(_dialog)
	_dialog.popup_centered_ratio(0.7)


func _on_web_photo(args: Array) -> void:
	var data := str(args[0])
	var comma := data.find(",")
	if comma < 0:
		return
	var img := Image.new()
	if img.load_jpg_from_buffer(Marshalls.base64_to_raw(data.substr(comma + 1))) == OK:
		_keep(img)


func _keep(img: Image) -> void:
	var longest := maxi(img.get_width(), img.get_height())
	if longest > MAX_SIDE:
		var k := float(MAX_SIDE) / longest
		img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := "%s/%d_%d.jpg" % [DIR, int(Time.get_unix_time_from_system()), randi() % 100000]
	if img.save_jpg(path, 0.85) == OK:
		picked.emit(path)


## The picture at a path, or null if there is none (a photo since cleared away).
func texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if path.begins_with("res://"):
		tex = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_cache[path] = tex
	return tex


func forget(path: String) -> void:
	_cache.erase(path)
	if path.begins_with(DIR) and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
