extends RefCounted

## Shared bounds for game windows; the persistent HUD keeps its own area.
static func safe_top(tree: SceneTree) -> float:
	var coordinator: Node = tree.get_first_node_in_group("window_coordinator")
	return float(coordinator.get("_top_height")) if coordinator != null else 0.0

static func fill_screen(panel: Control, viewport: Vector2, top: float) -> void:
	panel.scale = Vector2.ONE
	panel.position = Vector2(0, top)
	panel.size = Vector2(viewport.x, maxf(120.0, viewport.y - top))

static func compact_control(control: Control) -> void:
	if control is Button and not control.has_meta("preserve_art_style") and not control.has_meta("brass_close") and not control.has_meta("compact_hud"):
		# Product/ship/portrait selectors are cards; action buttons use their
		# natural text width, even when their container fills the screen.
		if not control.has_meta("selection_card") and not control.has_meta("resource_id") and not str(control.name).begins_with("Ship_"):
			control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			control.autowrap_mode = TextServer.AUTOWRAP_OFF
			control.custom_minimum_size.x = 0
			control.custom_minimum_size.y = 32
			control.set_meta("compact_description", true)
			control.set_meta("ui_base_min_height", 32)
			if not control.has_meta("fixed_font_size"):
				control.set_meta("ui_base_font_size", 12)
				control.add_theme_font_size_override("font_size", 14)
	if control is ScrollContainer and not control.has_meta("horizontal_catalog"):
		control.custom_minimum_size.y = 0
		control.size_flags_vertical = Control.SIZE_EXPAND_FILL

static func compact_branch(node: Node) -> void:
	if node is Control:
		compact_control(node)
	for child in node.get_children():
		compact_branch(child)
