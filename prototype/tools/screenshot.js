// Save a PNG at a given sim time. Needs: npm i @napi-rs/canvas.  Usage: node tools/screenshot.js 12 out.png
const { load } = require('./headless');
const fs = require('fs');
const t = parseFloat(process.argv[2] || '10'), out = process.argv[3] || 'shot.png';
const { wf, canvas } = load();
wf.newMatch();
while (wf.T() < t && !wf.game.ko) wf.step(1 / 60);
wf.render();
fs.writeFileSync(out, canvas.toBuffer('image/png'));
console.log('wrote', out, 'at T=' + wf.T().toFixed(1));
