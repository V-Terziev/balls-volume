class_name Ball1D extends Resource

@export var P: float
@export var R: float

func _init(pos: float, r: float) -> void:
	P = pos
	R = maxf(0.0, r)

func V() -> float:
		return 2 * R

func rand_inside() -> float:
	return randf_range(P - R, P + R)


# For caching, should be initialized inside algorithms if they are useful.

@export var left_edge: float

func init_left_edge() -> void:
	left_edge = P - R

@export var right_edge: float

func init_right_edge() -> void:
	right_edge = P + R
