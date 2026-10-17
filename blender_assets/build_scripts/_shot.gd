extends SceneTree
var cam: Camera3D
var step := 0
var pending := ""
var frames := 0
func _initialize() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())
	cam = Camera3D.new(); root.add_child(cam)
func view(pos: Vector3, look: Vector3, name: String, fov := 80.0) -> void:
	cam.make_current(); cam.global_position = pos; cam.look_at(look); cam.fov = fov
	step += 1; pending = name
func _process(d: float) -> bool:
	if pending != "":
		frames += 1
		if frames == 4:
			root.get_texture().get_image().save_png("C:/Users/asgei/AppData/Local/Temp/claude/C--Users-asgei-Desktop-student-game/660b3222-e610-4728-a13b-0960c6bbc8aa/scratchpad/br_" + pending + ".png")
			pending = ""; frames = 0
		return false
	match step:
		0: view(Vector3(-24.5, 1.5, 3.0), Vector3(-30.5, 1.5, 6.5), "a_corner", 85.0)
		1: view(Vector3(-26.5, 1.6, 8.5), Vector3(-26.0, 1.2, 3.5), "b_hall", 85.0)
		_: quit()
	return false
