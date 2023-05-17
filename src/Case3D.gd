class_name Space3D extends Node3D

@onready var rendering_button: CarouselButton = $InterfaceLayer/RenderButton
@onready var camera: Camera3D = $Camera3D
@onready var mesh_container: Node3D = $MeshContainer
const MIN_BALL_RADIUS = 0.5
const INPUT_MULT = 0.125
const INSERT_BALL_DIST_TIMES_RADIUS = 3.5

const drawing_states = [&"Show Nothing", &"Power Diagram"]
var drawing_state := drawing_states[0]
var draw_voronoi_cells := false

const exact_algorithm := &"sample_planes"
const arg_names := {
	&"monte_carlo": ["Checks"],
	&"monte_carlo_2": ["Checks"],
	&"sample_points": ["Divisions"],
	&"sample_planes": ["Divisions"],
}

var queued_for_redraw := false

var max_offset := 0.0
var average_radius := 0.0

var ball_set: Array[Ball3D]
var selected_ball: Ball3D = null
var selected_ball_idx := -1


func _process(_delta: float) -> void:
	if queued_for_redraw:
		redraw()
		queued_for_redraw = false

func queue_redraw() -> void:
	queued_for_redraw = true

func redraw() -> void:
	for node in mesh_container.get_children():
		node.queue_free()
	
	# Boundary
	var bound_mesh := SphereMesh.new()
	bound_mesh.material = StandardMaterial3D.new()
	bound_mesh.material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bound_mesh.material.albedo_color = Color(0.7, 0.8, 1.0, 0.005)
	bound_mesh.radius = max_offset
	bound_mesh.height = max_offset * 2
	bound_mesh.material.cull_mode = StandardMaterial3D.CULL_DISABLED
	var bound_mesh_instance := MeshInstance3D.new()
	bound_mesh_instance.mesh = bound_mesh
	bound_mesh_instance.position = Vector3.ZERO
	bound_mesh_instance.layers = 2
	mesh_container.add_child(bound_mesh_instance)
	
	# Add spheres
	var base_color := Color.from_hsv(1.0 / (ball_set.size() + 1), 0.8, 1.0)
	for i in ball_set.size():
		var ball = ball_set[i]
		var tint = Color(base_color, 0.15 if selected_ball_idx == i else 0.1)
		tint.h *= i
		# Make the sphere mesh.
		var ball_mesh := SphereMesh.new()
		ball_mesh.material = StandardMaterial3D.new()
		ball_mesh.material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ball_mesh.material.cull_mode = StandardMaterial3D.CULL_DISABLED
		ball_mesh.material.albedo_color = tint
		ball_mesh.radius = ball.R
		ball_mesh.height = ball.R * 2
		# Make the mesh instance.
		var ball_mesh_instance := MeshInstance3D.new()
		ball_mesh_instance.mesh = ball_mesh
		ball_mesh_instance.position = ball.P
		mesh_container.add_child(ball_mesh_instance)
		# Make the label.
		var label := Label3D.new()
		label.text = str(i)
		label.font_size = 240
		label.outline_size = 0
		label.position = ball.P
		mesh_container.add_child(label)
	
	if draw_voronoi_cells:
		var file := FileAccess.open("user://balls.txt", FileAccess.WRITE)
		file.store_string("")
		for idx in ball_set.size():
			var ball := ball_set[idx]
			file.store_line("%d %f %f %f %f" % [idx, ball.P.x, ball.P.y, ball.P.z, ball.R])
		file.flush()
		
		
		var bounds := Space3D.find_bounds(ball_set)
		bounds.left -= 2
		bounds.right += 2
		bounds.down -= 2
		bounds.up += 2
		bounds.forward -= 2
		bounds.backward += 2
		var args := PackedStringArray(["-o", "-r", "-c", '"%i', '%w', '%s', '%P', '%t"',
				str(bounds.left), str(bounds.right), str(bounds.down),
				str(bounds.up), str(bounds.forward), str(bounds.backward),
				ProjectSettings.globalize_path("user://balls.txt")])
		OS.execute("voro++", args)
		
		var output := FileAccess.get_file_as_string("user://balls.txt.vol")
		var lines := output.split("\n")
		for line in lines:
			if line.is_empty():
				continue
			var split_line := line.split(" ")
			var id := split_line[0].to_int()
			var points_count := split_line[1].to_int()
			var faces_count := split_line[2].to_int()
			var points: Array[Vector3] = []
			var faces: Array[Array] = []
			
			var current_idx := 3
			for i in points_count:
				var S := split_line[current_idx].left(-1).right(-1).split(",")
				points.append(Vector3(S[0].to_float(), S[1].to_float(), S[2].to_float()))
				current_idx += 1
			for i in faces_count:
				var ints := split_line[current_idx].split(",")
				var arr := []
				for j in ints:
					arr.append(j.to_int())
				faces.append(arr)
				current_idx += 1
			
			var imesh := ImmediateMesh.new()
			for face in faces:
				var coords_arr := PackedVector3Array()
				var coords2d_arr := PackedVector2Array()
				for vertex_idx in face:
					coords_arr.append(points[vertex_idx])
					coords2d_arr.append(Vector2(points[vertex_idx].x, points[vertex_idx].y))
				var point_count := coords_arr.size()
				
				var boundary_face := false
				var x_arr := []
				var y_arr := []
				var z_arr := []
				for coords in coords_arr:
					x_arr.append(coords.x)
					y_arr.append(coords.y)
					z_arr.append(coords.z)
				
				if x_arr.count(bounds.left) == point_count or\
				x_arr.count(bounds.right) == point_count or\
				y_arr.count(bounds.forward) == point_count or\
				y_arr.count(bounds.backward) == point_count or\
				z_arr.count(bounds.up) == point_count or\
				z_arr.count(bounds.down) == point_count:
					continue
				
				var triangulation_indices := Geometry2D.triangulate_polygon(coords2d_arr)
				for i in int(triangulation_indices.size() / 3.0):
					var vertex1 := coords_arr[triangulation_indices[3*i]]
					var vertex2 := coords_arr[triangulation_indices[3*i+1]]
					var vertex3 := coords_arr[triangulation_indices[3*i+2]]
					imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
					imesh.surface_add_vertex(vertex1)
					imesh.surface_add_vertex(vertex2)
					imesh.surface_add_vertex(vertex3)
					imesh.surface_end()
			var voronoi_mesh_material := StandardMaterial3D.new()
			voronoi_mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			voronoi_mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			voronoi_mesh_material.cull_mode = StandardMaterial3D.CULL_DISABLED
			voronoi_mesh_material.albedo_color = Color(0.82, 0.88, 1.0, 0.01)
			var voronoi_mesh_instance := MeshInstance3D.new()
			voronoi_mesh_instance.mesh = imesh
			voronoi_mesh_instance.material_overlay = voronoi_mesh_material
			mesh_container.add_child(voronoi_mesh_instance)

