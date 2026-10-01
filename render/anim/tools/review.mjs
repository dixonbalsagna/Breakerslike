// The review pipeline (docs/animation/review-plan.md): machines do the first pass, Orb sees one reel, one exceptions sheet and a few
// A/B pairs per wave. No dependencies (Node 24 built-ins). Run from the repo root.
//
//   node render/anim/tools/review.mjs wave --name strikes [--ids strike.] [--seeds 4,12345] [--ticks 3000] [--no-match] [--project DIR]
//       Runs pose_lint, silhouette_lint, stacking_lint and (unless --no-match) limb_scan, pop_scan and anim_check, merges their findings
//       into art/animation/review/<name>/: exceptions.md (what Orb sees, with a reason and a suggested action for each), summary.json
//       (every finding, machine readable) and exceptions-sheet.png (a contact sheet of the flagged poses).
//   node render/anim/tools/review.mjs reel --name strikes --seed 4 --from 1800 --count 400 [--step 3] [--crop 260x150] [--args "--style=fluid"]
//       The wave's reel: a real seeded match window, before the overhaul on the left (--noragdoll) and after on the right, as a GIF.
//   node render/anim/tools/review.mjs ab --name strikes --a "--style=snappy" --b "--style=fluid" --seed 4 --from 735 --count 120
//       An A/B pair: the same window under two argument sets, side by side, to be answered by a letter.
//   node render/anim/tools/review.mjs fix-reach --name strikes
//       Rewrites the hand and foot targets of the unreachable findings (not the strike poses, whose reach the contact slice reads) to
//       where the limb actually ends up: no visual change, the baked pose is what it was, but the data now says what the pose shows.
//
// GODOT_BIN names the Godot console executable (default: the one in %LOCALAPPDATA%\Programs\Godot\4.7.2). --project is the project
// directory to run in (default the current directory): use a clean export of HEAD plus your files when the working tree is busy.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const argv = process.argv.slice(2);
const cmd = argv[0];
const opt = (n, d) => { const i = argv.indexOf('--' + n); return i >= 0 && i + 1 < argv.length && !argv[i + 1].startsWith('--') ? argv[i + 1] : d; };
const flag = n => argv.includes('--' + n);
const project = resolve(opt('project', '.'));
const name = opt('name', 'wave');
const godot = process.env.GODOT_BIN || join(process.env.LOCALAPPDATA || '', 'Programs/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe');
const outRoot = resolve(opt('out', 'art/animation/review'));
const outDir = join(outRoot, name);
const rawDir = join(outDir, 'raw');
mkdirSync(rawDir, { recursive: true });

function runGodot(script, args, { headless = true, timeout = 900 } = {}) {
  const a = ['--path', project];
  if (headless) a.push('--headless');
  a.push('--script', `res://render/anim/tools/${script}.gd`, '--', ...args);
  const r = spawnSync(godot, a, { encoding: 'utf8', timeout: timeout * 1000, maxBuffer: 1 << 28 });
  if (r.status !== 0 && r.status !== null && r.stdout.indexOf('passed') < 0 && r.stdout.indexOf('FAILED') < 0) console.error(`[review] ${script} exited ${r.status}`);
  return r.stdout || '';
}
const readJson = p => existsSync(p) ? JSON.parse(readFileSync(p, 'utf8')) : null;

