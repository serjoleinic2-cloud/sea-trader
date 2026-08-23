extends Node2D

## Main game scene root.
## Phase 01: Verifies autoloads are present. No gameplay yet.

func _ready() -> void:
	print("Sea Trader — Phase 01 Foundation")
	assert(GameState != null, "GameState autoload missing")
	assert(EventBus != null, "EventBus autoload missing")
	assert(SaveSystem != null, "SaveSystem autoload missing")
	print("All autoloads verified.")
