// Every generated class must compile: the corpus is converted and linted in
// a scratch copy of this repository with its own abaplint configs, so that
// check_syntax resolves z2ui5_cl_cgui_report, the selection screen, the list
// and the ALV against the pinned abap2UI5 release.
//
// - v750 (abaplint.jsonc, every rule of the repository): no finding in a
//   generated class. The flight tables of the corpus exist on premise;
//   test/ddic has stubs.
// - ABAP Cloud (.github/abaplint/abap_cloud.jsonc): only findings about the
//   objects the migration report lists for their release state - the
//   unreleased tables - and none in the reports that use no such object.
//
// - v702 (.github/abaplint/abap_702.jsonc, the gate of check-702.sh): the
//   copy is downported with abaplint --fix, then checked with the 7.02 syntax
//   - no finding in a generated class.
// - the abap2UI5 linter (abap2ui5lint.jsonc, UI5 1.71) with --all-classes:
//   no finding in a generated class.
//
// Findings in src/ itself are the business of the repository's own gates
// (npm run check) - they are reported as a diagnostic, not as a failure, so
// that this test answers one question: do the generated classes compile
// against src/01 as it is.
//
// abaplint clones the dependencies of the configs, the 7.02 gate the popups
// (git, network).
import { test } from "node:test";
import assert from "node:assert/strict";
import { lint, lintUi5 } from "../lib/gate.mjs";
import { corpus, convertEntry, DDIC } from "./corpus.mjs";

const converted = corpus().map((e) => ({ e, ...convertEntry(e) })).filter((c) => c.result.ok);
const files = Object.assign({}, ...converted.map((c) => c.result.files));
const fmt = (list) => list.map((i) => `${i.file}:${i.row}:${i.col} [${i.key}] ${i.message}`).join("\n");

test("every report but the refused one converts", () => {
  assert.ok(converted.length >= 9, `${converted.length} converted`);
});

/** the findings of the repository's own sources - npm run check's business */
const repositoryFindings = (t, r) => {
  const outside = r.issues.filter((i) => !i.file.startsWith("src/r2c/"));
  if (outside.length) t.diagnostic(`${outside.length} finding(s) in the repository's own sources (npm run check), not in a generated class`);
};

test("abaplint v750 with the repository's rules: no finding in any generated class", { timeout: 300000 }, (t) => {
  const r = lint({ files, target: "v750", ddic: DDIC });
  repositoryFindings(t, r);
  assert.equal(r.generated.length, 0, fmt(r.generated));
});

test("abaplint ABAP Cloud: only the objects the migration report lists as not released", { timeout: 300000 }, (t) => {
  const r = lint({ files, target: "cloud" });
  repositoryFindings(t, r);
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

test("abaplint v702: every generated class downports and checks with the 7.02 syntax", { timeout: 600000 }, (t) => {
  const r = lint({ files, target: "v702", ddic: DDIC });
  repositoryFindings(t, r);
  assert.equal(r.generated.length, 0, fmt(r.generated));
});

test("abap2UI5 linter: no finding in any generated class", { timeout: 300000 }, () => {
  const r = lintUi5({ files });
  assert.ok(r.files >= converted.length, `${r.files} classes checked`);
  assert.equal(r.issues.length, 0, r.issues.map((i) => `${i.file}:${i.row}:${i.col} [${i.key}] ${i.message}`).join("\n"));
});
