class_name TutorialScript
extends RefCounted
## The Arrakeen training sequence: what each step says and how the game proves
## the player did it. Every condition reads real gameplay state or an event
## recorded from an existing gameplay signal - nothing here simulates a mechanic.
##
## All dialogue is original placeholder text written for this prototype.

const Order = AllyAIController.Order
const Link = CommandLinkComponent.State


static func build(t: TutorialManager) -> Array[TutorialStep]:
	var steps: Array[TutorialStep] = []
	for data in _movement(t) + _ranged(t) + _melee(t) + _stealth(t) + _squad(t) + _recon(t) + _prescience(t) + _desert(t) + _combined(t):
		steps.append(TutorialStep.create(data))
	return steps


# --------------------------------------------------------------------------
# Section 1 - movement, camera, sprint, crouch
# --------------------------------------------------------------------------

static func _movement(t: TutorialManager) -> Array:
	return [
		{
			"id": &"move_marker", "section": &"movement", "title": "Movement",
			"speaker": "GURNEY",
			"instruction": "Use WASD to walk to the marked stone.",
			"hint": "W is north, S is south, A and D step sideways. The camera follows you.",
			"markers": ["Marker_MoveA"],
			"completion": func() -> bool: return t.happened(&"enter_move_a") or t.at_trigger(&"move_a"),
		},
		{
			"id": &"move_sprint", "section": &"movement", "title": "Sprint",
			"speaker": "GURNEY",
			"instruction": "Hold SHIFT to sprint, and run to the far marker.",
			"hint": "Hold SHIFT while moving. Sprinting is faster, and far louder.",
			"markers": ["Marker_MoveB"],
			"completion": func() -> bool:
				if t.player.is_sprinting:
					t.add_counter(&"sprint", t.get_process_delta_time())
				return t.counter(&"sprint") >= 0.8 and (t.happened(&"enter_move_b") or t.at_trigger(&"move_b")),
		},
		{
			"id": &"move_crouch", "section": &"movement", "title": "Crouch",
			"speaker": "GURNEY",
			"instruction": "Press CTRL to crouch, then move across the sand bed.",
			"hint": "CTRL toggles the crouch. Move while crouched to feel the difference.",
			"markers": ["Marker_MoveC"],
			"note": "Crouched you are slower, quieter, and harder to see.",
			"completion": func() -> bool:
				if t.player.is_crouching and t.player.current_speed > 5.0:
					t.add_counter(&"crouch", t.get_process_delta_time())
				return t.counter(&"crouch") >= 0.8,
		},
	]


# --------------------------------------------------------------------------
# Section 2 - aiming, shooting, reload, cover
# --------------------------------------------------------------------------

static func _ranged(t: TutorialManager) -> Array:
	return [
		{
			"id": &"aim_target", "section": &"ranged", "title": "Aiming",
			"speaker": "GURNEY",
			"instruction": "The maula pistol is yours. Aim at the target with the mouse.",
			"hint": "Your aim marker always points at the cursor, whichever way you walk.",
			"markers": ["Highlight_AimTarget"],
			"completion": func() -> bool:
				var target: Node2D = t.actor(&"Target_Aim")
				if target == null:
					return true
				var wanted: Vector2 = t.player.global_position.direction_to(target.global_position)
				if absf(t.player.aim_direction.angle_to(wanted)) < deg_to_rad(12.0):
					t.add_counter(&"aim", t.get_process_delta_time())
				return t.counter(&"aim") >= 0.5,
		},
		{
			"id": &"fire_target", "section": &"ranged", "title": "Ranged combat",
			"speaker": "GURNEY",
			"instruction": "Left mouse to fire. Put a round into that target.",
			"hint": "Click once per shot. The pistol is semi-automatic.",
			"markers": ["Highlight_AimTarget"],
			"completion": func() -> bool: return t.happened(&"damaged_Target_Aim"),
		},
		{
			"id": &"reload_weapon", "section": &"ranged", "title": "Reload",
			"speaker": "GURNEY",
			"instruction": "Press R to reload. Do it before you need to, not after.",
			"hint": "R reloads. You cannot fire while the magazine is out.",
			"completion": func() -> bool: return t.happened(&"reload_finished"),
		},
		{
			"id": &"cover_target", "section": &"ranged", "title": "Cover",
			"speaker": "GURNEY",
			"instruction": "That target sits behind a pillar. Move until you have a clean line, then fire.",
			"hint": "Rounds stop at stone. Change your angle instead of shooting through it.",
			"markers": ["Highlight_CoverTarget"],
			"note": "Cover stops rounds. Yours and theirs.",
			"completion": func() -> bool: return t.happened(&"damaged_Target_Cover"),
		},
	]


