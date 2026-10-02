# Shots: a shot that is let pass carries on as a straight shot (Game Design's ruling 6a, agency-pass.md section 11).
# Usage: python shots_release.py <repo root>. Neutral: nothing fires a shot in a match yet. One new hashed field
# (Shot.passed), so the goldens' full-state checkpoints would move only once shots exist; regenerate with the data change.
#   - SimShots.release(S, shot): a seeking shot loses its target and flies on in a straight line at its last velocity.
#   - A seeking shot that arrives and is not stopped (the director's hitFighter returned false, or its target cannot be
#     hit) is released, where before it stayed on its target and met him again every tick.
#   - Shot.passed: the slots a shot has already passed, so a dodged shot is not offered to the same fighter each tick.
import os, sys
os.chdir(sys.argv[1])
def edit(p, pairs):
    s=open(p,encoding='utf-8').read()
    for a,b in pairs:
        assert s.count(a)==1,(p,a[:80],s.count(a))
        s=s.replace(a,b)
    open(p,'w',encoding='utf-8',newline='\n').write(s)

edit('sim/core/state.gd', [
('''	var deflected: int = 0    # times it was sent back
''','''	var deflected: int = 0    # times it was sent back
	var passed: int = 0       # a bit per slot it has passed without stopping (a dodge): it is not offered to him again
'''),
])
edit('sim/core/hash.gd', [
('''"power", "dmg", "group", "deflected", "fresh", "dead"]''','''"power", "dmg", "group", "deflected", "fresh", "dead", "passed"]'''),
])
edit('sim/core/shots.gd', [
('''	sh.left = _seekTicks(sh, S.fighters[old], kinds[sh.kind].speed)
	sh.total = sh.left
	sh.deflected += 1
''','''	sh.left = _seekTicks(sh, S.fighters[old], kinds[sh.kind].speed)
	sh.total = sh.left
	sh.deflected += 1
	sh.passed = 0


## A seeking shot loses its target (a dodge, or the director's call): it flies on as a straight shot at its last
## velocity, for the kind's life, and from then on the ground and the water stop it like any straight shot.
static func release(_S: SimState, sh) -> void:
	var kd: Dictionary = kinds[sh.kind]
	if SimDetMath.hypot(sh.vx, sh.vy) <= 0.0:   # released before it moved: straight ahead of its owner
		sh.vx = _S.fighters[sh.owner].face * kd.speed * TPS
		sh.vy = 0.0
	sh.mode = LINE
	sh.tgt = -1
	sh.left = int(kd.lifeTicks)
	sh.total = sh.left
'''),
('''				if k == sh.owner:
					continue
				var f = S.fighters[k]''','''				if k == sh.owner or (sh.passed & (1 << k)) != 0:
					continue
				var f = S.fighters[k]'''),
('''				if met:
					hitOne = true
					if hitFighter(S, sh, f):
						end(S, sh, "hit")
					break''','''				if met:
					hitOne = true
					if hitFighter(S, sh, f):
						end(S, sh, "hit")
					else:
						sh.passed |= 1 << k   # he let it pass: it flies on, and is not offered to him again
						if sh.mode == SEEK:
							release(S, sh)
					break'''),
('''		elif sh.mode == SEEK:
			if arrived[i]:
				end(S, sh, "life")   # it reached where its target was and he was not hit (the director let it pass)''','''		elif sh.mode == SEEK:
			if arrived[i]:
				release(S, sh)   # it reached where its target was and could not hit him: it flies on, straight'''),
])
p='sim/core/tools/parity.gd'
s=open(p,encoding='utf-8').read()
a='''	# the cap
	b.x = SimWrap.wrap(a.x + 60000.0)'''
assert s.count(a)==1
s=s.replace(a,'''	# a seeking shot that cannot hit its target flies on as a straight shot, and then the ground stops it
	S.out.fx.clear()
	a.x = 40000.0
	a.y = WorldTerrain.groundY(S, a.x) + 400.0
	b.x = a.x + 600.0
	b.y = WorldTerrain.groundY(S, b.x)
	b.state = "intro"   # he cannot be hit
	sh = SimShots.fire(S, 0, "bolt", {"target": 1})
	var n0: int = sh.left
	run.call(n0 + 1)
	if S.shots.is_empty() or sh.mode != SimShots.LINE or sh.tgt != -1 or sh.vy >= 0.0:
		return "a seeking bolt that could not hit did not fly on as a straight shot"
	run.call(int(bolt.lifeTicks))
	if not S.shots.is_empty() or count.call("shot_end", "cause", "ground") != 1 or count.call("shot_hit") != 0:
		return "a released bolt did not end on the ground"
	b.state = "free"
	sh = SimShots.fire(S, 0, "bolt", {"target": 1})
	SimShots.release(S, sh)
	if sh.mode != SimShots.LINE or sh.vx == 0.0:
		return "release before the first move left the shot still"
	SimShots.end(S, sh, "test")
	run.call(1)
	a.y = 3000.0
	b.y = 3000.0
	# the cap
	b.x = SimWrap.wrap(a.x + 60000.0)''')
open(p,'w',encoding='utf-8',newline='\n').write(s)
print("shots release applied")
