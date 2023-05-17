extends SubViewport

var space: Node = null
var NSpace: GDScript = Space2D

const PAN_SPEED = 600.0
const PAN_SPEED_3D = 45.0
const PAN_BUFFER_SIZE := 40
const PAN_BUFFER_SIZE_3D := 60

func change_case(scene: PackedScene) -> void:
	if space != null:
		space.queue_free()
	space = scene.instantiate()
	add_child(space)
	match Config.dimension:
		1: NSpace = Space1D
		2: NSpace = Space2D
		3: NSpace = Space3D

func run_algorithms() -> void:
	var true_V: float
	if not Config.print_volume:
		true_V = NSpace.call(NSpace.exact_algorithm, space.ball_set.duplicate())
	# Run the algorithms.
	var config := Config.config
	UI.algo_info.text = ""
	for foo in config.get_section_keys(Config.get_algo_section()):
		var balls: Array = space.ball_set.duplicate()
		var args: Array = [balls] + config.get_value(Config.get_algo_section(), foo)
		get_tree().get_root().set_disable_input(true)
		var V: float
		# Start benchmarking.
		var t: float = Time.get_ticks_usec()
		for i in Config.benchmark_runs:
			V = NSpace.callv(foo, args)
		t = (Time.get_ticks_usec() - t) / (Config.benchmark_runs * 1000.0)
		# End benchmarking.
		get_tree().get_root().set_disable_input(false)
		UI.algo_info.text += "%s() in %.2fms: " % [foo, t]
		if Config.print_volume:
			UI.algo_info.text += "Volume = %.2f\n" % V
		else:
			UI.algo_info.text += "Error = %.6f%%\n" % (absf(true_V - V) * 100 / true_V)


func _process(delta: float) -> void:
	var cam: Node = space.camera
	var old_cam_pos = cam.position
	match Config.dimension:
		1:
			var L := maxf(space.max_offset + Config.max_radius -\
					get_parent().size.x / 2 + PAN_BUFFER_SIZE, 0.0)
			var vec := Input.get_axis(&"left", &"right")
			cam.position.x += vec * PAN_SPEED * delta
			cam.position.x = clampf(cam.position.x, -L, L)
		2:
			var L := maxf(space.max_offset + Config.max_radius -\
					get_parent().size.x / 2 + PAN_BUFFER_SIZE, 0.0)
			var h_vec := Input.get_axis(&"left", &"right")
			var v_vec := Input.get_axis(&"up", &"down")
			if v_vec == 0:
				if Input.is_action_pressed(&"backward"):
					v_vec = -1
				elif Input.is_action_pressed(&"forward"):
					v_vec = 1
			cam.position += Vector2(h_vec, v_vec) * PAN_SPEED * delta
			cam.position = cam.position.clamp(Vector2(-L, -L), Vector2(L, L))
		3:
			var L := maxf(2 * space.max_offset + Config.max_radius, 0.0)
			var h_vec := Input.get_axis(&"left", &"right")
			var v_vec := Input.get_axis(&"down", &"up")
			if v_vec == 0:
				if Input.is_action_pressed(&"down_3d"):
					v_vec = -1
				elif Input.is_action_pressed(&"up_3d"):
					v_vec = 1
			var vec := Vector3(h_vec, v_vec, Input.get_axis(&"backward", &"forward"))
			cam.position += vec * PAN_SPEED_3D * delta
			cam.position = cam.position.clamp(Vector3(-L, -L, -L), Vector3(L, L, L))
	
	var selection = space.selected_ball
	if selection != null:
		if Config.dimension == 1:
			selection.P += cam.position.x - old_cam_pos.x
			selection.P = clampf(selection.P, -Config.max_offset, Config.max_offset)
		else:
			selection.P += cam.position - old_cam_pos
			selection.P = selection.P.limit_length(Config.max_offset)
		space.queue_redraw()