func _ready() -> void:
	rendering_button.options = drawing_states
	rendering_button.item = 0
	camera.position.z = absf(max_offset + average_radius) * 1.25
	generate_new()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Deselect or remove ball.
		if not event.is_pressed():
			if event.button_index == MOUSE_BUTTON_RIGHT:
				if event.is_ctrl_pressed() and selected_ball != null:
					ball_set.remove_at(selected_ball_idx)
					UI.update_gen_info(ball_set)
					queue_redraw()
				elif not event.is_ctrl_pressed():
					var from := camera.project_ray_origin(event.position)
					var delta := camera.project_ray_normal(event.position) *\
							average_radius * INSERT_BALL_DIST_TIMES_RADIUS
					if Vector3.ZERO.distance_squared_to(from + delta) > max_offset ** 2:
						var query_output := Geometry3D.segment_intersects_sphere(from,
								from + delta * 420, Vector3.ZERO, max_offset)
						if not query_output.is_empty():
							ball_set.append(Ball3D.new(query_output[0], average_radius))
					else:
						ball_set.append(Ball3D.new(from + delta, average_radius))
					
					UI.update_gen_info(ball_set)
					queue_redraw()
			selected_ball = null
			selected_ball_idx = -1
			queue_redraw()
			return
	
		var closest_ball: Ball3D = null
		var closest_ball_idx := -1
		var closest_dist := INF
		for idx in ball_set.size():
			var ball := ball_set[idx]
			var from := camera.project_ray_origin(event.position)
			var query_output := Geometry3D.segment_intersects_sphere(from,
					from + camera.project_ray_normal(event.position) * 420, ball.P, ball.R)
			if query_output.is_empty():
				continue
			
			var dist_to_ball := camera.position.distance_squared_to(query_output[0])
			if dist_to_ball < closest_dist:
				closest_dist = dist_to_ball
				closest_ball_idx = idx
				closest_ball = ball_set[idx]
		selected_ball = closest_ball
		selected_ball_idx = closest_ball_idx
	
	if event is InputEventMouseMotion and event.button_mask == MOUSE_BUTTON_LEFT:
		if selected_ball == null:
			return
		
		if event.is_ctrl_pressed():
			selected_ball.R = maxf(selected_ball.R + event.relative.x * INPUT_MULT,
					MIN_BALL_RADIUS)
			UI.update_gen_info(ball_set)
			queue_redraw()
		else:
			var from := camera.project_ray_origin(event.position)
			selected_ball.P = from + camera.project_ray_normal(event.position) *\
					camera.position.distance_to(selected_ball.P)
			selected_ball.P = selected_ball.P.limit_length(max_offset)
			UI.update_gen_info(ball_set)
			queue_redraw()

