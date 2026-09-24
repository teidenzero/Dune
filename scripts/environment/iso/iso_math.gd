class_name IsoMath
extends RefCounted
## Isometric (2:1 dimetric) helpers for the Solo scope's interiors.
##
## The physics world stays the ordinary 2D screen plane; "isometric" is how the
## level is laid out and drawn. A grid cell (x, y) sits on a 128 x 64 diamond.

const TILE_W: float = 128.0
const TILE_H: float = 64.0
## The 8 facings, clockwise from screen-up. Diagonals follow the 2:1 grid
## lines, so walking "north-east" runs straight along a corridor.
const DIRECTIONS: Array[Vector2] = [
	Vector2(0, -1), Vector2(0.894427, -0.447214), Vector2(1, 0), Vector2(0.894427, 0.447214),
	Vector2(0, 1), Vector2(-0.894427, 0.447214), Vector2(-1, 0), Vector2(-0.894427, -0.447214),
]


static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)


static func world_to_cell(point: Vector2) -> Vector2i:
	var gx: float = point.x / TILE_W + point.y / TILE_H
	var gy: float = point.y / TILE_H - point.x / TILE_W
	return Vector2i(roundi(gx), roundi(gy))


## The nearest of the 8 facings; zero stays zero.
static func snap8(vector: Vector2) -> Vector2:
	if vector.is_zero_approx():
		return Vector2.ZERO
	var best: Vector2 = DIRECTIONS[0]
	var best_dot: float = -INF
	var unit: Vector2 = vector.normalized()
	for direction in DIRECTIONS:
		var dot: float = unit.dot(direction)
		if dot > best_dot:
			best_dot = dot
			best = direction
	return best


## 0..7, clockwise from screen-up: which of the 8 sprite directions to show.
static func facing_index(vector: Vector2) -> int:
	var snapped: Vector2 = snap8(vector)
	return maxi(DIRECTIONS.find(snapped), 0)


## Keyboard to movement: a pressed diagonal becomes the 2:1 grid diagonal.
static func keys_to_move(input: Vector2) -> Vector2:
	if input.is_zero_approx():
		return Vector2.ZERO
	var x: float = signf(input.x) if absf(input.x) > 0.3 else 0.0
	var y: float = signf(input.y) if absf(input.y) > 0.3 else 0.0
	if x != 0.0 and y != 0.0:
		return Vector2(2.0 * x, y).normalized()
	return Vector2(x, y)


## The diamond footprint of one cell, around its centre.
static func diamond(scale: float = 1.0) -> PackedVector2Array:
	var hw: float = TILE_W * 0.5 * scale
	var hh: float = TILE_H * 0.5 * scale
	return PackedVector2Array([Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)])
