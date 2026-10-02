# Game Design's first numbers for shots (docs/design/agency-pass.md section 11, item 6b): data only.
# Usage: python shots_numbers.py <repo root>. It rewrites the kinds in data/fight/shots.json; no code, no schema change.
# The fight data hash is in the goldens, so regenerate them once (the light digests do not move: nothing fires a shot yet).
import os, sys, json, collections
os.chdir(sys.argv[1])
OD=collections.OrderedDict
p="data/fight/shots.json"
d=json.load(open(p,encoding='utf-8'),object_pairs_hook=OD)
assert list(d["kinds"].keys())==["bolt","charged","lob"], list(d["kinds"].keys())
LIGHT=26.0   # data/combat/templates.json base.light
HEAVY=66.0   # ... base.heavy
d["kinds"]=OD([
 ("bolt",   OD([("speed",60.0),("r",14.0),("power",1.0),("dmg",round(LIGHT/3.0,2)),("lifeTicks",120)])),
 ("shard",  OD([("speed",50.0),("r",10.0),("power",1.0),("dmg",round(LIGHT/5.0,2)),("lifeTicks",24)])),
 ("arc",    OD([("speed",45.0),("r",20.0),("power",2.0),("dmg",round(HEAVY*0.8,2)),("lifeTicks",120)])),
 ("charged",OD([("speed",90.0),("r",30.0),("power",3.0),("dmg",round(HEAVY*0.6,2)),("lifeTicks",120)])),
 ("lob",    OD([("speed",40.0),("r",24.0),("power",3.0),("dmg",HEAVY),("lifeTicks",36),("lobTicks",36),("lobArc",300.0)])),
])
d["_numbers"]="Game Design's first values (agency-pass.md section 11, item 6b). Speeds and trade powers are as ruled. dmg is the plain rule's stand-in for 'a shape carries its strike's damage': a bolt a third of a light (26 / 3), a shard a fifth, an arc 0.8 of a heavy (66), a charged shot 0.6 of a heavy on a tap (the director raises it to a full heavy at 30 ticks of charge), a lob a heavy. The director's blasts pass their own damage at the fire. A shard flies 1,200 units (24 ticks at 50). Not here, because they are the director's: the ki costs (bolt 1, a volley of 3 bolts 3, a spread of 5 shards 3, arc, lob and charged 8 each), the counts, and the burst (no travel, within 150 units, power 3: an area hit, not a shot). The radii and the lob's height are Simulation's placeholders."
nd=OD()
for k,v in d.items():
    if k=="_numbers":
        continue
    nd[k]=v
    if k=="_about":
        nd["_numbers"]=d["_numbers"]
open(p,'w',encoding='utf-8',newline='\n').write(json.dumps(nd,indent=2,ensure_ascii=False)+"\n")
print("shot numbers applied")
