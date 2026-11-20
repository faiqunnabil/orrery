class_name MainMenu
extends Node3D

const TITLE := "Orrery"
const TAGLINE := "An interactive 3D solar system for exploration and gravity experiments."
const TITLE_FONT_SIZE := 72
const CAMERA_FOV := 55.0
const PLANET_ID := "earth"
const PLANET_POSITION := Vector3(2.25, -0.2, -4.2)
const PLANET_RADIUS := 1.75
const PLANET_SECONDS_PER_SECOND := 1800.0
const SUN_DIRECTION := Vector3(-0.78, 0.22, -0.58)
const SKY_DRIFT := 0.004
const SWAY_AMPLITUDE := 0.02
const SWAY_FREQUENCY := 0.11

var _camera := Camera3D.new()
var _menu := ShellMenu.new(TITLE, TAGLINE, TITLE_FONT_SIZE, true)
var _environment := SpaceScene.make_space_environment()
var _planet: BodyVisual
var _planet_definition: BodyDefinition
var _planet_seconds := 0.0
var _elapsed := 0.0


func _ready() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.environment = _environment
	_environment.glow_enabled = Quality.profile()["glow"]
	add_child(world_environment)
	_camera.fov = CAMERA_FOV
	add_child(_camera)
	_camera.current = true
	_build_planet()
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = OrreryTheme.build()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.add_child(_menu)
	_menu.add_entry("Explore", func() -> void: get_tree().change_scene_to_file(SpaceScene.EXPLORE_SCENE), true, "telescope")
	_menu.add_entry("Sandbox", func() -> void: get_tree().change_scene_to_file(SpaceScene.SANDBOX_SCENE), false, "atom")
	_menu.add_entry("Settings", _menu.open_settings, false, "settings")
	_menu.add_entry("Credits", _menu.open_credits, false, "info")
	_menu.add_entry("Quit", Audio.quit_application, false, "power")
	_menu.show_root()


func _build_planet() -> void:
	for body in BodyCatalog.load_bodies():
		if body.id == PLANET_ID:
			_planet_definition = body
	if _planet_definition == null:
		return
	_planet = BodyVisual.new(_planet_definition.texture_path, _planet_definition.night_texture_path, false)
	_planet.add_atmosphere_layers(_planet_definition)
	_planet.add_surface_detail(_planet_definition)
	var profile := Quality.profile()
	_planet.set_mesh_detail(profile["sphere_radial_segments"])
	_planet.set_effects_detail(profile["full_effects"])
	add_child(_planet)
	_planet_seconds = Astro.unix_to_simulation_seconds(Time.get_unix_time_from_system())
	_place_planet()


func _place_planet() -> void:
	if _planet == null:
		return
	_planet.place(PLANET_POSITION, PLANET_RADIUS, _planet_definition.orientation(_planet_seconds), SUN_DIRECTION.normalized())


func _process(delta: float) -> void:
	_elapsed += delta
	_planet_seconds += delta * PLANET_SECONDS_PER_SECOND
	_place_planet()
	_environment.sky_rotation.y = _elapsed * SKY_DRIFT
	_camera.rotation = Vector3(sin(_elapsed * SWAY_FREQUENCY) * SWAY_AMPLITUDE, cos(_elapsed * SWAY_FREQUENCY * 0.7) * SWAY_AMPLITUDE, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("take_screenshot"):
		_capture_screenshot()


func _capture_screenshot() -> void:
	if await ScreenCapture.save_frame(get_viewport()) != "":
		Audio.play_effect(&"click")
