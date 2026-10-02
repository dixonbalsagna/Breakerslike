// The scripted masher (docs/design/control-rules.md section 6): a v2 human slot pressing light every 8 ticks against the AI at each level.
// masher.gd plays the matches in one Godot process per level; this turns the wins into band rows. Point estimates only, with the sample size in the note:
// at 40 matches the 95% interval is about 30 points wide (the medium row read 60% at 40 matches and 43% at 200), so the default is 100 and a row near a band edge needs more (--masher=N).
const { spawn } = require('child_process');
const { godot, ROOT } = require('./godot');

function runLevel(level, n, base, forms = false) {
  const g = godot();
  if (!g) return Promise.reject(new Error('Godot 4.7 not found'));
  return new Promise((resolve, reject) => {
    const p = spawn(g.exe, ['--headless', '--path', ROOT, '--script', 'res://qa/godot/masher.gd', '--', String(n), String(base), `--level=${level}`, `--forms=${forms ? 1 : 0}`], { stdio: ['ignore', 'pipe', 'pipe'] });
    let out = '';
    p.stdout.on('data', d => { out += d; }); p.stderr.on('data', d => { out += d; });
    p.on('error', reject);
    p.on('close', code => {
      const line = out.split('\n').find(l => l.startsWith('{') && l.includes('"masher"'));
      if (code !== 0 || !line) return reject(new Error('masher.gd failed for ' + level + ' (exit ' + code + ')\n' + out.slice(0, 1200)));
      resolve(JSON.parse(line));
    });
  });
}

// Levels run side by side (three Godot processes).
// The lights-only mirror (Game Design, agency pass 13): two mashers who take their forms play each other; at least 95% of the matches must finish before the cap (two beginners on one button must not sit in a stalemate).
function runMirror(n, base) {
  const g = godot();
  if (!g) return Promise.reject(new Error('Godot 4.7 not found'));
  return new Promise((resolve, reject) => {
    const p = spawn(g.exe, ['--headless', '--path', ROOT, '--script', 'res://qa/godot/players.gd', '--', String(n), String(base), '--a=masher:forms=1', '--b=masher:forms=1'], { stdio: ['ignore', 'pipe', 'pipe'] });
    let out = '';
    p.stdout.on('data', d => { out += d; }); p.stderr.on('data', d => { out += d; });
    p.on('error', reject);
    p.on('close', code => {
      const line = out.split(String.fromCharCode(10)).find(l => l.startsWith('{') && l.includes('"players"'));
      if (code !== 0 || !line) return reject(new Error('players.gd failed for the mirror (exit ' + code + ')' + String.fromCharCode(10) + out.slice(0, 1200)));
      const r = JSON.parse(line);
      resolve({ mirror: true, n: r.n, finished: r.aWins + r.bWins, timeouts: r.timeouts, medianSec: r.medianSec, brink: r.brinkToKoMedian });
    });
  });
}

// A pair of scripted players (players.gd specs) against each other: the energy rows of agency pass 16 (a bolt-only player finishes at least 95% against a melee masher and wins 20 to 40% against the medium AI; a blast-heavy script against a rush-heavy one 40 to 60%).
function runPair(tag, a, b, n, base) {
  const g = godot();
  if (!g) return Promise.reject(new Error('Godot 4.7 not found'));
  return new Promise((resolve, reject) => {
    const p = spawn(g.exe, ['--headless', '--path', ROOT, '--script', 'res://qa/godot/players.gd', '--', String(n), String(base), `--a=${a}`, `--b=${b}`], { stdio: ['ignore', 'pipe', 'pipe'] });
    let out = '';
    p.stdout.on('data', d => { out += d; }); p.stderr.on('data', d => { out += d; });
    p.on('error', reject);
    p.on('close', code => {
      const line = out.split(String.fromCharCode(10)).find(l => l.startsWith('{') && l.includes('"players"'));
      if (code !== 0 || !line) return reject(new Error('players.gd failed for ' + tag + ' (exit ' + code + ')' + String.fromCharCode(10) + out.slice(0, 1200)));
      const r = JSON.parse(line);
      resolve({ pair: tag, n: r.n, aWins: r.aWins, bWins: r.bWins, timeouts: r.timeouts, medianSec: r.medianSec });
    });
  });
}

// Two waves of three processes: the masher who takes forms (the banded rows) and the one who never transforms (INFO), per Encounter's finding in docs/director/masher-probes.md.
async function runMasher({ n = 100, base = 1, levels = ['easy', 'medium', 'hard'] } = {}) {
  const withForms = await Promise.all(levels.map(l => runLevel(l, n, base, true)));
  const noForms = await Promise.all(levels.map(l => runLevel(l, n, base, false)));
  const mirror = await runMirror(Math.min(n, 60), base);   // one more process; the mirror's matches are the slow ones (a stalemate runs to the cap), so it gets fewer
  const E = ':energy=1:forms=1:stick=1', R = ':forms=1:stick=1';
  const pairs = await Promise.all([
    runPair('bolt-melee', 'masher:energy=1:forms=1', 'masher:forms=1', Math.min(n, 40), base),
    runPair('bolt-medium', 'masher:energy=1:forms=1', 'ai:level=medium', Math.min(n, 40), base),
    runPair('blast-rush', 'tapper:acc=80:win=4:mix=LLH' + E, 'tapper:acc=80:win=4:mix=LLH' + R, Math.min(n, 40), base),
  ]);
  return [...withForms, ...noForms, mirror, ...pairs];
}

