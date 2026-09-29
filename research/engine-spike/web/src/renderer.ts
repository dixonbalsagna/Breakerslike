// WebGL2 renderer for the web spike. Reads sim and camera state, never writes it.
// Everything is drawn camera-relative (floating origin): the eye sits at render (0, cam.y, cam.distance()).
import { NC, COL, biomeAt, SEA_BASE, sdx } from '../../shared/sim-ref.mjs';
import * as M from './math.ts';
import { program, buffer, texture1D, GpuTimer } from './gl.ts';
import type { Program } from './gl.ts';
import * as S from './shaders.ts';
import { P_CAP, P_STRIDE } from './particles.ts';
import type { ParticleRing } from './particles.ts';
import type { SceneView, CameraView, TerrainView } from './types.ts';

// Biome colours for the terrain top (linear 0..1): ocean floor, plains, city, village, forest, desert, mountains.
const BIOME_RGB: number[][] = [
  [0.50, 0.46, 0.36], [0.42, 0.63, 0.29], [0.55, 0.55, 0.58], [0.60, 0.62, 0.36],
  [0.20, 0.45, 0.20], [0.88, 0.76, 0.50], [0.52, 0.47, 0.42],
];
const BOX_A = [0x3d / 255, 0x8f / 255, 0xdc / 255];     // #3d8fdc
const BOX_B = [0xa5 / 255, 0x2a / 255, 0x2a / 255];     // #a52a2a
// Beam colours per owner: 0 cyan-white, 1 orange-white.
const BEAM_RGB = [
  { glow: [0.10, 0.45, 0.80], core: [0.80, 1.00, 1.00], flare: [0.30, 0.75, 1.00] },
  { glow: [0.80, 0.34, 0.06], core: [1.00, 0.94, 0.78], flare: [1.00, 0.58, 0.18] },
];
const LIGHT = (() => { const v = [0.3, 0.6, 0.75], l = Math.hypot(v[0], v[1], v[2]); return [v[0] / l, v[1] / l, v[2] / l]; })();
const FX_FLOATS = 9, FX_MAX = 64;

// gpuTag: a tag stored with this frame's GPU timer sample (the bench passes the measured-frame index); -1 = not recorded.
export interface DrawOptions { nowTick: number; showSeam: boolean; gpuTag: number }

export class Renderer {
  gl: WebGL2RenderingContext;
  canvas: HTMLCanvasElement;
  terrainFs: Program; waterFs: Program; sky: Program; box: Program; fx: Program; part: Program;
  vaoGround: WebGLVertexArrayObject; vaoSky: WebGLVertexArrayObject; vaoBox: WebGLVertexArrayObject;
  vaoFx: WebGLVertexArrayObject; vaoPart: WebGLVertexArrayObject;
  groundIndexCount: number;
  texH: WebGLTexture; texB: WebGLTexture; texC: WebGLTexture;
  heights: Float32Array = new Float32Array(NC);
  lastTerrain: TerrainView | null = null;
  lastVersion: number = -1;
  boxInst: Float32Array = new Float32Array(12);
  boxInstBuf: WebGLBuffer;
  fxInst: Float32Array = new Float32Array(FX_MAX * FX_FLOATS);
  fxInstBuf: WebGLBuffer;
  fxCount: number = 0;
  partBuf: WebGLBuffer;
  vp: Float32Array = new Float32Array(16);
  timer: GpuTimer;
  uploads: number = 0;
  drawnParticles: number = 0;       // instances submitted last frame (live window, including dead ones it holds)