# --------------------------------------------------------------------------
# Section 3 - crysknife and personal shields
# --------------------------------------------------------------------------

static func _melee(t: TutorialManager) -> Array:
	return [
		{
			"id": &"melee_fast", "section": &"melee", "title": "Fast strike",
			"speaker": "DUNCAN",
			"instruction": "Take the crysknife. Tap E for a fast strike on the practice dummy.",
			"hint": "Get close. The blade has a short reach, and it cuts where you aim.",
			"markers": ["Highlight_MeleeDummy"],
			"completion": func() -> bool: return t.happened(&"melee_hit_fast"),
		},
		{
			"id": &"melee_slow", "section": &"melee", "title": "Slow strike",
			"speaker": "DUNCAN",
			"instruction": "Now hold E to slow the blade, then release.",
			"hint": "Hold E until the arc brightens, then let go. You move slowly while it is raised.",
			"markers": ["Highlight_MeleeDummy"],
			"note": "The slow stroke hits far harder, and it commits you.",
			"completion": func() -> bool: return t.happened(&"melee_hit_slow"),
		},
		{
			"id": &"shield_shot", "section": &"melee", "title": "Shields: gunfire",
			"speaker": "DUNCAN",
			"instruction": "This one wears a body shield. Shoot it.",
			"hint": "Go ahead and empty the magazine into it. Learn this the cheap way.",
			"markers": ["Highlight_ShieldDummy"],
			"note": "Fast attacks cannot penetrate an active personal shield.",
			"completion": func() -> bool: return t.happened(&"shield_blocked_ranged"),
		},
		{
			"id": &"shield_fast", "section": &"melee", "title": "Shields: fast blade",
			"speaker": "DUNCAN",
			"instruction": "Try a fast crysknife strike.",
			"hint": "Tap E at the shielded dummy. Watch what the shield does with it.",
			"markers": ["Highlight_ShieldDummy"],
			"note": "The blade is moving too quickly.",
			"completion": func() -> bool: return t.happened(&"shield_blocked_melee"),
		},
		{
			"id": &"shield_slow", "section": &"melee", "title": "Shields: slow blade",
			"speaker": "DUNCAN",
			"instruction": "Slow the blade. Hold E, let the stroke build, and push it through.",
			"hint": "The shield stops speed, not steel. Hold E longer before you release.",
			"markers": ["Highlight_ShieldDummy"],
			"note": "Slow attacks pass through the shield.",
			"delay_after": 1.6,
			"completion": func() -> bool: return t.happened(&"shield_penetrated"),
		},
	]


# --------------------------------------------------------------------------
# Section 4 - stealth course against real perception
# --------------------------------------------------------------------------

static func _stealth(t: TutorialManager) -> Array:
	return [
		{
			"id": &"stealth_cross", "section": &"stealth", "title": "Stealth",
			"speaker": "DUNCAN",
			"instruction": "Cross to the far gate without being fully seen. Stay out of their cones.",
			"hint": "Crouch, keep stone between you, and let their meters fall before you move again.",
			"hint_delay": 12.0,
			"markers": ["Marker_StealthExit"],
			"note": "STEALTH TRAINING COMPLETE",
			"delay_after": 1.4,
			"completion": func() -> bool: return t.happened(&"enter_stealth_exit") or t.at_trigger(&"stealth_exit"),
		},
	]


# --------------------------------------------------------------------------
# Section 5 - squad selection and orders
# --------------------------------------------------------------------------

