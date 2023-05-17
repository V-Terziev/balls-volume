class_name Ball3D extends Resource

@export var P: Vector3
@export var R: float

func _init(pos: Vector3, r: float) -> void:
	P = pos
	R = maxf(0.0, r)

func V() -> float:
	return 4/3.0 * PI * R**3

func rand_inside() -> Vector3:
	var theta := randf_range(0, TAU)
	var phi := acos(randf_range(-1, 1))
	var offset := randf_range(0, R**3)
	var vec := Vector3(sin(phi) * sin(theta), sin(phi) * cos(theta), cos(phi))
	return P + vec * offset**(1/3.0)


# For caching, should be initialized inside algorithms if they are useful.

@export var radius_squared: float

func init_radius_squared() -> void:
	radius_squared = R * R

@export var volume: float

func init_volume():
	volume = V()
