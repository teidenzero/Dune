class_name SoloScope
extends RefCounted
## Puts a mission scene into the Solo scope: one hero, a Holtzman shield,
## more health, the camera following him, the Fremen gone, the HUD solo.
##
## `direct` puts him on WASD and mouse aim with the squad controls stood down
## to pausing. Without it (the isometric interiors) he stays on click orders:
## the SquadManager's hero_mode keeps him selected and adds dodge and shield.

const SOLO_HEALTH: float = 150.0


static func enter(tree: SceneTree, player: PlayerController, squad: SquadManager = null, direct: bool = true) -> void:
	for ally: Node in tree.get_nodes_in_group("allies"):
		ally.remove_from_group("allies")
		ally.queue_free()
	if is_instance_valid(player):
		if direct:
			player.enable_direct_control(true)
		else:
			player.fit_shield()
		player.health.max_health = SOLO_HEALTH
		player.health.reset_health()
		var camera: TacticalCamera = player.get_node_or_null("TacticalCamera") as TacticalCamera
		if camera != null:
			camera.follow = true
	if is_instance_valid(squad):
		if direct:
			squad.solo_mode = true
			squad.clear_selection()
		else:
			squad.hero_mode = true
	var hud: PlayerHud = tree.get_first_node_in_group("player_hud") as PlayerHud
	if hud != null:
		hud.set_solo(true, not direct)
