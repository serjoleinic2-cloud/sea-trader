extends RefCounted

## Shared race-aware portrait lookup. Atlases stay as editable source sheets;
## returned AtlasTextures isolate one portrait cell for existing UI controls.
const UNIT_ORDER := ["coast_guard", "rune_spearman", "stone_warden", "wind_rider", "crystal_mortar", "storm_drake"]
const RACE_ORDER := ["humans", "nerids", "surr", "meridians", "aery", "crystari"]
const GENERIC_UNIT_ROOT := "res://assets/characters/units/"
const UNIT_ATLAS_ROOT := "res://assets/characters/units/"
const OFFICER_ATLAS_ROOT := "res://assets/characters/crew/naval_officers/"

static func unit_portrait(race_id: String, unit_id: String) -> Texture2D:
	var atlas_path: String = "%s%s/roster_atlas.png" % [UNIT_ATLAS_ROOT, race_id]
	var cell: int = UNIT_ORDER.find(unit_id)
	if cell >= 0 and ResourceLoader.exists(atlas_path):
		return _atlas_cell(atlas_path, cell, 3, 2, 5.0)
	var generic_path: String = "%s%s.webp" % [GENERIC_UNIT_ROOT, unit_id]
	return load(generic_path) as Texture2D if ResourceLoader.exists(generic_path) else null

static func ship_officer_portrait(race_id: String, role_id: String, portrait_id: int, fallback_atlas: Texture2D = null) -> Texture2D:
	var role: String = role_id.to_lower()
	var is_captain: bool = role in ["captain", "commander", "role_captain"] or role.contains("капитан") or role.contains("командир")
	var is_assistant: bool = role in ["navigator", "bosun", "quartermaster", "first_mate", "mate", "assistant", "deputy"] or role.contains("лоцман") or role.contains("боцман") or role.contains("квартирмейстер") or role.contains("помощник") or role.contains("заместитель")
	var atlas_path: String = "%s%s/officers_atlas.png" % [OFFICER_ATLAS_ROOT, race_id]
	if (is_captain or is_assistant) and ResourceLoader.exists(atlas_path):
		var row: int = 0 if is_captain else 1
		return _atlas_cell(atlas_path, posmod(portrait_id, 3) + row * 3, 3, 2, 5.0)
	if fallback_atlas == null:
		return null
	var race_row: int = RACE_ORDER.find(race_id)
	if race_row < 0:
		race_row = 0
	return _texture_region(fallback_atlas, posmod(portrait_id, 3), race_row, 3, 6, 2.0)

static func _atlas_cell(path: String, cell_index: int, columns: int, rows: int, inset: float) -> Texture2D:
	var atlas: Texture2D = load(path) as Texture2D
	if atlas == null:
		return null
	return _texture_region(atlas, cell_index % columns, int(cell_index / columns), columns, rows, inset)

static func _texture_region(atlas: Texture2D, column: int, row: int, columns: int, rows: int, inset: float) -> AtlasTexture:
	var cell_width: float = float(atlas.get_width()) / float(columns)
	var cell_height: float = float(atlas.get_height()) / float(rows)
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(column * cell_width + inset, row * cell_height + inset, cell_width - inset * 2.0, cell_height - inset * 2.0)
	return texture
