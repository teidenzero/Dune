# Dune — Tactical Prototype

A top-down tactical prototype set on Arrakis: a small Fremen team raiding a
Harkonnen spice operation. Everything is placeholder art — flat shapes, no
audio — but the systems underneath are real and playable.

This is a prototype for testing, not a game. Expect rough edges.

## Running it

1. Install **Godot 4.7.x** (4.7.2 is what this is built and tested against).
   No C# / .NET build is needed — the standard version is fine.
   Download: https://godotengine.org/download
2. Clone this repository.
3. Open Godot, click **Import**, and select the `project.godot` file in the
   cloned folder. The first import takes a few seconds.
4. Press **F5** to run.

There are no plugins, addons or extra downloads. If Godot warns that the
project was made with a different version, you are on the wrong 4.x release —
get 4.7.x.

## What to play

Running the project opens a small launcher. Press the number or click:

| | |
|---|---|
| **1** | **Arrakeen Training** — nine-section tutorial. Start here; it teaches every mechanic in order. ~15 minutes. |
| **2** | **Harvester Raid** — the actual mission. Cripple a spice harvester and get out before the worm arrives. ~10–20 minutes. |
| **3** | **Test Arena** — a sandbox with isolated ranges for each system. Not a level; useful for poking at one thing at a time. |
| **4** | **The Council** — the campaign: faction standings, Harkonnen heat, resources. Brief the Harvester Raid and choose to fight it as a squad or resolve it politically (approach, agent, Intel, a dilemma). Outcomes persist for the session. |

## Controls

It plays like a real-time strategy game: you never steer anyone directly.
Select people, then right-click to tell them what to do. Every key you need
is printed on the action bar at the bottom of the screen.

| Input | Action |
|---|---|
| **Left-click** / drag | Select a unit / box-select several |
| **Right-click** ground | Move there |
| **Right-click** enemy | Attack it. Paul closes to range and fires one round per click (reload with `R`); the Fremen close in and keep firing on their own |
| **Right-click** machine or beacon | Paul walks over and uses it |
| **Double right-click** | Run there (fast, and loud) |
| `Shift` + right-click | Queue a waypoint |
| `1` `2` `3` `4` | Select Paul / Scout / Warrior / everyone. Press twice to jump the camera there |
| `Space` | Pause. You can still select and give orders while paused |
| `C` | Sneak / stand the selected units |
| **Left-click** an enemy (Paul selected) | Crysknife: a quick click is a quick strike, **hold** until the ring fills for a slow strike that gets through personal shields |
| `E` | Arm the crysknife for the next left-click (same click / hold rule) |
| `Q` | Prescience: a brief slow-motion look at what enemies are about to do |
| `Z` / `X` | Paul's weapon slots |
| `R` | Reload |
| `H` / `G` | Hold / Follow (Fremen) |
| `WASD`, arrows, screen edge | Move the camera |
| Mouse wheel | Zoom |
| `F11` | Fullscreen |
| `Enter` | Restart after Paul goes down |
| `F1` | Debug overlay |

### Solo controls

**The campaign** starts from the main menu: NEW CAMPAIGN plays a short intro, then the prologue, which is Paul's training in three parts. First the training hall with Gurney (fighting in the Solo scope), then the yard, where Duke Leto teaches command with the whole squad from the first step (C crouches or stands everyone together; the Fremen hold their fire while Gurney and Duncan drill Paul with weapons; Jessica teaches prescience, Kynes the desert). Last comes the council chamber, where the Duke talks Paul through his first political decision, the water-sellers' petition, which counts in the campaign. Then Act I begins with **1.1 The Hunter-Seeker**. On the first night a hunter-seeker homes on movement: stand still and click it when it is within reach. Then find the operator hiding in the house before he slips out through the cellars. Mapes, the Fremen housekeeper in the kitchen, can tell you where he is, and his hiding place changes each time. The developer launcher is under MISSIONS on the main menu (Esc returns).

**The strategic map** (launcher key `7`) is Act II's raid campaign on a Fremen map of Arrakis. Each week you choose operations: raid a harvester, steal water, free a village, ambush a patrol, rally a sietch, tend the plantings, hold a sietch against a sweep. Pick a hero to lead each one, then send it as an order or, where it can be played, play it as a Squad or Solo mission or through the Council. END WEEK resolves the orders. The Coriolis storm moves across the south, worms take harvesters, and Rabban rebuilds and sends troops when the heat is high. Keep his spice below the quota and the Emperor's attention rises; when it fills, Act III begins. The story's first raid (2.5) is the Harvester Raid, and winning it opens raids across the map.

**Solo Training** (launcher key `6`) teaches all of it, room by room, with Gurney: moving, running and dodging; walls and consoles; sneaking past a sentry; going into a fight with prescience and a silent kill; taking a vision back; firing, hit chance and evasion; being spotted; shields and the slow blade; fuel tanks. Each room's door opens when its lesson is done, and going down restarts that room.

The Solo scope is one hero on direct control inside an isometric interior. The first one is **inside the harvester** (launcher key `5`, or SOLO in the Council briefing): cut the comms relay, sabotage the two engine controls, then get out through the maintenance hatch before the worm takes the crawler. With the relay live, any alarm brings more crew aboard. Doors slide open for anyone who walks up to them, and walls in front of the hero fade.

In the interiors the hero moves by clicks, like the squad:

