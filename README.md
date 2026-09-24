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

## Controls

It plays like a real-time strategy game: you never steer anyone directly.
Select people, then right-click to tell them what to do. Every key you need
is printed on the action bar at the bottom of the screen.

| Input | Action |
|---|---|
| **Left-click** / drag | Select a unit / box-select several |
| **Right-click** ground | Move there |
| **Right-click** enemy | Attack it (the unit closes to range and keeps firing) |
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

The squad cards in the bottom-left corner are clickable too: click to select,
Shift-click to add, double-click to jump the camera to that unit.

## Three things worth knowing

**Shields.** Harkonnen elites wear Holtzman shields. Bullets and fast blades
bounce off them. Only a *slow* blade gets through: hold left-click on the target until the ring fills.
Shooting one forever will never work; that is deliberate.

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
