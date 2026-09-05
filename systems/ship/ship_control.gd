extends Node

## ShipControl — translates normalized input (-1..1) into physics commands.
## Sits between InputAdapter and ShipPhysics.
## Knows: ShipPhysics interface.
## Does NOT know: input source, Android API, game economy.
## See ARCHITECTURE.md, SYSTEM_MAP.md.

var _physics: Node  # ShipPhysics

# ============================================================================
# Public API
# ============================================================================

func setup(physics_node: Node) -> void:
	"""Link to ShipPhysics. Call once during scene init."""
	_physics = physics_node


func send_control(throttle: float, steering: float) -> void:
	"""Receive normalized commands and forward to ShipPhysics.
	throttle: -1..1  steering: -1..1"""
	if _physics == null:
		push_error("ShipControl: physics not set up")
		return
	_physics.apply_control(throttle, steering)