function wave() {
  const ids = opt('ids', '');
  const seeds = opt('seeds', '4,12345');
  const ticks = opt('ticks', '3000');
  const idArgs = ids ? [`--ids=${ids}`] : [];
  const found = [];
  const add = (severity, source, subject, detail, action) => found.push({ severity, source, subject, detail, action });
  // pose lint
  runGodot('pose_lint', [...idArgs, `--json=${join(rawDir, 'pose_lint.json')}`]);
  const pl = readJson(join(rawDir, 'pose_lint.json'));
  for (const it of pl?.issues ?? []) {
    if (it.kind === 'nan') add('error', 'pose_lint', it.id, it.detail, 'fix the pose data');
    else if (it.kind === 'unreachable') add(it.value > 5 ? 'review' : 'note', 'pose_lint', it.id, it.detail, it.value > 5 ? 'shorten the target or accept the clamped end (`fix-reach`)' : 'accept the clamped end (`fix-reach`)');
    else if (it.kind === 'joint range') add(it.value < -10 ? 'review' : 'note', 'pose_lint', it.id, it.detail, it.value < -10 ? 'a joint bent backwards: fix the pose' : 'the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant');
    else add('review', 'pose_lint', it.id, `${it.kind}: ${it.detail}`, 'adjust the pose');
  }
  // silhouette lint (the review threshold is a little under the lint's own)
  runGodot('silhouette_lint', [...idArgs, '--cross=0.80', '--same=0.92', `--json=${join(rawDir, 'silhouette.json')}`]);
  const sl = readJson(join(rawDir, 'silhouette.json'));
  for (const pr of sl?.pairs ?? []) add(pr.iou >= (pr.kind === 'same family' ? 0.95 : 0.85) ? 'review' : 'note', 'silhouette_lint', `${pr.a} / ${pr.b}`, `overlap ${pr.iou} (${pr.kind})`, pr.kind === 'same family' ? 'a key that barely moves: make the poses differ or drop one' : 'two moves that read alike: change one silhouette (or add the pair to data/anim/lint_allow.json with a reason)');
  // stacking lint
  runGodot('stacking_lint', [`--json=${join(rawDir, 'stacking.json')}`]);
  const st = readJson(join(rawDir, 'stacking.json'));
  for (const m of st?.moments ?? []) {
    if (m.status === 'FAIL') add('error', 'stacking_lint', m.id, `${m.count} marks (${m.marks.join(', ')}), the cap is 2`, 'drop a mark: Legal\'s stacking rule (rule-of-cool section 1 rule 9)');
    else if (m.status === 'warn') add('review', 'stacking_lint', m.id, `2 marks (${m.marks.join(', ')}): no room left`, 'nothing else may be added to this moment');
  }
  for (const id of st?.mark_one_poses ?? []) add('note', 'stacking_lint', id, 'mark 1: a crouch with fists at the sides', 'fine alone; never in a moment that also has a scream, a flame aura, rising rubble, lightning, hair or a gold flash');
  // match-level checks
  let matchNote = 'not run (--no-match)';
  if (!flag('no-match')) {
    runGodot('limb_scan', [`--seeds=${seeds}`, `--ticks=${ticks}`, `--json=${join(rawDir, 'limb_scan.json')}`]);
    const ls = readJson(join(rawDir, 'limb_scan.json'));
    for (const [k, v] of Object.entries(ls?.counts ?? {})) add('error', 'limb_scan', k, `${v} frames over ${ls.frames} fighter-frames`, 'a limb left human range in play: find the layer that did it');
    runGodot('pop_scan', [`--seeds=${seeds}`, `--ticks=${ticks}`, `--json=${join(rawDir, 'pop_scan.json')}`]);
    const ps = readJson(join(rawDir, 'pop_scan.json'));
    // A join above the limit is an eased swing, not a jump (inertialisation, pose-pipeline 9.x); only a turn past 3 rad (more than
    // half a turn in six ticks) is something to look at, the rest are logged with their worst case.
    if (ps && ps.worst > 3.0) add('review', 'pop_scan', 'joins', `the worst join turns a bone ${ps.worst.toFixed(2)} rad in one tick (${ps.joins} joins over ${ps.limit} rad)`, 'a pose pops: look at the example ticks in raw/pop_scan.json');
    else if (ps && ps.joins > 0) add('note', 'pop_scan', 'joins', `${ps.joins} eased swings over ${ps.limit} rad in ${ps.frames} fighter-frames, worst ${ps.worst.toFixed(2)} rad (${(ps.examples?.[0]?.text ?? '').replace(/^seed \d+ tick \d+ /, '')})`, 'none: the offset settles on its curve; raw/pop_scan.json lists the worst ticks');
    runGodot('anim_check', [`--seeds=${seeds}`, `--ticks=${ticks}`, `--report=${join(rawDir, 'anim_check.json')}`]);
    const ac = readJson(join(rawDir, 'anim_check.json'));
    for (const f of ac?.failures ?? []) add('error', 'anim_check', 'check', String(f), 'fix before anything else');
    for (const r of ac?.runs ?? []) {
      if (r.contact_err_max > 0.02) add('error', 'anim_check', `contact error (${r.seed}, ${r.mode})`, `${r.contact_err_max.toFixed(4)} rad on a contact frame`, 'a blow no longer lands on its contact key');
      if (r.contact_gap_worst > 1.0) add('review', 'anim_check', `contact gap (${r.seed}, ${r.mode})`, `${r.contact_gap_worst.toFixed(2)} units short of the defender`, 'the reach (arm, lunge, step-in) is not enough for this strike');
      if (r.contacts_beyond_reach > 0 && r.mode === 'mix') add('note', 'anim_check', `blows beyond reach (${r.seed})`, `${r.contacts_beyond_reach} of ${r.contacts_beyond_reach + r.contacts_within_reach}`, 'the sim lands blows farther than the animator can reach (Combat/Encounter spacing)');
    }
    matchNote = `${seeds} for ${ticks} ticks: limb_scan ${ls ? 'clean' : 'no data'}, anim_check ${ac ? (ac.failures.length ? ac.failures.length + ' failed' : 'passed, ' + ac.checks + ' checks') : 'no data'}`;
  }
  // the sheet of flagged poses
  const rank = { error: 0, review: 1, note: 2 };
  found.sort((a, b) => rank[a.severity] - rank[b.severity]);
  const flagged = [];
  for (const f of found) if (f.severity !== 'note') for (const part of f.subject.split(' / ')) if (/^[a-z][a-z0-9_]*(\.[a-z0-9_]+)*$/.test(part) && !flagged.includes(part) && flagged.length < 24) flagged.push(part);
  let sheet = '';
  if (flagged.length && !flag('no-sheet')) {
    sheet = join(outDir, 'exceptions-sheet.png');
    runGodot('pose_sheet', [`--out=${sheet}`, `--ids=${flagged.join(',')}`, '--cols=6', '--cell=190'], { headless: false, timeout: 300 });
  }
  // the markdown Orb reads
  const counts = { error: 0, review: 0, note: 0 };
  for (const f of found) counts[f.severity]++;
  const poseCount = pl?.poses ?? 0;
  const lines = [];
  lines.push(`# Review: ${name}`, '');
  lines.push(`Machine pass over ${poseCount} poses${ids ? ' (' + ids + ')' : ''}: **${counts.error} errors, ${counts.review} for review, ${counts.note} notes.** Errors are fixed by the director before Orb sees anything; the rows under "For review" are what Orb sees (with the sheet); notes are logged and need nobody.`, '');
  lines.push(`Match checks: ${matchNote}.`, '');
  if (sheet) lines.push(`Sheet of the flagged poses: ${'exceptions-sheet.png'}`, '');
  for (const [sev, title] of [['error', 'Errors (the director fixes these first)'], ['review', 'For review (what Orb sees)'], ['note', 'Notes (logged, no action needed)']]) {
    const rows = found.filter(f => f.severity === sev);
    if (!rows.length) continue;
    lines.push(`## ${title}`, '', '| Source | Subject | Finding | Suggested action |', '| :--- | :--- | :--- | :--- |');
    for (const r of rows.slice(0, sev === 'note' ? 40 : 200)) lines.push(`| ${r.source} | ${r.subject} | ${r.detail} | ${r.action} |`);
    if (rows.length > 40 && sev === 'note') lines.push(`| | | ... and ${rows.length - 40} more notes (summary.json) | |`);
    lines.push('');
  }
  writeFileSync(join(outDir, 'exceptions.md'), lines.join('\n'));
  writeFileSync(join(outDir, 'summary.json'), JSON.stringify({ wave: name, poses: poseCount, counts, flagged, findings: found }, null, 1));
  console.log(`[review] ${name}: ${poseCount} poses, ${counts.error} errors, ${counts.review} for review, ${counts.note} notes -> ${outDir}`);
}

