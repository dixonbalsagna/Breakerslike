// GLSL ES 3.00 sources for the web spike. All positions arrive in camera-relative render space, except particles,
// whose spawn x is a world x that the vertex shader wraps against the camera (same formula as math.particleRelX).

export const SKY_VS = `#version 300 es
out vec2 vP;
void main() {
  vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2)) * 2.0 - 1.0;   // one big triangle
  vP = p;
  gl_Position = vec4(p, 0.0, 1.0);
}`;

// Vertical gradient over the view ray's elevation, same colours and falloff as the Godot build's sky.gdshader. The
// camera never pitches, so the ray is (ndc.x * tan(hfov/2), ndc.y * tan(vfov/2), -1) and the horizon is mid-screen.
export const SKY_FS = `#version 300 es
precision highp float;
in vec2 vP;
out vec4 o;
const float TAN_V = 0.36397023426620234;          // tan(20 deg)
const float ASPECT = 1.7777777777777777;
void main() {
  float y = normalize(vec3(vP.x * TAN_V * ASPECT, vP.y * TAN_V, -1.0)).y;
  vec3 top = vec3(0.16, 0.34, 0.66), horizon = vec3(0.70, 0.82, 0.93), below = vec3(0.55, 0.62, 0.70);
  vec3 c = y >= 0.0 ? mix(horizon, top, clamp(y / 0.36, 0.0, 1.0)) : mix(horizon, below, clamp(-y / 0.36, 0.0, 1.0));
  o = vec4(c, 1.0);
}`;

// Terrain and water share one static grid: 4 vertices per column (top back, top front, face top, face bottom).
// aV = (column i, z, yMode, face). Terrain: yMode 0 -> height, 1 -> -700. Water: yMode 0 -> 0, 1 -> min(height, 0).
export const GROUND_VS = `#version 300 es
precision highp float;
precision highp int;
precision highp sampler2D;
layout(location = 0) in vec4 aV;
uniform mat4 uVP;
uniform int uCol0;
uniform float uOffX;
uniform int uWater;
uniform sampler2D uH;      // R32F, base + deform, re-uploaded when terrain.version moves
uniform sampler2D uB;      // R32F, base (static)
uniform sampler2D uC;      // RGBA8, biome colour, a = sea flag (static)
out vec3 vCol;
out vec3 vN;
out float vScorch;
out float vFace;
out float vSea;
out float vY;
out float vH;
const int NC = 1200;
void main() {
  int i = int(aV.x);
  int col = (uCol0 + i) % NC;
  float h = texelFetch(uH, ivec2(col, 0), 0).r;
  vec4 c = texelFetch(uC, ivec2(col, 0), 0);
  float y;
  if (uWater == 0) y = aV.z > 0.5 ? -700.0 : h;
  else y = aV.z > 0.5 ? min(h, 0.0) : 0.0;
  if (aV.w < 0.5) {
    float hl = texelFetch(uH, ivec2((col + NC - 1) % NC, 0), 0).r;
    float hr = texelFetch(uH, ivec2((col + 1) % NC, 0), 0).r;
    vN = normalize(vec3(hl - hr, 16.0, 0.0));     // slope from neighbouring texels (2 columns = 16 units)
  } else {
    vN = vec3(0.0, 0.0, 1.0);
  }
  float base = texelFetch(uB, ivec2(col, 0), 0).r;
  vScorch = clamp((base - h) / 90.0, 0.0, 1.0);    // deform < 0 darkens
  vCol = c.rgb;
  vSea = c.a;
  vFace = aV.w;
  vY = y;
  vH = h;
  gl_Position = uVP * vec4(uOffX + aV.x * 8.0, y, aV.y, 1.0);
}`;

export const TERRAIN_FS = `#version 300 es
precision highp float;
in vec3 vCol;
in vec3 vN;
in float vScorch;
in float vFace;
in float vSea;
in float vY;
in float vH;
uniform vec3 uL;
out vec4 o;
void main() {
  vec3 n = normalize(vN);
  vec3 col = vCol;
  if (vFace > 0.5) {
    float d = clamp((vH - vY) / 520.0, 0.0, 1.0);         // cross-section: topsoil into rock
    col = mix(col * 0.72, vec3(0.30, 0.22, 0.17), clamp(d * 3.0, 0.0, 1.0));
    col = mix(col, vec3(0.20, 0.15, 0.13), d);
  } else if (vSea < 0.5) {
    col = mix(col, vec3(0.93, 0.95, 0.98), smoothstep(620.0, 780.0, vH));   // snow on high ground
  }
  col = mix(col, vec3(0.13, 0.10, 0.09), vScorch * 0.85);
  float diff = max(dot(n, uL), 0.0);
  o = vec4(col * (0.38 + 0.72 * diff), 1.0);
}`;

