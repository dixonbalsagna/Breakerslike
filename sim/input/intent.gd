class_name SimIntent
extends RefCounted
## Player intent, the per-tick input record a fighter acts on: the twin of intent.js (the prototype's f.in).
## stance is a float like every JS number: -1, or a pressed stance 0 to 3.

var mx: float = 0.0
var my: float = 0.0
var dash: bool = false
var charge: bool = false
var light: bool = false
var heavy: bool = false
var sig: bool = false
var stance: float = -1.0


## Neutral input, exactly as control() cleared it every tick.
static func clearIntent(i: SimIntent) -> void:
	i.mx = 0.0
	i.my = 0.0
	i.dash = false
	i.charge = false
	i.light = false
	i.heavy = false
	i.sig = false
	i.stance = -1.0


## Overwrite all eight fields of dst from src, as humanInput overwrote f.in for a human fighter.
static func applyIntent(dst: SimIntent, src: SimIntent) -> void:
	dst.mx = src.mx
	dst.my = src.my
	dst.dash = src.dash
	dst.charge = src.charge
	dst.light = src.light
	dst.heavy = src.heavy
	dst.sig = src.sig
	dst.stance = src.stance
