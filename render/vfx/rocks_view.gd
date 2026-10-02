class_name VfxRocksView
extends MultiMeshInstance3D
## Draws the levitating rocks (rocks.gd, a prototype behind `hub.rocks_enabled`) for one pane: one MultiMesh, one draw call, the shard
## shader's earth chunk (shape 3, mode 2). Every piece is placed from the fighter's interpolated pose and the clock, so it follows him
## smoothly between ticks. Reads only.

const CAP := 2 * VfxRocks.MAX_PIECES + 4
const STRIDE := 20

var _buf := PackedFloat32Array()
var count: int = 0


func _ready() -> void:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = CAP
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-40000.0, -12000.0, -1200.0), Vector3(80000.0, 60000.0, 2400.0))
	multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = preload("res://render/vfx/shaders/shard.gdshader")
	m.render_priority = 2
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_buf.resize(CAP * STRIDE)


func update(hub: VfxHub, host: SimHost, a: float, cam_x: float, half_w: float) -> void:
	var n: int = 0
	var bh: float = VfxLook.BH
	var rk: VfxRocks = hub.rocks
	var q: float = VfxLook.QUALITY_SHARDS[clampi(hub.quality, 0, 2)] * (0.5 if hub.reduced_motion else 1.0)
	var t: float = (float(rk.clock) + a) / 60.0
	rk.shown = 0
	for i in range(mini(2, host.S.fighters.size())):
		var lvl: float = lerpf(rk.prev[i], rk.level[i], a)
		if lvl < 0.01:
			continue
		var f = host.S.fighters[i]
		var tier: int = clampi(int(floor(float(f.tier) + 0.001)), 1, 4)
		var cnt: int = VfxRocks.count_for(tier, q)
		if cnt <= 0:
			continue
		var fx: float = host.fighter_x(i, a)
		var rel: float = SimWrap.sdx(cam_x, fx)
		if absf(rel) > half_w + 5.0 * bh:
			continue
		var pose: Vector3 = host.fighter_pose(i, a)
		var fz: float = host.fighter_z(i, a)
		var biome: String = VfxPalette.biome_key(fx)
		var tones: Array = [VfxPalette.dust(biome, "mid"), VfxPalette.dust(biome, "light"), VfxPalette.dust(biome, "shadow")]
		var size_k: float = VfxRocks.p("rocks", "t4_size") if tier >= 4 else 1.0
		var bob_amp: float = 0.0 if hub.reduced_motion else VfxRocks.p("rocks", "bob_bh") * bh
		for k in range(cnt):
			if n >= CAP:
				break
			var pc: VfxRocks.Piece = rk.pieces[i][k]
			# They rise one after another out of the ground as the level comes up.
			var lo: float = float(k) / float(cnt) * 0.5
			var act: float = smoothstep(lo, lo + 0.5, lvl)
			if act < 0.01:
				continue
			var off: Vector3 = VfxRocks.at(pc, t, bh, bob_amp)
			var px: float = rel + off.x * act
			var py: float = pose.y + off.y * act
			var pz: float = fz + off.z * act
			var col: Color = tones[pc.tone]
			col.a = VfxRocks.p("rocks", "alpha") * smoothstep(0.0, 0.5, act)
			var sx: float = pc.size * size_k * (0.6 + 0.4 * act)
			_put(n, Vector2(px, py), pc.rot0 + pc.spin * t, sx, sx * 0.8, pz, col, pc.seed)
			n += 1
	count = n
	rk.shown = n
	multimesh.visible_instance_count = n
	if n > 0:
		multimesh.buffer = _buf


func _put(i: int, c: Vector2, rot: float, sx: float, sy: float, z: float, col: Color, sd: float) -> void:
	var o: int = i * STRIDE
	var cs: float = cos(rot)
	var sn: float = sin(rot)
	_buf[o] = cs * sx
	_buf[o + 1] = -sn * sy
	_buf[o + 2] = 0.0
	_buf[o + 3] = c.x
	_buf[o + 4] = sn * sx
	_buf[o + 5] = cs * sy
	_buf[o + 6] = 0.0
	_buf[o + 7] = c.y
	_buf[o + 8] = 0.0
	_buf[o + 9] = 0.0
	_buf[o + 10] = 1.0
	_buf[o + 11] = z
	_buf[o + 12] = col.r
	_buf[o + 13] = col.g
	_buf[o + 14] = col.b
	_buf[o + 15] = col.a
	_buf[o + 16] = 3.0       # shape: chunk
	_buf[o + 17] = sd
	_buf[o + 18] = 2.0       # mode: earth (a lit and a shaded side of its own colour)
	_buf[o + 19] = 0.0
