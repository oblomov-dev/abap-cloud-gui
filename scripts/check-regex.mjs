// Fails on regular expressions in src/, POSIX and PCRE alike. The POSIX
// engine is obsolete from 7.55 on - the extended check warns "The regex
// standard POSIX is deprecated" - and PCRE does not exist on 7.02, so the
// code uses no regex at all: FIND / CS / CN / CA, substring( ) and friends
// instead. abaplint has no rule for it.
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const patterns = [
  [/\bREGEX\b(?!\s*=)/i, "FIND / REPLACE ... REGEX"],
  [/\bPCRE\b(?!\s*=)/i, "FIND / REPLACE ... PCRE"],
  [/\bpcre\s*=/i, "pcre = in a built-in function (matches, find, replace, count, ...)"],
  [/\bregex\s*=/i, "regex = in a built-in function (matches, find, replace, count, ...)"],
  [/\bcl_abap_regex\b/i, "cl_abap_regex"],
  [/\bcl_abap_matcher\b/i, "cl_abap_matcher"],
];

function files(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? files(join(dir, e.name)) : e.name.endsWith(".abap") ? [join(dir, e.name)] : []);
}

// drop comments and the content of literals, so that only code is matched
function code(line) {
  if (line.startsWith("*")) return "";
  return line.replace(/'[^']*'|`[^`]*`|\|[^|]*\|/g, "''").replace(/".*$/, "");
}

let found = 0;
for (const file of files("src")) {
  readFileSync(file, "utf8").split(/\r?\n/).forEach((line, i) => {
    const text = code(line);
    for (const [re, what] of patterns) {
      if (re.test(text)) {
        console.log(`${file}:${i + 1}: ${what} - POSIX regex is deprecated, PCRE is not on 7.02: use string operations`);
        found++;
      }
    }
  });
}
if (found > 0) process.exit(1);
console.log("no regular expressions in src/");
