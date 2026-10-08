extends RefCounted

## Conservative visual bounds only; gameplay/navigation never depend on visibility.
static func bounds_for(root: Node3D) -> AABB:
	var bounds := AABB(root.global_position, Vector3.ZERO)
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is MeshInstance3D or node is MultiMeshInstance3D:
			bounds = bounds.merge(node.global_transform * node.get_aabb())
		pending.append_array(node.get_children())
	# Small margin covers flags, lights and minor vertex animation at the edge.
	return bounds.grow(2.0)

static func intersects_frustum(bounds: AABB, planes: Array[Plane], inside_point: Vector3) -> bool:
	var center := bounds.get_center()
	var half_size := bounds.size * 0.5
	for plane in planes:
		var outward: float = 1.0 if plane.distance_to(inside_point) < 0.0 else -1.0
		if plane.distance_to(center) * outward > plane.normal.abs().dot(half_size):
			return false
	return true
