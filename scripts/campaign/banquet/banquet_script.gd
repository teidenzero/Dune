class_name BanquetScript
extends RefCounted
## 1.2 The Banquet: who sits at the table, what each of them may secretly
## want, and what Paul can say over five courses. All text is original.
##
## Paul is the one who speaks. His parents always know what to say; he is
## learning it. Each course a guest speaks, and Paul has three replies. Which
## one is good depends on what the guest secretly wants (his agenda, set by
## the seed), so the table has to be read, not memorised.
##
## A reply has two parts:
##   `beyond`     what it does around the table - other factions, Kynes, the
##                Baron's ears. The Duke's memory shows it.
##   `reactions`  how this guest takes it, by agenda: his line, his faction,
##                the table's composure, and a `grade` (good / mixed / poor).
##                Jessica's face shows it.
## A reply that lands badly has a `rescue`: the Duke or Jessica steps in, in
## words fitted to what Paul said - the player learns from how his parents
## react, not from numbers. Good and half-good replies draw a look or a word
## from APPROVAL and NUDGE.
## Every course also carries `tells` (a detail anyone at the table can see,
## by agenda - the player's own reading), Jessica's `face` (by agenda) and the
## Duke's `memory` (one lesson for the course).
## Effect keys: "standings" {faction: n}, "resources" {id: n}, "heat" n,
## "kynes" n (his trust), "composure" n (the table's), "flags" [..],
## "reveal" true (the reply shows the guest's agenda for what it is).

const GUESTS: Array[Dictionary] = [
	{"id": &"water", "name": "Lingar Bewt", "title": "Master of the water-sellers' guild", "faction": &"choam", "portrait": "lingar_bewt",
		"agendas": [&"greedy", &"afraid"], "may_inform": true},
	{"id": &"guild", "name": "Mael Serrin", "title": "Banker of the Spacing Guild", "faction": &"guild", "portrait": "mael_serrin",
		"agendas": [&"provocateur", &"indifferent"], "may_inform": true},
	{"id": &"choam", "name": "Carthag Ryme", "title": "Factor for CHOAM", "faction": &"choam", "portrait": "carthag_ryme",
		"agendas": [&"profit", &"hedging"], "may_inform": true},
	{"id": &"smuggler", "name": "Esmar Tuek", "title": "A trader, of a kind", "faction": &"smugglers", "portrait": "esmar_tuek",
		"agendas": [&"opportunist", &"wary"], "may_inform": false},
	{"id": &"kynes", "name": "Liet Kynes", "title": "Imperial Planetologist", "faction": &"fremen", "portrait": "kynes",
		"agendas": [&"judging", &"testing"], "may_inform": false},
]

## What each agenda is, in plain words, once known.
const AGENDAS: Dictionary = {
	&"greedy": "Wants his monopoly and his Harkonnen prices kept, and nothing else.",
	&"afraid": "Is frightened. He fears the Harkonnen will return and punish whoever helped the Atreides.",
	&"provocateur": "Has come to goad the House into an insult the Guild can remember.",
	&"indifferent": "Cares for fees and freight, not for Great Houses.",
	&"profit": "Answers to the quota, and to nothing else.",
	&"hedging": "Is weighing whether this House will last, before CHOAM chooses a side.",
	&"opportunist": "Wants a share of the new Duke's routes, and will pay for it.",
	&"wary": "Has come to learn whether an Atreides word is worth anything in the desert.",
	&"judging": "Is deciding whether this House values water and people above spice.",
	&"testing": "Wants to know whether Paul has understood the desert at all.",
	&"informant": "Is bought by the Harkonnen. Every word said tonight will reach the Baron.",
}

## The informant's tell is the same at every seat: a patient reader learns it.
const INFORMANT_TELL: String = "He waits for every answer before he eats, and he is listening to the whole table, not only to Paul."
const INFORMANT_FACE: String = "Mother's face is still - too still. This one is listening for someone else. Give him as little as you can."

