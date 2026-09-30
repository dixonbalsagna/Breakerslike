// Combat's dynamic-feel probe (docs/combat/dynamic-feel.md) run as part of the Godot QA: feel_probe.gd steps AI-vs-AI
// matches on the live sim and sorts every frame into freeze, active or idle; this turns its summary into band rows for the
// §10 dynamic-feel targets. One Godot process, read-only, about a minute for 40 matches.
const { spawn } = require('child_process');
const { godot, ROOT } = require('./godot');

function runFeel({ matches = 40, base = 1 } = {}) {
  const g = godot();
  if (!g) return Promise.reject(new Error('Godot 4.7 not found'));
  return new Promise((resolve, reject) => {
    const p = spawn(g.exe, ['--headless', '--path', ROOT, '--script', 'res://qa/godot/feel/feel_probe.gd', '--', String(matches), String(base)], { stdio: ['ignore', 'pipe', 'pipe'] });
    let out = '';
    p.stdout.on('data', d => { out += d; }); p.stderr.on('data', d => { out += d; });
    p.on('error', reject);
    p.on('close', code => {
      const line = out.split('\n').find(l => l.startsWith('{"label"'));
      if (code !== 0 || !line) return reject(new Error('feel_probe.gd failed (exit ' + code + ')\n' + out.slice(0, 1500)));
      resolve(JSON.parse(line).summary);
    });
  });
}

// The dynamic-feel targets (docs/combat/dynamic-feel.md section 3, adopted in balance-targets §10), default arm.
function feelRows(s, matches) {
  const rows = [], n = `${matches} default-arm matches`;
  const pct = v => (v * 100).toFixed(1) + '%', sec = v => v.toFixed(2) + ' s';
  const add = (id, what, v, f, ok, band) => rows.push({ id, ref: '§10 feel', what, status: v < 0 ? 'PENDING' : ok(v) ? 'PASS' : 'FAIL', value: v < 0 ? 'no data' : f(v), band, note: n });
  add('feel.idle', 'Melee idle share inside exchanges', s.melee_idle_share, pct, v => v <= 0.15, 'at most 15.0%');
  add('feel.still.med', 'Melee longest still stretch per exchange, median', s.melee_longest_idle_med_s, sec, v => v <= 0.25, 'at most 0.25 s');
  add('feel.still.p90', 'Melee longest still stretch per exchange, p90', s.melee_longest_idle_p90_s, sec, v => v <= 0.5, 'at most 0.50 s');
  add('feel.first', 'Request to first strike, median, on exchanges that start within 2,500 units (longer ones are pursuit flights by design)', s.request_to_first_strike_near_med_s !== undefined ? s.request_to_first_strike_near_med_s : s.request_to_first_strike_med_s, sec, v => v <= 0.6, 'at most 0.60 s');
  add('feel.gap.med', 'Gap between visible strikes, median', s.gap_between_strikes_med_s, sec, v => v <= 0.25, 'at most 0.25 s');
  add('feel.gap.p90', 'Gap between visible strikes, p90', s.gap_between_strikes_p90_s, sec, v => v <= 2.0, 'at most 2.00 s');
  add('feel.strikes', 'Strikes per minute', s.strikes_per_min, v => v.toFixed(1), v => v >= 80, 'at least 80');
  add('feel.release', 'Release to the next request, median', s.release_to_next_request_med_s, sec, v => v <= 1.0, 'at most 1.00 s');
  add('feel.standoff', 'Close standoff runs, p90', s.standoff_run_p90_s, sec, v => v <= 0.6, 'at most 0.60 s');
  add('feel.inEx', 'Share of fight time inside exchanges', s.share_time_in_exchanges, pct, v => v >= 0.5, 'at least 50.0%');
  add('feel.hitstop', 'Hit-stop share of exchange frames (deliberate, unchanged)', s.freeze_share_in_exchanges, pct, v => v >= 0.07 && v <= 0.13, '7.0% to 13.0%');
  rows.push({ id: 'feel.len', ref: '§10 feel', what: 'Exchange length, median (informational; replaces the old 2.5 to 4.0 s band)', status: 'INFO', value: sec(s.exchange_len_med_s), band: '', note: n });
  return rows;
}
module.exports = { runFeel, feelRows };
