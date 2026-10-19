extends GridContainer

var tile_width: float = 264.0
var maximum_columns: int = 5

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("h_separation", 10)
	add_theme_constant_override("v_separation", 10)

func _process(_delta: float) -> void:
	var count: int = clampi(floori((size.x + 10.0) / (tile_width + 10.0)), 1, maximum_columns)
	if columns != count: columns = count
