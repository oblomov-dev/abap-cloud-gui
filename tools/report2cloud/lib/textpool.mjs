// The text pool of a report, as abapGit serializes it into <name>.prog.xml:
// text symbols (ID I, TEXT-001), selection texts (ID S, keyed by the field
// name) and the title (ID R). The source alone does not carry them, so a
// report converted without its .prog.xml gets placeholder texts and a TODO
// for each one.
//
// A selection text is stored with an 8 character prefix: blanks, or "D" and
// blanks when the text is taken from the DDIC - then there is no text of its
// own, and the selection screen shows the DDIC label as well.

const decode = (s) => s
  .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"')
  .replace(/&apos;/g, "'").replace(/&amp;/g, "&");

const tag = (item, name) => {
  const m = new RegExp(`<${name}>([\\s\\S]*?)</${name}>`).exec(item);
  return m ? decode(m[1]) : "";
};

/** { title, symbols: Map("001" -> text), selection: Map("P_CARR" -> text | null) }
 *  - null for a selection text taken from the DDIC. */
export function parseTextpool(xml) {
  const pool = { title: "", symbols: new Map(), selection: new Map() };
  if (!xml) return pool;
  const tpool = /<TPOOL>([\s\S]*?)<\/TPOOL>/.exec(xml);
  if (!tpool) return pool;
  for (const m of tpool[1].matchAll(/<item>([\s\S]*?)<\/item>/g)) {
    const id = tag(m[1], "ID");
    const key = tag(m[1], "KEY").trim().toUpperCase();
    const entry = tag(m[1], "ENTRY");
    if (id === "R") pool.title = entry.trim();
    else if (id === "I") pool.symbols.set(key, entry.replace(/\s+$/, ""));
    else if (id === "S") {
      const ddic = entry.startsWith("D") && entry.slice(8).trim() === ".";
      pool.selection.set(key, ddic ? null : entry.slice(8).trim() || null);
    }
  }
  return pool;
}