| Input | Action |
|---|---|
| **Click** a tile (left or right) | Walk to it; the tile under the mouse is outlined. Click twice to run |
| **Right-click** an enemy | Fire at him |
| **Left-click** an enemy | Crysknife: click for a quick strike, hold for the slow one |
| **Right-click** the relay or an engine control | Walk there and use it |
| `Space` | Dodge |
| `T` | Raise / lower the Holtzman shield |
| `C` / `R` / `Z` `X` / `Q` | Crouch / reload / weapons / prescience |
| `1` | Centre the camera on the hero |
| `P` | Pause |

**Fights are turn-based**, Fallout style. Whoever attacks first acts first. A guard who spots you opens the fight and the Harkonnen move first. Press `Q` to go in with prescience, or simply attack (right-click to shoot, left-click for the knife, hold for the slow blade), and the fight opens on your turn with that attack. Attacking directly spends no vision, so it cannot be taken back; a guard you cannot reach or see this turn gets an ordinary real-time order instead. The screen switches to combat mode: the camera closes in, and the interface shows the turn order, your action points, health and prescience, and a command menu.

| Input | Action (cost) |
|---|---|
| Click a tile | Move (1 point a tile, 2 when sneaking); the path and its cost are shown |
| Click an enemy | Use the selected attack; hovering shows the hit chance and cost |
| `1` / `2` / `3` | Select FIRE (4) / QUICK KNIFE (3) / SLOW KNIFE (5). A knife walks up first |
| `V` | Eat a dose of spice: one more vision this fight |
| `4` | DISTRACT (2): throw a stone at a tile. Every guard within earshot who has not seen you turns to look there |
| `R` / `T` / `C` | Reload (2) / shield (1) / sneak |
| `Q` | Start a **vision**; during one, take it back |
| `Space` | End the turn: points left over become evasion |

- **Guards who have not seen you** stand frozen, watching. Each step inside a guard's view cone is a chance he notices you, lower when sneaking. A knife in the back of a guard who has not seen you is a silent kill. A gunshot brings in everyone within earshot.
- **Shields:** bullets and a quick blade do not get through, a slow blade does. Guards close in with the bayonet when your shield is up.
- **Prescience:** Paul has 3 visions per fight. A vision plays out your turn and the Harkonnen answer, then you accept that future or take it back. During a vision Paul stays where he stood, and a blue shadow of him acts out the future; accepting it brings the two together, taking it back puts everything exactly as it was. Going in with `Q` makes the opening a vision; take it back and the fight never happened.
- **Mission clocks:** each round is 5 seconds of the mission's time, for the worm and for reinforcements.

The direct controls below (WASD and mouse aim) are kept for the solo test on the raid map:

| Input | Action |
|---|---|
| `WASD` | Move along the isometric grid, 8 directions (`Shift` to run, `C` to crouch) |
| Mouse | Aim, snapped to the nearest of 8 directions |
| **Left-click** | Fire |
| `E` | Crysknife: tap for a quick strike, hold for the slow one |
| `Space` | Dodge: a quick step that bullets miss, with a short cooldown |
| `T` | Raise / lower the Holtzman shield: stops bullets and quick blades. Indoors it costs nothing, so the guards wear them too (on open sand it would call the worm) |
| `F` | Use (hold at the relay and the engine controls) |
| `Q` / `R` / `Z` `X` | Prescience / reload / weapons |
| `P` | Pause |

**Growth.** Heroes get better at what they do: knife work trains the blade, shooting trains firearms, going unseen and silent kills train desert craft, up to a limit per mission. Ranks make attacks surer and some actions cheaper. Prescience grows with spice: stand in the glowing spice patches in the desert, eat a dose with `V` (in a fight: one more vision; otherwise a full prescience bar), and at great moments of the story it rises for good. In the interiors, look into corners: pages of lore (right-click, READ) and caches (TAKE) give small rewards, and everything read is kept in the CODEX on the main menu.

Spice-fuel tanks explode when shot: they hurt everything nearby (you too) and the whole crawler hears it.

The squad cards in the bottom-left corner are clickable too: click to select,
Shift-click to add, double-click to jump the camera to that unit.

## Three things worth knowing

**Shields.** Harkonnen elites wear Holtzman shields and fight with the blade:
they charge you and cut. Bullets and fast blades bounce off the shield. Only
a *slow* blade gets through: hold left-click on him until the ring fills.
Watch his swing (the red arc builds before he cuts) and strike while he
recovers from it, or catch him from behind before he knows you are there.

**Sand and rock.** Movement on open sand makes vibration, and vibration brings
a sandworm. Rock is silent and rock is safe. Safe rock is drawn as grey stone;
sand is the tan ground. Running across sand is loud, walking less so,
sneaking almost nothing. Gunfire is very loud.

**Being seen is not instant.** Every enemy's field of view is drawn on the
ground, and it stops where walls and rocks stop it — if the cone does not reach
you, he cannot see you. Standing in one does not give you away immediately
either: enemies build up detection first, and the meter over their head shows
how far along they are. The cone warms from pale to amber to red as that
happens. Breaking line of sight while a guard is still only suspicious works.
Once he is actually in combat, it does not.

## Feedback that helps

- Where you got stuck, confused, or did not know what the game wanted.
- Anything that felt unfair rather than hard.
- Whether the Harvester Raid ran too long or too short, and where it dragged.
- Anything that looks broken: enemies stuck on walls, objectives not ticking
  off, the mission not ending when it should.

`F1` shows a live debug panel. If something looks wrong, a screenshot with
`F1` on is far more useful than one without.
