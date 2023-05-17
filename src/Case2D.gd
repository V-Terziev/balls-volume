class_name Space2D extends Node2D

@onready var rendering_button: CarouselButton = $InterfaceLayer/RenderButton
@onready var camera: Camera2D = $Camera2D
const MIN_BALL_RADIUS = 4.0

const drawing_states = [&"Show Nothing", &"Power Delaunay", &"Power Diagram", &"Show All"]
var drawing_state := drawing_states[0]
var draw_power_triangulation := false
var draw_voronoi_cells := false

const exact_algorithm := &"green_algorithm"
const arg_names := {
	&"monte_carlo": ["Checks"],
	&"monte_carlo_2": ["Checks"],
	&"sample_points": ["Divisions"],
	&"sample_lines": ["Divisions"],
	&"green_algorithm": [],
	&"voronoi_run": [],
}

var max_offset := 0.0
var average_radius := 0.0

var ball_set: Array[Ball2D]
var selected_ball: Ball2D = null
var selected_ball_idx := -1

var convex_hull_pid := -1
func _enter_tree() -> void:
	convex_hull_pid = OS.create_process("python3", PackedStringArray(["src/CHull.py"]))

func _exit_tree() -> void:
	OS.kill(convex_hull_pid)


func _ready() -> void:
	rendering_button.options = drawing_states
	rendering_button.item = 0
	generate_new()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Deselect or remove ball.
		if not event.is_pressed():
			if event.button_index == MOUSE_BUTTON_RIGHT:
				if event.is_ctrl_pressed() and selected_ball != null:
					ball_set.remove_at(selected_ball_idx)
					_update_balls()
				elif not event.is_ctrl_pressed():
					ball_set.append(Ball2D.new(get_global_mouse_position().limit_length(
							max_offset), average_radius))
					_update_balls()
			selected_ball = null
			selected_ball_idx = -1
			queue_redraw()
			return
		
		var closest_ball: Ball2D = null
		var closest_ball_idx := -1
		var closest_dist := INF
		for idx in ball_set.size():
			var ball := ball_set[idx]
			var dist_to_click: float = ball.P.distance_squared_to(get_global_mouse_position())
			if dist_to_click < maxf(MIN_BALL_RADIUS, ball.R) ** 2 and\
			dist_to_click < closest_dist:
				closest_ball = ball
				closest_ball_idx = idx
				closest_dist = dist_to_click
		selected_ball = closest_ball
		selected_ball_idx = closest_ball_idx
	
	if event is InputEventMouseMotion and event.button_mask == MOUSE_BUTTON_LEFT:
		if selected_ball == null:
			return
		
		if event.is_ctrl_pressed():
			selected_ball.R = maxf(selected_ball.R + event.relative.x, MIN_BALL_RADIUS)
			_update_balls()
		else:
			selected_ball.P = get_global_mouse_position()
			selected_ball.P = selected_ball.P.limit_length(max_offset)
			_update_balls()

func generate_new() -> void:
	ball_set.clear()
	max_offset = Config.max_offset
	average_radius = (Config.max_radius + Config.min_radius) / 2.0
	# Generation
	for i in Config.count:
		var abstract_ball := Ball2D.new(Vector2.ZERO, max_offset)
		ball_set.append(Ball2D.new(abstract_ball.rand_inside(),
				randf_range(Config.min_radius, Config.max_radius)))
	_update_balls()


# Algorithms

