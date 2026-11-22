class_name FirstTryHud
extends CanvasLayer

const HINT := "1-4 DROP  R RESET  LMB FIRE  RMB ADS  ESC SETTINGS"

var _player: PlayerController
var _clip_label: Label
var _hits_label: Label
var _shots_label: Label
var _drop_label: Label
var _hint_label: Label
var _cross_h: ColorRect
var _cross_v: ColorRect
var _scope: Control
var _pause: Control
var _sens_slider: HSlider
var _ads_slider: HSlider
var _fov_slider: HSlider
var _sens_label: Label
var _ads_label: Label
var _fov_label: Label
var _flash := 0.0
var _seen_hits := 0
var _building_ui := false
var _scope_laid_for := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	_build_play_hud()
	_build_scope()
	_build_pause()
	_sync_sliders_from_settings()


func set_paused(should_pause: bool) -> void:
	if should_pause and _player != null:
		_player.set_ads_held(false)
	_pause.visible = should_pause
	get_tree().paused = should_pause
	if should_pause:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as PlayerController
		if _player == null:
			return
	_clip_label.text = _player.clip_status_text()
	_hits_label.text = "HITS: %d / 5" % _player.clip_hits()
	_shots_label.text = "SHOTS: %d" % _player.clip_shots()
	_drop_label.text = _player.drop_label()
	_hint_label.visible = _player.is_clip_ready()
	_scope.visible = _player.is_ads() and not get_tree().paused
	var view_size := get_viewport().get_visible_rect().size
	if view_size != _scope_laid_for and view_size.x > 0.0:
		_scope_laid_for = view_size
		_layout_scope_marks(64.0, 26.0, 3.0)
	if _player.confirmed_hits_serial != _seen_hits:
		_seen_hits = _player.confirmed_hits_serial
		_flash = 0.15
	if _flash > 0.0:
		_flash -= delta
		_set_cross_color(Color("#4ADE80"))
	else:
		_set_cross_color(Color(0.96, 0.97, 0.98, 0.95))


func poke_hit_flash() -> void:
	_flash = 0.15
	_set_cross_color(Color("#4ADE80"))


func _set_cross_color(color: Color) -> void:
	_cross_h.color = color
	_cross_v.color = color


func _build_play_hud() -> void:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(margin)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_child(column)

	_clip_label = _label(34)
	_hits_label = _label(24)
	_shots_label = _label(24)
	_drop_label = _label(24)
	_hint_label = _label(18)
	_hint_label.text = HINT
	_hint_label.add_theme_color_override("font_color", Color("#CBD5E1"))
	column.add_child(_clip_label)
	column.add_child(_hits_label)
	column.add_child(_shots_label)
	column.add_child(_drop_label)
	column.add_child(_hint_label)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(center)
	add_child(center)
	var cross := Control.new()
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.custom_minimum_size = Vector2(18, 18)
	center.add_child(cross)
	_cross_h = ColorRect.new()
	_cross_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross_h.position = Vector2(0, 8)
	_cross_h.size = Vector2(18, 2)
	cross.add_child(_cross_h)
	_cross_v = ColorRect.new()
	_cross_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross_v.position = Vector2(8, 0)
	_cross_v.size = Vector2(2, 18)
	cross.add_child(_cross_v)


func _build_scope() -> void:
	_scope = Control.new()
	_scope.name = "Scope"
	_scope.visible = false
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(_scope)
	add_child(_scope)
	var gap := 64.0
	var arm := 26.0
	var thick := 3.0
	# Four corners around the screen center. Positions are updated to the viewport.
	_layout_scope_marks(gap, arm, thick)
	call_deferred("_layout_scope")


func _layout_scope() -> void:
	_layout_scope_marks(64.0, 26.0, 3.0)