export const WATER_FS = `#version 300 es
precision highp float;
in vec3 vCol;
in vec3 vN;
in float vScorch;
in float vFace;
in float vSea;
in float vY;
in float vH;
out vec4 o;
void main() {
  if (vSea < 0.5) discard;
  if (vFace > 0.5) o = vec4(0.08, 0.30, 0.58, 0.62);
  else o = vec4(0.30, 0.58, 0.86, 0.50);
}`;

export const BOX_VS = `#version 300 es
precision highp float;
layout(location = 0) in vec3 aP;
layout(location = 1) in vec3 aN;
layout(location = 2) in vec3 aOff;
layout(location = 3) in vec3 aCol;
uniform mat4 uVP;
out vec3 vN;
out vec3 vCol;
void main() {
  vN = aN;
  vCol = aCol;
  gl_Position = uVP * vec4(aOff + aP * vec3(40.0, 60.0, 40.0), 1.0);
}`;

export const BOX_FS = `#version 300 es
precision highp float;
in vec3 vN;
in vec3 vCol;
uniform vec3 uL;
out vec4 o;
void main() {
  float diff = max(dot(normalize(vN), uL), 0.0);
  o = vec4(vCol * (0.42 + 0.68 * diff), 1.0);
}`;

// Beams, flares and the seam marker: instanced quads in the z = 0 plane, additive.
// aSeg = (x0, y0, x1, y1) render space; aK = (half width, kind 0 line | 1 flare).
export const FX_VS = `#version 300 es
precision highp float;
layout(location = 0) in vec2 aQ;
layout(location = 1) in vec4 aSeg;
layout(location = 2) in vec3 aCol;
layout(location = 3) in vec2 aK;
uniform mat4 uVP;
out vec2 vUV;
out vec3 vCol;
flat out float vKind;
flat out float vLen;
void main() {
  vec2 p;
  float hw = aK.x;
  if (aK.y < 0.5) {
    vec2 d = aSeg.zw - aSeg.xy;
    float L = length(d);
    vec2 t = L > 0.0 ? d / L : vec2(1.0, 0.0);
    vec2 n = vec2(-t.y, t.x);
    float s = mix(-hw, L + hw, aQ.x);               // extend by the half width for soft end caps
    p = aSeg.xy + t * s + n * (aQ.y * hw);
    vUV = vec2(aQ.y, s / hw);
    vLen = L / hw;
  } else {
    vec2 q = vec2(aQ.x * 2.0 - 1.0, aQ.y);
    p = aSeg.xy + q * hw;
    vUV = q;
    vLen = 0.0;
  }
  vKind = aK.y;
  vCol = aCol;
  gl_Position = uVP * vec4(p, 0.0, 1.0);
}`;

export const FX_FS = `#version 300 es
precision highp float;
in vec2 vUV;
in vec3 vCol;
flat in float vKind;
flat in float vLen;
out vec4 o;
void main() {
  float r2;
  if (vKind < 0.5) {
    float s = vUV.y;
    float e = s < 0.0 ? -s : (s > vLen ? s - vLen : 0.0);
    r2 = vUV.x * vUV.x + e * e;
  } else {
    r2 = dot(vUV, vUV);
  }
  if (r2 >= 1.0) discard;
  float k = 1.0 - r2;
  o = vec4(vCol * (k * k), 1.0);
}`;

// Particles: aQ is the quad corner, one instance per ring slot. Time is in ticks (exact integers in float32), so the
// discard test matches the CPU live count exactly.
export const PART_VS = `#version 300 es
precision highp float;
layout(location = 0) in vec2 aQ;
layout(location = 1) in vec4 aPV;     // spawn x (world), spawn y, vx, vy
layout(location = 2) in vec3 aT;      // spawn tick, life ticks, size
layout(location = 3) in vec4 aC;      // colour (normalised u8)
uniform mat4 uVP;
uniform float uNow;                   // current tick
uniform float uCamX;                  // camera world x
out vec2 vUV;
out vec3 vCol;
void main() {
  float age = uNow - aT.x;
  if (age < 0.0 || age >= aT.y) {     // dead or not born: collapse outside the clip volume
    gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
    vUV = vec2(0.0);
    vCol = vec3(0.0);
    return;
  }
  float s = age / 60.0;
  float x = aPV.x - uCamX + aPV.z * s;
  x -= 9600.0 * floor((x + 4800.0) / 9600.0);             // wrap into [-HALF, HALF) around the camera
  float y = aPV.y + aPV.w * s - 450.0 * s * s;             // gravity 900 u/s^2
  vec2 p = vec2(x, y) + aQ * (0.5 * aT.z);                 // size = quad side in world units
  vUV = aQ;
  vCol = aC.rgb * (1.0 - age / aT.y);
  gl_Position = uVP * vec4(p, 0.0, 1.0);
}`;

export const PART_FS = `#version 300 es
precision mediump float;
in vec2 vUV;
in vec3 vCol;
out vec4 o;
void main() {
  float r2 = dot(vUV, vUV);
  if (r2 >= 1.0) discard;
  o = vec4(vCol * min(1.0, 1.6 * (1.0 - r2)), 1.0);
}`;
