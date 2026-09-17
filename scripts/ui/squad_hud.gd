extends PanelContainer

const LINK_COLORS: Dictionary = {
	CommandLinkComponent.State.CONNECTED: Color(0.65, 1, 0.9),
	CommandLinkComponent.State.WEAK_LINK: Color(1, 0.86, 0.45),
	CommandLinkComponent.State.OUT_OF_RANGE: Color(1, 0.55, 0.45),
}
## Out of contact because the player put him there, not because it went wrong.
const POSTED_COLOR: Color = Color(0.78, 0.82, 0.86)

var manager: SquadManager


func _process(_delta: float) -> void:
	if not is_instance_valid(manager):
		return
	$Rows/Mode.text = "COMMAND MODE  ·  %.0f%% speed" % (manager.command_time_scale * 100) if manager.command_mode else "FREMEN SQUAD"
	for slot in [2, 3]:
		var row: Label = $Rows/Scout if slot == 2 else $Rows/Warrior
		row.text = "Scout unavailable" if slot == 2 else "Warrior unavailable"
		row.modulate = Color.WHITE
		for ally in manager.members:
			if not is_instance_valid(ally) or ally.selection_slot != slot:
				continue
			var label: String = "Scout" if slot == 2 else "Warrior"
			if ally.health.is_dead:
				row.text = "%s %s  0/%.0f  DOWN" % [" ", label, ally.health.max_health]
				row.modulate = Color(0.7, 0.7, 0.7)
				continue
			var state: int = manager.link_state(ally)
			row.text = "%s %s  %.0f/%.0f  %s  LINK: %s" % [
				">" if ally.selected else " ",
				label,
				ally.health.current_health,
				ally.health.max_health,
				AllyAIController.Order.keys()[ally.ai.current_order],
				ally.command_link.short_label(),
			]
			# An ally the player deliberately left holding is not a fault, so an
			# out-of-range HOLD reads as a posted sentry rather than a red alert.
			var posted: bool = ally.ai.current_order == AllyAIController.Order.HOLD
			var tint: Color = LINK_COLORS.get(state, Color.WHITE)
			if posted and state == CommandLinkComponent.State.OUT_OF_RANGE:
				tint = POSTED_COLOR
			row.modulate = tint if (ally.selected or state != CommandLinkComponent.State.CONNECTED) else Color.WHITE
	var status: Label = $Rows/Status
	status.visible = manager.rejection_active()
	status.text = manager.rejection_message
	$Rows/Help.text = "1 Paul   2 Scout   3 Warrior   4 Both\nH Hold   G Follow   TAB Commands   MMB Watch ally"
	if manager.command_mode:
		$Rows/Help.text += "\nLMB Select · Shift-click Add/remove\nRMB Ground: Move / Enemy: Attack\nWASD / screen edge pans camera\nPaul stays still · TAB Resume"
