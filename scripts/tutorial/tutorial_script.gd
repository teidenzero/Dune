class_name TutorialScript
extends RefCounted
## The Arrakeen training sequence: what each step says and how the game proves
## the player did it. Every condition reads real gameplay state or an event
## recorded from an existing gameplay signal - nothing here simulates a mechanic.
##
## All dialogue is original placeholder text written for this prototype.

const Order = AllyAIController.Order
const Link = CommandLinkComponent.State
## Where the Fremen wait in the prescience yard: 470 px beside the sentry's
## lane, outside his cone and beyond his sight.
const PRESCIENCE_STAGING: Array[Vector2] = [Vector2(5850, 150), Vector2(5850, 330)]


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
			"speaker": "DUKE LETO",
			"instruction": "Your squad is yours to command: you, and two Fremen guides. Right-click the marked stone and all three go.",
			"hint": "All three are selected - see their cards, bottom left. Right-click ground to move. WASD or the screen edge moves the camera.",
			"markers": ["Marker_MoveA"],
			"completion": func() -> bool: return t.happened(&"enter_move_a") or t.at_trigger(&"move_a"),
		},
		{
			"id": &"move_sprint", "section": &"movement", "title": "Sprint",
			"speaker": "DUKE LETO",
			"instruction": "Double right-click the far marker to run there.",
			"hint": "Two quick right-clicks on the same spot. Running is faster, and far louder.",
			"markers": ["Marker_MoveB"],
			"completion": func() -> bool:
				if t.player.is_sprinting:
					t.add_counter(&"sprint", t.get_process_delta_time())
				return t.counter(&"sprint") >= 0.8 and (t.happened(&"enter_move_b") or t.at_trigger(&"move_b")),
		},
		{
			"id": &"move_crouch", "section": &"movement", "title": "Crouch",
			"speaker": "DUKE LETO",
			"instruction": "Press C: the whole squad goes low. Then right-click across the sand bed.",
			"hint": "C crouches everyone at once, and C again stands everyone up. Move while low to feel the difference.",
			"markers": ["Marker_MoveC"],
			"note": "Low, the squad is slower, quieter, and harder to see.",
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
			"id": &"fire_target", "section": &"ranged", "title": "Ranged combat",
			"speaker": "DUKE LETO",
			"instruction": "The maula pistol is yours. Right-click the target to open fire.",
			"hint": "Right-click an enemy: Paul closes to pistol range and shoots until it drops or you give a new order.",
			"markers": ["Highlight_AimTarget"],
			"completion": func() -> bool: return t.happened(&"damaged_Target_Aim"),
		},
		{
			"id": &"reload_weapon", "section": &"ranged", "title": "Reload",
			"speaker": "GURNEY",
			"instruction": "Press R to reload. Do it before you need to, not after.",
			"hint": "R reloads. Count your shots: an empty gun only clicks, and that is the worst moment to find out.",
			"completion": func() -> bool: return t.happened(&"reload_finished"),
		},
		{
			"id": &"cover_target", "section": &"ranged", "title": "Cover",
			"speaker": "GURNEY",
			"instruction": "That target sits behind a pillar. Right-click it anyway.",
			"hint": "Paul walks until he has a clean line, then fires. Where he ends up standing is your problem.",
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
			"instruction": "Take the crysknife. With Paul selected, left-click the practice dummy.",
			"hint": "A quick left-click on an enemy is a quick strike: Paul walks into reach and cuts. Right-click would shoot instead.",
			"markers": ["Highlight_MeleeDummy"],
			"completion": func() -> bool: return t.happened(&"melee_hit_fast"),
		},
		{
			"id": &"melee_slow", "section": &"melee", "title": "Slow strike",
			"speaker": "DUNCAN",
			"instruction": "Now the slow strike. Hold left-click on the dummy until the ring fills, then let go.",
			"hint": "Hold the button until the crysknife slot glows. A held click commits Paul to the slow stroke.",
			"markers": ["Highlight_MeleeDummy"],
			"note": "The slow stroke hits far harder, and it commits you.",
			"completion": func() -> bool: return t.happened(&"melee_hit_slow"),
		},
		{
			"id": &"shield_shot", "section": &"melee", "title": "Shields: gunfire",
			"speaker": "DUNCAN",
			"instruction": "This one wears a body shield. Right-click it to shoot.",
			"hint": "Go ahead, click again and again - empty the magazine into it. Learn this the cheap way.",
			"markers": ["Highlight_ShieldDummy"],
			"note": "Fast attacks cannot penetrate an active personal shield.",
			"completion": func() -> bool: return t.happened(&"shield_blocked_ranged"),
		},
		{
			"id": &"shield_fast", "section": &"melee", "title": "Shields: fast blade",
			"speaker": "DUNCAN",
			"instruction": "Try a fast crysknife strike.",
			"hint": "A quick left-click on the shielded dummy. Watch what the shield does with it.",
			"markers": ["Highlight_ShieldDummy"],
			"note": "The blade is moving too quickly.",
			"completion": func() -> bool: return t.happened(&"shield_blocked_melee"),
		},
		{
			"id": &"shield_slow", "section": &"melee", "title": "Shields: slow blade",
			"speaker": "DUNCAN",
			"instruction": "Slow the blade. Hold left-click on it, let the ring fill, and push it through.",
			"hint": "The shield stops speed, not steel. Only the slow stroke gets in.",
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
			"hint": "Sneak with C, move in short right-clicks from stone to stone, and pause with SPACE whenever you need to think.",
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
			"speaker": "DUKE LETO",
			"instruction": "Two of my people will train with you. Click the Scout, or press 2.",
			"hint": "1 is Paul, 2 the Scout, 3 the Warrior, 4 everyone. The cards bottom-left work too.",
			"markers": ["Highlight_Scout"],
			"completion": func() -> bool:
				return not t.squad.paul_selected and t.squad.selected_members.size() == 1 and t.squad.selected_members[0].selection_slot == 2,
		},
		{
			"id": &"squad_select_both", "section": &"squad", "title": "Squad",
			"speaker": "DUKE LETO",
			"instruction": "Take everyone at once. Press 4, or drag a box around the three of you.",
			"hint": "Hold left-click and drag to draw a selection box.",
			"completion": func() -> bool: return t.squad.selected_members.size() == 2 and t.squad.paul_selected,
		},
		{
			"id": &"squad_pause", "section": &"squad", "title": "Pause",
			"speaker": "DUKE LETO",
			"instruction": "Press SPACE to stop the world, then SPACE again to let it run.",
			"hint": "While paused you can still select and give orders. They start the moment you resume.",
			"completion": func() -> bool: return t.happened(&"paused") and not t.squad.paused,
		},
		{
			"id": &"squad_move", "section": &"squad", "title": "Move order",
			"speaker": "DUKE LETO",
			"instruction": "Select only the Scout and right-click the marked ground to send him there.",
			"hint": "Click the Scout or press 2, then right-click the marker.",
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
			"speaker": "DUKE LETO",
			"instruction": "Select the Warrior with 3 and press H. He holds where he stands.",
			"hint": "H holds the selected Fremen in place. They will still defend themselves.",
			"markers": ["Highlight_Warrior"],
			"completion": func() -> bool:
				var warrior: AllyCharacter = t.ally(3)
				return warrior != null and warrior.ai.current_order == Order.HOLD,
		},
		{
			"id": &"squad_follow", "section": &"squad", "title": "Recall",
			"speaker": "DUKE LETO",
			"instruction": "Press G to call the Warrior back to you.",
			"hint": "G returns the selected Fremen to following you.",
			"completion": func() -> bool:
				var warrior: AllyCharacter = t.ally(3)
				if warrior == null or warrior.ai.current_order != Order.FOLLOW:
					return false
				return warrior.global_position.distance_to(t.player.global_position) < 220.0,
		},
		{
			"id": &"squad_discipline", "section": &"squad", "title": "Fire discipline",
			"speaker": "DUKE LETO",
			"instruction": "Your Fremen hold their fire until you say otherwise - their cards read HOLD. Select both and press B for RETURN: they answer anyone who sees them. Press again for AT WILL. Crouching (C) puts the whole squad back on HOLD until you are seen.",
			"hint": "Press 4 for both Fremen, then B. Each press moves on: HOLD, RETURN, AT WILL.",
			"note": "A squad that holds its fire chooses when the fight begins.",
			"completion": func() -> bool:
				for member in t.squad.members:
					if is_instance_valid(member) and member.ai.fire_discipline != AllyAIController.Fire.RETURN:
						return false
				return not t.squad.members.is_empty(),
		},
		{
			"id": &"squad_signal", "section": &"squad", "title": "On my signal",
			"speaker": "DUKE LETO",
			"instruction": "A raid moves as one. Hold CTRL and right-click to plan an order: nothing happens yet, but a line shows the plan. Plan one for each Fremen, then press F - on your signal, they go together.",
			"hint": "Press 2, CTRL + right-click a spot. Press 3, CTRL + right-click another. Then F. H calls a plan off.",
			"note": "Plan in quiet, strike at once.",
			"completion": func() -> bool: return t.squad.last_signal_count >= 2,
		},
		{
			"id": &"squad_attack", "section": &"squad", "title": "Attack order",
			"speaker": "DUKE LETO",
			"instruction": "A target stands at the end of the yard. Order the Scout to kill it.",
			"hint": "Select the Scout, then right-click directly on the hostile.",
			"markers": ["Highlight_SquadEnemy"],
			"note": "Holding fire, a Fremen still shoots what you point him at.",
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
			"speaker": "DUKE LETO",
			"instruction": "Stay behind this wall. Send the Scout to the far overlook.",
			"hint": "Select the Scout with 2 and right-click the distant marker. Paul stays put.",
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
			"id": &"recon_camera", "section": &"recon", "title": "Camera",
			"speaker": "DUKE LETO",
			"instruction": "Watch him go. Pan after him with WASD or the screen edge.",
			"hint": "Press 2 twice quickly to jump the camera to the Scout. 1 twice brings it back to Paul.",
			"note": "The camera goes wherever you look. Your people stay where you put them.",
			"delay_after": 1.8,
			"completion": func() -> bool:
				var scout: AllyCharacter = t.ally(2)
				return scout != null and scout.global_position.distance_to(t.player.global_position) >= 520.0,
		},
		{
			"id": &"recon_weak", "section": &"recon", "title": "Weak link",
			"speaker": "DUKE LETO",
			"instruction": "Keep watching his link on the squad panel.",
			"hint": "The bars on his card drop from three, to two, to a red cross as he gets further out.",
			"note": "A weak link still carries orders. It is a warning, not a wall.",
			"completion": func() -> bool:
				var scout: AllyCharacter = t.ally(2)
				return scout != null and t.squad.link_state(scout) != Link.CONNECTED,
		},
		{
			"id": &"recon_lost", "section": &"recon", "title": "Command range",
			"speaker": "DUKE LETO",
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
			"speaker": "DUKE LETO",
			"instruction": "Try it. Select the Scout and give him a new order.",
			"hint": "Press 2 and right-click somewhere. Watch the order bounce.",
			"note": "Move Paul closer to restore the command link.",
			"delay_after": 1.8,
			"completion": func() -> bool: return t.happened(&"command_rejected"),
		},
		{
			"id": &"recon_restore", "section": &"recon", "title": "Restore the link",
			"speaker": "DUKE LETO",
			"instruction": "Select Paul and walk him toward the Scout until he can hear you again.",
			"hint": "Press 1, then right-click toward the Scout. The link repairs itself the moment you are close enough.",
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
			"id": &"presc_observe", "section": &"prescience", "title": "The watch post",
			"speaker": "JESSICA",
			"instruction": "A sentry walks the gap ahead. Take the watch post beside his lane and sneak with C.",
			"hint": "Right-click the marked post. His cone looks along his lane, north and south - from out to the side he cannot see you.",
			"markers": ["Marker_PrescienceWatch"],
			"note": "Watch his cone: it never points at the post.",
			# The Fremen wait out of sight until their own lesson.
			"on_start": func() -> void: t.station_allies(PRESCIENCE_STAGING),
			"completion": func() -> bool: return t.happened(&"enter_presc_watch") or t.at_trigger(&"presc_watch"),
		},
		{
			"id": &"presc_activate", "section": &"prescience", "title": "Prescience",
			"speaker": "JESSICA",
			"instruction": "You cannot read his timing by eye. Press Q.",
			"hint": "Q slows the world to a fifth of its speed for a few seconds and shows what is already in motion.",
			"note": "Each blue ghost is where he will be: +1s, +2s, +3s.",
			"completion": func() -> bool: return t.happened(&"prescience_started"),
		},
		{
			"id": &"presc_study", "section": &"prescience", "title": "Read the future",
			"speaker": "JESSICA",
			"instruction": "Follow the ghosts forward. Where they bunch together, he stops and turns.",
			"hint": "The thread runs from him through +1s, +2s, +3s. A turn at the end of his lane is where his back is to you.",
			"hint_delay": 6.0,
			"completion": func() -> bool:
				if t.player.prescience.active:
					t.add_counter(&"studied", t.get_process_delta_time() / maxf(Engine.time_scale, 0.01))
				return t.counter(&"studied") >= 0.75,
		},
		{
			"id": &"presc_energy", "section": &"prescience", "title": "The cost",
			"speaker": "JESSICA",
			"instruction": "Look at the ring around Q on your action bar. Prescience is not free.",
			"note": "Each vision costs a third of your reserve. It refills while you wait.",
			"delay_after": 2.0,
			"completion": func() -> bool:
				var energy: PrescienceEnergyComponent = t.player.prescience_energy
				return energy != null and energy.current_energy < energy.max_energy,
		},
		{
			"id": &"presc_pause", "section": &"prescience", "title": "Stop and think",
			"speaker": "JESSICA",
			"instruction": "Three seconds is short. Press Q, then SPACE while the vision is open. SPACE again when you have seen enough.",
			"hint": "Paused, the vision stays up and does not run down. Study it as long as you like, then resume.",
			"hint_delay": 8.0,
			"note": "Pause holds the vision. Plan against the future, then let it happen.",
			"delay_after": 1.6,
			"completion": func() -> bool: return t.happened(&"paused_in_vision") and not t.squad.paused,
		},
		{
			"id": &"presc_scout", "section": &"prescience", "title": "Their future too",
			"speaker": "JESSICA",
			"instruction": "The Scout crosses first - but plan it before you send him. Select him (2), CTRL + right-click the far marker, and press Q: the vision walks your plan beside the sentry. Gold is clear; red is where he would be SEEN. When it reads clear, press F.",
			"hint": "The plan line is already red where it crosses his view as he stands now - but he walks. Q shows where he will be: red from the moment he would see the Scout, and his cone at that moment. Wait for the gap, read it again, then F. C makes the Scout harder to spot.",
			"hint_delay": 6.0,
			"markers": ["Marker_PrescienceExit", "Highlight_Scout"],
			"note": "A plan read in a vision is a plan rehearsed.",
			"delay_after": 1.4,
			"retry_here": true,
			# A retry lands here straight from a reload; stage the Fremen again.
			"on_start": func() -> void: t.station_allies(PRESCIENCE_STAGING),
			"completion": func() -> bool:
				var sentry: EnemyCharacter = t.find(&"PrescienceSentry") as EnemyCharacter
				# The sentry breaking his patrol over a Fremen means the Scout was
				# seen. Paul being seen is the stealth rule's business, not this one.
				var disturbed: bool = sentry != null and not sentry.health.is_dead and sentry.ai.state != EnemyAIController.State.PATROL and sentry.ai.state != EnemyAIController.State.RETURN
				if disturbed and sentry.perception.target is AllyCharacter:
					t.fail_section("THE SENTRY SAW THE SCOUT")
					return false
				var scout: AllyCharacter = t.ally(2)
				var marker: Node2D = t.actor(&"Marker_PrescienceExit")
				return scout != null and marker != null and scout.global_position.distance_to(marker.global_position) < 110.0,
		},
		{
			"id": &"presc_cross", "section": &"prescience", "title": "Your turn",
			"speaker": "JESSICA",
			"instruction": "Now you. Read him, and cross behind him to the Scout.",
			"hint": "Press Q, pause if you need to, and right-click the far marker when his ghosts walk away from your line.",
			"hint_delay": 12.0,
			"markers": ["Marker_PrescienceExit"],
			"retry_here": true,
			"on_start": func() -> void: t.hold_allies(),
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
			"speaker": "KYNES",
			"instruction": "Open sand carries vibration. Cross to the next rock.",
			"hint": "Right-click the rock and just walk it. Watch the worm readout, top right.",
			"markers": ["Marker_MidRock"],
			"note": "Rock breaks the rhythm.",
			"delay_after": 1.6,
			"completion": func() -> bool: return t.happened(&"enter_mid_rock") or t.at_trigger(&"mid_rock"),
		},
		{
			"id": &"desert_sprint", "section": &"desert", "title": "Rhythm",
			"speaker": "KYNES",
			"instruction": "Now run to the far rock. Double right-click it.",
			"hint": "Run the whole way. You will feel the difference in the readout.",
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
			"speaker": "KYNES",
			"instruction": "Step off the rock onto the sand, then right-click the target to fire.",
			"hint": "Rock swallows the shock of a shot; sand carries it. Fire from the sand and watch the readout jump.",
			"markers": ["Highlight_DesertTarget"],
			"note": "A firefight on open sand is a firefight against the desert too.",
			"delay_after": 1.6,
			"on_start": func() -> void:
				t.add_counter(&"desert_shots_seen", float(t.count(&"weapon_fired"))),
			# The lesson is the shot fired from the sand, not the hit. Rock mutes
			# gunfire completely, so a shot from the rock teaches nothing and
			# does not count.
			"completion": func() -> bool:
				var shots: int = t.count(&"weapon_fired")
				if shots <= int(t.counter(&"desert_shots_seen")):
					return false
				t.add_counter(&"desert_shots_seen", float(shots) - t.counter(&"desert_shots_seen"))
				var safety: TerrainSafetyComponent = TerrainSafetyComponent.find_on(t.player)
				return safety == null or not safety.is_safe(),
		},
		{
			"id": &"desert_machine", "section": &"desert", "title": "Vibration",
			"speaker": "KYNES",
			"instruction": "Right-click the training rig to start it, then stand back and watch.",
			"hint": "Paul walks to the rig and throws the switch. Then let it run.",
			"markers": ["Highlight_Rig"],
			"note": "A standing rhythm calls louder than any of us can.",
			"completion": func() -> bool:
				var worm: WormThreatManager = t.worm()
				return worm != null and worm.stage >= WormThreatManager.Stage.INTERESTED,
		},
		{
			"id": &"desert_shelter", "section": &"desert", "title": "Shelter",
			"speaker": "KYNES",
			"instruction": "It is coming for the rig. Get onto the far rock and stay there.",
			"hint": "Double right-click the marked rock. Sand is where it hunts; stone is not.",
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
			"instruction": "Live opposition ahead: three guards, one on patrol, and a shielded elite. Clear the yard - with the whole squad.",
			"hint": "Pause with SPACE, read the patrol with Q, place your Fremen, set their fire with B, and save a held left-click - the slow blade - for the shielded one.",
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
