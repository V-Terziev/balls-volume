class_name Utils extends RefCounted

static func solve_QE(a: float, b: float, c: float) -> Array[float]:
	var D := sqrt(b*b - 4*a*c)
	return [(-b - D) / (2*a), (-b + D) / (2*a)]

static func get_triangle_normal(A: Vector3, B: Vector3, C: Vector3) -> Vector3:
	var cross_AB := A.cross(B)
	var cross_BC := B.cross(C)
	var cross_CA := C.cross(A)
	return (cross_AB + cross_BC + cross_CA).normalized()

static func get_power_circumcenter(A: Vector3, B: Vector3, C: Vector3) -> Vector2:
	var N := Utils.get_triangle_normal(A, B, C)
	return (-0.5 / N.z) * Vector2(N.x, N.y)

static func is_ccw_triangle(A: Vector2, B: Vector2, C: Vector2) -> bool:
	return A.x * B.y + B.x * C.y + C.x * A.y - A.y * B.x - B.y * C.x - C.y * A.x > 0
