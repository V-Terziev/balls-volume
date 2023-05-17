class_name CarouselButton extends HBoxContainer

signal carouseled
var options := []

@onready var label: Label = $Label
@onready var left: Button = $Left
@onready var right: Button = $Right

var item := 0:
	set(value):
		item = value
		if item > -1 and item < options.size():
			label.text = options[item]
			UI.set_button_enabled(left, item > 0)
			UI.set_button_enabled(right, item < options.size() - 1)
			carouseled.emit()

func get_current() -> String:
	return options[item]

func _on_left_pressed() -> void:
	item -= 1

func _on_right_pressed() -> void:
	item += 1
