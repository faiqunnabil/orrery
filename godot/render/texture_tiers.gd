class_name TextureTiers
extends RefCounted

const HIGH_SUFFIX := "_4k"
const LOW_DIVISOR := 2

static var _reduced: Dictionary = {}


static func body_texture(path: String) -> Texture2D:
	if path == "":
		return null
	match Quality.preset:
		Quality.Preset.HIGH:
			_reduced.clear()
			return _high_or_default(path)
		Quality.Preset.LOW:
			return _reduced_texture(path)
	_reduced.clear()
	return load(path)


static func sky_texture(path: String) -> Texture2D:
	return _high_or_default(path) if Quality.preset == Quality.Preset.HIGH else load(path)


static func high_path(path: String) -> String:
	return path.get_basename() + HIGH_SUFFIX + "." + path.get_extension()


static func _high_or_default(path: String) -> Texture2D:
	var high := high_path(path)
	return load(high) if ResourceLoader.exists(high) else load(path)


static func _reduced_texture(path: String) -> Texture2D:
	if _reduced.has(path):
		return _reduced[path]
	var source: Texture2D = load(path)
	var image := source.get_image()
	if image == null or image.is_empty():
		return source
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	image.resize(maxi(image.get_width() / LOW_DIVISOR, 1), maxi(image.get_height() / LOW_DIVISOR, 1), Image.INTERPOLATE_BILINEAR)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_reduced[path] = texture
	return texture
