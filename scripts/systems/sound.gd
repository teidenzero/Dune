class_name Sound
## Static access to the Sfx autoload from anywhere, without naming it (a
## script run on its own, as the smoke tests are, compiles before autoload
## names exist). Silent when the autoload is missing.


static func _player() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Sfx") if tree != null else null


## A world sound at `at`; without a position it plays flat.
static func play(slot: StringName, at: Vector2 = Vector2.INF, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	var player: Node = _player()
	if player != null:
		player.play(slot, at, volume_db, pitch_jitter)


## An interface sound: flat, on the UI bus.
static func ui(slot: StringName, volume_db: float = 0.0) -> void:
	var player: Node = _player()
	if player != null:
		player.ui(slot, volume_db)


static func loop(slot: StringName, node: Node2D, volume_db: float = 0.0) -> AudioStreamPlayer2D:
	var player: Node = _player()
	return player.loop(slot, node, volume_db) if player != null else null


static func stop_loop(slot: StringName, node: Node) -> void:
	var player: Node = _player()
	if player != null:
		player.stop_loop(slot, node)
