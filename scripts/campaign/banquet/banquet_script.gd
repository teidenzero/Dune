class_name BanquetScript
extends RefCounted
## 1.2 The Banquet: who sits at the table, what each of them may secretly
## want, and what is said over five courses. All text is original.
##
## A reply has a certain part (`effects`, what anyone at the table can see it
## will do) and a part that depends on the guest's hidden agenda
## (`reactions`), which only a reading or a glimpse shows before it is said.
## Effect keys: "standings" {faction: n}, "resources" {id: n}, "heat" n,
## "kynes" n (his trust), "composure" n (the table's), "flags" [..].

const GUESTS: Array[Dictionary] = [
	{"id": &"water", "name": "Lingar Bewt", "title": "Master of the water-sellers' guild", "faction": &"choam", "portrait": "",
		"agendas": [&"greedy", &"afraid"], "may_inform": true},
	{"id": &"guild", "name": "Mael Serrin", "title": "Banker of the Spacing Guild", "faction": &"guild", "portrait": "",
		"agendas": [&"provocateur", &"indifferent"], "may_inform": true},
	{"id": &"choam", "name": "Carthag Ryme", "title": "Factor for CHOAM", "faction": &"choam", "portrait": "",
		"agendas": [&"profit"], "may_inform": true},
	{"id": &"smuggler", "name": "Esmar Tuek", "title": "A trader, of a kind", "faction": &"smugglers", "portrait": "",
		"agendas": [&"opportunist", &"wary"], "may_inform": false},
	{"id": &"kynes", "name": "Liet Kynes", "title": "Imperial Planetologist", "faction": &"fremen", "portrait": "kynes",
		"agendas": [&"judging"], "may_inform": false},
]

## What a reading tells you about each agenda.
const AGENDAS: Dictionary = {
	&"greedy": "Wants his monopoly and his Harkonnen prices kept, and nothing else.",
	&"afraid": "Is frightened. He fears the Harkonnen will return and punish whoever helped the Atreides.",
	&"provocateur": "Has come to goad the Duke into an insult the Guild can remember.",
	&"indifferent": "Cares for fees and freight, not for Great Houses.",
	&"profit": "Answers to the quota, and to nothing else.",
	&"opportunist": "Wants a share of the new Duke's routes, and will pay for it.",
	&"wary": "Has come to learn whether a Duke's word is worth anything in the desert.",
	&"judging": "Says little and watches everything. He is deciding whether this House values water and people above spice.",
	&"informant": "Is bought by the Harkonnen. Every word said tonight will reach the Baron.",
}

