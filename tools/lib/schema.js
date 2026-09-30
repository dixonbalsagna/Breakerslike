'use strict';
// A small JSON Schema (draft 2020-12) validator: Node built-ins only, deterministic.
// It implements only the keywords listed in SUPPORTED. `checkSchema` rejects a schema that
// uses any other keyword, so a constraint can never be silently ignored.
//
//   const errors = validate(schema, data);  // [{pointer, rule, message}]
//   const problems = checkSchema(schema);   // [string]
//
// Rules are the keyword names ("type", "enum", "required", "additionalProperties", ...).
// `$ref` is "#", "#/$defs/name", or "other.schema.json#/$defs/name" (a sibling schema file, found through
// the `load(name)` callback). `format` is an annotation, not asserted.
// Note: additionalProperties and items see only the properties of their own schema object,
// as in 2020-12 without unevaluated*; schemas here list every property in the base object.

const ANNOTATIONS = new Set(['$schema', '$id', '$comment', 'title', 'description', 'examples', 'default', 'deprecated', 'format', '$defs']);
const APPLICATORS = new Set([
  'type', 'enum', 'const',
  'properties', 'required', 'additionalProperties', 'patternProperties', 'propertyNames', 'minProperties', 'maxProperties', 'dependentRequired',
  'items', 'prefixItems', 'minItems', 'maxItems', 'uniqueItems',
  'minimum', 'maximum', 'exclusiveMinimum', 'exclusiveMaximum', 'multipleOf',
  'minLength', 'maxLength', 'pattern',
  'allOf', 'anyOf', 'oneOf', 'not', 'if', 'then', 'else', '$ref',
]);
const SUPPORTED = new Set([...ANNOTATIONS, ...APPLICATORS]);

const TYPES = ['null', 'boolean', 'object', 'array', 'number', 'integer', 'string'];

function typeOf(v) {
  if (v === null) return 'null';
  if (Array.isArray(v)) return 'array';
  return typeof v; // boolean, number, string, object
}

function isType(v, t) {
  const actual = typeOf(v);
  if (t === 'integer') return actual === 'number' && Number.isInteger(v);
  return actual === t;
}

function canon(v) {
  if (Array.isArray(v)) return `[${v.map(canon).join(',')}]`;
  if (v && typeof v === 'object') return `{${Object.keys(v).sort().map((k) => `${JSON.stringify(k)}:${canon(v[k])}`).join(',')}}`;
  return JSON.stringify(v);
}

const show = (v) => {
  const s = JSON.stringify(v);
  return s === undefined ? String(v) : s.length > 60 ? `${s.slice(0, 57)}...` : s;
};