func _layout_scope_marks(gap: float, arm: float, thick: float) -> void:
	for child in _scope.get_children():
		child.queue_free()
	var size := get_viewport().get_visible_rect().size
	var center := size * 0.5
	var corners: Array[Vector2] = [
		Vector2(-1, -1),
		Vector2(1, -1),
		Vector2(-1, 1),
		Vector2(1, 1),
	]
	for corner in corners:
		var origin := center + Vector2(corner.x * gap, corner.y * gap)
		var horizontal := ColorRect.new()
		horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		horizontal.color = Color(1, 1, 1, 0.95)
		horizontal.size = Vector2(arm, thick)
		horizontal.position = origin + Vector2(0.0 if corner.x > 0.0 else -arm, -thick * 0.5)
		_scope.add_child(horizontal)
		var vertical := ColorRect.new()
		vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vertical.color = Color(1, 1, 1, 0.95)
		vertical.size = Vector2(thick, arm)
		vertical.position = origin + Vector2(-thick * 0.5, 0.0 if corner.y > 0.0 else -arm)
		_scope.add_child(vertical)


func _build_pause() -> void:
	_pause = Control.new()
	_pause.name = "Pause"
	_pause.visible = false
	_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	_fill(_pause)
	add_child(_pause)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.07, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_fill(dim)
	_pause.add_child(dim)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(center)
	_pause.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.14, 0.96)
	style.set_corner_radius_all(12)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := _label(36)
	title.text = "SETTINGS"
	column.add_child(title)

	_sens_label = _label(22)
	_sens_slider = _slider(FirstTrySettings.MIN_SENS, FirstTrySettings.MAX_SENS, 0.01)
	_ads_label = _label(22)
	_ads_slider = _slider(FirstTrySettings.MIN_ADS, FirstTrySettings.MAX_ADS, 0.01)
	_fov_label = _label(22)
	_fov_slider = _slider(FirstTrySettings.MIN_FOV, FirstTrySettings.MAX_FOV, 1.0)
	column.add_child(_sens_label)
	column.add_child(_sens_slider)
	column.add_child(_ads_label)
	column.add_child(_ads_slider)
	column.add_child(_fov_label)
	column.add_child(_fov_slider)

	var keys := _label(18)
	keys.text = "WASD move    Mouse look    Space jump\nLMB fire    RMB hold ADS\n1 2 3 4 teleport    R reset drop    Esc settings"
	keys.add_theme_color_override("font_color", Color("#CBD5E1"))
	column.add_child(keys)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	var resume := _button("RESUME")
	resume.pressed.connect(func() -> void: set_paused(false))
	var quit := _button("QUIT")
	quit.pressed.connect(func() -> void: get_tree().quit())
	buttons.add_child(resume)
	buttons.add_child(quit)

	_sens_slider.value_changed.connect(_on_sens_changed)
	_ads_slider.value_changed.connect(_on_ads_changed)
	_fov_slider.value_changed.connect(_on_fov_changed)


func _sync_sliders_from_settings() -> void:
	_building_ui = true
	_sens_slider.set_value_no_signal(FirstTrySettings.live.mouse_sensitivity)
	_ads_slider.set_value_no_signal(FirstTrySettings.live.ads_sensitivity_multiplier)
	_fov_slider.set_value_no_signal(FirstTrySettings.live.fov)
	_refresh_slider_labels()
	_building_ui = false


func _on_sens_changed(value: float) -> void:
	if _building_ui:
		return
	FirstTrySettings.live.set_mouse_sensitivity(value)
	_refresh_slider_labels()


func _on_ads_changed(value: float) -> void:
	if _building_ui:
		return
	FirstTrySettings.live.set_ads_sensitivity_multiplier(value)
	_refresh_slider_labels()


func _on_fov_changed(value: float) -> void:
	if _building_ui:
		return
	FirstTrySettings.live.set_fov(value)
	_refresh_slider_labels()


func _refresh_slider_labels() -> void:
	_sens_label.text = "Mouse sensitivity   %.2f deg/pixel    (0.05 – 2.50)" % _sens_slider.value
	_ads_label.text = "ADS sensitivity   %.2f    (0.20 – 1.50)" % _ads_slider.value
	_fov_label.text = "FOV   %d    (70 – 120)" % int(_fov_slider.value)


func _slider(min_value: float, max_value: float, step: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.custom_minimum_size = Vector2(600, 28)
	return slider


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 44)
	return button


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _fill(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
