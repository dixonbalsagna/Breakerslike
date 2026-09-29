extends MultiMeshInstance3D
## Engine spike (throwaway, research only). Presentation particles, per SPEC:
##   crater event (kind 0)  150 per event, 2.0 s, vx +-300, vy 150..700,  size 6
##   big crater (kind 1)   3000 per event, 3.0 s, vx +-900, vy 200..1400, size 8
##   beam spark               5 per beam per tick at (tx, ty), 0.8 s, vx +-400, vy 100..600, size 4
## Approach: one MultiMesh of 29 800 quads drawn in one call with a stateless ballistic vertex shader
## (render/particles.gdshader). The CPU never touches a particle: a spawn writes one texel (x, y, spawn tick, seed) into
## a ring buffer of burst slots, and the shader derives each particle's velocity from a hash of (burst seed, index).
## Seeds come from a presentation RandomNumberGenerator with a fixed seed, never from the sim RNG.
## Live counts are tracked analytically from spawn ticks (exact, because every section has a fixed life).
## Slot capacity covers the worst scene exactly: 60 craters/s x 2 s = 120 <= 128, 1 big per 2 s x 3 s = 2 <= 3,
## 6 beams x 60/s x 0.8 s = 288 <= 320. Overwriting a live burst is counted in `overwrites` (it must stay 0).

const CR_N: int = 150
const BG_N: int = 3000
const SP_N: int = 5
const N_PER: Array[int] = [CR_N, BG_N, SP_N]
const SLOTS: Array[int] = [128, 3, 320]
const LIFE_TICKS: Array[int] = [120, 180, 48]   # 2.0 s, 3.0 s, 0.8 s at 60 Hz
const TEXEL0: Array[int] = [0, 128, 131]
const TEXELS: int = 451
const INSTANCES: int = 29800                     # 150*128 + 3000*3 + 5*320; must match the shader's constants
const PRESENTATION_SEED: int = 20260929

var mat: ShaderMaterial
var bursts := PackedFloat32Array()   # TEXELS x (x, y, spawn tick, +-seed)
var burst_img: Image
var burst_tex: ImageTexture
var rng := RandomNumberGenerator.new()
var spawned: Array[int] = [0, 0, 0]
var retired: Array[int] = [0, 0, 0]
var spawn_tick: Array[PackedInt64Array] = []
var overwrites: int = 0
var total_spawned_particles: int = 0
var dirty: bool = true


func _ready() -> void:
	mat = material_override
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = QuadMesh.new()   # 1 x 1; the shader scales it to the particle size in view space
	mm.instance_count = INSTANCES
	# The vertex shader places every quad, so give the MultiMesh bounds that always cover the view.
	mm.custom_aabb = AABB(Vector3(-20000.0, -20000.0, -1000.0), Vector3(40000.0, 40000.0, 2000.0))
	multimesh = mm
	bursts.resize(TEXELS * 4)
	burst_img = Image.create_empty(TEXELS, 1, false, Image.FORMAT_RGBAF)
	burst_tex = ImageTexture.create_from_image(burst_img)
	mat.set_shader_parameter("bursts", burst_tex)
	for s in 3:
		var p := PackedInt64Array()
		p.resize(SLOTS[s])
		spawn_tick.append(p)
	clear()


## Kills every burst (scene change: the sim tick restarts at 0).
func clear() -> void:
	for t in TEXELS:
		bursts[t * 4] = 0.0
		bursts[t * 4 + 1] = 0.0
		bursts[t * 4 + 2] = -1.0e9     # spawn tick far in the past: every slot is dead
		bursts[t * 4 + 3] = 0.0
	spawned = [0, 0, 0]
	retired = [0, 0, 0]
	rng.seed = PRESENTATION_SEED
	overwrites = 0
	total_spawned_particles = 0
	dirty = true


func _retire(s: int, now: float) -> void:
	var life: int = LIFE_TICKS[s]
	var slots: int = SLOTS[s]
	var st: PackedInt64Array = spawn_tick[s]
	while retired[s] < spawned[s] and now - float(st[retired[s] % slots]) >= float(life):
		retired[s] += 1


func _spawn(s: int, x: float, y: float, tick: int, sign_: float) -> void:
	_retire(s, float(tick))
	var slots: int = SLOTS[s]
	if spawned[s] - retired[s] >= slots:
		retired[s] += 1          # ring full: the oldest live burst is overwritten (never happens within SPEC load)
		overwrites += 1
	var slot: int = spawned[s] % slots
	var t: int = TEXEL0[s] + slot
	var seed: int = rng.randi_range(1, 16777215)   # exact in float32
	bursts[t * 4] = x
	bursts[t * 4 + 1] = y
	bursts[t * 4 + 2] = float(tick)
	bursts[t * 4 + 3] = sign_ * float(seed)
	spawn_tick[s][slot] = tick
	spawned[s] += 1
	total_spawned_particles += N_PER[s]
	dirty = true


## Called once after every sim step: spawns from scene.events and the beams. Reads the scene only.
func spawn_from(scene) -> void:
	var tick: int = scene.tick
	for e in scene.events:
		if int(e.kind) == 1:
			_spawn(1, e.x, e.y, tick, 1.0)
		else:
			_spawn(0, e.x, e.y, tick, 1.0)
	for bm in scene.beams:
		_spawn(2, bm.tx, bm.ty, tick, 1.0 if int(bm.owner) == 0 else -1.0)


## A crater made by player input (demo C key) outside scene.events.
func spawn_crater(x: float, y: float, tick: int) -> void:
	_spawn(0, x, y, tick, 1.0)


## Uploads the burst texture if anything spawned; sets the per-frame uniforms. Returns ms spent.
func update_gpu(cam_x: float, now_tick: float) -> float:
	var t0: int = Time.get_ticks_usec()
	if dirty:
		burst_img.set_data(TEXELS, 1, false, Image.FORMAT_RGBAF, bursts.to_byte_array())
		burst_tex.update(burst_img)
		dirty = false
	mat.set_shader_parameter("cam_x", cam_x)
	mat.set_shader_parameter("now_tick", now_tick)
	return float(Time.get_ticks_usec() - t0) / 1000.0


## Live particles at time now (in ticks, may be fractional), from spawn ticks: exact, same rule as the shader.
func live_count(now: float) -> int:
	var n: int = 0
	for s in 3:
		_retire(s, now)
		n += (spawned[s] - retired[s]) * N_PER[s]
	return n
