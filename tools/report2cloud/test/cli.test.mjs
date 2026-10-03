// The command line: what it writes, its exit codes and its refusals.
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { CORPUS, HERE } from "./corpus.mjs";

const CLI = join(HERE, "..", "cli.mjs");
const run = (...args) => spawnSync(process.execPath, [CLI, ...args], { encoding: "utf8" });

test("converts a report: class, sidecar and migration report, named after the report", () => {
  const out = mkdtempSync(join(tmpdir(), "report2cloud-cli-"));
  try {
    const r = run(join(CORPUS, "zr2c_01_hello.prog.abap"), "--out", out);
    assert.equal(r.status, 0, r.stderr);
    for (const f of ["zcl_r2c_01_hello.clas.abap", "zcl_r2c_01_hello.clas.xml", "zcl_r2c_01_hello.migration.md"]) {
      assert.ok(existsSync(join(out, f)), f);
    }
    assert.match(readFileSync(join(out, "zcl_r2c_01_hello.clas.abap"), "utf8"), /^CLASS zcl_r2c_01_hello DEFINITION PUBLIC/);
    assert.match(readFileSync(join(out, "zcl_r2c_01_hello.migration.md"), "utf8"), /Text pool \| `.*zr2c_01_hello\.prog\.xml`/);
    assert.match(r.stdout, /zcl_r2c_01_hello: \d+ constructs mapped/);
  } finally {
    rmSync(out, { recursive: true, force: true });
  }
});

test("--class names the class, --texts takes the text pool from elsewhere", () => {
  const out = mkdtempSync(join(tmpdir(), "report2cloud-cli-"));
  try {
    const r = run(join(CORPUS, "zr2c_02_flights.prog.abap"), "--class", "ZCL_MY_FLIGHTS", "--out", out,
      "--texts", join(CORPUS, "zr2c_06_dynamic.prog.xml"));
    assert.equal(r.status, 0, r.stderr);
    const abap = readFileSync(join(out, "zcl_my_flights.clas.abap"), "utf8");
    assert.match(abap, /^CLASS zcl_my_flights DEFINITION PUBLIC/);
    assert.match(abap, /set_title\( `Dynamic Selection Screen` \)/);
    assert.match(readFileSync(join(out, "zcl_my_flights.clas.xml"), "utf8"), /<CLSNAME>ZCL_MY_FLIGHTS<\/CLSNAME>/);
  } finally {
    rmSync(out, { recursive: true, force: true });
  }
});

test("refuses with file:row:col, exit code 2 and no class - --partial writes the draft", () => {
  const out = mkdtempSync(join(tmpdir(), "report2cloud-cli-"));
  try {
    const file = join(CORPUS, "zr2c_10_refused.prog.abap");
    const r = run(file, "--out", out);
    assert.equal(r.status, 2);
    assert.ok(r.stderr.includes(`${file}:36:3 - CALL SCREEN - a dynpro has no counterpart`), r.stderr);
    assert.ok(!existsSync(join(out, "zcl_r2c_10_refused.clas.abap")));
    assert.match(readFileSync(join(out, "zcl_r2c_10_refused.migration.md"), "utf8"), /## Refused/);

    const p = run(file, "--out", out, "--partial");
    assert.equal(p.status, 2);
    assert.match(readFileSync(join(out, "zcl_r2c_10_refused.clas.abap"), "utf8"), /" report2cloud refused \(line 36\)/);
  } finally {
    rmSync(out, { recursive: true, force: true });
  }
});

test("usage: --help, a wrong option, a missing file", () => {
  assert.equal(run("--help").status, 0);
  assert.equal(run("x.prog.abap", "--nope").status, 1);
  assert.equal(run(join(CORPUS, "missing.prog.abap")).status, 1);
  assert.equal(run().status, 1);
});
