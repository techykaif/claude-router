#!/usr/bin/env node

function stripJsonc(source) {
    let out = '';
    let inString = false;
    let escaped = false;
    let changed = false;

    for (let i = 0; i < source.length; i += 1) {
        const ch = source[i];
        const next = source[i + 1];

        if (inString) {
            out += ch;
            if (escaped) escaped = false;
            else if (ch === '\\') escaped = true;
            else if (ch === '"') inString = false;
            continue;
        }

        if (ch === '"') {
            inString = true;
            out += ch;
            continue;
        }

        if (ch === '/' && next === '/') {
            changed = true;
            i += 2;
            while (i < source.length && source[i] !== '\n' && source[i] !== '\r') i += 1;
            if (i < source.length) out += source[i];
            continue;
        }

        if (ch === '/' && next === '*') {
            changed = true;
            i += 2;
            while (i < source.length && !(source[i] === '*' && source[i + 1] === '/')) {
                if (source[i] === '\n' || source[i] === '\r') out += source[i];
                i += 1;
            }
            if (i >= source.length) throw new Error('Unterminated comment');
            i += 1;
            continue;
        }

        out += ch;
    }

    // JSONC permits a trailing comma before } or ]. Remove only commas whose
    // next non-whitespace character closes an object or array.
    let normalized = '';
    inString = false;
    escaped = false;
    for (let i = 0; i < out.length; i += 1) {
        const ch = out[i];
        if (inString) {
            normalized += ch;
            if (escaped) escaped = false;
            else if (ch === '\\') escaped = true;
            else if (ch === '"') inString = false;
            continue;
        }
        if (ch === '"') {
            inString = true;
            normalized += ch;
            continue;
        }
        if (ch === ',') {
            let j = i + 1;
            while (j < out.length && /\s/.test(out[j])) j += 1;
            if (out[j] === '}' || out[j] === ']') {
                changed = true;
                continue;
            }
        }
        normalized += ch;
    }

    return { text: normalized, changed };
}

function parseJsonc(source) {
    const result = stripJsonc(source);
    return { value: JSON.parse(result.text), changed: result.changed };
}

module.exports = { parseJsonc, stripJsonc };