const COURSES: Array[Dictionary] = [
	{"guest": &"water", "course": "The first course",
		"line": "My lord Duke, my guild has carried Arrakeen's water for eighty years. We hope the new House will not mistake a fair profit for a crime.",
		"replies": [
			{"speaker": "DUKE LETO", "text": "Profit is no crime. Thirst is. Your prices will be looked at - fairly.",
				"effects": {"standings": {&"fremen": 1}, "kynes": 1},
				"reactions": {
					&"greedy": {"line": "Bewt's smile thins. \"Of course, my lord.\" He will not forget it.", "effects": {"standings": {&"choam": -1}, "composure": -1}},
					&"afraid": {"line": "Bewt breathes out, as if a weight had moved. Later, quietly, he names a Harkonnen agent in the town.", "effects": {"resources": {&"intel": 1}, "composure": 1}},
					&"informant": {"line": "Bewt nods too quickly, and remembers every word.", "effects": {"heat": 1}}}},
			{"speaker": "JESSICA", "text": "Your guild's service is known to us. We will speak of terms privately, when the table is cleared.",
				"effects": {},
				"reactions": {
					&"greedy": {"line": "Bewt is pleased: a private talk is where prices are kept.", "effects": {"standings": {&"choam": 1}, "composure": 1}},
					&"afraid": {"line": "He hesitates. He had hoped to hear that he was safe.", "effects": {}},
					&"informant": {"line": "He smiles. A private talk is just what his masters hoped for.", "effects": {"heat": 1}}}},
			{"speaker": "PAUL", "text": "On Arrakis a man's water is his life. Who profits from another man's thirst?",
				"effects": {"standings": {&"fremen": 1}, "kynes": 2, "composure": -1},
				"reactions": {
					&"greedy": {"line": "The table goes quiet. Bewt's knuckles are white on his cup.", "effects": {"standings": {&"choam": -1}, "composure": -1}},
					&"afraid": {"line": "Bewt looks at his plate, and says nothing at all.", "effects": {}},
					&"informant": {"line": "Bewt laughs as if it were a jest, and his eyes do not.", "effects": {}}}},
		]},
	{"guest": &"guild", "course": "The fish",
		"line": "They say the Atreides fought well on Caladan, where there was water to fight over. Here, I wonder - will the Duke keep to his walls, as the last House did?",
		"replies": [
			{"speaker": "DUKE LETO", "text": "The last House kept to its walls because it feared what was outside them. I do not.",
				"effects": {"kynes": 1},
				"reactions": {
					&"provocateur": {"line": "Serrin inclines his head, disappointed. The Duke gave him nothing to carry home.", "effects": {"composure": 1}},
					&"indifferent": {"line": "Serrin smiles thinly. A man who knows his own mind is good for business.", "effects": {"standings": {&"guild": 1}}},
					&"informant": {"line": "He files the boast away for someone else to read.", "effects": {"heat": 1}}}},
			{"speaker": "PAUL", "text": "And the Guild? Does it ever leave its ships?",
				"effects": {"composure": -1},
				"reactions": {
					&"provocateur": {"line": "There it is - the insult he came for. The Guild will remember it.", "effects": {"standings": {&"guild": -1}, "composure": -1}},
					&"indifferent": {"line": "Serrin laughs outright, and the table breathes again.", "effects": {"composure": 1}},
					&"informant": {"line": "He notes the heat in the boy, and smiles.", "effects": {}}}},
			{"speaker": "JESSICA", "text": "We have come to stay, Banker. The only question is how long you will stay at our table - all evening, I hope.",
				"effects": {"composure": 1},
				"reactions": {
					&"provocateur": {"line": "Deflected, gracefully. He will have to try again - and does not.", "effects": {}},
					&"indifferent": {"line": "Serrin raises his glass to the Lady. He likes a good host.", "effects": {"standings": {&"guild": 1}}},
					&"informant": {"line": "He answers the courtesy with courtesy, and learns nothing.", "effects": {}}}},
		]},
	{"guest": &"choam", "course": "The meat",
		"line": "The quota, my lord. CHOAM's directors will want to know that it will be met, whatever it costs.",
		"replies": [
			{"speaker": "DUKE LETO", "text": "It will be met.",
				"effects": {"standings": {&"choam": 1}, "kynes": -1},
				"reactions": {
					&"profit": {"line": "Ryme is satisfied, and says so twice.", "effects": {"composure": 1}},
					&"informant": {"line": "He will report the Duke's confidence - and the harvesters it will cost.", "effects": {"heat": 1}}}},
			{"speaker": "DUKE LETO", "text": "It will be met - but not with men's lives. A harvester that cannot be lifted will not be worked.",
				"effects": {"standings": {&"fremen": 1, &"choam": -1}, "kynes": 2},
				"reactions": {
					&"profit": {"line": "Ryme frowns and writes something down.", "effects": {"composure": -1}},
					&"informant": {"line": "He writes it down too, for a different reader.", "effects": {}}}},
			{"speaker": "JESSICA", "text": "The Duke has been on Arrakis a month, Factor. Ask him again in a year.",
				"effects": {},
				"reactions": {
					&"profit": {"line": "Ryme concedes the point, unhappily.", "effects": {}},
					&"informant": {"line": "He wanted a number. He will have to guess one for the Baron.", "effects": {"resources": {&"intel": 1}}}}},
		]},
	{"guest": &"smuggler", "course": "The sweets",
		"line": "I carry what the Guild will not, to where the Guild cannot. The Harkonnen knew how to look away. Does the Duke?",
		"replies": [
			{"speaker": "DUKE LETO", "text": "Honest trade has nothing to fear from me. The rest had better be careful.",
				"effects": {"standings": {&"guild": 1, &"smugglers": -1}},
				"reactions": {
					&"opportunist": {"line": "Tuek shrugs. There are other buyers.", "effects": {"standings": {&"smugglers": -1}}},
					&"wary": {"line": "Tuek nods slowly. Plain words, at least - he values those.", "effects": {"composure": 1}}}},
			{"speaker": "JESSICA", "text": "Gurney Halleck will call on you. He likes a man who speaks plainly.",
				"effects": {"standings": {&"smugglers": 1, &"guild": -1}, "flags": [&"smugglers_channel"]},
				"reactions": {
					&"opportunist": {"line": "Tuek smiles. It is exactly what he came for.", "effects": {"standings": {&"smugglers": 1}}},
					&"wary": {"line": "He will wait and see whether Gurney comes.", "effects": {}}}},
			{"speaker": "PAUL", "text": "What do you see from your side of the desert that we don't?",
				"effects": {"resources": {&"intel": 1}},
				"reactions": {
					&"opportunist": {"line": "He sells you a scrap, and makes it sound like more.", "effects": {}},
					&"wary": {"line": "He tells you something true, to see what you will do with it.", "effects": {"resources": {&"intel": 1}, "standings": {&"smugglers": 1}}}}},
		]},
	{"guest": &"kynes", "course": "The coffee",
		"line": "You have seen something of the desert now, young man. What do you make of it?",
		"replies": [
			{"speaker": "PAUL", "text": "It's a fortune. There's more spice out there than a House could ever spend.",
				"effects": {"standings": {&"choam": 1}, "kynes": -2},
				"reactions": {&"judging": {"line": "Kynes looks at Paul for a long moment, and turns back to his cup.", "effects": {}}}},
			{"speaker": "PAUL", "text": "It's a planet dying of thirst. I wonder what it would take to change that.",
				"effects": {"standings": {&"fremen": 1}, "kynes": 3},
				"reactions": {&"judging": {"line": "Something opens in Kynes's face. \"Do you,\" he says softly. \"So do I.\"", "effects": {"composure": 1}}}},
			{"speaker": "PAUL", "text": "I'd like to know the people who live in it.",
				"effects": {"standings": {&"fremen": 1}, "kynes": 2},
				"reactions": {&"judging": {"line": "\"Few ask,\" says Kynes. \"Fewer mean it.\" He is watching to see if Paul does.", "effects": {}}}},
		]},
]

## Kynes's trust at the end: at least this much, he trusts the Atreides.
const KYNES_TRUSTS: int = 5
const KYNES_DOUBTS: int = 1
const START_COMPOSURE: int = 5
const MAX_COMPOSURE: int = 6
const READINGS: int = 2
const GLIMPSES: int = 1
## The most one evening can move a faction's standing.
const MAX_SWING: int = 2


static func guest(id: StringName) -> Dictionary:
	for entry in GUESTS:
		if entry.id == id:
			return entry
	return {}
