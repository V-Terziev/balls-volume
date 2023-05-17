class_name Ball2D extends Resource

@export var P: Vector2
@export var R: float

func _init(pos: Vector2, r: float) -> void:
	P = pos
	R = maxf(0.0, r)

func V() -> float:
	return PI * R * R

func rand_inside() -> Vector2:
	var theta := randf_range(0, TAU)
	var offset := randf_range(0, R * R)
	var vec := Vector2(cos(theta), sin(theta))
	return P + vec * sqrt(offset)


# For caching, should be initialized inside algorithms if they are useful.

@export var radius_squared: float

func init_radius_squared() -> void:
	radius_squared = R * R

@export var volume: float

func init_volume():
	volume = V()
