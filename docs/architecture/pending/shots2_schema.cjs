// Tools' side of shots, the second round (docs/architecture/shots.md sections 13 to 18): the new keys of
// data/fight/shots.json in tools/schemas/fight-shots.schema.json. Usage: node shots2_schema.cjs <repo root>
// Additive: it re-reads the schema and writes it back with the new keys; nothing existing is tightened. One bound is
// loosened: a kind's speed may be 0 (a mine does not travel; the loader still refuses 0 for a kind that is not a mine),
// and with it the one self-test case in tools/fixtures/cases.json that expected 0 to be refused.
const fs = require('fs'), path = require('path');
const root = process.argv[2];
const p = path.join(root, 'tools/schemas/fight-shots.schema.json');
const s = JSON.parse(fs.readFileSync(p, 'utf8'));
const P = s.properties;
if (P.structures || P.deflect) throw new Error('already applied');
const num = (min, d) => ({ type: 'number', minimum: min, description: d });
const int = (min, d) => ({ type: 'integer', minimum: min, description: d });
P.structures = { type: 'boolean', description: 'A straight or lobbed shot stops at a standing front-row building its path crosses.' };
P.deflect = {
  type: 'object',
  description: 'What a deflect does to a shot.',
  required: ['scatter', 'nearMin', 'nearMax', 'farMin', 'farMax', 'farChance', 'awayChance', 'speed', 'minTicks', 'arcPer', 'safeTicks', 'backCos'],
  properties: {
    scatter: { type: 'boolean', description: 'true: the shot flies wild to a seeded spot on the ground. false: it flies back at its owner.' },
    nearMin: { type: 'number', exclusiveMinimum: 0, description: 'The near band of landing distances, in units.' },
    nearMax: { type: 'number', exclusiveMinimum: 0 },
    farMin: { type: 'number', exclusiveMinimum: 0, description: 'The far band.' },
    farMax: { type: 'number', exclusiveMinimum: 0 },
    farChance: { type: 'number', minimum: 0, maximum: 1, description: 'The share of deflects that land in the far band.' },
    awayChance: { type: 'number', minimum: 0, maximum: 1, description: 'The share that land on the side away from the shooter.' },
    speed: { type: 'number', exclusiveMinimum: 0, description: 'Units a tick along the flight.' },
    minTicks: int(1, 'The shortest flight.'),
    arcPer: num(0, 'The arc\'s height per unit of landing distance.'),
    safeTicks: int(0, 'Ticks for which it cannot hit the fighter who deflected it.'),
    backCos: { type: 'number', minimum: -1, maximum: 1, description: 'It never leaves within the angle with this cosine of the line back to the shooter.' },
  },
  additionalProperties: false,
  patternProperties: { '^_': true },
};
P.mineCap = { type: 'integer', minimum: 0, maximum: 32, description: 'Mines one fighter may have laid at once.' };
P.mineGap = num(0, 'A mine cannot be laid within this of another.');
const K = s.properties.kinds.additionalProperties.properties;
delete K.speed.exclusiveMinimum;
K.speed.minimum = 0;
K.speed.description = 'Units a tick (a minimum for a seeking shot). 0 only for a mine.';
K.mine = {
  type: 'object',
  description: 'This kind is a mine: it stays where it is laid.',
  required: ['trigR', 'blastR', 'chainR', 'armTicks', 'fuseTicks', 'chainTicks', 'ownShare', 'tierR'],
  properties: {
    trigR: num(0, 'A rival\'s centre within this sets it off.'),
    blastR: num(0, 'Its blast hits every fighter within this.'),
    chainR: num(0, 'Its blast sets off the mines within this.'),
    armTicks: int(0, 'Ticks before it is armed.'),
    fuseTicks: int(0, 'Ticks from set off to blast.'),
    chainTicks: int(1, 'Ticks between the mines of a chain.'),
    ownShare: { type: 'number', minimum: 0, maximum: 1, description: 'The share of its damage its owner takes inside the blast.' },
    tierR: { type: 'array', minItems: 4, maxItems: 4, items: { type: 'number', exclusiveMinimum: 0 }, description: 'The radii\'s growth by its owner\'s tier.' },
  },
  additionalProperties: false,
  patternProperties: { '^_': true },
};
s.description = s.description.replace('and each kind\'s speed', 'what a deflect does, whether shots stop at buildings, the mine limits, and each kind\'s speed');
fs.writeFileSync(p, JSON.stringify(s, null, 2) + '\n');
// the self-test's case "shots-speed-zero" expected 0 to be refused: it now sets -1 and expects the minimum rule
const cp = path.join(root, 'tools/fixtures/cases.json');
const c = fs.readFileSync(cp, 'utf8');
const at = c.indexOf('"id": "shots-speed-zero"');
if (at < 0) throw new Error('the case shots-speed-zero is not in tools/fixtures/cases.json');
const end = c.indexOf('"id":', at + 10);
let blk = c.slice(at, end);
const was = '"/kinds/bolt/speed": 0', rule = '"rule": "exclusiveMinimum"';
if (blk.split(was).length !== 2 || blk.split(rule).length !== 2) throw new Error('the case shots-speed-zero is not as expected');
blk = blk.replace(was, '"/kinds/bolt/speed": -1').replace(rule, '"rule": "minimum"');
fs.writeFileSync(cp, c.slice(0, at) + blk + c.slice(end));
console.log('fight-shots schema: structures, deflect, mineCap, mineGap, kinds.*.mine added; speed may be 0; the case shots-speed-zero now sets -1');