const BANDS = { easy: [0.60, 1, 'at least 60%'], medium: [0.35, 0.50, '35 to 50%'], hard: [0, 0.15, 'at most 15%'] };

function masherRows(results) {
  const rows = results.filter(r => !r.mirror && !r.pair).map(r => {
    const [lo, hi, text] = BANDS[r.level], decided = r.wins + r.losses, v = decided ? r.wins / decided : NaN, ok = decided && v >= lo && v <= hi, forms = !!r.forms;
    return { id: 'masher.' + (forms ? '' : 'noforms.') + r.level, ref: '§6 masher', what: `A scripted masher (light every ${r.gap} ticks, ${forms ? 'takes forms' : 'no forms'}) wins against the ${r.level} AI`, status: decided ? (forms ? (ok ? 'PASS' : 'FAIL') : 'INFO') : 'PENDING', value: decided ? `${(v * 100).toFixed(1)}% (${r.wins} of ${decided})` : 'no decided matches', band: forms ? text : `(${text} if forms are taken)`, note: `${r.n} matches, ${r.timeouts} timed out, median ${r.medianSec} s; point estimate only${forms ? '' : '; a beginner who never transforms fights at tier 1 (Game Design to rule)'}; per match: launches by the masher ${r.launchesByMasher}, of which air catches ${r.airCatchesOfAI}; launches on the masher ${r.launchesOnMasher}, air catches ${r.airCatchesOfMasher}` };
  });
  for (const r of results.filter(x => x.pair)) {
    const dec = r.aWins + r.bWins;
    if (r.pair === 'bolt-melee') rows.push({ id: 'masher.bolt.finish', ref: '§6 masher', what: 'A bolt-only player (energy held, a bolt every 8 ticks) finishes the match against a melee masher before the cap (agency pass 16: at least 95%)', status: dec / r.n >= 0.95 ? 'PASS' : 'FAIL', value: `${(100 * dec / r.n).toFixed(1)}% (${dec} of ${r.n}; ${r.timeouts} ran to the cap)`, band: 'at least 95%', note: `median ${r.medianSec} s; point estimate` });
    else if (r.pair === 'bolt-medium') rows.push({ id: 'masher.bolt.medium', ref: '§6 masher', what: 'A bolt-only player wins against the medium AI (agency pass 16: 20 to 40%)', status: dec ? (r.aWins / dec >= 0.20 && r.aWins / dec <= 0.40 ? 'PASS' : 'FAIL') : 'PENDING', value: dec ? `${(100 * r.aWins / dec).toFixed(1)}% (${r.aWins} of ${dec})` : 'no decided matches', band: '20 to 40%', note: `${r.n} matches, ${r.timeouts} ran to the cap; point estimate` });
    else if (r.pair === 'blast-rush') rows.push({ id: 'masher.blast.rush', ref: '§6 masher', what: 'A blast-heavy timed script against a rush-heavy timed script (agency pass 15.6: 40 to 60%)', status: dec ? (r.aWins / dec >= 0.40 && r.aWins / dec <= 0.60 ? 'PASS' : 'FAIL') : 'PENDING', value: dec ? `${(100 * r.aWins / dec).toFixed(1)}% (${r.aWins} of ${dec})` : 'no decided matches', band: '40 to 60%', note: `${r.n} matches, ${r.timeouts} ran to the cap; point estimate` });
  }
  const m = results.find(r => r.mirror);
  if (m) rows.push({ id: 'masher.mirror', ref: '§6 masher', what: 'Two lights-only players (mashers who take their forms) finish the match before the cap', status: m.finished / m.n >= 0.95 ? 'PASS' : 'FAIL', value: `${(100 * m.finished / m.n).toFixed(1)}% (${m.finished} of ${m.n}; ${m.timeouts} ran to the cap)`, band: 'at least 95%', note: `median ${m.medianSec} s; point estimate` });
  if (m && m.brink >= 0) rows.push({ id: 'masher.brink', ref: '§6 masher', what: 'Lights-only mirror: brink to KO, median (45 to 55 s expected after a plain blur ender counts as half a set-up, agency pass 14)', status: m.brink >= 45 && m.brink <= 55 ? 'PASS' : 'FAIL', value: m.brink.toFixed(1) + ' s', band: '45 to 55 s', note: `${m.finished} matches that ended in a KO; the overall band stays 45 to 90 s` });
  rows.push({ id: 'masher.expert', ref: '§6 masher', what: 'An expert script (guards, punishes with a heavy, perfect-blocks heavies and enders) wins against the medium AI (at most 15%)', status: 'PENDING', value: '', band: 'at most 15%', note: 'needs the expert script: it reads the rival tells (Encounter scratch build has one, not in the tree)' });
  return rows;
}

module.exports = { runMasher, masherRows };