function reel(extraA = [], extraB = [], labelA = 'noragdoll', labelB = '', gifName = null) {
  const seed = opt('seed', '4');
  const from = opt('from', '735');
  const count = opt('count', '120');
  const step = opt('step', '2');
  const crop = opt('crop', '220x140');
  const scale = opt('scale', '2');
  const mk = (tag, extra) => {
    const out = join(rawDir, `reel_${tag}.rgb`);
    runGodot('anim_reel', [`--out=${out}`, `--seed=${seed}`, `--from=${from}`, `--count=${count}`, `--step=${step}`, `--crop=${crop}`, `--scale=${scale}`, ...extra], { headless: false, timeout: 1800 });
    return out;
  };
  const a = mk('a', extraA);
  const b = mk('b', extraB);
  const gif = gifName || join(outDir, `${name}-reel.gif`);
  const r = spawnSync(process.execPath, [join(project, 'render/anim/tools/gif.mjs'), gif, a, b, '--delay', opt('delay', '5')], { encoding: 'utf8' });
  console.log(r.stdout.trim());
}

function fixReach() {
  const sum = readJson(join(outDir, 'raw/pose_lint.json'));
  if (!sum) { console.error('no raw/pose_lint.json: run the wave first'); process.exit(1); }
  const path = join(project, 'data/anim/poses.json');
  let txt = readFileSync(path, 'utf8');
  let n = 0;
  // strike poses keep their authored reach: the contact slice reads it
  for (const it of sum.issues.filter(i => i.kind === 'unreachable' && !i.id.startsWith('strike.'))) {
    const re = new RegExp(`("${it.id.replace(/\./g, '\\.')}": \\{[^\\n]*?"${it.limb}": )\\[[^\\]]*\\]`);
    if (re.test(txt)) { txt = txt.replace(re, `$1[${it.achieved.join(', ')}]`); n++; }
  }
  writeFileSync(path, txt);
  console.log(`[review] fix-reach: ${n} targets moved to where the limb ends up`);
}

if (cmd === 'wave') wave();
else if (cmd === 'reel') reel(['--noragdoll'], []);
else if (cmd === 'ab') reel((opt('a', '')).split(' ').filter(Boolean), (opt('b', '')).split(' ').filter(Boolean), 'A', 'B', join(outDir, `${name}-ab.gif`));
else if (cmd === 'fix-reach') fixReach();
else { console.error('usage: node render/anim/tools/review.mjs wave|reel|ab|fix-reach --name NAME ...  (see the header of this file)'); process.exit(2); }