func generate_new() -> void:
	ball_set.clear()
	max_offset = Config.max_offset
	average_radius = (Config.max_radius + Config.min_radius) / 2.0
	# Generation
	for i in Config.count:
		var abstract_ball := Ball3D.new(Vector3.ZERO, max_offset)
		ball_set.append(Ball3D.new(abstract_ball.rand_inside(),
				randf_range(Config.min_radius, Config.max_radius)))
	queue_redraw()
	UI.update_gen_info(ball_set)


# Algorithms

static func monte_carlo(balls: Array[Ball3D], checks_count: int) -> float:
	for ball in balls:
		ball.init_radius_squared()
	var bounds := Space3D.find_bounds(balls)
	# Run checks.
	var points_inside := 0
	for i in checks_count:
		var checked_pos := Vector3(randf_range(bounds.left, bounds.right), randf_range(
				bounds.up, bounds.down), randf_range(bounds.backward, bounds.forward))
		if Space3D.is_point_in_ball(checked_pos, balls):
			points_inside += 1
	# Estimate volume.
	return (bounds.right - bounds.left) * (bounds.up - bounds.down) *\
			(bounds.backward - bounds.forward) * points_inside / checks_count

static func sample_points(balls: Array[Ball3D], divisions: int) -> float:
	for ball in balls:
		ball.init_radius_squared()
	var bounds := Space3D.find_bounds(balls)
	
	var step_size_x := (bounds.right - bounds.left) / divisions
	var step_size_y := (bounds.up - bounds.down) / divisions
	var step_size_z := (bounds.backward - bounds.forward) / divisions
	var estimated_V := 0.0
	var x_start := bounds.left - step_size_x / 2
	var y_start := bounds.down - step_size_y / 2
	var checked_pos := Vector3(x_start, y_start, bounds.forward - step_size_z / 2)
	while checked_pos.z < bounds.backward:
		checked_pos.y = y_start
		checked_pos.z += step_size_z
		while checked_pos.y < bounds.up:
			checked_pos.x = x_start
			checked_pos.y += step_size_y
			while checked_pos.x < bounds.right:
				checked_pos.x += step_size_x
				for ball in balls:
					var dist_to_center := ball.P.distance_squared_to(checked_pos)
					if dist_to_center < ball.radius_squared:
						estimated_V += step_size_x * step_size_y * step_size_z
						break
	return estimated_V

