class_name IsoKit
extends RefCounted
## Painted art for an isometric interior, by kit: `assets/environment/iso_<kit>/`.
## A kit is optional - without one (or without a file) every piece keeps its
## own drawn look, so an interior can take its art a piece at a time.

const ROOT: String = "res://assets/environment/iso_"
## Where the grid cell's centre sits in each kind of image, from its top-left.
const BLOCK_ANCHOR: Vector2 = Vector2(64, 96)
const FLOOR_ANCHOR: Vector2 = Vector2(64, 32)
const DRUM_ANCHOR: Vector2 = Vector2(32, 80)


static func texture(kit: StringName, name: String) -> Texture2D:
	if kit == &"":
		return null
	var path: String = ROOT + String(kit) + "/" + name + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
