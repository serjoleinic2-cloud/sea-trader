extends Node

## Applies one persistent text-size setting to dynamically created schematic UI.
const SCALES: Array[float] = [1.0, 1.25, 1.5]
const DEFAULT_FONT_SIZE: int = 16
const MINIMUM_READABLE_SIZE: int = 18

var _scale: float = 1.25

func _ready() -> void:
	add_to_group("ui_accessibility")
	_scale = _normalize_scale(float(GameState.settings_state.get("ui_scale", 1.25)))
	GameState.settings_state["ui_scale"] = _scale
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_apply_existing")

func get_scale() -> float:
	return _scale

func get_scale_percent() -> int:
	return int(round(_scale * 100.0))

func cycle_scale() -> int:
	var current_index: int = SCALES.find(_scale)
	var next_index: int = posmod(current_index + 1, SCALES.size())
	_scale = SCALES[next_index]
	GameState.settings_state["ui_scale"] = _scale
	_apply_existing()
	SaveSystem.save_game()
	return get_scale_percent()

func _normalize_scale(value: float) -> float:
	var best: float = SCALES[0]
	var distance: float = absf(value - best)
	for candidate in SCALES:
		var candidate_distance: float = absf(value - candidate)
		if candidate_distance < distance:
			best = candidate
			distance = candidate_distance
	return best

func _on_node_added(node: Node) -> void:
	if node is Control:
		call_deferred("_apply_control", node)

func _apply_existing() -> void:
	var root: Window = get_tree().root
	_apply_branch(root)

func _apply_branch(node: Node) -> void:
	if node is Control:
		_apply_control(node)
	for child in node.get_children():
		_apply_branch(child)

func _apply_control(control: Control) -> void:
	if not is_instance_valid(control):
		return
	if _uses_font_size(control):
		if not control.has_meta("ui_base_font_size"):
			var base_size: int = DEFAULT_FONT_SIZE
			if control.has_theme_font_size_override("font_size"):
				base_size = control.get_theme_font_size("font_size")
			control.set_meta("ui_base_font_size", base_size)
		var stored_size: int = int(control.get_meta("ui_base_font_size", DEFAULT_FONT_SIZE))
		control.add_theme_font_size_override("font_size", maxi(MINIMUM_READABLE_SIZE, int(round(stored_size * _scale))))
	if control is Button:
		if not control.has_meta("ui_base_min_height"):
			control.set_meta("ui_base_min_height", maxf(36.0, control.custom_minimum_size.y))
		var base_height: float = float(control.get_meta("ui_base_min_height", 36.0))
		control.custom_minimum_size.y = ceil(base_height * _scale)

func _uses_font_size(control: Control) -> bool:
	return control is Label or control is Button or control is LineEdit or control is TextEdit or control is RichTextLabel or control is OptionButton or control is SpinBox or control is ProgressBar or control is CheckBox
