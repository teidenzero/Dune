extends PanelContainer

const RESULT_DISPLAY_MS: int = 1400
const CHARGE_COLOR: Color = Color(0.85, 0.95, 1.0)
const SLOW_COLOR: Color = Color(1.0, 0.78, 0.35)
const BLOCKED_COLOR: Color = Color(0.45, 0.85, 1.0)
const HIT_COLOR: Color = Color(0.7, 1.0, 0.7)
const DENIED_DISPLAY_MS: int = 1600
const BAR_SEGMENTS: int = 10
const ACTIVE_COLOR: Color = Color(0.72, 0.86, 1.0)
const DENIED_COLOR: Color = Color(1, 0.62, 0.45)
const LOW_COLOR: Color = Color(0.72, 0.72, 0.72)
const WORM_COLORS: Array[Color] = [
	Color(0.8, 0.8, 0.8), Color(0.88, 0.84, 0.66), Color(1.0, 0.86, 0.5),
	Color(1.0, 0.7, 0.36), Color(1.0, 0.5, 0.3), Color(1.0, 0.35, 0.28),
]

var weapon: WeaponController
var health: HealthComponent
var player: PlayerController


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var profile: StealthProfile = player.stealth_profile
	var mode: String = profile.stance if player.is_crouching else profile.movement_mode
	if mode == "STILL":
		mode = "STANDING"
	$Margin/Rows/Stealth.text = "%s | Noise: %.0f" % [mode, profile.current_noise_radius]
	$Margin/Rows/Stealth.visible = not player.health.is_dead
	_refresh_melee()
	_refresh_prescience()
	_refresh_worm()


## Crysknife readiness, charge progress, and the outcome of the last swing.
func _refresh_melee() -> void:
	var row: Label = $Margin/Rows/Melee
	var melee: MeleeController = player.melee
	row.visible = not player.health.is_dead
	if not row.visible:
		return
	var color: Color = Color.WHITE
	var text: String = "Crysknife: READY"
	match melee.state:
		MeleeController.State.CHARGING:
			if melee.slow_ready:
				text = "PENETRATING STRIKE READY"
				color = SLOW_COLOR
			else:
				text = "Slow Attack: %d%%" % roundi(melee.charge_ratio() * 100.0)
				color = CHARGE_COLOR
		MeleeController.State.IDLE:
			if Time.get_ticks_msec() - melee.last_result_time < RESULT_DISPLAY_MS:
				text = "%s: %s" % [melee.last_attack_name, "TOO FAST - BLOCKED" if melee.last_result == "BLOCKED" else "HIT " + melee.last_target]
				color = BLOCKED_COLOR if melee.last_result == "BLOCKED" else HIT_COLOR
		_:
			text = "Crysknife: " + melee.attack_name()
			color = SLOW_COLOR if melee.current_attack == melee.slow_attack else CHARGE_COLOR
	row.text = text
	row.modulate = color


## Compact reserve bar, remaining real time while active, and a brief refusal.
func _refresh_prescience() -> void:
	var row: Label = $Margin/Rows/Prescience
	var prescience: PrescienceController = player.prescience
	var energy: PrescienceEnergyComponent = player.prescience_energy
	row.visible = not player.health.is_dead
	if not row.visible or prescience == null or energy == null:
		return
	if Time.get_ticks_msec() - prescience.last_denied_time < DENIED_DISPLAY_MS:
		row.text = prescience.last_denied_reason
		row.modulate = DENIED_COLOR
		return
	var filled: int = int(roundf(energy.ratio() * BAR_SEGMENTS))
	var bar: String = ""
	for index in range(BAR_SEGMENTS):
		bar += "█" if index < filled else "░"
	if prescience.active:
		row.text = "PRESCIENCE %s  %.1fs" % [bar, prescience.remaining]
		row.modulate = ACTIVE_COLOR
		return
	row.text = "PRESCIENCE %s %d/%d" % [bar, roundi(energy.current_energy), roundi(energy.max_energy)]
	row.modulate = Color.WHITE if energy.can_spend() else LOW_COLOR


## Stage first, number second, and nothing at all while the desert is calm.
func _refresh_worm() -> void:
	var row: Label = $Margin/Rows/Worm
	var worm: WormThreatManager = get_tree().get_first_node_in_group("worm_threat") as WormThreatManager
	if worm == null or player.health.is_dead:
		row.hide()
		return
	row.visible = worm.stage > WormThreatManager.Stage.CALM or worm.is_worm_approaching()
	if not row.visible:
		return
	var filled: int = int(roundf(worm.ratio() * BAR_SEGMENTS))
	var bar: String = ""
	for index in range(BAR_SEGMENTS):
		bar += "█" if index < filled else "░"
	row.text = "%s %s" % [worm.stage_text(), bar]
	row.modulate = WORM_COLORS[mini(int(worm.stage), WORM_COLORS.size() - 1)]


func bind_weapon(controller: WeaponController) -> void:
	weapon = controller
	weapon.ammo_changed.connect(_on_ammo_changed)
	weapon.reload_started.connect(_refresh)
	weapon.reload_finished.connect(_refresh)
	_refresh()


func bind_health(component: HealthComponent) -> void:
	health = component
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current_health, health.max_health)


func _on_health_changed(current: float, maximum: float) -> void:
	$Margin/Rows/Health.text = "HP: %.0f / %.0f" % [current, maximum]
	$Margin/Rows/Down.visible = current <= 0.0
	if current <= 0.0:
		$Margin/Rows/Status.hide()
		$Margin/Rows/Melee.hide()
		$Margin/Rows/Prescience.hide()
		$Margin/Rows/Worm.hide()


func _on_ammo_changed(_ammo: int, _size: int) -> void:
	_refresh()


func _refresh() -> void:
	$Margin/Rows/Weapon.text = "Weapon: " + weapon.weapon_data.weapon_name
	$Margin/Rows/Ammo.text = "Ammo: %d / %d" % [weapon.current_ammo, weapon.weapon_data.magazine_size]
	var status: Label = $Margin/Rows/Status
	status.text = "Reloading..." if weapon.is_reloading else "Empty - R to reload"
	status.visible = weapon.is_reloading or weapon.current_ammo == 0
