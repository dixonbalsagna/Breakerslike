// Minimal WebGL2 helpers: compile and link with readable errors, and look up uniforms once.

export function compile(gl: WebGL2RenderingContext, type: number, src: string, label: string): WebGLShader {
  const s = gl.createShader(type);
  if (!s) throw new Error('createShader failed: ' + label);
  gl.shaderSource(s, src);
  gl.compileShader(s);
  if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
    const log = gl.getShaderInfoLog(s);
    gl.deleteShader(s);
    throw new Error(`${label} shader failed to compile:\n${log}`);
  }
  return s;
}

export interface Program {
  prog: WebGLProgram;
  u: Record<string, WebGLUniformLocation | null>;
}

export function program(gl: WebGL2RenderingContext, vs: string, fs: string, label: string, uniforms: string[]): Program {
  const p = gl.createProgram();
  if (!p) throw new Error('createProgram failed: ' + label);
  const v = compile(gl, gl.VERTEX_SHADER, vs, label + ' vertex');
  const f = compile(gl, gl.FRAGMENT_SHADER, fs, label + ' fragment');
  gl.attachShader(p, v);
  gl.attachShader(p, f);
  gl.linkProgram(p);
  if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error(`${label} program failed to link:\n${gl.getProgramInfoLog(p)}`);
  gl.deleteShader(v);
  gl.deleteShader(f);
  const u: Record<string, WebGLUniformLocation | null> = {};
  for (const name of uniforms) u[name] = gl.getUniformLocation(p, name);
  return { prog: p, u };
}

export function buffer(gl: WebGL2RenderingContext, target: number, data: BufferSource | number, usage: number): WebGLBuffer {
  const b = gl.createBuffer();
  if (!b) throw new Error('createBuffer failed');
  gl.bindBuffer(target, b);
  if (typeof data === 'number') gl.bufferData(target, data, usage);
  else gl.bufferData(target, data, usage);
  return b;
}

export function texture1D(gl: WebGL2RenderingContext, internal: number, format: number, type: number, width: number,
  data: ArrayBufferView): WebGLTexture {
  const t = gl.createTexture();
  if (!t) throw new Error('createTexture failed');
  gl.bindTexture(gl.TEXTURE_2D, t);
  gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
  gl.texImage2D(gl.TEXTURE_2D, 0, internal, width, 1, 0, format, type, data);
  // texelFetch ignores filtering, but the texture must still be complete: no mipmaps, NEAREST.
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  return t;
}

// GPU frame time with EXT_disjoint_timer_query_webgl2, when the browser exposes it. Results arrive late (in Chrome,
// only after the frame's task ends and the GPU process reports back). A frame is timed only when fewer than
// MAX_INFLIGHT queries are waiting, so at uncapped frame rates this is a SAMPLE of frames, not every frame: `skipped`
// counts the frames that were not timed. Each sample keeps the caller's tag (the bench uses the frame index) so GPU
// time can be matched with that frame's interval; a tag < 0 means "do not record".
export const MAX_INFLIGHT = 1024;
export class GpuTimer {
  gl: WebGL2RenderingContext;
  ext: any;
  pool: WebGLQuery[] = [];
  inflight: { q: WebGLQuery; tag: number }[] = [];
  samples: number[] = [];
  sampleTags: number[] = [];
  lastMs: number = 0;
  running: WebGLQuery | null = null;
  disjoints: number = 0;
  skipped: number = 0;
  constructor(gl: WebGL2RenderingContext) {
    this.gl = gl;
    this.ext = gl.getExtension('EXT_disjoint_timer_query_webgl2');
  }
  get available(): boolean { return !!this.ext; }
  begin(): void {
    if (!this.ext || this.running) return;
    if (this.inflight.length >= MAX_INFLIGHT) { this.skipped++; return; }
    const q = this.pool.pop() || this.gl.createQuery();
    if (!q) return;
    this.gl.beginQuery(this.ext.TIME_ELAPSED_EXT, q);
    this.running = q;
  }
  end(tag: number): void {
    if (!this.running) return;
    this.gl.endQuery(this.ext.TIME_ELAPSED_EXT);
    this.inflight.push({ q: this.running, tag });
    this.running = null;
  }
  poll(): void {
    if (!this.ext) return;
    const gl = this.gl;
    const disjoint = gl.getParameter(this.ext.GPU_DISJOINT_EXT);
    if (disjoint) this.disjoints++;
    while (this.inflight.length) {
      const it = this.inflight[0];
      if (!gl.getQueryParameter(it.q, gl.QUERY_RESULT_AVAILABLE)) break;
      const ns = gl.getQueryParameter(it.q, gl.QUERY_RESULT) as number;
      this.inflight.shift();
      this.pool.push(it.q);
      if (!disjoint) {
        this.lastMs = ns / 1e6;
        if (it.tag >= 0) { this.samples.push(this.lastMs); this.sampleTags.push(it.tag); }
      }
    }
  }
}