static func voronoi_run(balls: Array[Ball2D]) -> float:
	# Resolve the <3 balls case immediately, makes things easier afterwards.
	if balls.size() == 0:
		return 0.0
	elif balls.size() == 1:
		return balls[0].V()
	elif balls.size() == 2:
		var R0 := balls[0].R
		var R1 := balls[1].R
		var distance_squared := balls[0].P.distance_squared_to(balls[1].P)
		
		if distance_squared <= (R0 - R1) ** 2:
			return maxf(R0, R1) ** 2 * PI
		elif distance_squared >= (R0 + R1) ** 2:
			return (R0 * R0 + R1 * R1) * PI
		
		var distance := sqrt(distance_squared)
		var angle1 := 2 * acos((R0 ** 2 + distance_squared - R1 ** 2) / (2 * R0 * distance))
		var angle2 := 2 * acos((R1 ** 2 + distance_squared - R0 ** 2) / (2 * R1 * distance))
		var area1 := 0.5 * angle1 * R0 ** 2 - 0.5 * R0 ** 2 * sin(angle1)
		var area2 := 0.5 * angle2 * R1 ** 2 - 0.5 * R1 ** 2 * sin(angle2)
		var overlap := area1 + area2
		
		return (R0 * R0 + R1 * R1) * PI - overlap
	
	# DEFAULT CASE STARTS HERE
	var total_V := 0.0
	var arr := Space2D.get_power_triangulation(balls)
	var tri_list = arr[0]
	var V = arr[1]
	var voronoi_cell_map := Space2D.get_voronoi_cells(balls, V, tri_list)
	for ball_idx in balls.size():
		if not ball_idx in voronoi_cell_map:
			continue
		
		var ball := balls[ball_idx]
		var voronoi_cell: Array = voronoi_cell_map[ball_idx]
		
		var used_ids := []
		for bs in voronoi_cell:
			var id: Array = bs[0]
			if [id[1], id[0]] in used_ids:
				voronoi_cell.erase(bs)
			else:
				used_ids.append(id)
		
		# First find if the ball's center is inside the cell.
		# TODO This should be possible with simply each edge's line equation.
		var edge_arr := []
		var staple_tri: Array
		var staple_point: Vector2
		
		var values_obtained := 0
		for edge in voronoi_cell:
			edge_arr.append(Space2D.get_finite_segment(edge, 128, false))
			if values_obtained == 0:
				staple_tri = [edge_arr[0][0], edge_arr[0][1]]
				values_obtained = 2
			elif values_obtained == 2:
				if staple_tri[0].is_equal_approx(edge_arr[1][0]) or\
				staple_tri[1].is_equal_approx(edge_arr[1][0]):
					staple_tri.append(edge_arr[1][1])
				else:
					staple_tri.append(edge_arr[1][0])
				values_obtained = 3
		
		staple_point = (((staple_tri[0] + staple_tri[1]) / 2) + staple_tri[2]) / 2
		
		for edge in edge_arr:
			var v1 = edge[0] - edge[1]
			var v2 = staple_point - edge[1]
			var v3 = ball.P - edge[1]
			var cp1 = v1.cross(v2)
			var cp2 = v1.cross(v3)
			var is_P_inside := signf(cp1) == signf(cp2)
		# TODO Finish implementation.
	
	# Green theorem for integrating along the boundary. Didn't work, so might be wrong.
	# Line segment: p0.x * p1.y + p0.y * p1.x
	# Circular arc: Cx*(y1-y0) - Cy*(x1-x0) ) + R^2*(t1-t0)
	return total_V

