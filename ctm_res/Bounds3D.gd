class_name Bounds3D extends Resource

var left: float
var right: float
var down: float
var up: float
var forward: float
var backward: float

func _init(l: float, r: float, d: float, u: float, f: float, b: float) -> void:
	left = l; right = r
	up = u; down = d
	forward = f; backward = b
