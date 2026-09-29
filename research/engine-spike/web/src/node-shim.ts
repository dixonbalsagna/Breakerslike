// Browser stand-ins for the node: built-ins that shared/test-ref.mjs imports at top level (node:crypto, node:fs,
// node:url, node:path). index.html's import map points all four specifiers here, only so the unchanged test-ref.mjs can
// be imported for its exported constants and scriptedInput(). Nothing here is used for hashing or file access in the
// browser: checks.ts hashes with WebCrypto. Anything test-ref.mjs would only call from its Node main block throws.
export function createHash(): never { throw new Error('node:crypto is not available in the browser (checks.ts uses WebCrypto)'); }
export function readFileSync(): never { throw new Error('node:fs is not available in the browser'); }
export function writeFileSync(): never { throw new Error('node:fs is not available in the browser'); }
export function existsSync(): boolean { return false; }
export function fileURLToPath(u: string | URL): string { return new URL(String(u)).pathname; }
export function dirname(p: string): string { const i = p.lastIndexOf('/'); return i > 0 ? p.slice(0, i) : '/'; }
export function join(...parts: string[]): string { return parts.join('/').replace(/\/{2,}/g, '/'); }