const COURSES: Array[Dictionary] = [
	{"guest": &"water", "course": "The first course",
		"line": "Young master, my guild has carried Arrakeen's water for eighty years. I hope the new House will not mistake a fair profit for a crime.",
		"tells": {
			&"greedy": "He has not touched his own water. His eyes go round the table, counting the glasses.",
			&"afraid": "His hand shakes a little as he sets his cup down, and he looks at the door before he speaks.",
		},
		"face": {
			&"greedy": "Mother's eyes rest on Bewt's untouched glass. He wants to keep what he has - that is all.",
			&"afraid": "Mother's glance is gentle. This man is not greedy; he is frightened.",
		},
		"memory": "Father, to the fishing guilds of Caladan: keep your trade, keep it honest, and it is safe with me. He promised them nothing he could not watch.",
		"replies": [
			{"text": "A fair profit is an honest one. My father's clerks will want to see the ledgers.",
				"rescue": {"speaker": "DUKE LETO", "line": "My son has his mother's eye for accounts. The clerks will be discreet, Master Bewt - you have my word on that."},
				"beyond": {"standings": {&"fremen": 1}, "kynes": 1},
				"reactions": {
					&"greedy": {"grade": &"mixed", "line": "Bewt's smile stays; his eyes do not. He will show the clerks a ledger - not the real one.", "effects": {"standings": {&"choam": -1}, "composure": 1}},
					&"afraid": {"grade": &"good", "line": "Bewt breathes out, as if a weight had moved. Later, quietly, he names a Harkonnen agent in the town.", "effects": {"resources": {&"intel": 1}, "composure": 1}},
					&"informant": {"grade": &"mixed", "line": "Bewt nods too quickly. The Baron will know the ledgers are to be opened.", "effects": {"heat": 1}}}},
			{"text": "Your guild's charter stands. The House won't change what works.",
				"rescue": {"speaker": "JESSICA", "line": "Paul speaks of the charter; the terms, of course, are his father's to set."},
				"beyond": {"standings": {&"fremen": -1}, "kynes": -1},
				"reactions": {
					&"greedy": {"grade": &"good", "line": "Bewt beams and raises his glass. The guild is the House's friend - for tonight.", "effects": {"standings": {&"choam": 1}, "composure": 1}},
					&"afraid": {"grade": &"mixed", "line": "He thanks you, but the fear stays in his face. A charter will not stop the Harkonnen.", "effects": {"composure": 1}},
					&"informant": {"grade": &"good", "line": "He smiles. There is nothing here the Baron did not already know.", "effects": {}}}},
			{"text": "On Arrakis a man's water is his life. Who profits from another man's thirst?",
				"rescue": {"speaker": "DUKE LETO", "line": "Paul feels deeply about water - this planet teaches that quickly. Don't mistake a young man's passion for the House's policy, Master Bewt."},
				"beyond": {"standings": {&"fremen": 1}, "kynes": 2},
				"reactions": {
					&"greedy": {"grade": &"poor", "line": "The table goes quiet. Bewt's knuckles are white on his cup.", "effects": {"standings": {&"choam": -1}, "composure": -2}},
					&"afraid": {"grade": &"poor", "line": "Bewt looks at his plate. He came for protection, and heard a threat.", "effects": {"composure": -1}},
					&"informant": {"grade": &"poor", "line": "Bewt laughs as if it were a jest. The Baron will hear the boy has teeth.", "effects": {"heat": 1, "composure": -1}}}},
		]},
	{"guest": &"guild", "course": "The fish",
		"line": "They say the Atreides fought well on Caladan, where there was water to fight over. Here, I wonder - will your father keep to his walls, as the last House did?",
		"tells": {
			&"provocateur": "He says it smiling, and watches the Duke's face, not yours, to see whether it lands.",
			&"indifferent": "He says it lightly, already cutting his fish. The answer hardly matters to him.",
		},
		"face": {
			&"provocateur": "Mother's gaze drops to Serrin's fingers on his glass. He is waiting for you to lose your temper.",
			&"indifferent": "Mother looks faintly bored on Serrin's behalf. He cares about nothing here but the bill.",
		},
		"memory": "When the Guild's man on Caladan tried to bait him, Father only asked the price of the voyage - and the room forgot the insult before the man did.",
		"replies": [
			{"text": "The last House feared what was outside its walls. We don't.",
				"rescue": {"speaker": "JESSICA", "line": "My son is proud of his father. He forgets that pride is poor company at dinner."},
				"beyond": {"standings": {&"fremen": 1}, "kynes": 1},
				"reactions": {
					&"provocateur": {"grade": &"mixed", "line": "Serrin inclines his head. Not the insult he came for - but a boast he can repeat.", "effects": {"standings": {&"guild": -1}, "composure": 1}},
					&"indifferent": {"grade": &"poor", "line": "Serrin sighs. Great Houses and their pride; he had hoped to talk business.", "effects": {"standings": {&"guild": -1}}},
					&"informant": {"grade": &"poor", "line": "He files the boast away, for someone else to read.", "effects": {"heat": 1}}}},
			{"text": "And the Guild - does it ever leave its ships?",
				"rescue": {"speaker": "DUKE LETO", "line": "Forgive him, Banker Serrin. He has been too long among soldiers, and not long enough among the Guild's friends - which this House means to be."},
				"beyond": {"standings": {&"smugglers": 1}},
				"reactions": {
					&"provocateur": {"grade": &"poor", "line": "There it is: the insult he came for. The Guild will remember it.", "effects": {"standings": {&"guild": -2}, "composure": -1}},
					&"indifferent": {"grade": &"mixed", "line": "Serrin laughs, though his eyes cool a degree. The Guild does not like to be teased.", "effects": {"standings": {&"guild": -1}, "composure": 1}},
					&"informant": {"grade": &"good", "line": "Caught off guard, he answers too fast and too hot - for a Guild banker. You see it. So does your mother.", "effects": {"resources": {&"intel": 1}, "reveal": true}}}},
			{"text": "My mother says this fish crossed half the Imperium to reach us. What did the Guild charge it?",
				"rescue": {"speaker": "JESSICA", "line": "Paul is curious about everything, I'm afraid. The Guild's prices are a mystery even to me."},
				"beyond": {"standings": {&"choam": 1}},
				"reactions": {
					&"provocateur": {"grade": &"good", "line": "Deflected, and gracefully. He came for an insult and got a question about freight - and has to answer it.", "effects": {"resources": {&"intel": 1}, "composure": 1}},
					&"indifferent": {"grade": &"good", "line": "Serrin brightens and names a sum. A young man who asks the price is good for business.", "effects": {"standings": {&"guild": 1}, "composure": 1}},
					&"informant": {"grade": &"mixed", "line": "He answers the courtesy with courtesy, and learns nothing - and neither do you.", "effects": {"composure": 1}}}},
		]},
	{"guest": &"choam", "course": "The meat",
		"line": "CHOAM's quota for Arrakis has not changed with the House that holds it. May I tell the Board the harvest will not fall?",
		"tells": {
			&"profit": "A small ledger lies open beside his plate, and he has not looked up from it.",
			&"hedging": "He asks the Duke, but his eyes go to Tuek and to the door, as though weighing who will still be here next year.",
		},
		"face": {
			&"profit": "Mother's eyes go to the ledger by his plate. He wants a number, nothing else.",
			&"hedging": "Mother follows his glance to the door. He is wondering whether we will last.",
		},
		"memory": "Father never promised a number at a dinner. Promise that you will be there, he told me, and let the ledger follow.",
		"replies": [
			{"text": "Tell the Board the harvest will be met - every gram.",
				"rescue": {"speaker": "DUKE LETO", "line": "My son is eager to please. The Board will have what the desert allows, and my word that we will try."},
				"beyond": {"standings": {&"fremen": -1}, "kynes": -1},
				"reactions": {
					&"profit": {"grade": &"good", "line": "Ryme is satisfied, and says so twice.", "effects": {"standings": {&"choam": 1}, "composure": 1}},
					&"hedging": {"grade": &"mixed", "line": "He writes it down. A promise is something - if this House lives to keep it.", "effects": {"composure": 1}},
					&"informant": {"grade": &"poor", "line": "He will report the House's confidence - and what it will cost to keep it.", "effects": {"heat": 1}}}},
			{"text": "The harvest will fall where men would die to keep it. We won't pay the quota in lives.",
				"rescue": {"speaker": "DUKE LETO", "line": "Paul has walked the harvesters with me; he speaks for the men he saw. The quota will be met, Factor Ryme - with them alive to meet it."},
				"beyond": {"standings": {&"fremen": 1}, "kynes": 2},
				"reactions": {
					&"profit": {"grade": &"poor", "line": "Ryme closes his ledger. The Board will hear the new Duke puts sentiment before the quota.", "effects": {"standings": {&"choam": -2}, "composure": -1}},
					&"hedging": {"grade": &"poor", "line": "Ryme sets down his pen. Principles are how Houses fall; CHOAM will keep a door open to the Harkonnen.", "effects": {"standings": {&"choam": -1}, "composure": -1}},
					&"informant": {"grade": &"mixed", "line": "A soft House, he will tell the Baron - and one its men would die for.", "effects": {"heat": 1, "composure": 1}}}},
			{"text": "The Board will have its spice - and a House still here in ten years to deliver it.",
				"rescue": {"speaker": "JESSICA", "line": "My son takes the long view. The Factor, I think, would like the short one too."},
				"beyond": {},
				"reactions": {
					&"profit": {"grade": &"mixed", "line": "Ryme nods. Ten years is not this quarter, and he dislikes boasts at dinner.", "effects": {"standings": {&"choam": 1}, "composure": -1}},
					&"hedging": {"grade": &"good", "line": "That is the answer he came for. He will tell the Board this House means to last.", "effects": {"standings": {&"choam": 1}, "resources": {&"intel": 1}, "composure": 1}},
					&"informant": {"grade": &"good", "line": "He smiles politely. Nothing in it the Baron can use.", "effects": {}}}},
		]},
	{"guest": &"smuggler", "course": "The sweets",
		"line": "A trader hears things, young master. For instance, that the new Duke will need eyes in the deep desert, where the Harkonnen patrols do not go. Eyes cost money.",
		"tells": {
			&"opportunist": "He names no price, but he has already moved his chair a little closer to the Duke.",
			&"wary": "He says it easily, but his hands stay flat on the table, where everyone can see them.",
		},
		"face": {
			&"opportunist": "Mother notes the chair moved closer. He is here to sell.",
			&"wary": "Mother notices his open hands. He is here to judge whether our word holds.",
		},
		"memory": "Father used men like this on Caladan - through Gurney, never at his own table, and always for more than money.",
		"replies": [
			{"text": "Name your price. We pay well for good eyes.",
				"rescue": {"speaker": "DUKE LETO", "line": "My son is new to trade. Master Tuek, Gurney Halleck will speak with you - about more than price."},
				"beyond": {"standings": {&"guild": -1}},
				"reactions": {
					&"opportunist": {"grade": &"good", "line": "Tuek smiles like a man who has sold a good horse. Gurney will hear from him.", "effects": {"standings": {&"smugglers": 1}, "flags": [&"smugglers_channel"]}},
					&"wary": {"grade": &"poor", "line": "Tuek's smile cools. A House that pays anyone who asks is a House that can be sold.", "effects": {"standings": {&"smugglers": -1}, "composure": -1}}}},
			{"text": "Eyes are worth more than money. What do you want that money can't buy?",
				"rescue": {"speaker": "JESSICA", "line": "Paul likes to ask what a man really wants. It is a habit I gave him - forgive it."},
				"beyond": {},
				"reactions": {
					&"opportunist": {"grade": &"mixed", "line": "Tuek laughs. He wanted money, and says so - but he likes the question.", "effects": {"standings": {&"smugglers": -1}, "composure": 1}},
					&"wary": {"grade": &"good", "line": "Tuek looks at you properly for the first time. \"Your word,\" he says, \"kept.\" Gurney will hear from him.", "effects": {"standings": {&"smugglers": 1}, "flags": [&"smugglers_channel"], "composure": 1}}}},
			{"text": "My father doesn't deal with smugglers at his own table.",
				"rescue": {"speaker": "DUKE LETO", "line": "My son is more particular about my table than I am. Master Tuek is my guest, Paul - as is everyone here."},
				"beyond": {"standings": {&"guild": 1, &"choam": 1}},
				"reactions": {
					&"opportunist": {"grade": &"poor", "line": "Tuek shrugs. There are other buyers, and he will find them.", "effects": {"standings": {&"smugglers": -1}}},
					&"wary": {"grade": &"mixed", "line": "Tuek nods slowly. Honest, at least. He may come round - by another door.", "effects": {"standings": {&"smugglers": -1}, "composure": 1}}}},
		]},
	{"guest": &"kynes", "course": "The coffee",
		"line": "You have seen something of the desert now, young man. What do you make of it?",
		"tells": {
			&"judging": "He asks it without looking up, turning his water glass slowly, as if the answer were already written in it.",
			&"testing": "He leans in and waits, as though there were a right answer and he wanted to see whether you know it.",
		},
		"face": {
			&"judging": "Mother's glance says: he is weighing what we value, not what we know.",
			&"testing": "Mother's glance says: he wants to know whether you have understood the desert.",
		},
		"memory": "Father, the day we landed: listen to what a land asks of you, before you ask anything of it.",
		"replies": [
			{"text": "It's a fortune. There's more spice out there than a House could ever spend.",
				"rescue": {"speaker": "JESSICA", "line": "Paul has seen the ledgers today; he hasn't yet seen the desert. He will."},
				"beyond": {"standings": {&"choam": 1, &"guild": 1}},
				"reactions": {
					&"judging": {"grade": &"poor", "line": "Kynes looks at you for a long moment, and turns back to his cup.", "effects": {"kynes": -2, "standings": {&"fremen": -1}}},
					&"testing": {"grade": &"poor", "line": "Kynes's mouth tightens. \"Spice,\" he says. \"They all say spice.\"", "effects": {"kynes": -2}}}},
			{"text": "It's a planet dying of thirst. I wonder what it would take to change that.",
				"rescue": {"speaker": "JESSICA", "line": "Paul is his father's son - he wants to mend what he finds."},
				"beyond": {"standings": {&"choam": -1}},
				"reactions": {
					&"judging": {"grade": &"good", "line": "Something opens in Kynes's face. \"Do you,\" he says softly. \"So do I.\"", "effects": {"kynes": 3, "standings": {&"fremen": 1}, "composure": 1}},
					&"testing": {"grade": &"mixed", "line": "He nods, but he wanted to hear what you know, not what you hope.", "effects": {"kynes": 1}}}},
			{"text": "Water rules it. Whoever holds the water holds everything else - and I think the Fremen know it.",
				"rescue": {"speaker": "DUKE LETO", "line": "My son has a cold head for a warm table, Doctor Kynes. He means that we will learn the desert's rules, not break them."},
				"beyond": {},
				"reactions": {
					&"judging": {"grade": &"mixed", "line": "Kynes considers it. Clever, his face says - and cold.", "effects": {"kynes": 1, "composure": -1}},
					&"testing": {"grade": &"good", "line": "Kynes's eyes sharpen. \"Who told you that?\" No one did. He is impressed, and hides it badly.", "effects": {"kynes": 3, "standings": {&"fremen": 1}}}}},
		]},
]

