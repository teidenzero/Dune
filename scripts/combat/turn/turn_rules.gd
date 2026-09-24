class_name TurnRules
extends RefCounted
## The numbers of the interiors' turn-based combat, and the grid it is played
## on. Kept apart from TurnCombat so balance lives in one place.

const MOVE_COST: int = 1
## Sneaking is slower on points and much harder to spot.
const SNEAK_COST: int = 2
const FIRE_COST: int = 4
const QUICK_KNIFE_COST: int = 3
const SLOW_KNIFE_COST: int = 5
const RELOAD_COST: int = 2
const SHIELD_COST: int = 1
## A stone thrown to turn heads: guards who have not seen the hero look where
## it lands.
const DISTRACT_COST: int = 2
const DISTRACT_RANGE_TILES: float = 7.0
const DISTRACT_HEARING_TILES: float = 5.0

## Harkonnen action points by kind.
const GUARD_POINTS: int = 8
const ELITE_POINTS: int = 10
## A turn-based round stands for this much mission time (worm, reinforcements).
const ROUND_SECONDS: float = 5.0
## Each point left unspent at the end of the hero's turn is evasion.
const EVASION_PER_POINT: float = 3.0
## One tile, measured along the grid, in world pixels (a grid step is ~72).
const TILE_DISTANCE: float = 72.0

const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1),
]

enum Attack { FIRE, QUICK_KNIFE, SLOW_KNIFE }


static func attack_cost(kind: Attack) -> int:
	match kind:
		Attack.QUICK_KNIFE:
			return QUICK_KNIFE_COST
		Attack.SLOW_KNIFE:
			return SLOW_KNIFE_COST
	return FIRE_COST


static func attack_name(kind: Attack) -> String:
	return ["FIRE", "QUICK KNIFE", "SLOW KNIFE"][kind]


static func is_melee(kind: Attack) -> bool:
	return kind != Attack.FIRE


static func tiles_between(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b) / TILE_DISTANCE


## Chance (0..100) that a shot lands. Range is the main factor; a crouched
## target is smaller, and a hero who kept points back is harder to pin.
static func fire_chance(shooter: Node2D, target: Node2D, base: float, evasion: float) -> float:
	var tiles: float = tiles_between(shooter.global_position, target.global_position)
	var chance: float = base - maxf(tiles - 2.0, 0.0) * 5.0 - evasion
	if target.get("is_crouching") == true:
		chance -= 10.0
	return clampf(chance, 5.0, 95.0)


static func knife_chance(kind: Attack, evasion: float) -> float:
	var base: float = 90.0 if kind == Attack.QUICK_KNIFE else 75.0
	return clampf(base - evasion, 10.0, 95.0)


## Standing at the target's back: behind the way it faces.
static func is_behind(attacker: Vector2, target: Node2D) -> bool:
	var pivot: Node2D = target.get_node_or_null("AimPivot") as Node2D
	var forward: Vector2 = Vector2.RIGHT.rotated(pivot.global_rotation if pivot != null else target.global_rotation)
	return forward.dot(target.global_position.direction_to(attacker)) < -0.25


static func adjacent(a: Vector2i, b: Vector2i) -> bool:
	return a != b and absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1


## Cells a character may step between: inside the level, not a wall, and not
## cutting a wall corner on a diagonal. Doors are open ground (they slide
## open) unless locked.
static func can_step(level: IsoLevel, from: Vector2i, to: Vector2i) -> bool:
	if to.x < 0 or to.y < 0 or to.x >= level.size.x or to.y >= level.size.y or level.is_blocked(to):
		return false
	if from.x != to.x and from.y != to.y:
		return not level.is_wall(Vector2i(to.x, from.y)) and not level.is_wall(Vector2i(from.x, to.y))
	return true


## Breadth-first costs from `start` up to `budget` steps; `blocked` cells
## (other characters) cannot be entered. Returns cell -> steps.
static func reach(level: IsoLevel, start: Vector2i, budget: int, blocked: Dictionary) -> Dictionary:
	var costs: Dictionary = {start: 0}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		var steps: int = costs[cell]
		if steps >= budget:
			continue
		for offset in NEIGHBOURS:
			var next: Vector2i = cell + offset
			if costs.has(next) or blocked.has(next) or not can_step(level, cell, next):
				continue
			costs[next] = steps + 1
			frontier.append(next)
	return costs


## Shortest path of cells from `start` (excluded) to `goal` (included), or
## empty when there is none.
static func path(level: IsoLevel, start: Vector2i, goal: Vector2i, blocked: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if start == goal:
		return result
	var came: Dictionary = {start: start}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		if cell == goal:
			break
		for offset in NEIGHBOURS:
			var next: Vector2i = cell + offset
			if came.has(next) or (blocked.has(next) and next != goal) or not can_step(level, cell, next):
				continue
			came[next] = cell
			frontier.append(next)
	if not came.has(goal):
		return result
	var cursor: Vector2i = goal
	while cursor != start:
		result.push_front(cursor)
		cursor = came[cursor]
	return result


## Walls and closed doors stop a line of sight; characters do not, here.
static func has_sight(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> bool:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, 1)
	return space.intersect_ray(query).is_empty()
