class_name GrowthReport
extends RefCounted
## What grew in this mission, as lines for a results screen: experience per
## skill, spice saturation, rank-ups and milestones.


static func lines(campaign: CampaignState) -> PackedStringArray:
	var result: PackedStringArray = []
	if campaign == null or campaign.mission_gains.is_empty() and campaign.growth_log.is_empty():
		return result
	result.append("")
	result.append("GROWTH")
	var gains: PackedStringArray = []
	for key: String in campaign.mission_gains:
		var parts: PackedStringArray = key.split("/")
		var what: String = parts[1] if parts.size() > 1 else key
		var amount: float = float(campaign.mission_gains[key])
		if amount <= 0.0:
			continue
		if what == "saturation":
			gains.append("Spice saturation +%.1f" % amount)
		else:
			gains.append("%s +%d" % [Progression.SKILL_NAMES.get(StringName(what), what), roundi(amount)])
	if not gains.is_empty():
		result.append("   ·   ".join(gains))
	for line in campaign.growth_log:
		result.append(line)
	return result