static func _squad(t: TutorialManager) -> Array:
	return [
		{
			"id": &"squad_select_scout", "section": &"squad", "title": "Squad",
			"speaker": "STILGAR",
			"instruction": "Two of my people will train with you. Press 2 to select the Scout.",
			"hint": "1 clears your selection, 2 is the Scout, 3 the Warrior, 4 takes both.",
			"markers": ["Highlight_Scout"],
			"completion": func() -> bool:
				return t.squad.selected_members.size() == 1 and t.squad.selected_members[0].selection_slot == 2,
		},
		{
			"id": &"squad_select_both", "section": &"squad", "title": "Squad",
			"speaker": "STILGAR",
			"instruction": "Press 4 to take both Fremen at once.",
			"hint": "4 selects every living companion.",
			"completion": func() -> bool: return t.squad.selected_members.size() == 2,
		},
		{
			"id": &"squad_command_mode", "section": &"squad", "title": "Command mode",
			"speaker": "STILGAR",
			"instruction": "Press TAB. Time slows, you hold still, and you give orders.",
			"hint": "TAB toggles command mode. Press it again to go back to fighting yourself.",
			"completion": func() -> bool: return t.squad.command_mode,
		},
		{
			"id": &"squad_move", "section": &"squad", "title": "Move order",
			"speaker": "STILGAR",
			"instruction": "Select the Scout and right-click the marked ground to send him there.",
			"hint": "In command mode: left-click picks a Fremen, right-click on open ground moves them.",
			"markers": ["Marker_SquadMove"],
			"completion": func() -> bool:
				var scout: AllyCharacter = t.ally(2)
				var marker: Node2D = t.actor(&"Marker_SquadMove")
				if scout == null or marker == null:
					return false
				return scout.ai.current_order == Order.HOLD and scout.global_position.distance_to(marker.global_position) < 80.0,
		},
		{
			"id": &"squad_hold", "section": &"squad", "title": "Hold order",
			"speaker": "STILGAR",
			"instruction": "Select the Warrior with 3 and press H. He holds where he stands.",
			"hint": "H holds the selected Fremen in place. They will still defend themselves.",
			"markers": ["Highlight_Warrior"],
			"completion": func() -> bool:
				var warrior: AllyCharacter = t.ally(3)
				return warrior != null and warrior.ai.current_order == Order.HOLD,
		},
		{
			"id": &"squad_follow", "section": &"squad", "title": "Recall",
			"speaker": "STILGAR",
			"instruction": "Press G to call the Warrior back to you.",
			"hint": "G returns the selected Fremen to following you.",
			"completion": func() -> bool:
				var warrior: AllyCharacter = t.ally(3)
				if warrior == null or warrior.ai.current_order != Order.FOLLOW:
					return false
				return warrior.global_position.distance_to(t.player.global_position) < 220.0,
		},
		{
			"id": &"squad_attack", "section": &"squad", "title": "Attack order",
			"speaker": "STILGAR",
			"instruction": "A target stands at the end of the yard. Order the Scout to kill it.",
			"hint": "In command mode, right-click directly on a hostile to send your Fremen at it.",
			"markers": ["Highlight_SquadEnemy"],
			"note": "You do not have to fire a shot yourself.",
			"on_start": func() -> void: t.set_actor_armed(&"Target_SquadEnemy", true),
			"completion": func() -> bool:
				var target: Node = t.find(&"Target_SquadEnemy")
				var health: HealthComponent = HealthComponent.find_on(target) if target != null else null
				return health != null and health.is_dead,
		},
	]


# --------------------------------------------------------------------------
# Section 6 - tactical camera and command range
# --------------------------------------------------------------------------

static func _recon(t: TutorialManager) -> Array:
	return [
		{
			"id": &"recon_send", "section": &"recon", "title": "Reconnaissance",
			"speaker": "STILGAR",
			"instruction": "Stay behind this wall. Send the Scout to the far overlook.",
			"hint": "Select the Scout with 2, press TAB, and right-click the distant marker.",
			"markers": ["Marker_Overlook", "Highlight_Scout"],
			"completion": func() -> bool:
				var scout: AllyCharacter = t.ally(2)
				var marker: Node2D = t.actor(&"Marker_Overlook")
				if scout == null or marker == null:
					return false
				if scout.ai.current_order != Order.MOVE_TO and scout.ai.current_order != Order.HOLD:
					return false
				return scout.ai.order_position.distance_to(marker.global_position) < 160.0,
		},
		{
			"id": &"recon_camera", "section": &"recon", "title": "Tactical camera",
			"speaker": "STILGAR",
			"instruction": "Watch him go. The view will let him lead it away from you.",
			"hint": "In command mode, WASD pans the tactical camera and the number keys recentre it.",
			"note": "The tactical camera can follow distant squad members.",
			"delay_after": 1.8,
			"completion": func() -> bool:
				var scout: AllyCharacter = t.ally(2)
				return scout != null and scout.global_position.distance_to(t.player.global_position) >= 520.0,
		},
		{
			"id": &"recon_weak", "section": &"recon", "title": "Weak link",
			"speaker": "STILGAR",
			"instruction": "Keep watching his link on the squad panel.",
			"hint": "The panel reads LINK: OK, then WEAK, then LOST as he gets further out.",
			"note": "A weak link still carries orders. It is a warning, not a wall.",
			"completion": func() -> bool:
				var scout: AllyCharacter = t.ally(2)
				return scout != null and t.squad.link_state(scout) != Link.CONNECTED,
		},
		{
			"id": &"recon_lost", "section": &"recon", "title": "Command range",
			"speaker": "STILGAR",
			"instruction": "There. He is past your range now.",
			"hint": "He keeps walking. He simply cannot hear anything new from you.",
			"note": "Units outside Paul's command range continue their current orders but cannot receive new commands.",
			"delay_after": 2.2,
			"completion": func() -> bool:
				var scout: AllyCharacter = t.ally(2)
				return scout != null and t.squad.link_state(scout) == Link.OUT_OF_RANGE,
		},
		{
			"id": &"recon_rejected", "section": &"recon", "title": "Link lost",
			"speaker": "STILGAR",
			"instruction": "Try it. Select the Scout and give him a new order.",
			"hint": "TAB into command mode, press 2, and right-click somewhere. Watch the panel refuse it.",
			"note": "Move Paul closer to restore the command link.",
			"delay_after": 1.8,
			"completion": func() -> bool: return t.happened(&"command_rejected"),
		},
		{
			"id": &"recon_restore", "section": &"recon", "title": "Restore the link",
			"speaker": "STILGAR",
			"instruction": "Leave command mode and walk toward him until he can hear you again.",
			"hint": "TAB out, then move. The link repairs itself the moment you are close enough.",
			"note": "COMMAND LINK RESTORED",
			"delay_after": 1.6,
			"completion": func() -> bool:
				var scout: AllyCharacter = t.ally(2)
				return scout != null and t.squad.link_state(scout) != Link.OUT_OF_RANGE,
		},
	]


