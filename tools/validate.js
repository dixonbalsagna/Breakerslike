#!/usr/bin/env node
'use strict';
// Data validator: every data file against its JSON Schema (draft 2020-12), plus the
// cross-references between files. Node built-ins only, deterministic, no clock.
//
//   node tools/validate.js                 all data (data/, audio/data/, ui/data/) + cross-references
//   node tools/validate.js <paths...>      only these files or folders (schema and lint checks only)
//   node tools/validate.js --xref <paths>  the same, plus the cross-reference rules
//   node tools/validate.js --self-test     prove the validator: engine, parser, schemas, fixtures, cross-references
//   node tools/validate.js --list          print the folder-to-schema map
//
// Exit 0: no errors (warnings allowed; a missing or empty data folder is fine). Exit 1: any error.
// Exit 2: bad usage. Each finding names the file, line, JSON pointer and rule.
// Docs: docs/tools/README.md
const fs = require('node:fs');
const path = require('node:path');
const core = require('./lib/core');

function format(f) {
  const where = f.line !== undefined ? `${f.file}:${f.line}` : f.file;
  const ptr = f.pointer === '' || f.pointer === undefined ? '' : ` ${f.pointer}`;
  return `${f.level}  ${where}${ptr}  [${f.rule}] ${f.message}`;
}

// Runs the checks over `rels` (repo-relative paths) and returns every finding, sorted by file.
// `read(rel)` returns the text; the default reads from disk.
function run(rels, { withXref, read }) {
  const findings = [];
  const docs = new Map(); // rel -> { value, lineOf }
  for (const rel of rels) {
    const { parsed, findings: lint } = core.lintText(rel, read(rel));
    findings.push(...lint);
    if (parsed.ok) docs.set(rel, { value: parsed.value, lineOf: parsed.line });
  }
  findings.push(...core.analyzeDocs(docs, { withXref }));
  return core.sortFindings(findings);
}

function main(argv) {
  const flags = new Set(argv.filter((a) => a.startsWith('--')));
  const paths = argv.filter((a) => !a.startsWith('--'));
  const known = new Set(['--self-test', '--list', '--xref', '--help', '-h']);
  for (const f of flags) {
    if (!known.has(f)) {
      console.error(`unknown option ${f}\nusage: node tools/validate.js [--xref] [paths...] | --self-test | --list`);
      return 2;
    }
  }
  if (flags.has('--help') || flags.has('-h')) {
    console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(2, 14).map((l) => l.replace(/^\/\/ ?/, '')).join('\n'));
    return 0;
  }
  if (flags.has('--list')) {
    for (const r of core.loadMap().rules) console.log(`${r.match.padEnd(38)} ${r.schema}`);
    return 0;
  }
  if (flags.has('--self-test')) return require('./lib/selftest').run();

  let rels;
  try {
    rels = core.discover(paths);
  } catch (e) {
    console.error(`error: ${e.message}`);
    return 2;
  }
  const findings = run(rels, {
    withXref: paths.length === 0 || flags.has('--xref'),
    read: (rel) => fs.readFileSync(path.join(core.repoRoot, rel), 'utf8'),
  });
  for (const f of findings) console.log(format(f));
  const errors = findings.filter((f) => f.level === 'error').length;
  const warnings = findings.length - errors;
  console.log(`${rels.length} file${rels.length === 1 ? '' : 's'} checked, ${errors} error${errors === 1 ? '' : 's'}, ${warnings} warning${warnings === 1 ? '' : 's'}`);
  return errors ? 1 : 0;
}

if (require.main === module) process.exit(main(process.argv.slice(2)));
module.exports = { run, format };