static func green_algorithm(balls: Array[Ball2D]) -> float:
	# Remove balls that are fully inside another.
	for i in range(balls.size() - 1, -1, -1):
		for j in range(i - 1, -1, -1):
			var distance := balls[i].P.distance_to(balls[j].P)
			if distance + balls[j].R <= balls[i].R or distance + balls[i].R <= balls[j].R:
				balls.remove_at(i if balls[i].R < balls[j].R else j)
				break
	
	for ball in balls:
		ball.init_radius_squared()
	
	var total_V := 0.0
	for i in balls.size():
		var ball := balls[i]
		var i_pts: Array[Vector2] = []  # Intersection points
		for j in balls.size():
			var ball2 := balls[j]
			if i == j or not Space2D.intersecting(ball, ball2):
				continue
			
			var Pi := ball.P
			var Pj := ball2.P
			var Ri := ball.R
			var Rj := ball2.R
			# For intersection between two circles there are two points.
			# The thetas represent the points' position along the circle in rad.
			# The Y axis is down in 2D software, meaning the measurements are clockwise!
			var ans_arr := Space2D.line_intersect(ball, 2 * (Pj.x - Pi.x), 2 * (Pj.y - Pi.y),
					Ri * Ri - Rj * Rj + Pj.x * Pj.x - Pi.x * Pi.x + Pj.y * Pj.y - Pi.y * Pi.y)
			var blah1 := ans_arr[0] - Pi
			var blah2 := ans_arr[1] - Pi
			# Separate case for y < 0 is needed as Godot's angle() returns negative then.
			var theta1 := blah1.angle() if blah1.y >= 0 else TAU + blah1.angle()
			var theta2 := blah2.angle() if blah2.y >= 0 else TAU + blah2.angle()
			
			var avg_angle := (theta1 + theta2) / 2.0  # Middle of the intersection arc
			# Make it so theta2 >= theta1.
			if theta1 > theta2:
				var temp := theta2
				theta2 = theta1
				theta1 = temp
			
			# If the rightmost part of the circle (0 rad) is inside the other circle,
			# then save the intersection segment in two parts to preserve it properly.
			if (Pj.x - Pi.x - Ri * cos(avg_angle)) ** 2 +\
			(Pj.y - Pi.y - Ri * sin(avg_angle)) ** 2 < Rj * Rj:
				i_pts.append(Vector2(theta1, theta2))
			else:
				var adjusted_angle := fmod(avg_angle + PI, TAU)
				if (Pj.x - Pi.x - Ri * cos(adjusted_angle)) ** 2 +\
				(Pj.y - Pi.y - Ri * sin(adjusted_angle)) ** 2 < Rj * Rj:
					i_pts.append(Vector2(theta2, TAU))
					i_pts.append(Vector2(0.0, theta1))
		
		if i_pts.size() == 0:
			# No intersections, just add the ball's area.
			total_V += ball.V()
		else:
			i_pts.sort()
			var theta1 := i_pts[0].x
			var theta2 := i_pts[0].y
			var arcs: Array[Vector2] = [Vector2(0.0, theta1)]
			
			for j in i_pts.size():
				while j < i_pts.size() and theta2 >= i_pts[j].x:
					theta2 = maxf(i_pts[j].y, theta2)
					j += 1
				if j < i_pts.size():
					arcs.append(Vector2(theta2, i_pts[j].x))
					theta1 = i_pts[j].x
					theta2 = i_pts[j].y
			arcs.append(Vector2(theta2, TAU))
			# arcs now contains the ranges in rad, in which the circles' outlines
			# are outside other circles. 0 and TAU are used too.
			for j in arcs.size():
				var arc := arcs[j]  # x is starting angle, y is end. They aren't coords!
				
				total_V += (ball.R * (ball.P.x * sin(arc.y)) +\
						ball.radius_squared * (arc.y + sin(arc.y) * cos(arc.y)) * 0.5) -\
						(ball.R * (ball.P.x * sin(arc.x)) +\
						ball.radius_squared * (arc.x + sin(arc.x) * cos(arc.x)) * 0.5)
	return total_V

static func monte_carlo(balls: Array[Ball2D], checks_count: int) -> float:
	for ball in balls:
		ball.init_radius_squared()
	var bounds := Space2D.find_bounds(balls)
	# Run checks.
	var points_inside := 0
	for i in checks_count:
		var checked_pos := Vector2(randf_range(bounds.left, bounds.right),
				randf_range(bounds.up, bounds.down))
		if Space2D.is_point_in_ball(checked_pos, balls):
			points_inside += 1
	# Estimate volume.
	return (bounds.right - bounds.left) * (bounds.down - bounds.up) * points_inside /\
			checks_count