const escapeToken = (t) => String(t).replace(/~/g, '~0').replace(/\//g, '~1');

// Returns {node, root} (root is the schema document the node lives in, for nested refs) or undefined.
function resolveRef(root, ref, load) {
  const hash = ref.indexOf('#');
  if (hash < 0) return undefined;
  const file = ref.slice(0, hash);
  const frag = ref.slice(hash);
  if (file) {
    root = load ? load(file) : undefined;
    if (root === undefined) return undefined;
  }
  if (frag === '#') return { node: root, root };
  if (!frag.startsWith('#/')) return undefined;
  let node = root;
  for (const raw of frag.slice(2).split('/')) {
    const key = raw.replace(/~1/g, '/').replace(/~0/g, '~');
    if (node === null || typeof node !== 'object' || !(key in node)) return undefined;
    node = node[key];
  }
  return { node, root };
}

function checkSchema(schema, load, where = '#') {
  const problems = [];
  const walk = (s, path) => {
    if (typeof s === 'boolean') return;
    if (s === null || typeof s !== 'object' || Array.isArray(s)) {
      problems.push(`${path}: a schema must be an object or a boolean`);
      return;
    }
    for (const k of Object.keys(s)) {
      if (!SUPPORTED.has(k)) problems.push(`${path}: keyword "${k}" is not supported by tools/lib/schema.js`);
    }
    if ('type' in s) {
      const ts = Array.isArray(s.type) ? s.type : [s.type];
      for (const t of ts) if (!TYPES.includes(t)) problems.push(`${path}/type: unknown type ${show(t)}`);
    }
    if ('pattern' in s) {
      try { new RegExp(s.pattern, 'u'); } catch (e) { problems.push(`${path}/pattern: invalid regular expression (${e.message})`); }
    }
    for (const k of ['properties', 'patternProperties', '$defs']) {
      if (s[k] && typeof s[k] === 'object') {
        for (const [name, sub] of Object.entries(s[k])) {
          if (k === 'patternProperties') {
            try { new RegExp(name, 'u'); } catch (e) { problems.push(`${path}/${k}: invalid regular expression ${show(name)}`); }
          }
          walk(sub, `${path}/${k}/${escapeToken(name)}`);
        }
      }
    }
    for (const k of ['additionalProperties', 'items', 'propertyNames', 'not', 'if', 'then', 'else']) {
      if (k in s) walk(s[k], `${path}/${k}`);
    }
    for (const k of ['allOf', 'anyOf', 'oneOf', 'prefixItems']) {
      if (Array.isArray(s[k])) s[k].forEach((sub, n) => walk(sub, `${path}/${k}/${n}`));
      else if (k in s) problems.push(`${path}/${k}: must be an array`);
    }
    if ('$ref' in s && resolveRef(schema, s.$ref, load) === undefined) problems.push(`${path}/$ref: cannot resolve ${show(s.$ref)}`);
  };
  walk(schema, where);
  return problems;
}

function validate(schema, data, load) {
  const errors = [];
  const regexCache = new Map();
  const rx = (p) => {
    if (!regexCache.has(p)) regexCache.set(p, new RegExp(p, 'u'));
    return regexCache.get(p);
  };

  // Returns the errors of `data` against `s`, without touching the outer list, so that
  // if/not/anyOf/oneOf can test a subschema.
  const check = (s, v, ptr, root) => {
    const out = [];
    const add = (rule, message, at = ptr) => out.push({ pointer: at, rule, message });
    if (s === true) return out;
    if (s === false) {
      add('false', 'this property is not allowed here');
      return out;
    }

    if (s.$ref !== undefined) {
      const target = resolveRef(root, s.$ref, load);
      if (target === undefined) add('$ref', `cannot resolve ${s.$ref}`);
      else out.push(...check(target.node, v, ptr, target.root));
    }

    if (s.type !== undefined) {
      const ts = Array.isArray(s.type) ? s.type : [s.type];
      if (!ts.some((t) => isType(v, t))) add('type', `must be ${ts.join(' or ')} (got ${typeOf(v)})`);
    }
    if (s.enum !== undefined && !s.enum.some((e) => canon(e) === canon(v))) {
      add('enum', `must be one of ${s.enum.map(show).join(', ')} (got ${show(v)})`);
    }
    if (s.const !== undefined && canon(s.const) !== canon(v)) add('const', `must be ${show(s.const)} (got ${show(v)})`);

    const t = typeOf(v);
    if (t === 'number') {
      if (s.minimum !== undefined && v < s.minimum) add('minimum', `must be >= ${s.minimum} (got ${v})`);
      if (s.maximum !== undefined && v > s.maximum) add('maximum', `must be <= ${s.maximum} (got ${v})`);
      if (s.exclusiveMinimum !== undefined && v <= s.exclusiveMinimum) add('exclusiveMinimum', `must be > ${s.exclusiveMinimum} (got ${v})`);
      if (s.exclusiveMaximum !== undefined && v >= s.exclusiveMaximum) add('exclusiveMaximum', `must be < ${s.exclusiveMaximum} (got ${v})`);
      if (s.multipleOf !== undefined) {
        const q = v / s.multipleOf;
        if (Math.abs(q - Math.round(q)) > 1e-9) add('multipleOf', `must be a multiple of ${s.multipleOf} (got ${v})`);
      }
    }
    if (t === 'string') {
      const len = [...v].length;
      if (s.minLength !== undefined && len < s.minLength) add('minLength', `must have at least ${s.minLength} characters (got ${len})`);
      if (s.maxLength !== undefined && len > s.maxLength) add('maxLength', `must have at most ${s.maxLength} characters (got ${len})`);
      if (s.pattern !== undefined && !rx(s.pattern).test(v)) add('pattern', `must match /${s.pattern}/ (got ${show(v)})`);
    }
    if (t === 'array') {
      if (s.minItems !== undefined && v.length < s.minItems) add('minItems', `must have at least ${s.minItems} items (got ${v.length})`);
      if (s.maxItems !== undefined && v.length > s.maxItems) add('maxItems', `must have at most ${s.maxItems} items (got ${v.length})`);
      if (s.uniqueItems) {
        const seen = new Map();
        v.forEach((item, n) => {
          const key = canon(item);
          if (seen.has(key)) add('uniqueItems', `items ${seen.get(key)} and ${n} are identical`, `${ptr}/${n}`);
          else seen.set(key, n);
        });
      }
      const prefix = s.prefixItems || [];
      prefix.forEach((sub, n) => {
        if (n < v.length) out.push(...check(sub, v[n], `${ptr}/${n}`, root));
      });
      if (s.items !== undefined) {
        for (let n = prefix.length; n < v.length; n++) out.push(...check(s.items, v[n], `${ptr}/${n}`, root));
      }
    }
    if (t === 'object') {
      const keys = Object.keys(v);
      if (s.minProperties !== undefined && keys.length < s.minProperties) add('minProperties', `must have at least ${s.minProperties} properties (got ${keys.length})`);
      if (s.maxProperties !== undefined && keys.length > s.maxProperties) add('maxProperties', `must have at most ${s.maxProperties} properties (got ${keys.length})`);
      for (const k of s.required || []) if (!(k in v)) add('required', `missing required property "${k}"`);
      for (const [k, need] of Object.entries(s.dependentRequired || {})) {
        if (k in v) for (const n of need) if (!(n in v)) add('dependentRequired', `"${k}" requires "${n}"`);
      }
      const props = s.properties || {};
      const patterns = Object.keys(s.patternProperties || {});
      for (const k of keys) {
        const at = `${ptr}/${escapeToken(k)}`;
        let known = false;
        if (Object.prototype.hasOwnProperty.call(props, k)) {
          known = true;
          out.push(...check(props[k], v[k], at, root));
        }
        for (const p of patterns) {
          if (rx(p).test(k)) {
            known = true;
            out.push(...check(s.patternProperties[p], v[k], at, root));
          }
        }
        if (!known && s.additionalProperties !== undefined) {
          if (s.additionalProperties === false) add('additionalProperties', `unknown property "${k}"`, at);
          else out.push(...check(s.additionalProperties, v[k], at, root));
        }
        if (s.propertyNames !== undefined) {
          for (const e of check(s.propertyNames, k, at, root)) out.push({ ...e, rule: 'propertyNames', message: `property name ${show(k)}: ${e.message}` });
        }
      }
    }

    for (const sub of s.allOf || []) out.push(...check(sub, v, ptr, root));
    if (s.anyOf) {
      const results = s.anyOf.map((sub) => check(sub, v, ptr, root));
      if (!results.some((r) => r.length === 0)) add('anyOf', `matches none of ${s.anyOf.length} alternatives; closest: ${closest(results)}`);
    }
    if (s.oneOf) {
      const results = s.oneOf.map((sub) => check(sub, v, ptr, root));
      const hits = results.filter((r) => r.length === 0).length;
      if (hits === 0) add('oneOf', `matches none of ${s.oneOf.length} alternatives; closest: ${closest(results)}`);
      else if (hits > 1) add('oneOf', `matches ${hits} alternatives, must match exactly one`);
    }
    if (s.not !== undefined && check(s.not, v, ptr, root).length === 0) add('not', 'must not match the excluded schema');
    if (s.if !== undefined) {
      const passes = check(s.if, v, ptr, root).length === 0;
      if (passes && s.then !== undefined) out.push(...check(s.then, v, ptr, root));
      if (!passes && s.else !== undefined) out.push(...check(s.else, v, ptr, root));
    }
    return out;
  };

  const closest = (results) => {
    let best = results[0];
    for (const r of results) if (r.length < best.length) best = r;
    const e = best[0];
    return e ? `${e.pointer || '/'} [${e.rule}] ${e.message}` : 'none';
  };

  errors.push(...check(schema, data, '', schema));
  return errors;
}

module.exports = { validate, checkSchema, SUPPORTED, resolveRef };
