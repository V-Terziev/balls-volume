extends Node

var font := preload("res://visual/Font.ttf")

var cases := {
	1: preload("res://src/Case1D.tscn"), 2: preload("res://src/Case2D.tscn"),
	3: preload("res://src/Case3D.tscn"),
}

@onready var case: SubViewport = get_tree().current_scene.get_child(0)
@onready var gen_info: RichTextLabel = %GenInfo
@onready var algo_info: RichTextLabel = %Output
@onready var gen_box: VBoxContainer = %GenSettings
@onready var algo_box: VBoxContainer = %AlgoBox
@onready var reset_all: Button = %ResetAll
@onready var gen_settings: Button = %Settings
@onready var algo_settings: Button = %Settings2
@onready var output_mode: Button = %Mode
@onready var carousel: CarouselButton = %Current

@onready var case_buttons := { 1: %Case1, 2: %Case2, 3: %Case3 }

@onready var count_spinbox: CustomSpinbox = %Count
@onready var max_offset_spinbox: CustomSpinbox = %MaxOffset
@onready var min_radius_spinbox: CustomSpinbox = %MinRadius
@onready var max_radius_spinbox: CustomSpinbox = %MaxRadius
@onready var benchmark_runs_spinbox: CustomSpinbox = %BenchmarkRuns
@onready var arg_spinbox: CustomSpinbox = %Arg
@onready var arg_label: Label = %ArgLabel
@onready var gen_spinboxes := {
	"count": %Count, "max_offset": %MaxOffset,
	"min_radius": %MinRadius, "max_radius": %MaxRadius
}

func _ready() -> void:
	set_button_enabled(case_buttons[Config.dimension], false)
	update_gen_spinboxes()
	benchmark_runs_spinbox.value = Config.benchmark_runs
	set_button_enabled(benchmark_runs_spinbox.reset, Config.benchmark_runs !=\
			Config.default_config["Universal"]["benchmark_runs"])
	case.change_case(cases[Config.dimension])
	update_algo_spinboxes()
	carousel.item = 0
	gen_settings.button_pressed = Config.show_gen_settings
	gen_box.visible = Config.show_gen_settings
	algo_settings.button_pressed = Config.show_algo_settings
	algo_box.visible = Config.show_algo_settings
	output_mode.text = "V" if Config.print_volume else "E"

func set_dimension(new_dimension) -> void:
	if Config.dimension == new_dimension:
		case.generate_new()
	else:
		set_button_enabled(case_buttons[Config.dimension], true)
		set_button_enabled(case_buttons[new_dimension], false)
		Config.dimension = new_dimension
		update_gen_spinboxes()
		case.change_case(cases[new_dimension])
		carousel.item = 0
		update_algo_spinboxes()

func switch_to_1d() -> void:
	set_dimension(1)

func switch_to_2d() -> void:
	set_dimension(2)

func switch_to_3d() -> void:
	set_dimension(3)

func reset_gen_settings() -> void:
	Config.reset_gen_settings()
	update_gen_spinboxes()

func generate_new() -> void:
	case.space.generate_new()
	update_gen_info(case.space.ball_set)

func run_algorithms() -> void:
	case.run_algorithms()


func toggle_gen_settings(value: bool) -> void:
	Config.show_gen_settings = value
	gen_box.visible = value
	gen_info.custom_minimum_size.y = 87 if value else 120

func toggle_algo_settings(value: bool) -> void:
	Config.show_algo_settings = value
	algo_box.visible = value

func toggle_output_mode() -> void:
	Config.print_volume = not Config.print_volume
	output_mode.text = "V" if Config.print_volume else "E"


# Helpers

func update_gen_spinboxes() -> void:
	set_button_enabled(reset_all, false)
	for key in gen_spinboxes:
		var current_value = Config.config.get_value(Config.get_gen_section(), key)
		gen_spinboxes[key].value = current_value
		var reset_button: Button = gen_spinboxes[key].reset
		if current_value != Config.default_config[Config.get_gen_section()][key]:
			set_button_enabled(reset_button, true)
			set_button_enabled(reset_all, true)
		else:
			set_button_enabled(reset_button, false)

func update_algo_spinboxes() -> void:
	carousel.options = case.NSpace.arg_names.keys()
	if not case.NSpace.arg_names[carousel.get_current()].is_empty():
		var current_value: int = Config.config.get_value(Config.get_algo_section(),
				carousel.get_current())[0]
		arg_label.text = case.NSpace.arg_names[carousel.get_current()][0]
		arg_spinbox.show()
		arg_spinbox.config_bind = carousel.get_current()
		arg_spinbox.value = current_value
		var reset_button: Button = arg_spinbox.reset
		set_button_enabled(reset_button, current_value !=\
				Config.default_config[Config.get_algo_section()][carousel.get_current()][0])
	else:
		arg_label.text = " "
		arg_spinbox.hide()

func set_button_enabled(button: Button, new_value: bool) -> void:
	button.disabled = not new_value
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if new_value\
			else Control.CURSOR_ARROW

func update_gen_info(balls: Array) -> void:
	algo_info.text = "[color=#888888]" + algo_info.text + "[/color]"
	gen_info.text = ""
	match Config.dimension:
		1:
			for i in balls.size():
				var ball = balls[i]
				gen_info.text += "Ball %d: P = %.2f, R = %.2f\n" % [i, ball.P, ball.R]
		_:
			for i in balls.size():
				var ball = balls[i]
				gen_info.text += "Ball %d: P = %.2v, R = %.2f\n" % [i, ball.P, ball.R]


func algo_carouseled() -> void:
	update_algo_spinboxes()
