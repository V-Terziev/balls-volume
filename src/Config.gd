extends Node

const save_path = "user://config.cfg"
var config := ConfigFile.new()

const default_config = {
	"Universal": {
		"dimension": 2,
		"show_gen_settings": false,
		"show_algo_settings": false,
		"print_volume": true,
		"benchmark_runs": 1,
	},
	"Generation1D": {
		"count": 8,
		"max_offset": 384.0,
		"min_radius": 6.0,
		"max_radius": 64.0,
	},
	"Generation2D": {
		"count": 13,
		"max_offset": 320.0,
		"min_radius": 6.0,
		"max_radius": 128.0,
	},
	"Generation3D": {
		"count": 21,
		"max_offset": 32.0,
		"min_radius": 1.0,
		"max_radius": 16.0,
	},
	"Algorithms1D": {
		"monte_carlo": [2048],
		"sample_points": [1024],
		"exact": [],
	},
	"Algorithms2D": {
		"monte_carlo": [4096],
		"monte_carlo_2": [4096],
		"sample_points": [80],
		"sample_lines": [320],
		"green_algorithm": [],
		"voronoi_run": [],
	},
	"Algorithms3D": {
		"monte_carlo": [8192],
		"monte_carlo_2": [8192],
		"sample_points": [20],
		"sample_planes": [80],
	}
}

func _enter_tree() -> void:
	load_config()

func save_setting(section: String, setting: String, value) -> void:
	config.set_value(section, setting, value)
	config.save(save_path)

func load_config() -> void:
	var error := config.load(save_path)
	if error:
		for section in default_config.keys():
			for setting in default_config[section].keys():
				config.set_value(section, setting, default_config[section][setting])
		return
	for setting in config.get_section_keys("Universal"):
		set(setting, config.get_value("Universal", setting))

func reset_gen_settings() -> void:
	for setting in config.get_section_keys(get_gen_section()):
		set(setting, default_config[get_gen_section()][setting])

func reset_algo_settings() -> void:
	for setting in config.get_section_keys(get_algo_section()):
		set(setting, default_config[get_gen_section()][setting])

# Generation

var count: int:
	set(value):
		count = maxi(value, 0)
		save_setting(get_gen_section(), "count", count)

var max_offset: float:
	set(value):
		max_offset = maxf(value, 0.0)
		save_setting(get_gen_section(), "max_offset", max_offset)

var min_radius: float:
	set(value):
		min_radius = minf(min_radius, max_radius)
		min_radius = maxf(value, 0.0)
		save_setting(get_gen_section(), "min_radius", min_radius)

var max_radius: float:
	set(value):
		max_radius = maxf(value, min_radius)
		save_setting(get_gen_section(), "max_radius", max_radius)

# Universal

var dimension := 2:
	set(value):
		dimension = clampi(value, 1, 3)
		save_setting("Universal", "dimension", dimension)

var show_gen_settings: bool:
	set(value):
		show_gen_settings = value
		save_setting("Universal", "show_gen_settings", show_gen_settings)

var show_algo_settings: bool:
	set(value):
		show_algo_settings = value
		save_setting("Universal", "show_algo_settings", show_algo_settings)

var print_volume: bool:
	set(value):
		print_volume = value
		save_setting("Universal", "print_volume", print_volume)

var benchmark_runs := 1:
	set(value):
		benchmark_runs = value
		save_setting("Universal", "benchmark_runs", benchmark_runs)


# Helpers

func get_gen_section() -> String:
	return "Generation%sD" % dimension

func get_algo_section() -> String:
	return "Algorithms%sD" % dimension
