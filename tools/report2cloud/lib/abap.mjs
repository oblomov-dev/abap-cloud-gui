// Helpers over the @abaplint/core syntax tree: node kinds, tokens, and the
// renderer that writes a statement back as source - with the spacing and
// line breaks it had, and single tokens replaced where the conversion
// rewrites them (a TEXT-001, a sy-ucomm, a screen-active).
import * as abaplint from "@abaplint/core";

export { abaplint };

export const isToken = (n) => n instanceof abaplint.Nodes.TokenNode || n instanceof abaplint.Nodes.TokenNodeRegex;
export const kind = (n) => n.get().constructor.name;
export const lc = (s) => String(s).toLowerCase();
export const uc = (s) => String(s).toUpperCase();
export const key = (tok) => `${tok.getRow()}:${tok.getCol()}`;

/** the direct child expressions of kind k */
export const children = (n, k) => n.getChildren().filter((c) => !isToken(c) && (!k || kind(c) === k));
export const child = (n, k) => children(n, k)[0];

/** every expression below n of kind k, depth first */
export function findAll(n, k, out = []) {
  for (const c of n.getChildren()) {
    if (isToken(c)) continue;
    if (kind(c) === k) out.push(c);
    findAll(c, k, out);
  }
  return out;
}

/** the upper case words of the tokens directly under a statement - what
 *  tells PARAMETERS ... AS CHECKBOX from PARAMETERS ... TYPE i */
export const words = (n) => n.getChildren().filter(isToken).map((t) => uc(t.get().getStr())).filter((w) => w !== "." && w !== ",");

/** true when the word list holds the words of seq in a row */
export function hasSeq(list, ...seq) {
  for (let i = 0; i + seq.length <= list.length; i++) {
    if (seq.every((w, j) => list[i + j] === w)) return true;
  }
  return false;
}

/** the expression right after the token word in the children of n */
export function after(n, word, k) {
  const ch = n.getChildren();
  for (let i = 0; i < ch.length - 1; i++) {
    if (isToken(ch[i]) && uc(ch[i].get().getStr()) === word) {
      for (let j = i + 1; j < ch.length; j++) {
        if (isToken(ch[j])) {
          if (!k) return ch[j];
          continue;
        }
        if (!k || kind(ch[j]) === k) return ch[j];
        return undefined;
      }
    }
  }
  return undefined;
}

/** a backquote literal, the way the generated code writes texts */
export const literal = (s) => "`" + String(s).replace(/`/g, "``") + "`";

/** the text of a character or backquote literal token, unquoted */
export function unquote(s) {
  if (s.startsWith("`")) return s.slice(1, -1).replace(/``/g, "`");
  if (s.startsWith("'")) return s.slice(1, s.lastIndexOf("'")).replace(/''/g, "'");
  return s;
}

/**
 * The tokens as source text. Tokens on one row keep their distance, a
 * token on a new row starts a new line indented by its distance from the
 * first token (the caller places the first line). `overrides` maps a token
 * key to its replacement, null drops the token. In a chained statement the
 * part after the colon follows the shared prefix with one blank.
 */
export function renderTokens(tokens, overrides = new Map(), colon = undefined) {
  let out = "";
  let prev;
  let refCol = tokens.length ? tokens[0].getCol() : 1;
  let lineStart = 0;
  for (const tok of tokens) {
    const k = key(tok);
    const repl = overrides.has(k) ? overrides.get(k) : tok.getStr();
    const crossesColon = colon && prev && before(prev, colon) && !before(tok, colon);
    if (prev === undefined) {
      out += repl ?? "";
    } else if (crossesColon) {
      if (repl !== null) {
        out += " ";
        refCol = tok.getCol() - (out.length - lineStart);
        out += repl;
      }
    } else if (tok.getRow() === prev.getRow()) {
      const gap = tok.getCol() - (prev.getCol() + prev.getStr().length);
      if (repl !== null) out += " ".repeat(Math.max(gap, 0)) + repl;
    } else if (repl !== null) {
      out += "\n";
      lineStart = out.length;
      out += " ".repeat(Math.max(tok.getCol() - refCol, 2)) + repl;
    }
    prev = tok;
  }
  return out;
}

const before = (a, b) => a.getRow() < b.getRow() || (a.getRow() === b.getRow() && a.getCol() < b.getCol());

/** a statement without its closing period or comma */
export function stmtTokens(s) {
  const toks = s.getTokens();
  const last = toks[toks.length - 1];
  if (last && (last.getStr() === "." || last.getStr() === ",")) return toks.slice(0, -1);
  return toks;
}

/** the tokens of a node, rendered */
export const nodeText = (n, overrides) => renderTokens(isToken(n) ? [n.get()] : n.getTokens(), overrides);

/** the tokens of a chained statement after its colon - or after the first
 *  `skip` tokens of a statement that is not chained */
export function partTokens(s, skip = 1) {
  const toks = stmtTokens(s);
  const colon = s.getColon();
  if (!colon) return toks.slice(skip);
  return toks.filter((t) => !before(t, colon));
}