static func sample_planes(balls: Array[Ball3D], divisions: int = 256) -> float:
	for ball in balls:
		ball.init_radius_squared()
	var bounds := Space3D.find_bounds(balls)
	
	var estimated_V := 0.0
	var step_size := (bounds.backward - bounds.forward) / divisions
	# Create a Space2D with the relevant balls.
	var checked_ypos := bounds.down - step_size / 2
	while checked_ypos < bounds.up - step_size:
		checked_ypos += step_size
		# Construct a plane at the given height.
		var plane_balls: Array[Ball2D] = []
		for ball in balls:
			var y_dist := absf(checked_ypos - ball.P.y)
			if y_dist < ball.R:
				plane_balls.append(Ball2D.new(Vector2(ball.P.x, ball.P.z),
						sqrt(ball.radius_squared - y_dist * y_dist)))
		estimated_V += Space2D.green_algorithm(plane_balls) * step_size
	return estimated_V

static func monte_carlo_2(balls: Array[Ball3D], checks_count: int) -> float:
	# Distribute checks fairly.
	var naive_volume := 0.0
	for ball in balls:
		ball.init_volume()
		ball.init_radius_squared()
		naive_volume += ball.volume
	
	var estimated_V := 0.0
	for idx in balls.size():
		var checks_inside_cell := 0
		var scaled_checks := int(checks_count * balls[idx].volume / naive_volume)
		if scaled_checks != 0:
			for i in scaled_checks:
				var is_in_cell := true
				var check_pos := balls[idx].rand_inside()
				for j in range(idx + 1, balls.size()):
					if balls[j].P.distance_squared_to(check_pos) < balls[j].radius_squared:
						is_in_cell = false
						break
				if is_in_cell:
					checks_inside_cell += 1
			estimated_V += balls[idx].volume * float(checks_inside_cell) / scaled_checks
	return estimated_V


# Helpers

static func is_point_in_ball(point: Vector3, balls: Array[Ball3D]) -> bool:
	for ball in balls:
		if ball.P.distance_squared_to(point) < ball.radius_squared:
			return true
	return false

static func intersecting(B1: Ball3D, B2: Ball3D) -> bool:
	var d := B1.P.distance_squared_to(B2.P)
	return not d > (B1.R + B2.R) ** 2 and not d <= absf(B1.R - B2.R) ** 2

static func find_bounds(balls: Array[Ball3D]) -> Bounds3D:
	var bounds := Bounds3D.new(INF, -INF, INF, -INF, INF, -INF)
	for ball in balls:
		bounds.left = minf(ball.P.x - ball.R, bounds.left)
		bounds.right = maxf(ball.P.x + ball.R, bounds.right)
		bounds.down = minf(ball.P.y - ball.R, bounds.down)
		bounds.up = maxf(ball.P.y + ball.R, bounds.up)
		bounds.forward = minf(ball.P.z - ball.R, bounds.forward)
		bounds.backward = maxf(ball.P.z + ball.R, bounds.backward)
	return bounds

static func appoximate_volume(ball: Ball3D) -> float:
	return 0.0  # Not implemented
#	var truncations: Array[Plane]
#	var total_V := ball.R ** 3
#	var in_brackets := (4 * PI) / 3.0
#	for plane in truncations:
#		var integral := 0
#		for j in range(0, ball.R, 0.1):
#			integral += sqrt(ball.R ** 2 - plane.distance_to(ball.P) ** 2) * 0.1
#		in_brackets -= plane.distance_to(ball.P) * integral
#	total_V *= in_brackets
#	return total_V

func _on_render_button_carouseled() -> void:
	drawing_state = rendering_button.get_current()
	draw_voronoi_cells = (drawing_state == &"Power Diagram")
	queue_redraw()
