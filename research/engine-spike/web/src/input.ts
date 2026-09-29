// Keyboard and gamepad to intent. Input never touches the sim directly: the app samples it once per tick, before
// scene.step(), so a recorded input stream replays exactly (same rule as the reference's flight-input golden).
// Keyboard: arrows or WASD fly box a in `flight`; C craters under box a; 1..6 pick a scene; H toggles the HUD;
// M toggles the seam marker. Gamepad (standard mapping): left stick or d-pad flies box a, A (button 0) craters.

export interface Intent { ix: number; iy: number; active: boolean }

const FLY: Record<string, [number, number]> = {
  ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, 1], ArrowDown: [0, -1],
  KeyA: [-1, 0], KeyD: [1, 0], KeyW: [0, 1], KeyS: [0, -1],
};

export class Input {
  held: Set<string> = new Set();
  presses: string[] = [];          // edge-triggered keys since the last drain (by KeyboardEvent.code)
  padCrater: boolean = false;
  touched: boolean = false;        // becomes true once a human flies box a; the flight golden no longer applies then

  attach(target: Window): void {
    target.addEventListener('keydown', (e: KeyboardEvent) => {
      if (FLY[e.code] || /^Digit[1-6]$/.test(e.code) || e.code === 'KeyC' || e.code === 'KeyH' || e.code === 'KeyM') e.preventDefault();
      if (!e.repeat) this.presses.push(e.code);
      this.held.add(e.code);
    });
    target.addEventListener('keyup', (e: KeyboardEvent) => { this.held.delete(e.code); });
    target.addEventListener('blur', () => { this.held.clear(); });
  }

  drainPresses(): string[] { const p = this.presses; this.presses = []; return p; }

  // Sampled once per tick.
  intent(): Intent {
    let ix = 0, iy = 0;
    for (const code of this.held) { const v = FLY[code]; if (v) { ix += v[0]; iy += v[1]; } }
    const pads = typeof navigator.getGamepads === 'function' ? navigator.getGamepads() : [];
    for (const p of pads) {
      if (!p || !p.connected) continue;
      const dead = (v: number): number => (v > -0.2 && v < 0.2 ? 0 : v);
      ix += dead(p.axes[0] || 0); iy -= dead(p.axes[1] || 0);
      if (p.buttons[14] && p.buttons[14].pressed) ix -= 1;
      if (p.buttons[15] && p.buttons[15].pressed) ix += 1;
      if (p.buttons[12] && p.buttons[12].pressed) iy += 1;
      if (p.buttons[13] && p.buttons[13].pressed) iy -= 1;
      const a = !!(p.buttons[0] && p.buttons[0].pressed);
      if (a && !this.padCrater) this.presses.push('KeyC');
      this.padCrater = a;
    }
    ix = ix < -1 ? -1 : ix > 1 ? 1 : ix;
    iy = iy < -1 ? -1 : iy > 1 ? 1 : iy;
    const active = ix !== 0 || iy !== 0;
    if (active) this.touched = true;
    return { ix, iy, active: this.touched };
  }
}
