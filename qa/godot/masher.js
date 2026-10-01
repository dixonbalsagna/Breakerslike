// The scripted masher (docs/design/control-rules.md section 6): a v2 human slot pressing light every 8 ticks against the AI at each level.
// masher.gd plays the matches in one Godot process per level; this turns the wins into band rows. Point estimates only, with the sample size in the note:
// at 40 matches the 95% interval is about 30 points wide, so a row near a band edge needs more matches (--masher=N).
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
// Two waves of three processes: the masher who takes forms (the banded rows) and the one who never transforms (INFO), per Encounter's finding in docs/director/masher-probes.md.
async function runMasher({ n = 40, base = 1, levels = ['easy', 'medium', 'hard'] } = {}) {
  const withForms = await Promise.all(levels.map(l => runLevel(l, n, base, true)));
  const noForms = await Promise.all(levels.map(l => runLevel(l, n, base, false)));
  return [...withForms, ...noForms];
}

const BANDS = { easy: [0.60, 1, 'at least 60%'], medium: [0.35, 0.50, '35 to 50%'], hard: [0, 0.15, 'at most 15%'] };

function masherRows(results) {
  const rows = results.map(r => {
    const [lo, hi, text] = BANDS[r.level], decided = r.wins + r.losses, v = decided ? r.wins / decided : NaN, ok = decided && v >= lo && v <= hi, forms = !!r.forms;
    return { id: 'masher.' + (forms ? '' : 'noforms.') + r.level, ref: '§6 masher', what: `A scripted masher (light every ${r.gap} ticks, ${forms ? 'takes forms' : 'no forms'}) wins against the ${r.level} AI`, status: decided ? (forms ? (ok ? 'PASS' : 'FAIL') : 'INFO') : 'PENDING', value: decided ? `${(v * 100).toFixed(1)}% (${r.wins} of ${decided})` : 'no decided matches', band: forms ? text : `(${text} if forms are taken)`, note: `${r.n} matches, ${r.timeouts} timed out, median ${r.medianSec} s; point estimate only${forms ? '' : '; a beginner who never transforms fights at tier 1 (Game Design to rule)'}` };
  });
  rows.push({ id: 'masher.expert', ref: '§6 masher', what: 'An expert script (guards, punishes with a heavy, perfect-blocks heavies and enders) wins against the medium AI (at most 15%)', status: 'PENDING', value: '', band: 'at most 15%', note: 'needs the expert script: it reads the rival tells (Encounter scratch build has one, not in the tree)' });
  return rows;
}

module.exports = { runMasher, masherRows };
