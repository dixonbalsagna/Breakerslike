// Pure render math for the web spike: grid anchoring, the perspective camera and the wrap-aware helpers the shaders
// mirror. No WebGL here, so Node unit tests (web/test/) can check it across the seam.
// Render space is camera-relative (floating origin): the camera sits at render x = 0 and every object is placed at
// sdx(cam.x, worldX). Nothing is ever placed at a raw world x.
import { W, HALF, NC, COL, sdx } from '../../shared/sim-ref.mjs';
import { CAM } from '../../shared/camera-ref.mjs';

export const GRID_COLS = 1100;          // vertex columns in the static terrain grid (SPEC: 1100 columns, 8 units apart)
export const GRID_HALF = 550;           // columns left of the camera column
export const Z_BACK = -400;             // terrain top surface depth span
export const Z_FRONT = 120;
export const Y_BOTTOM = -700;           // the front face runs down to here
export const TAN_HALF_VFOV = CAM.TAN_HALF_HFOV / CAM.ASPECT;   // tan(20 deg): vertical FOV 40 deg at 16:9

export type Mat4 = Float32Array | Float64Array;

export interface GridAnchor {
  col0: number;      // world column (0..NC-1) under grid vertex column 0
  offsetX: number;   // render x of grid vertex column 0
}

// The grid is static; only these two numbers move with the camera. Vertex column i sits at render x
// offsetX + i * COL and reads its height from texel (col0 + i) mod NC.
export function gridAnchor(camX: number): GridAnchor {
  const c = Math.floor(camX / COL) - GRID_HALF;          // unwrapped column index, may be negative
  return { col0: ((c % NC) + NC) % NC, offsetX: c * COL - camX };
}
export function gridColumn(a: GridAnchor, i: number): number { return (a.col0 + i) % NC; }
export function gridX(a: GridAnchor, i: number): number { return a.offsetX + i * COL; }

// Same as camera.distance(): the distance from the eye to the z = 0 plane that shows exactly viewW.
export function cameraDistance(viewW: number): number { return (viewW / 2) / CAM.TAN_HALF_HFOV; }

export function clipPlanes(dist: number): { near: number; far: number } {
  // Nothing is closer to the eye than the terrain front face (z = +120) and nothing is further than its back (-400).
  return { near: Math.max(1, dist - 800), far: dist + 1200 };
}

// Column-major view-projection for an eye at render (0, camY, dist) looking along -z, with vertical FOV 40 deg.
// The view is a pure translation, so VP = P * T(0, -camY, -dist) is written out directly.
export function viewProj(out: Mat4, camY: number, dist: number, near: number, far: number, aspect: number = CAM.ASPECT): Mat4 {
  const f = 1 / TAN_HALF_VFOV;
  const m10 = (far + near) / (near - far), m14 = (2 * far * near) / (near - far);
  out.fill(0);
  out[0] = f / aspect;
  out[5] = f;
  out[10] = m10;
  out[11] = -1;
  // column 3 = P * (0, -camY, -dist, 1)
  out[12] = 0;
  out[13] = f * -camY;
  out[14] = m10 * -dist + m14;
  out[15] = dist;
  return out;
}

// Project a render-space point with a column-major matrix to normalised screen coordinates: (0, 0) top left.
export function projectScreen(m: Mat4, x: number, y: number, z: number): [number, number] {
  const cx = m[0] * x + m[4] * y + m[8] * z + m[12];
  const cy = m[1] * x + m[5] * y + m[9] * z + m[13];
  const cw = m[3] * x + m[7] * y + m[11] * z + m[15];
  return [0.5 + 0.5 * (cx / cw), 0.5 - 0.5 * (cy / cw)];
}

// CPU mirror of the particle vertex shader's x: ballistic x relative to the camera, wrapped into [-HALF, HALF).
export function particleRelX(spawnX: number, camX: number, vx: number, ageSec: number): number {
  const r = spawnX - camX + vx * ageSec;
  return r - W * Math.floor((r + HALF) / W);
}

// Beam endpoints in render space. The target is reached along the beam's own short arc from its source, so a beam
// that straddles the camera's antipode never splits in two.
export function beamRenderX(camX: number, sx: number, tx: number): [number, number] {
  const x0 = sdx(camX, sx);
  return [x0, x0 + sdx(sx, tx)];
}

// Seam position in render space (world x = 0).
export function seamRenderX(camX: number): number { return sdx(camX, 0); }
