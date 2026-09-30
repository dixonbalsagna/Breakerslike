'use strict';
// Strict JSON parser. Accepts exactly the JSON.parse grammar (RFC 8259) and additionally
// reports what JSON.parse hides: duplicate object keys, every number literal as written,
// and the line of every value (by JSON pointer). Deterministic, no dependencies.
//
//   const r = parse(text);
//   r.ok            true, or false with r.error = {message, line, col}
//   r.value         the parsed value (when ok)
//   r.line(pointer) 1-based line of the value at a JSON pointer ('' is the root)
//   r.numbers       [{pointer, literal, line}] every number literal in document order
//   r.duplicates    [{pointer, key, line}] a key repeated inside one object

function escapePointerToken(t) {
  return String(t).replace(/~/g, '~0').replace(/\//g, '~1');
}

function parse(text) {
  const lineStarts = [0];
  for (let i = 0; i < text.length; i++) if (text.charCodeAt(i) === 10) lineStarts.push(i + 1);
  const lineAt = (off) => {
    let lo = 0;
    let hi = lineStarts.length - 1;
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (lineStarts[mid] <= off) lo = mid;
      else hi = mid - 1;
    }
    return lo + 1;
  };
  const colAt = (off) => off - lineStarts[lineAt(off) - 1] + 1;

  const lines = new Map();
  const numbers = [];
  const duplicates = [];
  let i = 0;

  class Fail extends Error {
    constructor(message, off) {
      super(message);
      this.off = off;
    }
  }

  const ws = () => {
    while (i < text.length) {
      const c = text.charCodeAt(i);
      if (c === 32 || c === 9 || c === 10 || c === 13) i++;
      else break;
    }
  };

  const string = () => {
    const start = i;
    i++; // opening quote
    let out = '';
    for (;;) {
      if (i >= text.length) throw new Fail('unterminated string', start);
      const c = text[i];
      const code = text.charCodeAt(i);
      if (c === '"') {
        i++;
        return out;
      }
      if (code < 0x20) throw new Fail('control character in string (escape it)', i);
      if (c === '\\') {
        const e = text[i + 1];
        if (e === 'u') {
          const hex = text.slice(i + 2, i + 6);
          if (!/^[0-9a-fA-F]{4}$/.test(hex)) throw new Fail('bad \\u escape', i);
          out += String.fromCharCode(parseInt(hex, 16));
          i += 6;
        } else {
          const map = { '"': '"', '\\': '\\', '/': '/', b: '\b', f: '\f', n: '\n', r: '\r', t: '\t' };
          if (!(e in map)) throw new Fail(`bad escape \\${e === undefined ? '' : e}`, i);
          out += map[e];
          i += 2;
        }
      } else {
        out += c;
        i++;
      }
    }
  };

  const NUM = /-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/y;

  const value = (pointer) => {
    ws();
    if (i >= text.length) throw new Fail('unexpected end of input', i);
    lines.set(pointer, lineAt(i));
    const c = text[i];
    if (c === '{') {
      i++;
      const obj = {};
      const seen = new Set();
      ws();
      if (text[i] === '}') {
        i++;
        return obj;
      }
      for (;;) {
        ws();
        if (text[i] !== '"') throw new Fail('expected a quoted key', i);
        const keyOff = i;
        const key = string();
        const childPtr = `${pointer}/${escapePointerToken(key)}`;
        if (seen.has(key)) duplicates.push({ pointer: childPtr, key, line: lineAt(keyOff) });
        seen.add(key);
        ws();
        if (text[i] !== ':') throw new Fail("expected ':' after key", i);
        i++;
        const v = value(childPtr);
        Object.defineProperty(obj, key, { value: v, enumerable: true, writable: true, configurable: true });
        ws();
        if (text[i] === ',') {
          i++;
          continue;
        }
        if (text[i] === '}') {
          i++;
          return obj;
        }
        throw new Fail("expected ',' or '}'", i);
      }
    }
    if (c === '[') {
      i++;
      const arr = [];
      ws();
      if (text[i] === ']') {
        i++;
        return arr;
      }
      for (;;) {
        arr.push(value(`${pointer}/${arr.length}`));
        ws();
        if (text[i] === ',') {
          i++;
          continue;
        }
        if (text[i] === ']') {
          i++;
          return arr;
        }
        throw new Fail("expected ',' or ']'", i);
      }
    }
    if (c === '"') return string();
    if (text.startsWith('true', i)) return ((i += 4), true);
    if (text.startsWith('false', i)) return ((i += 5), false);
    if (text.startsWith('null', i)) return ((i += 4), null);
    NUM.lastIndex = i;
    const m = NUM.exec(text);
    if (m) {
      i += m[0].length;
      numbers.push({ pointer, literal: m[0], line: lineAt(i - m[0].length) });
      return Number(m[0]);
    }
    throw new Fail(`unexpected character ${JSON.stringify(c)}`, i);
  };

  try {
    if (text.charCodeAt(0) === 0xfeff) throw new Fail('file starts with a byte-order mark (save as UTF-8 without BOM)', 0);
    const v = value('');
    ws();
    if (i < text.length) throw new Fail('unexpected content after the JSON value', i);
    return { ok: true, value: v, line: (p) => lines.get(p), numbers, duplicates };
  } catch (e) {
    if (!(e instanceof Fail)) throw e;
    return { ok: false, error: { message: e.message, line: lineAt(e.off), col: colAt(e.off) }, line: () => undefined, numbers, duplicates };
  }
}

// Significant decimal digits of a number literal: the mantissa digits without leading or
// trailing zeros ("0.10" is 1, "293.66" is 5, "1200000" is 2).
function significantDigits(literal) {
  const mantissa = literal.replace(/^-/, '').split(/[eE]/)[0].replace('.', '');
  const trimmed = mantissa.replace(/^0+/, '').replace(/0+$/, '');
  return trimmed.length;
}

module.exports = { parse, significantDigits, escapePointerToken };
