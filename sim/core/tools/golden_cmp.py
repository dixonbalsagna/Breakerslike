# Compare two golden.json files: per match and replay, the tick count and the light digest (the gameplay that the
# per-tick light digests cover) must be equal; the full-state checkpoints may differ when the hash gains fields.
# Usage: python golden_cmp.py <old golden.json> <new golden.json>
import json, sys
a=json.load(open(sys.argv[1])); b=json.load(open(sys.argv[2]))
bad=0
def row(kind, i, x, y):
    global bad
    same_ticks = x.get('ticks')==y.get('ticks')
    same_light = x.get('light')==y.get('light')
    cps = sum(1 for p,q in zip(x.get('checkpoints',[]), y.get('checkpoints',[])) if p==q)
    part = sum(1 for p,q in zip(x.get('checkpoints',[]), y.get('checkpoints',[])) if p.split(':')[0]==q.split(':')[0])
    if not (same_ticks and same_light): bad+=1
    print("%s %d  ticks %s (%s)  light %s  checkpoints equal %d of %d (first part equal %d)" % (kind, i, x.get('ticks'), "same" if same_ticks else "DIFFERENT: %s"%y.get('ticks'), "same" if same_light else "DIFFERENT", cps, len(x.get('checkpoints',[])), part))
for i,(x,y) in enumerate(zip(a['matches'], b['matches'])): row("match", i, x, y)
for i,(x,y) in enumerate(zip(a['replays'], b['replays'])): row("replay", i, x['run'], y['run'])
for k in ('tick0','wounds','rally','cripple','mood','keyed','rosterHash','fightHash'):
    print("%-10s %s" % (k, "same" if a.get(k)==b.get(k) else "different"))
print("RESULT:", "light digests and tick counts identical" if bad==0 else "%d DIFFER" % bad)
sys.exit(1 if bad else 0)
