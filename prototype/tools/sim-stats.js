// AI-vs-AI batch runner. Usage: node tools/sim-stats.js [matches=60]
// Reports win rate, match length, collateral and director decision frequencies.
const { load } = require('./headless');
const N = parseInt(process.argv[2] || '60', 10);
const { wf, feedLog } = load();
const wins = {}, durs = [], cas = [], structs = [];
for (let s = 0; s < N; s++) {
  wf.newMatch();
  let steps = 0;
  while (steps < 60 * 300 && !(wf.game.ko && wf.game.koT > 3)) {
    wf.step(1 / 60); steps++;
    for (const f of wf.fighters()) for (const k of ['x', 'y', 'vx', 'vy', 'hp', 'ki', 'power'])
      if (!Number.isFinite(f[k])) { console.error('NaN in', f.name, k, 'at', wf.T()); process.exit(1); }
  }
  const w = wf.world();
  const loser = wf.game.ko ? wf.game.ko.name : null;
  const winner = loser ? wf.fighters().find(f => f.name !== loser).name : 'timeout';
  wins[winner] = (wins[winner] || 0) + 1;
  durs.push(wf.T()); cas.push(w.casualties / w.pop0); structs.push(w.structuresLost);
}
const avg = a => a.reduce((x, y) => x + y, 0) / a.length;
const nb = wf.buildings().length;
console.log(`matches ${N}   wins`, JSON.stringify(wins));
console.log(`length avg ${avg(durs).toFixed(1)}s  min ${Math.min(...durs).toFixed(1)}  max ${Math.max(...durs).toFixed(1)}`);
console.log(`collateral avg ${(avg(cas) * 100).toFixed(0)}% of civilians   ${avg(structs).toFixed(1)} of ${nb} structures`);
const tally = {};
for (const [, tag, sub] of feedLog) {
  if (/^LAUNCH: /.test(tag)) tally[tag] = (tally[tag] || 0) + 1;
  else if (sub && / vs /.test(tag)) tally[sub.replace(/ \(ambush\)/, '').replace(/ →.*/, '')] = (tally[sub.replace(/ \(ambush\)/, '').replace(/ →.*/, '')] || 0) + 1;
  else if (/PARRIES|goes to ground| found/.test(tag)) { const k = tag.replace(/^[A-Z]+ /, ''); tally[k] = (tally[k] || 0) + 1; }
}
console.log('director decisions (count):');
Object.entries(tally).sort((a, b) => b[1] - a[1]).forEach(([k, v]) => console.log('  ' + String(v).padStart(5) + '  ' + k));
