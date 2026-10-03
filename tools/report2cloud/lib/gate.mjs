// The abaplint gates for generated classes. A generated class is only worth
// something if it compiles against this repository and the abap2UI5 release
// it is pinned to, so it is linted the way src/ is: copied into a scratch copy
// of the repository (src/ plus a package of its own, src/r2c), with the
// repository's own abaplint config as the base - abaplint.jsonc for v750, and
// .github/abaplint/abap_cloud.jsonc for ABAP Cloud. check_syntax then
// resolves z2ui5_cl_cgui_report, the selection screen, the list and the ALV
// exactly as it does for the samples.
//
// Two adjustments, both explicit parameters:
// - `ddic`: a folder of abapGit DDIC objects (TABL, DTEL, ...) added as a
//   dependency - the tests use stubs of the flight tables, which exist on
//   premise but are part of neither dependency. Without it a SELECT on SFLIGHT
//   is an unknown table, which is exactly what the cloud run is for.
// - `naming`: the repository's object_naming rule demands Z2UI5_CL_CGUI_*;
//   a user's class is named after the user's namespace, so the CLI drops the
//   rule. The tests keep it and name their classes accordingly.
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

export const REPO = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");

export const TARGETS = {
  v750: "abaplint.jsonc",
  cloud: ".github/abaplint/abap_cloud.jsonc",
};

/** JSON with comments, as the abaplint configs are written - comments and
 *  trailing commas are dropped outside of strings only. */
export function parseJsonc(text) {
  let out = "";
  let i = 0;
  while (i < text.length) {
    const c = text[i];
    if (c === '"') {
      let j = i + 1;
      while (j < text.length && text[j] !== '"') j += text[j] === "\\" ? 2 : 1;
      out += text.slice(i, j + 1);
      i = j + 1;
    } else if (c === "/" && text[i + 1] === "/") {
      while (i < text.length && text[i] !== "\n") i++;
    } else if (c === "/" && text[i + 1] === "*") {
      i = text.indexOf("*/", i + 2) + 2;
    } else {
      out += c;
      i++;
    }
  }
  return JSON.parse(out.replace(/,(\s*[}\]])/g, "$1"));
}

/** The config of a target, rebased onto a scratch copy whose root holds it. */
export function gateConfig(target, { ddic = false, naming = true } = {}) {
  const config = parseJsonc(readFileSync(join(REPO, TARGETS[target]), "utf8"));
  config.global.files = "/src/**/*.*";
  if (ddic) config.dependencies.push({ folder: "/ddic", files: "/**/*.*" });
  if (!naming) delete config.rules.object_naming;
  return config;
}

const PACKAGE = `﻿<?xml version="1.0" encoding="utf-8"?>
<abapGit version="v1.0.0" serializer="LCL_OBJECT_DEVC" serializer_version="v1.0.0">
 <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
  <asx:values>
   <DEVC>
    <CTEXT>report2cloud - generated</CTEXT>
   </DEVC>
  </asx:values>
 </asx:abap>
</abapGit>
`;

/**
 * Lint generated files in a scratch copy of the repository.
 *
 *   files   { "zcl_x.clas.abap": text, "zcl_x.clas.xml": text, ... }
 *   target  "v750" | "cloud"
 *   ddic    folder of DDIC stubs, added as a dependency (optional)
 *   naming  keep the repository's object_naming rule (default true)
 *
 * Returns { issues, generated }: every issue abaplint reports, and the ones
 * in the generated files, as { file, row, col, key, message }.
 */
export function lint({ files, target, ddic, naming = true, keep = false }) {
  const work = mkdtempSync(join(tmpdir(), `report2cloud-${target}-`));
  try {
    cpSync(join(REPO, "src"), join(work, "src"), { recursive: true });
    mkdirSync(join(work, "src", "r2c"));
    writeFileSync(join(work, "src", "r2c", "package.devc.xml"), PACKAGE);
    for (const [name, text] of Object.entries(files)) writeFileSync(join(work, "src", "r2c", name), text);
    if (ddic) cpSync(ddic, join(work, "ddic"), { recursive: true });
    writeFileSync(join(work, "abaplint.json"), JSON.stringify(gateConfig(target, { ddic: !!ddic, naming }), null, 2));

    const cli = join(REPO, "node_modules", "@abaplint", "cli", "abaplint");
    const run = spawnSync(process.execPath, [cli, "abaplint.json", "-f", "json"], {
      cwd: work, encoding: "utf8", maxBuffer: 64 * 1024 * 1024,
    });
    const at = run.stdout.indexOf("[");
    if (at < 0) {
      throw new Error(`abaplint (${target}) produced no result:\n${run.stdout}\n${run.stderr}`);
    }
    const issues = JSON.parse(run.stdout.slice(at)).map((i) => ({
      file: i.file.replace(/^.*?src\//, "src/"),
      row: i.start.row,
      col: i.start.col,
      key: i.key,
      message: i.description,
    }));
    return { issues, generated: issues.filter((i) => i.file.startsWith("src/r2c/")), work: keep ? work : undefined };
  } finally {
    if (!keep) rmSync(work, { recursive: true, force: true });
  }
}
