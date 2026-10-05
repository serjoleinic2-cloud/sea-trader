extends "res://tests/test_base.gd"

var _hud: CanvasLayer
var last_allocation: Dictionary = {}

func before_each() -> void:
	_hud = load("res://systems/ui/combat_notification_hud.gd").new()
	add_child(_hud)
	_hud._system = self

func after_each() -> void:
	if is_instance_valid(_hud):
		_hud.free()

func test_raid_report_shows_unit_art_then_tribute_handover() -> void:
	_hud._on_report({
		"kind": "player_raid", "outcome": "Победа", "target": "Рифовый порт",
		"target_port_id": "reef", "tribute_started": true, "tribute_daily_amount": 220,
		"participants": {"coast_guard": {"count": 10}},
		"unit_losses": {"coast_guard": 2},
		"enemy_roster": {"rune_spearman": 8},
		"enemy_unit_loss_roster": {"rune_spearman": 3}
	})
	assert_true(_hud._story_root.visible, "a raid opens the full-screen report")
	assert_eq(_hud._story_content.get_child_count(), 1, "the battle view contains both sides")
	var columns: HBoxContainer = _hud._story_content.get_child(0)
	assert_eq(columns.get_child_count(), 2, "attacker and defender have separate card columns")
	_hud._advance_story()
	assert_eq(_hud._story_phase, 1, "a victorious raid advances to tribute handover")
	assert_true(_hud._story_background.texture is Texture2D, "handover art is loaded")

func test_revolt_letter_shows_outcome_and_casualties() -> void:
	_hud._on_report({"kind": "tribute_revolt", "target": "Рифовый порт", "won": false,
		"summary": "Остров освободился.", "casualties_text": "гарнизон 4, мятежники 7"})
	assert_eq(_hud._story_title.text, "ПИСЬМО ЭКСТРЕННОЕ · Рифовый порт")
	assert_true(_hud._story_content.get_child_count() >= 2, "emergency letter includes outcome and both-side losses")
	assert_true(_hud._story_background.texture is Texture2D, "rebellion art is loaded")

func test_post_battle_sliders_confirm_visible_occupation_counts() -> void:
	_hud._on_report({"kind": "player_raid", "target": "Рифовый порт", "target_port_id": "reef",
		"tribute_started": true, "tribute_daily_amount": 120,
		"participants": {"coast_guard": {"count": 8}}, "unit_losses": {"coast_guard": 2}})
	_hud._advance_story()
	assert_true(_hud._occupation_sliders.has("coast_guard"), "handover offers a slider for each surviving unit type")
	var entry: Dictionary = _hud._occupation_sliders.coast_guard
	assert_eq(float(entry.slider.max_value), 6.0, "slider maximum excludes battle casualties")
	entry.slider.value = 3
	assert_true(_hud._story_continue.text.contains("оставить 3 бойцов"), "done button shows the selected troop total")
	_hud._advance_story()
	assert_eq(last_allocation, {"coast_guard": 3}, "done confirms the exact chosen occupation roster")
	assert_true(_hud._story_title.text.contains("ОСТАВЛЕНО: 3"), "confirmed island garrison count is shown explicitly")

func get_reports() -> Array:
	return []

func get_unread_report_count() -> int:
	return 0

func set_tribute_occupation_roster(_port_id: String, roster: Dictionary) -> Dictionary:
	last_allocation = roster.duplicate(true)
	return {"ok": true, "stationed": roster.duplicate(true), "total": 3}
