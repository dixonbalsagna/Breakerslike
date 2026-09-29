// Small text HUD: fps, frame ms, scene, tick, live particles, sim hash status. H toggles it.
// The DOM text is refreshed at most 4 times a second so the HUD costs next to nothing in bench runs.
export interface HudData {
  scene: string; tick: number; live: number; hash: string; mode: string; extra?: string;
}

export class Hud {
  el: HTMLElement;
  visible: boolean = true;
  frames: number = 0;
  sumMs: number = 0;
  lastUpdate: number = 0;
  fps: number = 0;
  ms: number = 0;

  constructor(el: HTMLElement) { this.el = el; }

  toggle(): void { this.visible = !this.visible; this.el.style.display = this.visible ? '' : 'none'; }

  frame(now: number, dtMs: number, d: HudData): void {
    if (dtMs > 0) { this.frames++; this.sumMs += dtMs; }
    if (now - this.lastUpdate < 250 && this.lastUpdate !== 0) return;
    if (this.frames) { this.ms = this.sumMs / this.frames; this.fps = 1000 / this.ms; }
    this.frames = 0; this.sumMs = 0; this.lastUpdate = now;
    if (!this.visible) return;
    this.el.textContent =
      `${this.fps.toFixed(0)} fps  ${this.ms.toFixed(2)} ms  [${d.mode}]\n` +
      `scene ${d.scene}  tick ${d.tick}  particles ${d.live}\n` +
      `hash ${d.hash}` + (d.extra ? `\n${d.extra}` : '');
  }

  // Immediate refresh (screenshots render a single frame).
  now(d: HudData): void { this.lastUpdate = 0; this.frame(performance.now(), 0, d); }
}
