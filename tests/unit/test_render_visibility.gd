extends "res://tests/test_base.gd"

const Visibility = preload("res://systems/rendering/render_visibility.gd")

func test_camera_keeps_partial_islands_and_restores_objects_after_turn() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.far = 80.0
	var front := AABB(Vector3(-1, -1, -11), Vector3(2, 2, 2))
	var behind := AABB(Vector3(-1, -1, 9), Vector3(2, 2, 2))
	var far_away := AABB(Vector3(-1, -1, -122), Vector3(2, 2, 2))
	var partial_island := AABB(Vector3(4, -2, -24), Vector3(36, 4, 8))
	var planes := camera.get_frustum()
	var inside := camera.global_position - camera.global_basis.z * (camera.near + 1.0)
	assert_true(Visibility.intersects_frustum(front, planes, inside), "Ship in front remains visible")
	assert_false(Visibility.intersects_frustum(behind, planes, inside), "Ship behind camera is hidden")
	assert_false(Visibility.intersects_frustum(far_away, planes, inside), "Beyond far clip is hidden")
	assert_true(Visibility.intersects_frustum(partial_island, planes, inside), "Partially visible city is retained even with its center outside the screen")
	camera.rotation.y = PI
	planes = camera.get_frustum()
	inside = camera.global_position - camera.global_basis.z * (camera.near + 1.0)
	assert_true(Visibility.intersects_frustum(behind, planes, inside), "Turning back restores the object")
	assert_false(Visibility.intersects_frustum(front, planes, inside), "Old forward view is now behind")
	camera.free()

func test_bounds_include_transformed_child_geometry() -> void:
	var island := Node3D.new()
	add_child(island)
	island.position = Vector3(40, 5, 20)
	island.rotation.y = PI * 0.5
	var building := MeshInstance3D.new()
	building.mesh = BoxMesh.new()
	building.position = Vector3(12, 30, 4)
	island.add_child(building)
	var bounds := Visibility.bounds_for(island)
	assert_true(bounds.has_point(building.global_position), "Tall structures are included")
	assert_true(bounds.has_point(building.global_transform * Vector3(0.9, 0.9, 0.9)), "Rotation and translation are accounted for")
	island.free()
