// Every generated class must compile: the corpus is converted and linted in
// a scratch copy of this repository with its own abaplint configs, so that
// check_syntax resolves z2ui5_cl_cgui_report, the selection screen, the list
// and the ALV against the pinned abap2UI5 release.
//
// - v750 (abaplint.jsonc, every rule of the repository): no finding at all.
//   The flight tables of the corpus exist on premise; test/ddic has stubs.
// - ABAP Cloud (.github/abaplint/abap_cloud.jsonc): only findings about the
//   objects the migration report lists for their release state - the
//   unreleased tables - and none in the reports that use no such object.
//
// abaplint clones the dependencies of the configs (git, network).
import { test } from "node:test";
import assert from "node:assert/strict";
import { lint } from "../lib/gate.mjs";
import { corpus, convertEntry, DDIC } from "./corpus.mjs";

const converted = corpus().map((e) => ({ e, ...convertEntry(e) })).filter((c) => c.result.ok);
const files = Object.assign({}, ...converted.map((c) => c.result.files));
const fmt = (list) => list.map((i) => `${i.file}:${i.row}:${i.col} [${i.key}] ${i.message}`).join("\n");

test("every report but the refused one converts", () => {
  assert.ok(converted.length >= 9, `${converted.length} converted`);
});

test("abaplint v750 with the repository's rules: no finding in any generated class", { timeout: 300000 }, () => {
  const r = lint({ files, target: "v750", ddic: DDIC });
  assert.equal(r.issues.length, 0, fmt(r.issues));
});

test("abaplint ABAP Cloud: only the objects the migration report lists as not released", { timeout: 300000 }, () => {
  const r = lint({ files, target: "cloud" });
  const outside = r.issues.filter((i) => !i.file.startsWith("src/r2c/"));
  assert.equal(outside.length, 0, `findings outside the generated classes:\n${fmt(outside)}`);
  for (const c of converted) {
    const mine = r.generated.filter((i) => i.file.startsWith(`src/r2c/${c.result.className}.`));
    const listed = c.result.release.filter((x) => x.kind === "database table" || x.kind === "DDIC type").map((x) => x.name.toLowerCase());
    if (!listed.length) {
      assert.equal(mine.length, 0, `${c.e.name} uses no unreleased object and must be clean on ABAP Cloud:\n${fmt(mine)}`);
      continue;
    }
    const unexplained = mine.filter((i) => !listed.some((name) => i.message.toLowerCase().includes(name)));
    assert.equal(unexplained.length, 0, `${c.e.name}: findings the migration report does not explain:\n${fmt(unexplained)}`);
    assert.ok(mine.length > 0, `${c.e.name}: lists ${listed.join(", ")} as not released - abaplint must agree`);
  }
});
