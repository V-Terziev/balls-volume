class_name CustomSpinbox extends HBoxContainer

@onready var reset: Button = $Reset
@onready var up: Button = %Up
@onready var up_buildup_timer: Timer = %Up/Timer
@onready var up_repeat_timer: Timer = %Up/Timer2
@onready var down: Button = %Down
@onready var down_buildup_timer: Timer = %Down/Timer
@onready var down_repeat_timer: Timer = %Down/Timer2
@onready var num_edit: LineEdit = %LineEdit

@export var config_bind: StringName
@export var min_value := 0
@export var max_value := 1024
@export var is_float := true

signal value_changed
var lol

var value = min_value:
	set(new_value):
		var old_value = value
		value = clamp(new_value, min_value, max_value)
		num_edit.text = str(value)
		if value != old_value:
			value_changed.emit(new_value)

const gen_binds = ["count", "max_offset", "min_radius", "max_radius"]

func _ready() -> void:
	value_changed.connect(_on_value_changed)
	UI.set_button_enabled(down, value != min_value)
	UI.set_button_enabled(up, value != max_value)

func _on_reset_pressed() -> void:
	if config_bind in gen_binds:
		Config.set(config_bind, Config.default_config[Config.get_gen_section()][config_bind])
		UI.update_gen_spinboxes()
	elif config_bind != "benchmark_runs":
		Config.save_setting(Config.get_algo_section(), config_bind,
				Config.default_config[Config.get_algo_section()][config_bind])
		UI.update_algo_spinboxes()
	else:
		Config.set(config_bind, Config.default_config["Universal"]["benchmark_runs"])
		UI.benchmark_runs_spinbox.value = Config.benchmark_runs
		UI.set_button_enabled(reset, false)

func _on_value_changed(new_value: float) -> void:
	UI.set_button_enabled(down, new_value != min_value)
	UI.set_button_enabled(up, new_value != max_value)
	
	if config_bind in gen_binds:
		Config.set(config_bind, new_value)
		UI.update_gen_spinboxes()
	elif config_bind != "benchmark_runs":
		Config.save_setting(Config.get_algo_section(), config_bind, [new_value])
		UI.update_algo_spinboxes()
	else:
		Config.set(config_bind, new_value)
		UI.benchmark_runs_spinbox.value = Config.benchmark_runs
		UI.set_button_enabled(reset,
				value != Config.default_config["Universal"]["benchmark_runs"])


func _on_up_button_down() -> void:
	value += 1
	up_buildup_timer.start(0.5)

func _on_up_button_up() -> void:
	up_buildup_timer.stop()
	up_repeat_timer.stop()

func _on_up_buildup_timer_timeout() -> void:
	up_repeat_timer.start(0.05)

func _on_up_repeat_timer_timeout() -> void:
	value += 1
	if value == max_value:
		up_repeat_timer.stop()

func _on_down_button_down() -> void:
	value -= 1
	down_buildup_timer.start(0.5)

func _on_down_button_up() -> void:
	down_buildup_timer.stop()
	down_repeat_timer.stop()

func _on_down_buildup_timer_timeout() -> void:
	down_repeat_timer.start(0.05)

func _on_down_repeat_timer_timeout() -> void:
	value -= 1
	if value == min_value:
		down_repeat_timer.stop()


func _on_focus_entered() -> void:
	get_tree().paused = true

func _on_focus_exited() -> void:
	if is_float:
		value = num_edit.text.to_float()
	else:
		value = num_edit.text.to_int()
	get_tree().paused = false

func _on_text_submitted(new_text: String) -> void:
	if is_float:
		value = new_text.to_float()
	else:
		value = new_text.to_int()
	num_edit.release_focus()

func _input(event: InputEvent) -> void:
	if (num_edit.has_focus() and event is InputEventMouseButton and\
	not num_edit.get_global_rect().has_point(event.position)):
		num_edit.release_focus()