static func sample_points(balls: Array[Ball2D], divisions: int) -> float:
	for ball in balls:
		ball.init_radius_squared()
	var bounds := Space2D.find_bounds(balls)
	
	var step_size_x := (bounds.right - bounds.left) / divisions
	var step_size_y := (bounds.down - bounds.up) / divisions
	var estimated_V := 0.0
	# Walk through from left to right, top to bottom. If the point is inside a ball,
	# assume that the entire adjacent volume is filled and add it.
	var x_start := bounds.left - step_size_x / 2
	var checked_pos := Vector2(x_start, bounds.up - step_size_y / 2)
	while checked_pos.y < bounds.down:
		checked_pos.x = x_start
		checked_pos.y += step_size_y
		while checked_pos.x < bounds.right:
			checked_pos.x += step_size_x
			for idx in balls.size():
				var ball = balls[idx]
				if ball.P.distance_squared_to(checked_pos) < ball.radius_squared:
					# Reorder the array so the ball is at the beginning and gets checked early.
					if idx > 0:
						var temp := balls[0]
						balls[0] = balls[idx]
						balls[idx] = temp
					estimated_V += step_size_x * step_size_y
					break
	return estimated_V

static func sample_lines(balls: Array[Ball2D], divisions: int) -> float:
	for ball in balls:
		ball.init_radius_squared()
	var bounds := Space2D.find_bounds(balls)
	
	var estimated_V := 0.0
	var step_size := (bounds.down - bounds.up) / divisions
	# Create a Space1D with the relevant balls.
	var checked_ypos := bounds.up - step_size / 2
	while checked_ypos < bounds.down - step_size:
		checked_ypos += step_size
		# Construct a line at the given height.
		var line_balls: Array[Ball1D] = []
		for ball in balls:
			var y_dist := absf(checked_ypos - ball.P.y)
			if y_dist < ball.R:
				line_balls.append(Ball1D.new(ball.P.x,
						sqrt(ball.radius_squared - y_dist * y_dist)))
		estimated_V += Space1D.exact(line_balls) * step_size
	return estimated_V

static func monte_carlo_2(balls: Array[Ball2D], checks_count: int) -> float:
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

static func is_point_in_ball(point: Vector2, balls: Array[Ball2D]) -> bool:
	for ball in balls:
		if ball.P.distance_squared_to(point) < ball.radius_squared:
			return true
	return false

static func intersecting(B1: Ball2D, B2: Ball2D) -> bool:
	var d := B1.P.distance_squared_to(B2.P)
	return not d > (B1.R + B2.R) ** 2 and not d <= (absf(B1.R - B2.R)) ** 2

static func get_segment_ball_intersection(p0: Vector2, p1: Vector2, B: Ball2D) -> Vector2:
	return p0.lerp(p1, Geometry2D.segment_intersects_circle(p0, p1, B.P, B.R))

static func find_bounds(balls: Array[Ball2D]) -> Bounds2D:
	var bounds := Bounds2D.new(INF, -INF, INF, -INF)
	for ball in balls:
		bounds.left = minf(ball.P.x - ball.R, bounds.left)
		bounds.right = maxf(ball.P.x + ball.R, bounds.right)
		bounds.up = minf(ball.P.y - ball.R, bounds.up)
		bounds.down = maxf(ball.P.y + ball.R, bounds.down)
	return bounds


# Extra helpers for Green's algorithm

static func line_intersect(ball: Ball2D, a: float, b: float, c: float) -> Array[Vector2]:
	var X := ball.P.x
	var Y := ball.P.y
	if b != 0:
		var ab := a/b
		var cbm := c/b - Y
		var roots := Utils.solve_QE(1 + ab * ab, -2 * X - 2 * ab * cbm,
				X * X + cbm * cbm - ball.radius_squared)
		return [Vector2(roots[0], (c - a * roots[0]) / b),
				Vector2(roots[1], (c - a * roots[1]) / b)]
	else:
		var ca := c/a
		var roots := Utils.solve_QE(1, -2 * Y, Y * Y + (ca - X)**2 - ball.radius_squared)
		return [Vector2(ca, roots[0]), Vector2(ca, roots[1])]