## How Paul's parents take a reply that lands well, or only half well: a look,
## a word. (A reply that lands badly has its own `rescue`, fitted to it.)
const APPROVAL: Array[Dictionary] = [
	{"speaker": "DUKE LETO", "line": "Your father's hand rests a moment on the table beside yours. Well said."},
	{"speaker": "JESSICA", "line": "Your mother's eyes meet yours for a heartbeat, warm. You read him right."},
	{"speaker": "DUKE LETO", "line": "The Duke lifts his glass, very slightly, toward you. No one else sees it."},
	{"speaker": "JESSICA", "line": "Your mother smiles at her plate. She would not have said it better."},
	{"speaker": "DUKE LETO", "line": "Your father says nothing, and does not need to."},
]
const NUDGE: Array[Dictionary] = [
	{"speaker": "JESSICA", "line": "Your mother's fingers touch her napkin: close, but not quite."},
	{"speaker": "DUKE LETO", "line": "Your father adds a quiet word to yours, and the answer sits better for it."},
	{"speaker": "JESSICA", "line": "A small look from your mother: listen to what he wants, not to what he says."},
	{"speaker": "DUKE LETO", "line": "The Duke lets the silence stretch a moment, then turns the talk. It could have gone better."},
	{"speaker": "JESSICA", "line": "Your mother's glance says: half right. Watch him next time."},
]

## Kynes's trust at the end: at least this much, he trusts the Atreides.
const KYNES_TRUSTS: int = 5
const KYNES_DOUBTS: int = 1
const START_COMPOSURE: int = 5
const MAX_COMPOSURE: int = 6
## Glances at Jessica, and lessons of the Duke recalled, per evening.
const FACES: int = 2
const MEMORIES: int = 2
## Paul's own prescience: none of his own yet; growth adds them.
const GLIMPSES: int = 0
## The most one evening can move a faction's standing.
const MAX_SWING: int = 2


static func guest(id: StringName) -> Dictionary:
	for entry in GUESTS:
		if entry.id == id:
			return entry
	return {}