# --------------------------------------------------------------------------
# Section 7 - prescience
# --------------------------------------------------------------------------

static func _prescience(t: TutorialManager) -> Array:
	return [
		{
			"id": &"presc_observe", "section": &"prescience", "title": "Observe",
			"speaker": "JESSICA",
			"instruction": "Take the covered post and watch the sentry crossing the gap.",
			"hint": "The marked stone by the wall. Stay behind it.",
			"markers": ["Marker_PrescienceWatch"],
			"completion": func() -> bool: return t.happened(&"enter_presc_watch") or t.at_trigger(&"presc_watch"),
		},
		{
			"id": &"presc_activate", "section": &"prescience", "title": "Prescience",
			"speaker": "JESSICA",
			"instruction": "You cannot read his timing by eye. Press Q.",
			"hint": "Q slows the world and shows you what is already in motion.",
			"note": "Prescience reveals likely near-future movement.",
			"completion": func() -> bool: return t.happened(&"prescience_started"),
		},
		{
			"id": &"presc_study", "section": &"prescience", "title": "Read the future",
			"speaker": "JESSICA",
			"instruction": "Hold the vision. Watch where he will be in one, two, three seconds.",
			"hint": "The ghosts are his path, not his ghosts. Follow the thread forward.",
			"hint_delay": 6.0,
			"completion": func() -> bool:
				if t.player.prescience.active:
					t.add_counter(&"studied", t.get_process_delta_time() / maxf(Engine.time_scale, 0.01))
				return t.counter(&"studied") >= 0.75,
		},
		{
			"id": &"presc_energy", "section": &"prescience", "title": "The cost",
			"speaker": "JESSICA",
			"instruction": "Look at your reserve. Prescience is not free.",
			"note": "Prescience consumes energy. Energy returns over time.",
			"delay_after": 2.0,
			"completion": func() -> bool:
				var energy: PrescienceEnergyComponent = t.player.prescience_energy
				return energy != null and energy.current_energy < energy.max_energy,
		},
		{
			"id": &"presc_cross", "section": &"prescience", "title": "Cross",
			"speaker": "JESSICA",
			"instruction": "Use the future path to cross to the far marker unseen.",
			"hint": "Read him again if you lose the timing. Being seen puts you back here.",
			"hint_delay": 12.0,
			"markers": ["Marker_PrescienceExit"],
			"note": "PRESCIENCE TRAINING COMPLETE",
			"delay_after": 1.4,
			"completion": func() -> bool: return t.happened(&"enter_presc_exit") or t.at_trigger(&"presc_exit"),
		},
	]


# --------------------------------------------------------------------------
# Section 8 - open desert and worm sign
# --------------------------------------------------------------------------

