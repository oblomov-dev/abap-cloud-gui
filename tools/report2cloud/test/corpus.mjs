// The test corpus: classic reports in corpus/, each with an optional
// .prog.xml text pool. A report zr2c_NN_name converts into the class
// z2ui5_cl_cgui_r2c_NN - a name the repository's object_naming rule
// accepts, so the gate test lints it with the repository's config as is.
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { convert } from "../lib/convert.mjs";
import { parseTextpool } from "../lib/textpool.mjs";
import { migrationReport } from "../lib/report.mjs";

export const HERE = dirname(fileURLToPath(import.meta.url));
export const CORPUS = join(HERE, "corpus");
export const SNAPSHOTS = join(HERE, "snapshots");
export const DDIC = join(HERE, "ddic");

export function corpus() {
  return readdirSync(CORPUS).filter((f) => f.endsWith(".prog.abap")).sort().map((file) => {
    const name = file.replace(/\.prog\.abap$/, "");
    const xml = join(CORPUS, `${name}.prog.xml`);
    return {
      file,
      name,
      className: `z2ui5_cl_cgui_r2c_${name.slice(5, 7)}`,
      source: readFileSync(join(CORPUS, file), "utf8"),
      texts: existsSync(xml) ? `${name}.prog.xml` : undefined,
      textpool: existsSync(xml) ? parseTextpool(readFileSync(xml, "utf8")) : undefined,
    };
  });
}

/** the conversion of a corpus report, and its migration report */
export function convertEntry(entry) {
  const result = convert(entry.source, { file: entry.file, className: entry.className, programName: entry.name, textpool: entry.textpool });
  const report = migrationReport(result, { source: entry.file, texts: entry.texts });
  return { result, report };
}
