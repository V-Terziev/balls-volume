class_name Space1D extends Node2D

@onready var camera: Camera2D = $Camera1D
const DRAW_WIDTH = 36
const MIN_BALL_RADIUS = 4.0

const exact_algorithm := &"exact"
const arg_names := {
	&"monte_carlo": ["Checks"],
	&"sample_points": ["Divisions"],
	&"exact": [],
}

var max_offset := 0.0
var average_radius := 0.0

var ball_set: Array[Ball1D]
var selected_ball: Ball1D = null
var selected_ball_idx := -1

func _draw() -> void:
	# Boundary
	draw_rect(Rect2(Vector2(-max_offset + 2.0, DRAW_WIDTH),
			Vector2(2 * max_offset - 4.0, -DRAW_WIDTH)), Color(0.7, 0.8, 1.0, 0.02))
	draw_line(Vector2(-max_offset, 0),
			Vector2(-max_offset, DRAW_WIDTH), Color(0.7, 0.8, 1.0, 0.04), 4.0)
	draw_line(Vector2(max_offset, 0),
			Vector2(max_offset, DRAW_WIDTH), Color(0.7, 0.8, 1.0, 0.04), 4.0)
	
	# Labels and ball insides
	var base_color := Color.from_hsv(1.0 / (ball_set.size() + 1), 0.8, 1.0)
	for i in ball_set.size():
		var ball := ball_set[i]
		var tint := base_color
		tint.h *= i
		draw_rect(Rect2(Vector2(ball.P - ball.R, DRAW_WIDTH),
				Vector2(ball.R * 2, -DRAW_WIDTH)),
				Color(tint, 0.45 if selected_ball_idx == i else 0.3), 1.0)
		var s := str(i)
		draw_string(UI.font, Vector2(ball.P - s.length() * 3.5, -5), s,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	
	# Ball outsides
	for i in ball_set.size():
		var ball := ball_set[i]
		var tint := base_color
		tint.h *= i
		draw_rect(Rect2(Vector2(ball.P - ball.R - 1.0, DRAW_WIDTH),
				Vector2(2.0, -DRAW_WIDTH)), tint, 1.0)
		draw_rect(Rect2(Vector2(ball.P + ball.R - 1.0, DRAW_WIDTH),
				Vector2(2.0, -DRAW_WIDTH)), tint, 1.0)

func _ready() -> void:
	generate_new()

var offset_from_center := 0.0
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if absf(get_global_mouse_position().y) >= DRAW_WIDTH:
			return
		# Deselect or remove ball.
		if not event.is_pressed():
			if event.button_index == MOUSE_BUTTON_RIGHT:
				if event.is_ctrl_pressed() and selected_ball != null:
					ball_set.remove_at(selected_ball_idx)
					UI.update_gen_info(ball_set)
					queue_redraw()
				elif not event.is_ctrl_pressed():
					ball_set.append(Ball1D.new(clampf(get_global_mouse_position().x,
							-max_offset, max_offset), average_radius))
					UI.update_gen_info(ball_set)
					queue_redraw()
			selected_ball = null
			selected_ball_idx = -1
			queue_redraw()
			return
		
		var closest_ball: Ball1D = null
		var closest_ball_idx := -1
		var closest_dist := INF
		for idx in ball_set.size():
			var ball := ball_set[idx]
			var dist_to_click := absf(ball.P - get_global_mouse_position().x)
			if dist_to_click < maxf(MIN_BALL_RADIUS, ball.R) and\
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
			UI.update_gen_info(ball_set)
			queue_redraw()
		else:
			selected_ball.P = get_global_mouse_position().x
			selected_ball.P = clampf(selected_ball.P, -max_offset, max_offset)
			UI.update_gen_info(ball_set)
			queue_redraw()

func generate_new() -> void:
	ball_set.clear()
	max_offset = Config.max_offset
	average_radius = (Config.max_radius + Config.min_radius) / 2.0
	# Generation
	for i in Config.count:
		ball_set.append(Ball1D.new(
				randf_range(-max_offset, max_offset),
				randf_range(Config.min_radius, Config.max_radius)))
	queue_redraw()
	UI.update_gen_info(ball_set)


# Algorithms

static func exact(balls: Array[Ball1D]) -> float:
	var total_V := 0.0
	var rightest_covered_edge := -INF
	
	# Cache edges
	for ball in balls:
		ball.init_left_edge()
		ball.init_right_edge()
	# Sort balls from leftmost to rightmost.
	balls.sort_custom(
		func(B1: Ball1D, B2: Ball1D) -> bool:
			return B1.left_edge > B2.left_edge
	)
	for i in balls.size():
		var ball: Ball1D = balls.pop_back()
		# New volume can be found by substracting the right edge by one of:
		# - rightest_covered_edge in case of partial overlap
		# - left edge in case of no overlap.
		# We must check which of these two values is further to the left.
		var new_V := ball.right_edge - maxf(ball.left_edge, rightest_covered_edge)
		if new_V > 0:
			# Negative value means the ball is completely inside the previous one.
			total_V += new_V
			rightest_covered_edge = ball.right_edge
	return total_V

static func monte_carlo(balls: Array[Ball1D], checks_count: int) -> float:
	var bounds := Space1D.find_bounds(balls)
	# Run checks.
	var points_inside := 0
	for i in checks_count:
		var checked_pos := randf_range(bounds.left, bounds.right)
		if Space1D.is_point_in_ball(checked_pos, balls):
			points_inside += 1
	# Estimate volume.
	return (bounds.right - bounds.left) * points_inside / checks_count

static func sample_points(balls: Array[Ball1D], divisions: int) -> float:
	var bounds := Space1D.find_bounds(balls)
	var step_size := (bounds.right - bounds.left) / divisions
	# Walk through and if the point is inside a ball,
	# assume that the entire adjacent volume is filled.
	var estimated_V := 0.0
	var checked_pos := bounds.left - step_size / 2
	while checked_pos < bounds.right:
		checked_pos += step_size
		for idx in balls.size():
			var ball = balls[idx]
			if absf(ball.P - checked_pos) < ball.R:
				# Reorder the array so the ball is at the beginning and gets checked early.
				if idx > 0:
					var temp := balls[0]
					balls[0] = balls[idx]
					balls[idx] = temp
				estimated_V += step_size
				break
	return estimated_V


# Helpers

static func is_point_in_ball(point: float, balls: Array[Ball1D]) -> bool:
	for ball in balls:
		if absf(ball.P - point) < ball.R:
			return true
	return false

static func separate(balls: Array[Ball1D]) -> Array[Array]:
	# Populate an array of initially separated arrays.
	var islands: Array[Array] = []
	for i in balls.size():
		islands.append([balls[i]])
	for i in islands:
		for B1 in i:
			var overlapping := false
			for j in islands:
				if i == j:
					continue
				for B2 in j:
					if absf(B1.P - B2.P) < B1.R + B2.R:
						overlapping = true
						break
				if overlapping:
					i.append_array(j)
					islands.erase(j)
					break
	return islands

static func find_bounds(balls: Array[Ball1D]) -> Bounds1D:
	var bounds := Bounds1D.new(INF, -INF)
	for ball in balls:
		bounds.right = maxf(ball.P + ball.R, bounds.right)
		bounds.left = minf(ball.P - ball.R, bounds.left)
	return bounds