static func _desert(t: TutorialManager) -> Array:
	return [
		{
			"id": &"desert_cross", "section": &"desert", "title": "Open sand",
			"speaker": "STILGAR",
			"instruction": "Open sand carries vibration. Cross to the next rock.",
			"hint": "Just walk it. Watch the sign on your readout as you go.",
			"markers": ["Marker_MidRock"],
			"note": "Rock breaks the rhythm.",
			"delay_after": 1.6,
			"completion": func() -> bool: return t.happened(&"enter_mid_rock") or t.at_trigger(&"mid_rock"),
		},
		{
			"id": &"desert_sprint", "section": &"desert", "title": "Rhythm",
			"speaker": "STILGAR",
			"instruction": "Now sprint to the far rock. Hold SHIFT.",
			"hint": "Sprint the whole way. You will feel the difference in the readout.",
			"markers": ["Marker_FarRock"],
			"note": "Fast rhythmic movement attracts attention.",
			"delay_after": 1.6,
			"completion": func() -> bool:
				if t.player.is_sprinting:
					t.add_counter(&"desert_sprint", t.get_process_delta_time())
				return t.counter(&"desert_sprint") >= 0.6 and (t.happened(&"enter_far_rock") or t.at_trigger(&"far_rock")),
		},
		{
			"id": &"desert_fire", "section": &"desert", "title": "Gunfire",
			"speaker": "STILGAR",
			"instruction": "Fire at the target out on the sand.",
			"hint": "One shot is enough. Watch the sign jump.",
			"markers": ["Highlight_DesertTarget"],
			"note": "A firefight on open sand is a firefight against the desert too.",
			"delay_after": 1.6,
			"on_start": func() -> void:
				var worm: WormThreatManager = t.worm()
				t.add_counter(&"desert_sign_base", worm.worm_sign if worm != null else 0.0),
			# The lesson is the spike the shot puts into the sand, not the hit.
			"completion": func() -> bool:
				var worm: WormThreatManager = t.worm()
				if worm == null:
					return t.happened(&"weapon_fired")
				return t.happened(&"weapon_fired") and worm.worm_sign > t.counter(&"desert_sign_base"),
		},
		{
			"id": &"desert_machine", "section": &"desert", "title": "Vibration",
			"speaker": "STILGAR",
			"instruction": "Start the training rig with F, then stand back and watch.",
			"hint": "Get close to the rig and press F. Then let it run.",
			"markers": ["Highlight_Rig"],
			"note": "A standing rhythm calls louder than any of us can.",
			"completion": func() -> bool:
				var worm: WormThreatManager = t.worm()
				return worm != null and worm.stage >= WormThreatManager.Stage.INTERESTED,
		},
		{
			"id": &"desert_shelter", "section": &"desert", "title": "Shelter",
			"speaker": "STILGAR",
			"instruction": "It is coming for the rig. Get onto the far rock and stay there.",
			"hint": "The marked rock. Sand is where it hunts; stone is not.",
			"hint_delay": 8.0,
			"markers": ["Marker_Haven"],
			"note": "On open desert, vibration is a clock. Rock is safety.",
			"delay_after": 2.4,
			"completion": func() -> bool:
				var worm: WormThreatManager = t.worm()
				if worm == null:
					return true
				var safety: TerrainSafetyComponent = TerrainSafetyComponent.find_on(t.player)
				return t.happened(&"worm_finished") and safety != null and safety.is_safe(),
		},
	]


# --------------------------------------------------------------------------
# Section 9 - combined exercise
# --------------------------------------------------------------------------

static func _combined(t: TutorialManager) -> Array:
	return [
		{
			"id": &"combined_clear", "section": &"combined", "title": "Final exercise",
			"speaker": "GURNEY",
			"instruction": "Live opposition ahead, one patrolling and one shielded. Clear the yard.",
			"hint": "Read the patrol with Q before you commit, place your Fremen, and save the crysknife for the shielded one.",
			"hint_delay": 14.0,
			"completion": func() -> bool:
				var group: Node = t.find(&"CombinedEnemies")
				if group == null:
					return true
				for enemy: Node in group.get_children():
					var health: HealthComponent = HealthComponent.find_on(enemy)
					if health != null and not health.is_dead:
						return false
				return true,
		},
		{
			"id": &"combined_extract", "section": &"combined", "title": "Extraction",
			"speaker": "GURNEY",
			"instruction": "Yard is yours. Move to the extraction marker.",
			"hint": "The marked ground at the far end ends the exercise.",
			"markers": ["Marker_Extraction"],
			"delay_after": 0.4,
			"completion": func() -> bool: return t.happened(&"enter_extraction") or t.at_trigger(&"extraction"),
		},
	]
