extends SceneTree

var frame := 0
var step := 0
var wait := 90
var failures := 0


func _initialize() -> void:
	root.get_node("Preferences").set_onboarding_done(true)
	change_scene_to_file("res://modes/explore/explore_mode.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if frame < wait:
		return false
	frame = 0
	wait = 20
	_run_step()
	step += 1
	return false


func _check(label: String, condition: bool) -> void:
	print(("PASS  " if condition else "FAIL  ") + label)
	if not condition:
		failures += 1
		_save_failure()


func _save_failure() -> void:
	var directory := OS.get_environment("FAILURE_DIR")
	if directory == "":
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var path := "%s/%s_failure_%d.jpg" % [directory, get_script().resource_path.get_file().get_basename(), failures]
	root.get_texture().get_image().save_jpg(path, 0.85)
	print("      screenshot ", path)


func _width(scene, id: String, parameter: String) -> int:
	var visual = scene.renderer._visuals[id]
	var material: ShaderMaterial = visual._material
	var texture: Texture2D = material.get_shader_parameter(parameter)
	return texture.get_width() if texture != null else 0


func _cloud_width(scene) -> int:
	var visual = scene.renderer._visuals["earth"]
	var material: ShaderMaterial = visual._clouds.material_override
	var texture: Texture2D = material.get_shader_parameter("cloud_texture")
	return texture.get_width()


func _sky_width(scene) -> int:
	var panorama: Texture2D = (scene.space_environment.sky.sky_material as ShaderMaterial).get_shader_parameter("panorama")
	return panorama.get_width()


func _timed_preset(quality, preset: int) -> float:
	var start := Time.get_ticks_usec()
	quality.set_preset(preset)
	return (Time.get_ticks_usec() - start) / 1000.0


func _run_step() -> void:
	var scene := current_scene
	var quality := root.get_node("Quality")
	match step:
		0:
			print("switch to High took %.0f ms" % _timed_preset(quality, 2))
		1:
			_check("High: Earth day map is 4K", _width(scene, "earth", "albedo_texture") == 4096)
			_check("High: Earth night map is 4K", _width(scene, "earth", "night_texture") == 4096)
			_check("High: Earth clouds are 4K", _cloud_width(scene) == 4096)
			_check("High: Io keeps its 2K map", _width(scene, "io", "albedo_texture") == 2048)
			_check("High: sky is 4K", _sky_width(scene) == 4096)
			print("switch to Low took %.0f ms" % _timed_preset(quality, 0))
		2:
			_check("Low: Earth day map is 1K", _width(scene, "earth", "albedo_texture") == 1024)
			_check("Low: Io map is 1K", _width(scene, "io", "albedo_texture") == 1024)
			var texture: Texture2D = scene.renderer._visuals["earth"]._material.get_shader_parameter("albedo_texture")
			_check("Low: reduced map has mipmaps", texture.get_image().has_mipmaps())
			_check("Low: sky stays 2K", _sky_width(scene) == 2048)
			print("switch to Medium took %.0f ms" % _timed_preset(quality, 1))
		3:
			_check("Medium: Earth day map is 2K", _width(scene, "earth", "albedo_texture") == 2048)
			_check("Medium: sky is 2K", _sky_width(scene) == 2048)
			var texture: Texture2D = scene.renderer._visuals["earth"]._material.get_shader_parameter("albedo_texture")
			_check("Medium: imported map has mipmaps", texture.get_image().has_mipmaps())
			print("FAILURES: ", failures)
			quit()
