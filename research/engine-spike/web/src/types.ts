// The parts of shared/sim-ref.mjs and shared/camera-ref.mjs that the web build reads. Type-only (erased at build).
// The renderer only ever reads these; input is the one writer (setInput, and the demo's C key crater), and it acts
// between ticks, never from the renderer.
export interface FighterView { x: number; y: number; vx: number; vy: number }
export interface BeamView { sx: number; sy: number; tx: number; ty: number; owner: number }
export interface SimEvent { kind: number; x: number; y: number; r: number }
export interface TerrainView {
  base: Float64Array;
  deform: Float64Array;
  version: number;
  crater(x: number, r: number, depth: number): void;
}
export interface SceneView {
  name: string;
  tick: number;
  terrain: TerrainView;
  a: FighterView;
  b: FighterView;
  beams: BeamView[];
  events: SimEvent[];
  step(): void;
  setInput?: (ix: number, iy: number) => void;
}
export interface CameraView {
  x: number;
  y: number;
  viewW: number;
  flips: number;
  flipping: boolean;
  step(a: FighterView, b: FighterView): void;
  reset(a: FighterView, b: FighterView): void;
  distance(): number;
  screenX(x: number): number;
  screenY(y: number): number;
}
