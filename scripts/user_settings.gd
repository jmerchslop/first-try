class_name FirstTrySettings
extends Node

## Mouse, ADS, and FOV settings. Values apply as they change and save to user://.

signal settings_changed

static var live: FirstTrySettings

const MIN_SENS := 0.05
const MAX_SENS := 2.5
const DEFAULT_SENS := 0.20
const MIN_ADS := 0.20
const MAX_ADS := 1.50
const DEFAULT_ADS := 0.80
const MIN_FOV := 70.0
const MAX_FOV := 120.0
const DEFAULT_FOV := 90.0

var mouse_sensitivity: float = DEFAULT_SENS
var ads_sensitivity_multiplier: float = DEFAULT_ADS
var fov: float = DEFAULT_FOV
var save_path: String = "user://settings.cfg"


func _ready() -> void:
	live = self
	load_settings()


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, MIN_SENS, MAX_SENS)
	settings_changed.emit()
	save_settings()


func set_ads_sensitivity_multiplier(value: float) -> void:
	ads_sensitivity_multiplier = clampf(value, MIN_ADS, MAX_ADS)
	settings_changed.emit()
	save_settings()


func set_fov(value: float) -> void:
	fov = clampf(value, MIN_FOV, MAX_FOV)
	settings_changed.emit()
	save_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("settings", "ads_sensitivity_multiplier", ads_sensitivity_multiplier)
	cfg.set_value("settings", "fov", fov)
	var err := cfg.save(save_path)
	if err != OK:
		push_error("Could not save settings to %s (%s)" % [save_path, error_string(err)])


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	mouse_sensitivity = clampf(
		float(cfg.get_value("settings", "mouse_sensitivity", DEFAULT_SENS)),
		MIN_SENS,
		MAX_SENS
	)
	ads_sensitivity_multiplier = clampf(
		float(cfg.get_value("settings", "ads_sensitivity_multiplier", DEFAULT_ADS)),
		MIN_ADS,
		MAX_ADS
	)
	fov = clampf(float(cfg.get_value("settings", "fov", DEFAULT_FOV)), MIN_FOV, MAX_FOV)
	settings_changed.emit()


func restore_defaults() -> void:
	mouse_sensitivity = DEFAULT_SENS
	ads_sensitivity_multiplier = DEFAULT_ADS
	fov = DEFAULT_FOV
	settings_changed.emit()
	save_settings()
