extends SceneTree

# Prints the display server Godot started with, so CI can confirm that a run
# meant for Wayland or X11 did not fall back to another one.


func _initialize() -> void:
	print("DISPLAY_SERVER: ", DisplayServer.get_name())
	quit()