# Rendering

class Triangle:
	var point1: int
	var point2: int
	var point3: int
	func _init(p1: int, p2: int, p3: int) -> void:
		point1 = p1
		point2 = p2
		point3 = p3
	func get_point(idx: int) -> int:
		return point1 if idx == 0 else point2 if idx == 1 else point3


func _update_balls() -> void:
	UI.update_gen_info(ball_set)
	queue_redraw()

func _draw() -> void:
	# Boundary
	draw_circle(Vector2.ZERO, max_offset, Color(0.7, 0.8, 1.0, 0.01))
	draw_arc(Vector2.ZERO, max_offset - 2, 0, TAU, ceili(max_offset * 3),
			Color(0.7, 0.8, 1.0, 0.02), 4.0)
	
	# Circles
	var base_color := Color.from_hsv(1.0 / (ball_set.size() + 1), 0.8, 1.0)
	for i in ball_set.size():
		var ball := ball_set[i]
		var tint := base_color
		tint.h *= i
		draw_circle(ball.P, ball.R, Color(tint, 0.45 if selected_ball_idx == i else 0.3))
		draw_arc(ball.P, ball.R - 1, 0, TAU, ceili(ball.R * 3), tint, 2.0)
	
	# Power triangulation
	var arr := Space2D.get_power_triangulation(ball_set)
	var tri_list = arr[0]
	var V = arr[1]
	
	if draw_power_triangulation:
		var edge_set := []
		for tri in tri_list:
			for i in 3:
				var potential_edge := [tri.get_point(i), tri.get_point((i + 1) % 3)]
				potential_edge.sort()
				if potential_edge not in edge_set:
					edge_set.append(potential_edge)
		
		for edge in edge_set:
			draw_line(ball_set[edge[0]].P, ball_set[edge[1]].P,
					Color(0.7, 0.8, 1.0, 0.25), 0.75, true)
	
	# Voronoi cells
	if draw_voronoi_cells:
		var voronoi_cell_map := Space2D.get_voronoi_cells(ball_set, V, tri_list)
		var edge_map := {}
		for segment_list in voronoi_cell_map.values():
			for idx in segment_list.size():
				var edge = segment_list[idx][0]
#				if not edge_map.has(edge) and not edge_map.has([edge[1], edge[0]]):
				edge_map[edge] = Space2D.get_finite_segment(segment_list[idx])
		
		for value in edge_map.values():
			draw_line(value[0], value[1], Color(0.82, 0.88, 1.0), 1.0, true)
	
	# Labels
	for i in ball_set.size():
		var ball := ball_set[i]
		var s := str(i)
		draw_string(UI.font, ball.P - Vector2(s.length() * 3.5, -5), s,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 12)


