// Minimal test helper for the qa suite. Node built-ins only, so it runs on any Node with no install step.
// Usage in a test file:
//   const t = require('../lib/check')('name');
//   t.test('does the thing', () => { assert.ok(...); return 'optional detail'; });
//   t.info('a non-failing note');
//   t.done();                       // sets a non-zero exit code if any test failed
module.exports = function suite(name) {
  let pass = 0, fail = 0;
  console.log(`== ${name}`);
  return {
    test(title, fn) {
      try {
        const detail = fn();
        pass++; console.log('  ok    ' + title + (detail ? '  (' + detail + ')' : ''));
      } catch (e) {
        fail++; console.log('  FAIL  ' + title + '\n' + String(e && e.message || e).split('\n').map(l => '          ' + l).join('\n'));
      }
    },
    info(msg) { console.log('  note  ' + msg); },
    done() {
      console.log(`${name}: ${pass} passed, ${fail} failed`);
      process.exitCode = fail ? 1 : 0;
    },
  };
};
