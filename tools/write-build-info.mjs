// Writes res://build_info.json (the repo root's build_info.json) for the feedback report: {"commit": "<sha7>", "date": "<yyyy-mm-dd>"}.
//   node tools/write-build-info.mjs [--commit <sha>] [--date <yyyy-mm-dd>] [--out <file>]
// Run it before a Godot export; CI does (the site job). The commit comes from --commit, then GITHUB_SHA, then
// `git rev-parse`; the date is the commit's own date (`git log -1 --format=%cs`), never the clock, so the same commit
// always writes the same file. With no git and no arguments both values are "unknown" and it still exits 0, so a local
// build without git never breaks.
// The file is git-ignored, is not under data/ (so the sim's data hash never sees it), and is packed into the export by
// the include_filter in export_presets.cfg. Docs: docs/tools/README.md
import { spawnSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const opt = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};
const git = (...a) => {
  try {
    const r = spawnSync('git', ['-C', root, ...a], { encoding: 'utf8' });
    return r.status === 0 ? r.stdout.trim() : '';
  } catch {
    return '';
  }
};

const sha = (opt('--commit') || process.env.GITHUB_SHA || git('rev-parse', 'HEAD') || '').trim();
const commit = /^[0-9a-f]{7,40}$/i.test(sha) ? sha.slice(0, 7).toLowerCase() : 'unknown';
const dateArg = opt('--date');
const date = /^\d{4}-\d{2}-\d{2}$/.test(dateArg || '') ? dateArg : git('log', '-1', '--format=%cs') || 'unknown';
const out = resolve(opt('--out') || join(root, 'build_info.json'));

writeFileSync(out, `${JSON.stringify({ commit, date })}\n`);
console.log(`wrote ${out}: commit ${commit}, date ${date}`);
