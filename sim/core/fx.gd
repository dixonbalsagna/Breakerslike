class_name SimFx
## Cosmetic lane (S.fx): the twin of fx.js (banner, P, spark, ring, debris, dust, splash, fire, afterimage, stepParts).
## Every draw here uses S.rngFx. Each particle is built in the JS object literal's order, so the draws happen in the
## same order (and happen even when P then drops the particle at the cap).


static func banner(S: SimState, text: String, col: String, dur: float) -> void:
	var b := SimState.Banner.new()
	b.text = text
	b.col = col if col != "" else "#ffffff"
	b.t = 0.0
	b.dur = dur if dur != 0.0 else 1.3
	S.fx.banner = b


## Particle spawn: the caller has already made its draws.
static func P(S: SimState, p: SimState.Part) -> void:
	if S.fx.parts.size() > 2400:
		return
	S.fx.parts.append(p)


static func spark(S: SimState, x: float, y: float, n: int, col: String, spd: float) -> void:
	var r: SimRng = S.rngFx
	for i in range(n):
		var a: float = r.range_(0.0, 6.283)
		var s: float = r.range_(0.3, 1.0) * (spd if spd != 0.0 else 500.0)
		var p := SimState.Part.new()
		p.type = "spark"; p.x = x; p.y = y
		p.vx = SimDetMath.cos(a) * s
		p.vy = SimDetMath.sin(a) * s
		p.life = r.range_(0.15, 0.4)
		p.col = col if col != "" else "#fff3c0"
		p.size = r.range_(1.5, 3.0)
		P(S, p)


static func ring(S: SimState, x: float, y: float, gr: float, col: String, life: float, r0: float) -> void:
	var p := SimState.Part.new()
	p.type = "ring"; p.x = x; p.y = y
	p.r = r0 if r0 != 0.0 else 10.0
	p.gr = gr
	p.life = life if life != 0.0 else 0.5
	p.col = col if col != "" else "#ffffff"
	P(S, p)


static func debris(S: SimState, x: float, y: float, n: int, col: String, spd: float) -> void:
	var r: SimRng = S.rngFx
	for i in range(n):
		var a: float = r.range_(0.2, 2.9)
		var s: float = r.range_(0.2, 1.0) * (spd if spd != 0.0 else 500.0)
		var p := SimState.Part.new()
		p.type = "deb"
		p.x = x + r.range_(-20.0, 20.0)
		p.y = y
		p.vx = SimDetMath.cos(a) * s * (-1.0 if r.next() < 0.5 else 1.0)
		p.vy = SimDetMath.sin(a) * s
		p.grav = 900.0
		p.life = r.range_(0.8, 1.8)
		p.col = col if col != "" else "#6d6a66"
		p.size = r.range_(3.0, 9.0)
		P(S, p)


static func dust(S: SimState, x: float, y: float, n: int, col: String = "") -> void:
	var r: SimRng = S.rngFx
	for i in range(n):
		var p := SimState.Part.new()
		p.type = "dust"
		p.x = x + r.range_(-40.0, 40.0)
		p.y = y + r.range_(0.0, 20.0)
		p.vx = r.range_(-90.0, 90.0)
		p.vy = r.range_(20.0, 140.0)
		p.life = r.range_(0.8, 1.8)
		p.col = col if col != "" else "#9b8f7e"
		p.size = r.range_(14.0, 34.0)
		p.drag = 0.02
		P(S, p)


static func splash(S: SimState, x: float, y: float, n: int) -> void:
	var r: SimRng = S.rngFx
	for i in range(n):
		var p := SimState.Part.new()
		p.type = "splash"
		p.x = x + r.range_(-30.0, 30.0)
		p.y = y
		p.vx = r.range_(-160.0, 160.0)
		p.vy = r.range_(250.0, 900.0)
		p.grav = 1200.0
		p.life = r.range_(0.7, 1.5)
		p.col = "#bfe6ff"
		p.size = r.range_(2.0, 5.0)
		P(S, p)


static func fire(S: SimState, x: float, y: float, n: int) -> void:
	var r: SimRng = S.rngFx
	for i in range(n):
		var p := SimState.Part.new()
		p.type = "flame"
		p.x = x + r.range_(-25.0, 25.0)
		p.y = y + r.range_(0.0, 30.0)
		p.vx = r.range_(-30.0, 30.0)
		p.vy = r.range_(60.0, 200.0)
		p.life = r.range_(0.5, 1.3)
		p.col = "#ff9a2e" if r.next() < 0.5 else "#ffd45a"
		p.size = r.range_(6.0, 16.0)
		P(S, p)


static func afterimage(S: SimState, f) -> void:
	var p := SimState.Part.new()
	p.type = "after"; p.x = f.x; p.y = f.y; p.life = 0.45; p.col = f.aura; p.face = f.face
	P(S, p)


## Particles (swap-remove when expired), then the damage numbers.
static func stepParts(S: SimState, dt: float) -> void:
	var parts: Array = S.fx.parts
	var floats: Array = S.fx.floats
	for i in range(parts.size() - 1, -1, -1):
		var p = parts[i]
		p.age += dt
		if p.age >= p.life:
			parts[i] = parts[parts.size() - 1]
			parts.pop_back()
			continue
		p.vy -= p.grav * dt
		if p.drag != 0.0:
			var d: float = SimDetMath.pow(1.0 - p.drag, dt * 60.0)
			p.vx *= d
			p.vy *= d
		p.x = SimWrap.wrap(p.x + p.vx * dt)
		p.y += p.vy * dt
		if p.type == "ring":
			p.r += p.gr * dt
		if p.type == "deb":
			var g: float = WorldTerrain.groundY(S, p.x)
			if p.y < g:
				p.y = g
				p.vy *= -0.3
				p.vx *= 0.6
	for i in range(floats.size() - 1, -1, -1):
		var f = floats[i]
		f.t += dt
		f.y += 60.0 * dt
		if f.t > 0.9:
			floats.remove_at(i)