  constructor(canvas: HTMLCanvasElement, base: Float64Array, preserve: boolean = false) {
    this.canvas = canvas;
    const gl = canvas.getContext('webgl2', {
      antialias: false, alpha: false, depth: true, stencil: false, premultipliedAlpha: false,
      preserveDrawingBuffer: preserve, powerPreference: 'default',   // GPU choice is left to the browser flags (EP amendment b)
    });
    if (!gl) throw new Error('WebGL2 is not available');
    this.gl = gl;
    this.timer = new GpuTimer(gl);

    const U_GROUND = ['uVP', 'uCol0', 'uOffX', 'uWater', 'uH', 'uB', 'uC', 'uL'];
    this.terrainFs = program(gl, S.GROUND_VS, S.TERRAIN_FS, 'terrain', U_GROUND);
    this.waterFs = program(gl, S.GROUND_VS, S.WATER_FS, 'water', U_GROUND);
    this.sky = program(gl, S.SKY_VS, S.SKY_FS, 'sky', []);
    this.box = program(gl, S.BOX_VS, S.BOX_FS, 'box', ['uVP', 'uL']);
    this.fx = program(gl, S.FX_VS, S.FX_FS, 'fx', ['uVP']);
    this.part = program(gl, S.PART_VS, S.PART_FS, 'particles', ['uVP', 'uNow', 'uCamX']);

    // ---- static terrain/water grid: 4 vertices per column, (i, z, yMode, face)
    const G = M.GRID_COLS, verts = new Float32Array(G * 16);
    for (let i = 0; i < G; i++) {
      verts.set([i, M.Z_BACK, 0, 0, i, M.Z_FRONT, 0, 0, i, M.Z_FRONT, 0, 1, i, M.Z_FRONT, 1, 1], i * 16);
    }
    const idx = new Uint16Array((G - 1) * 12);
    for (let i = 0, k = 0; i < G - 1; i++) {
      const a = 4 * i, b = 4 * (i + 1);
      idx.set([a, a + 1, b + 1, a, b + 1, b, a + 2, a + 3, b + 3, a + 2, b + 3, b + 2], k);
      k += 12;
    }
    this.groundIndexCount = idx.length;
    this.vaoGround = gl.createVertexArray()!;
    gl.bindVertexArray(this.vaoGround);
    buffer(gl, gl.ARRAY_BUFFER, verts, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 4, gl.FLOAT, false, 16, 0);
    buffer(gl, gl.ELEMENT_ARRAY_BUFFER, idx, gl.STATIC_DRAW);
    gl.bindVertexArray(null);

    // ---- textures: dynamic heights (R32F), static base (R32F), static biome colour + sea flag (RGBA8)
    for (let i = 0; i < NC; i++) this.heights[i] = base[i];
    this.texH = texture1D(gl, gl.R32F, gl.RED, gl.FLOAT, NC, this.heights);
    this.texB = texture1D(gl, gl.R32F, gl.RED, gl.FLOAT, NC, Float32Array.from(base));
    const rgba = new Uint8Array(NC * 4);
    for (let i = 0; i < NC; i++) {
      const c = BIOME_RGB[biomeAt(i * COL)];
      const jitter = 1 + ((Math.imul(i + 1, 2654435761) >>> 24) / 255 - 0.5) * 0.10;   // a little per-column grain
      for (let k = 0; k < 3; k++) rgba[i * 4 + k] = Math.min(255, Math.round(c[k] * jitter * 255));
      rgba[i * 4 + 3] = base[i] < SEA_BASE ? 255 : 0;
    }
    this.texC = texture1D(gl, gl.RGBA8, gl.RGBA, gl.UNSIGNED_BYTE, NC, rgba);

    // ---- sky: no attributes
    this.vaoSky = gl.createVertexArray()!;

    // ---- boxes: unit cube (pos, normal) + 2 instances (offset, colour)
    const cube: number[] = [];
    const faces: number[][] = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]];
    for (const n of faces) {
      const u = n[0] !== 0 ? [0, 1, 0] : [1, 0, 0];
      const v = [n[1] * u[2] - n[2] * u[1], n[2] * u[0] - n[0] * u[2], n[0] * u[1] - n[1] * u[0]];
      const corner = (su: number, sv: number): number[] =>
        [0, 1, 2].map(k => 0.5 * n[k] + 0.5 * su * u[k] + 0.5 * sv * v[k]).concat(n);
      for (const [su, sv] of [[-1, -1], [1, -1], [1, 1], [-1, -1], [1, 1], [-1, 1]]) cube.push(...corner(su, sv));
    }
    this.vaoBox = gl.createVertexArray()!;
    gl.bindVertexArray(this.vaoBox);
    buffer(gl, gl.ARRAY_BUFFER, new Float32Array(cube), gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, false, 24, 0);
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 3, gl.FLOAT, false, 24, 12);
    this.boxInstBuf = buffer(gl, gl.ARRAY_BUFFER, this.boxInst.byteLength, gl.DYNAMIC_DRAW);
    gl.enableVertexAttribArray(2);
    gl.vertexAttribPointer(2, 3, gl.FLOAT, false, 24, 0);
    gl.vertexAttribDivisor(2, 1);
    gl.enableVertexAttribArray(3);
    gl.vertexAttribPointer(3, 3, gl.FLOAT, false, 24, 12);
    gl.vertexAttribDivisor(3, 1);
    gl.bindVertexArray(null);

    // ---- fx: quad corners (along 0..1, across -1..1) + instances (seg, colour, half width + kind)
    this.vaoFx = gl.createVertexArray()!;
    gl.bindVertexArray(this.vaoFx);
    buffer(gl, gl.ARRAY_BUFFER, new Float32Array([0, -1, 1, -1, 0, 1, 1, 1]), gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 8, 0);
    this.fxInstBuf = buffer(gl, gl.ARRAY_BUFFER, this.fxInst.byteLength, gl.DYNAMIC_DRAW);
    const fs = FX_FLOATS * 4;
    gl.enableVertexAttribArray(1); gl.vertexAttribPointer(1, 4, gl.FLOAT, false, fs, 0); gl.vertexAttribDivisor(1, 1);
    gl.enableVertexAttribArray(2); gl.vertexAttribPointer(2, 3, gl.FLOAT, false, fs, 16); gl.vertexAttribDivisor(2, 1);
    gl.enableVertexAttribArray(3); gl.vertexAttribPointer(3, 2, gl.FLOAT, false, fs, 28); gl.vertexAttribDivisor(3, 1);
    gl.bindVertexArray(null);

    // ---- particles: quad corners + the ring buffer (attribute offsets are re-pointed per draw range)
    this.vaoPart = gl.createVertexArray()!;
    gl.bindVertexArray(this.vaoPart);
    buffer(gl, gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 8, 0);
    this.partBuf = buffer(gl, gl.ARRAY_BUFFER, P_CAP * P_STRIDE, gl.DYNAMIC_DRAW);
    for (const loc of [1, 2, 3]) { gl.enableVertexAttribArray(loc); gl.vertexAttribDivisor(loc, 1); }
    this.pointParticles(0);
    gl.bindVertexArray(null);
  }

  // Re-upload the height texture when terrain.version moved. Returns the CPU time spent, or -1 if nothing changed.
  syncHeights(t: TerrainView): number {
    if (t === this.lastTerrain && t.version === this.lastVersion) return -1;
    const t0 = performance.now();
    const gl = this.gl, h = this.heights, b = t.base, d = t.deform;
    for (let i = 0; i < NC; i++) h[i] = b[i] + d[i];
    gl.bindTexture(gl.TEXTURE_2D, this.texH);
    gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, NC, 1, gl.RED, gl.FLOAT, h);
    this.lastTerrain = t;
    this.lastVersion = t.version;
    this.uploads++;
    return performance.now() - t0;
  }

  // Upload particles spawned since the last upload (one or two bufferSubData ranges). Returns CPU ms, or -1.
  syncParticles(ring: ParticleRing): number {
    const from = ring.uploaded, to = ring.seq;
    if (to === from) return -1;
    const t0 = performance.now();
    const gl = this.gl;
    gl.bindBuffer(gl.ARRAY_BUFFER, this.partBuf);
    const n = to - from;
    if (n >= P_CAP) gl.bufferSubData(gl.ARRAY_BUFFER, 0, ring.u8);
    else {
      const s = from % P_CAP, first = Math.min(n, P_CAP - s);
      gl.bufferSubData(gl.ARRAY_BUFFER, s * P_STRIDE, ring.u8, s * P_STRIDE, first * P_STRIDE);
      if (n > first) gl.bufferSubData(gl.ARRAY_BUFFER, 0, ring.u8, 0, (n - first) * P_STRIDE);
    }
    ring.uploaded = to;
    return performance.now() - t0;
  }

  private pointParticles(slot: number): void {
    const gl = this.gl, o = slot * P_STRIDE;
    gl.bindBuffer(gl.ARRAY_BUFFER, this.partBuf);
    gl.vertexAttribPointer(1, 4, gl.FLOAT, false, P_STRIDE, o);
    gl.vertexAttribPointer(2, 3, gl.FLOAT, false, P_STRIDE, o + 16);
    gl.vertexAttribPointer(3, 4, gl.UNSIGNED_BYTE, true, P_STRIDE, o + 28);
  }

  private pushFx(x0: number, y0: number, x1: number, y1: number, rgb: number[], hw: number, kind: number): void {
    if (this.fxCount >= FX_MAX) return;
    this.fxInst.set([x0, y0, x1, y1, rgb[0], rgb[1], rgb[2], hw, kind], this.fxCount * FX_FLOATS);
    this.fxCount++;
  }

  draw(scene: SceneView, cam: CameraView, ring: ParticleRing, o: DrawOptions): void {
    const gl = this.gl, W = gl.drawingBufferWidth, H = gl.drawingBufferHeight;
    const dist = cam.distance(), { near, far } = M.clipPlanes(dist);
    M.viewProj(this.vp, cam.y, dist, near, far);
    const anchor = M.gridAnchor(cam.x);

    this.timer.begin();
    gl.viewport(0, 0, W, H);
    gl.disable(gl.CULL_FACE);
    gl.depthMask(true);
    gl.clearColor(0, 0, 0, 1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    // sky
    gl.disable(gl.DEPTH_TEST);
    gl.disable(gl.BLEND);
    gl.useProgram(this.sky.prog);
    gl.bindVertexArray(this.vaoSky);
    gl.drawArrays(gl.TRIANGLES, 0, 3);

    // terrain (opaque)
    gl.enable(gl.DEPTH_TEST);
    gl.depthFunc(gl.LEQUAL);
    gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, this.texH);
    gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D, this.texB);
    gl.activeTexture(gl.TEXTURE2); gl.bindTexture(gl.TEXTURE_2D, this.texC);
    const ground = (p: Program, water: number): void => {
      gl.useProgram(p.prog);
      gl.uniformMatrix4fv(p.u.uVP, false, this.vp);
      gl.uniform1i(p.u.uCol0, anchor.col0);
      gl.uniform1f(p.u.uOffX, anchor.offsetX);
      gl.uniform1i(p.u.uWater, water);
      gl.uniform1i(p.u.uH, 0); gl.uniform1i(p.u.uB, 1); gl.uniform1i(p.u.uC, 2);
      gl.uniform3f(p.u.uL, LIGHT[0], LIGHT[1], LIGHT[2]);
      gl.bindVertexArray(this.vaoGround);
      gl.drawElements(gl.TRIANGLES, this.groundIndexCount, gl.UNSIGNED_SHORT, 0);
    };
    ground(this.terrainFs, 0);

    // fighters (opaque boxes)
    const bi = this.boxInst;
    bi.set([sdx(cam.x, scene.a.x), scene.a.y, 0, BOX_A[0], BOX_A[1], BOX_A[2],
      sdx(cam.x, scene.b.x), scene.b.y, 0, BOX_B[0], BOX_B[1], BOX_B[2]]);
    gl.useProgram(this.box.prog);
    gl.uniformMatrix4fv(this.box.u.uVP, false, this.vp);
    gl.uniform3f(this.box.u.uL, LIGHT[0], LIGHT[1], LIGHT[2]);
    gl.bindVertexArray(this.vaoBox);
    gl.bindBuffer(gl.ARRAY_BUFFER, this.boxInstBuf);
    gl.bufferSubData(gl.ARRAY_BUFFER, 0, bi);
    gl.drawArraysInstanced(gl.TRIANGLES, 0, 36, 2);

    // water (translucent, no depth writes)
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.depthMask(false);
    ground(this.waterFs, 1);

    // beams, flares, seam marker (additive)
    gl.blendFunc(gl.ONE, gl.ONE);
    this.fxCount = 0;
    for (const bm of scene.beams) {
      const [x0, x1] = M.beamRenderX(cam.x, bm.sx, bm.tx), c = BEAM_RGB[bm.owner ? 1 : 0];
      this.pushFx(x0, bm.sy, x1, bm.ty, c.glow, 22, 0);     // 44-unit glow
      this.pushFx(x0, bm.sy, x1, bm.ty, c.core, 7, 0);      // 14-unit core
      this.pushFx(x1, bm.ty, x1, bm.ty, c.flare, 60, 1);    // impact flare, radius 60
    }
    if (o.showSeam) {
      const sx = M.seamRenderX(cam.x), vh = cam.viewW / 16 * 9;
      this.pushFx(sx, cam.y + 0.30 * vh, sx, cam.y + 0.47 * vh, [0.9, 0.2, 0.9], cam.viewW * 0.0016, 0);
    }
    if (this.fxCount) {
      gl.useProgram(this.fx.prog);
      gl.uniformMatrix4fv(this.fx.u.uVP, false, this.vp);
      gl.bindVertexArray(this.vaoFx);
      gl.bindBuffer(gl.ARRAY_BUFFER, this.fxInstBuf);
      gl.bufferSubData(gl.ARRAY_BUFFER, 0, this.fxInst, 0, this.fxCount * FX_FLOATS);
      gl.drawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, this.fxCount);
    }

    // particles (additive): draw only the live window of the ring, in one or two ranges
    const w = ring.window(), count = Math.min(w.count, P_CAP);
    this.drawnParticles = count;
    if (count > 0) {
      gl.useProgram(this.part.prog);
      gl.uniformMatrix4fv(this.part.u.uVP, false, this.vp);
      gl.uniform1f(this.part.u.uNow, o.nowTick);
      gl.uniform1f(this.part.u.uCamX, cam.x);
      gl.bindVertexArray(this.vaoPart);
      const start = (ring.seq - count) % P_CAP, first = Math.min(count, P_CAP - start);
      this.pointParticles(start);
      gl.drawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, first);
      if (count > first) { this.pointParticles(0); gl.drawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, count - first); }
    }

    gl.bindVertexArray(null);
    gl.depthMask(true);
    gl.disable(gl.BLEND);
    this.timer.end(o.gpuTag);
  }

  // Read one pixel of the frame just drawn (same task, before compositing). (x, y) from the top left.
  readPixel(x: number, y: number): number[] {
    const gl = this.gl, out = new Uint8Array(4);
    gl.readPixels(Math.round(x), gl.drawingBufferHeight - 1 - Math.round(y), 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, out);
    return Array.from(out);
  }

  info(): { version: string; glsl: string; vendor: string; renderer: string; timerQuery: boolean } {
    const gl = this.gl, dbg = gl.getExtension('WEBGL_debug_renderer_info');
    return {
      version: String(gl.getParameter(gl.VERSION)),
      glsl: String(gl.getParameter(gl.SHADING_LANGUAGE_VERSION)),
      vendor: String(dbg ? gl.getParameter(dbg.UNMASKED_VENDOR_WEBGL) : gl.getParameter(gl.VENDOR)),
      renderer: String(dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER)),
      timerQuery: this.timer.available,
    };
  }
}
