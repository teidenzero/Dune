extends NavigationRegion2D
## Bake this small static arena once at startup using its actual colliders.

@export var walkable_rect: Rect2 = Rect2(-1576, -1076, 3152, 2152)
@export var clearance: float = 20.0


func _ready() -> void:
	call_deferred("_bake")


func _bake() -> void:
	var polygon: NavigationPolygon = NavigationPolygon.new()
	polygon.agent_radius = clearance
	polygon.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	polygon.parsed_collision_mask = 3
	polygon.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	polygon.source_geometry_group_name = &"navigation_geometry"
	var geometry: NavigationMeshSourceGeometryData2D = NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(polygon, geometry, get_parent())
	geometry.add_traversable_outline(PackedVector2Array([
		walkable_rect.position, Vector2(walkable_rect.end.x, walkable_rect.position.y),
		walkable_rect.end, Vector2(walkable_rect.position.x, walkable_rect.end.y)]))
	NavigationServer2D.bake_from_source_geometry_data(polygon, geometry)
	navigation_polygon = polygon