static func get_power_triangulation(balls: Array[Ball2D]) -> Array:
	var balls_size := balls.size()
	if balls_size < 3:
		return [[], []]
	
	var S := PackedVector2Array()
	var R := PackedFloat64Array()
	for i in balls_size:
		S.append(balls[i].P)
		R.append(balls[i].R)
	# Compute the lifted weighted points.
	var S_lifted := []
	for i in balls_size:
		S_lifted.append(Vector3(S[i].x, S[i].y, S[i].dot(S[i]) - R[i] * R[i]))
	
	# Special case for 3 points
	if balls_size == 3:
		return [[Triangle.new(0, 1, 2)], [Utils.get_power_circumcenter(
				S_lifted[0], S_lifted[1], S_lifted[2])]] if Utils.is_ccw_triangle(
				S[0], S[1], S[2]) else [[Triangle.new(0, 2, 1)],
				[Utils.get_power_circumcenter(S_lifted[0], S_lifted[2], S_lifted[1])]]
	
	var convex_hull_routine := HTTPClient.new()
	var headers := PackedStringArray(["User-Agent: CHull/1.0 (godot)", "Accept: */*"])
	
	assert(convex_hull_routine.connect_to_host("localhost", 8000) == OK)
	while convex_hull_routine.get_status() in\
	[HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		convex_hull_routine.poll()
		OS.delay_msec(1)
	if convex_hull_routine.get_status() != HTTPClient.STATUS_CONNECTED:
		return [[], []]
	
	# Compute the convex hull of the lifted weighted points.
	var url := "http://localhost:8000/?params=" + str(S_lifted.size()) + "&"
	for i in S_lifted.size():
		var idx_str := str(i) + "="
		url += "x" + idx_str + str(S_lifted[i].x) + "&"
		url += "y" + idx_str + str(S_lifted[i].y) + "&"
		url += "z" + idx_str + str(S_lifted[i].z)
		if i != S_lifted.size() - 1:
			url += "&"
	assert(convex_hull_routine.request(HTTPClient.METHOD_GET, url, headers) == OK)
	while convex_hull_routine.get_status() == HTTPClient.STATUS_REQUESTING:
		convex_hull_routine.poll()
		OS.delay_msec(1)
	
	if not convex_hull_routine.get_status() in [HTTPClient.STATUS_BODY,
	HTTPClient.STATUS_CONNECTED] or not convex_hull_routine.has_response():
		return [[], []]
	
	var body := PackedByteArray() # Array that will hold the data.
	while convex_hull_routine.get_status() == HTTPClient.STATUS_BODY:
		convex_hull_routine.poll()
		var chunk = convex_hull_routine.read_response_body_chunk()
		if chunk.size() == 0:
			OS.delay_msec(1)
		else:
			body += chunk
	var outputs := body.get_string_from_utf8().split("\n")
	
	# Extract the Delaunay triangulation from the lower hull.
	var tri_list := []
	for i in outputs.size() - 1:
		var equation_z = outputs[i].get_slice(" ", 3).to_float()
		if equation_z <= 0:
			var a = outputs[i].get_slice(" ", 0).to_int()
			var b = outputs[i].get_slice(" ", 1).to_int()
			var c = outputs[i].get_slice(" ", 2).to_int()
			tri_list.append(Triangle.new(a, b, c))
	
	for idx in range(tri_list.size() - 1, -1):
		if tri_list[idx].point1 == tri_list[idx].point2 and\
		tri_list[idx].point1 == tri_list[idx].point2:
			tri_list.remove_at(idx)
	
	# Compute the Voronoi points.
	var V := PackedVector2Array()
	for tri in tri_list:
		V.append(Utils.get_power_circumcenter(S_lifted[tri.point1],
				S_lifted[tri.point2], S_lifted[tri.point3]))
	
	return [tri_list, V]

static func get_voronoi_cells(balls: Array[Ball2D],
V: PackedVector2Array, tri_list) -> Dictionary:
	var balls_size := balls.size()
	for tri in tri_list:
		if tri.point1 >= balls_size or tri.point2 >= balls_size or tri.point3 >= balls_size:
			return {}
	
	var S := PackedVector2Array()
	for i in balls_size:
		S.append(balls[i].P)
	
	# Two circles special case
	if balls_size == 2:
		var s0 := S[0]
		var s1 := S[1]
		var r0 := balls[0].R
		var r1 := balls[1].R
		if r0 < r1:
			var temp := s0
			s0 = s1
			s1 = temp
			var temp2 := r0
			r0 = r1
			r1 = temp2
		var ds := s0.distance_squared_to(s1)
		var d := sqrt(ds)
		var midpoint := s0.lerp(s1, sqrt(r0 ** 2 - (r0 ** 2 -\
				((r0 ** 2 - r1 ** 2 + ds) / (2 * d)) ** 2)) / d)
		var inf_vec := (midpoint - s0).orthogonal()
		return { 0: [[[-1, 0], [midpoint, inf_vec, null, 0]],
				[[1, -1], [midpoint, inf_vec, 0, null]]],
				1: [[[-1, 0], [midpoint, inf_vec, null, 0]],
				[[1, -1], [midpoint, inf_vec, 0, null]]] }
	
	var included_vertices: Array[int] = []
	for tri in tri_list:
		for i in 3:
			var tri_vertex: int = tri.get_point(i)
			if not tri_vertex in included_vertices:
				included_vertices.append(tri_vertex)
	included_vertices.sort()
	
	var edge_map := {}
	for i in tri_list.size():
		var tri: Triangle = tri_list[i]
		for j in 3:
			var edge: Array = [tri.get_point(j), tri.get_point((j + 1) % 3)]
			edge.sort()
			if not edge in edge_map:
				edge_map[edge] = [i]
			else:
				edge_map[edge].append(i)
	
	# For each triangle
	var voronoi_cell_map := {}
	for vertex in included_vertices:
		voronoi_cell_map[vertex] = []
	
	for i in tri_list.size():
		for j in 3:
			var tri = tri_list[i]
			var u: int = tri.get_point(j)
			var v: int = tri.get_point((j + 1) % 3)
			var w: int = tri.get_point((j + 2) % 3)
			# Finite Voronoi edge.
			var edge := [u, v]
			edge.sort()
			if edge_map[edge].size() == 2:
				var m: int = edge_map[edge][0]
				var k: int = edge_map[edge][1]
				if k == i:
					# Swap.
					var temp := k
					k = m
					m = temp
				# Compute the segment parameters.
				var U := V[k] - V[m]
				var U_norm := U.length()
				# Add the segment.
				voronoi_cell_map[u].append([ [m, k], [V[m], U / U_norm, 0, U_norm] ])
			else:
				# Infinite Voronoi edge. Compute the segment parameters.
				var A := S[u]
				var B := S[v]
				var C := S[w]
				var D := V[i]
				var U := (B - A).normalized()
				var I := A + (D - A).dot(U) * U
				var W := (I - D).normalized()
				if W.dot(I - C) < 0:
					W = -W
				# Add the segment.
				voronoi_cell_map[u].append([ [edge_map[edge][0], -i*3 - j], [D, W, 0, null] ])
				voronoi_cell_map[v].append([ [-i*3 - j, edge_map[edge][0]], [D, -W, null, 0] ])
	
	var segment_list := {}
	for key in voronoi_cell_map.keys():
		segment_list[key] = Space2D.order_segment_list(voronoi_cell_map[key])
	
	return segment_list

static func order_segment_list(segment_list: Array) -> Array:
	# Pick the first element.
	var first := 0
	var min_start = segment_list[0][0][0]
	for i in segment_list.size():
		if segment_list[i][0][0] < min_start:
			first = i
			min_start = segment_list[i][0][0]
	
	# In-place ordering.
	var temp = segment_list[0]
	segment_list[0] = segment_list[first]
	segment_list[first] = temp
	
	for i in segment_list.size() - 1:
		for j in range(i + 1, segment_list.size()):
			if segment_list[i][0][1] == segment_list[j][0][0]:
				var temp2 = segment_list[i + 1]
				segment_list[i + 1] = segment_list[j]
				segment_list[j] = temp2
				break
	
	return segment_list

static func get_finite_segment(segment: Array, extend := 1024, outside := true) -> Array:
	var A = segment[1][0]
	var U = segment[1][1]
	var tmin = segment[1][2]
	var tmax = segment[1][3]
	
	if tmax == null:
		tmax = max(extend, Config.max_offset * 4 if outside else 0.0,
				4 * A.distance_to(Vector2.ZERO) if outside else 0.0)
	if tmin == null:
		tmin = -max(extend, Config.max_offset * 4 if outside else 0.0)
	
	return [A + tmin * U, A + tmax * U]


func _on_render_button_carouseled() -> void:
	drawing_state = rendering_button.get_current()
	draw_power_triangulation = (drawing_state in [&"Power Delaunay", &"Show All"])
	draw_voronoi_cells = (drawing_state in [&"Power Diagram", &"Show All"])
	queue_redraw()
