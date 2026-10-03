// The conversion of the corpus: snapshots of every generated file and of
// the migration report, the abapGit format of the files, and the mapping
// table construct by construct. UPDATE_SNAPSHOTS=1 writes the snapshots
// anew - review the diff before committing it.
import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { convert, defaultClassName } from "../lib/convert.mjs";
import { corpus, convertEntry, SNAPSHOTS } from "./corpus.mjs";

const UPDATE = process.env.UPDATE_SNAPSHOTS === "1";
const entries = corpus();
const converted = new Map(entries.map((e) => [e.name, convertEntry(e)]));
const classOf = (name) => {
  const { result } = converted.get(name);
  return result.draft[`${result.className}.clas.abap`];
};

test("the corpus has ten reports and more", () => {
  assert.ok(entries.length >= 10, `${entries.length} reports in test/corpus`);
});

for (const e of entries) {
  test(`snapshot: ${e.name}`, () => {
    const { result, report } = converted.get(e.name);
    const dir = join(SNAPSHOTS, e.name);
    const actual = { ...result.files, [`${result.className}.migration.md`]: report };
    if (UPDATE) {
      rmSync(dir, { recursive: true, force: true });
      mkdirSync(dir, { recursive: true });
      for (const [name, text] of Object.entries(actual)) writeFileSync(join(dir, name), text);
      return;
    }
    assert.ok(existsSync(dir), `no snapshot for ${e.name} - run UPDATE_SNAPSHOTS=1 npm run test:report2cloud`);
    assert.deepEqual(readdirSync(dir).sort(), Object.keys(actual).sort(), "the generated files");
    for (const [name, text] of Object.entries(actual)) {
      assert.equal(text, readFileSync(join(dir, name), "utf8"), `${e.name}/${name} differs from its snapshot`);
    }
  });

  test(`deterministic: ${e.name}`, () => {
    const again = convertEntry(e);
    assert.deepEqual(again.result.draft, converted.get(e.name).result.draft);
    assert.equal(again.report, converted.get(e.name).report);
  });

  test(`abapGit format: ${e.name}`, () => {
    const { result } = converted.get(e.name);
    for (const [name, text] of Object.entries(result.draft)) {
      if (name.endsWith(".xml")) {
        assert.ok(text.startsWith("﻿<?xml"), `${name}: the sidecar starts with the BOM`);
        assert.match(text, new RegExp(`<CLSNAME>${result.className.toUpperCase()}</CLSNAME>`));
        assert.ok(!/'/.test(text), `${name}: an apostrophe is written as &apos;`);
      } else {
        assert.ok(!text.startsWith("﻿"), `${name}: no BOM in ABAP source`);
      }
      assert.ok(!text.includes("\r"), `${name}: LF only`);
      assert.ok(!text.includes("\t"), `${name}: no tabs`);
      assert.ok(text.endsWith("\n") && !text.endsWith("\n\n"), `${name}: exactly one newline at the end`);
      text.split("\n").forEach((line, i) => {
        assert.ok(!/\s$/.test(line), `${name}:${i + 1}: trailing blank`);
        assert.ok(line.length <= 255, `${name}:${i + 1}: ${line.length} characters`);
      });
    }
  });
}

// ------------------------------------------------------------- mapping table

test("PARAMETERS: type, DEFAULT, OBLIGATORY, LOWER CASE, selection texts", () => {
  const abap = classOf("zr2c_01_hello");
  assert.match(abap, /DATA p_name {2}TYPE string\./);
  assert.match(abap, /p_times = 3\./);
  assert.match(abap, /screen->parameter\( val {8}= p_name\n {23}text {7}= `Your name`\n {23}obligatory = abap_true/);
  assert.match(abap, /set_title\( `Hello World` \)\./);
});

test("SELECT-OPTIONS FOR a TABLES field: range attribute, the TABLES work area dropped", () => {
  const { result } = converted.get("zr2c_02_flights");
  const abap = classOf("zr2c_02_flights");
  assert.match(abap, /DATA s_fldate TYPE RANGE OF sflight-fldate\./);
  assert.match(abap, /DATA p_carrid TYPE sflight-carrid\./, "LIKE a field of the dropped TABLES becomes TYPE");
  assert.ok(!/DATA sflight /.test(abap));
  assert.ok(result.mapped.some((m) => /^TABLES sflight/.test(m.classic) && /dropped/.test(m.target)));
});

test("the header line of a select-option becomes a work area", () => {
  const abap = classOf("zr2c_02_flights");
  assert.match(abap, /DATA ls_s_fldate LIKE LINE OF s_fldate\./);
  assert.match(abap, /ls_s_fldate-sign {3}= 'I'\./);
  assert.match(abap, /APPEND ls_s_fldate TO s_fldate\./);
});

test("BEGIN OF BLOCK WITH FRAME TITLE TEXT-001: the text of the text pool", () => {
  assert.match(classOf("zr2c_02_flights"), /screen->block_begin\( `Flights`/);
});

test("TOP-OF-PAGE, END-OF-SELECTION, HIDE and AT LINE-SELECTION", () => {
  const abap = classOf("zr2c_02_flights");
  assert.match(abap, /METHOD start_of_selection\.\n\n {4}top_of_page\( \)\./);
  assert.match(abap, /" END-OF-SELECTION\n {4}list\( \)->skip\( \)\./);
  assert.match(abap, /hide {4}= \|\{ gs_flight-carrid \}\\t\{ gs_flight-connid \}\\t\{ gs_flight-fldate \}\|/);
  assert.match(abap, /SPLIT hide AT \|\\t\| INTO TABLE DATA\(lt_hide\)\.\n {4}gs_flight-carrid = VALUE #\( lt_hide\[ 1 \] OPTIONAL \)\./);
});

test("ABAP SQL in strict mode: host variables escaped, the field list separated", () => {
  const abap = classOf("zr2c_02_flights");
  assert.match(abap, /SELECT carrid, connid, fldate, price, currency, seatsmax, seatsocc/);
  assert.match(abap, /INTO TABLE @gt_flight\n {6}UP TO @p_max ROWS\n {6}WHERE carrid = @p_carrid\n {8}AND fldate IN @s_fldate\./);
});

test("MESSAGE: literal, text symbol, message class short and long form, DISPLAY LIKE, sy-msgty", () => {
  const abap = classOf("zr2c_07_messages");
  assert.match(abap, /MESSAGE e010\(zr2c\) WITH p_type INTO DATA\(lv_message\)\.\n {6}message\( text = lv_message\n {15}type = `E` \)\.\n {6}RETURN\./);
  assert.match(abap, /MESSAGE ID 'ZR2C' TYPE 'E' NUMBER '011' WITH p_num 'is negative' INTO lv_message\./);
  assert.match(abap, /message\( 'A status message' \)\./);
  assert.match(abap, /message\( text = gv_text\n {17}type = `W` \)\./, "S DISPLAY LIKE E is a warning");
  assert.match(abap, /MESSAGE s013 WITH p_num INTO gv_text\./, "MESSAGE ... INTO stays");
  assert.match(abap, /type = sy-msgty \)\./);
  const { result } = converted.get("zr2c_07_messages");
  assert.ok(result.todos.some((t) => /TEXT-001 is not in the text pool/.test(t.message)));
  assert.ok(result.release.some((r) => r.kind === "message class" && r.name === "ZR2C"));
});

test("FORM / PERFORM: USING, CHANGING, TABLES STRUCTURE, VALUE( ), RANGES", () => {
  const abap = classOf("zr2c_03_forms");
  assert.match(abap, /METHODS build_items\n {6}IMPORTING\n {8}VALUE\(iv_count\) TYPE i\n {6}CHANGING\n {8}ct_items TYPE ty_items\./);
  assert.match(abap, /TYPES ty_t_gs_template LIKE STANDARD TABLE OF gs_template WITH DEFAULT KEY\./);
  assert.match(abap, /total\( EXPORTING\n {13}iv_discount = p_disc\n {11}CHANGING\n {13}it_items {4}= gt_items\n {13}cv_net {6}= gv_net \)\./);
  assert.match(abap, /write_item\( ls_item \)\./);
  assert.match(abap, /output\( \)\./);
  assert.match(abap, /DATA lr_big LIKE RANGE OF ls_item-quantity\./);
});

test("AT SELECTION-SCREEN ON field: CASE field, an E message returns", () => {
  assert.match(classOf("zr2c_03_forms"), /CASE field\.\n {6}WHEN `P_ITEMS`\./);
});

test("CL_SALV_TABLE: one alv( ) chain with title, column texts, hidden columns; TRY/CATCH cx_salv_* gone", () => {
  const abap = classOf("zr2c_04_salv");
  assert.match(abap, /alv\( gt_spfli\n {8}\)->set_title\( 'Flight connections'\n {8}\)->set_column_text\( name = `CITYFROM`\n {28}text = 'Departure city'\n {8}\)->set_column_hidden\( `MANDT`\n {8}\)->set_column_hidden\( `FLTIME` \)\./);
  assert.ok(!/salv/i.test(abap.replace(/report2cloud/g, "")), "no CL_SALV_* left");
  assert.ok(!/TRY\./.test(abap));
});

test("REUSE_ALV_GRID_DISPLAY: field catalog, title, USER_COMMAND callback as at_line_selection", () => {
  const abap = classOf("zr2c_05_reuse");
  assert.match(abap, /alv\( gt_scarr\n {8}\)->set_title\( 'Airlines'/);
  assert.match(abap, /set_column_text\( name = `CURRCODE`\n {28}text = 'Currency'/, "APPEND VALUE #( ) to the field catalog");
  assert.match(abap, /set_column_hidden\( `MANDT`/);
  assert.match(abap, /\)->set_line_selection\( \)\./);
  assert.match(abap, /METHOD at_line_selection\.[\s\S]*READ TABLE gt_scarr INTO gs_scarr INDEX row\./);
  assert.ok(!/slis_|fieldcat|build_fieldcat|sy-subrc <> 0/.test(abap), "field catalog, layout and the EXCEPTIONS check are gone");
});

test("dynamic selection screen: MODIF ID, USER-COMMAND, LOOP AT SCREEN, push button, F4", () => {
  const abap = classOf("zr2c_06_dynamic");
  assert.match(abap, /radiobutton\( val {10}= p_disp\n {24}text {9}= `Display material`\n {24}group {8}= `MODE`\n {24}user_command = `MODE`/);
  assert.match(abap, /checkbox\( val {10}= p_expert\n {21}text {9}= `Expert settings`\n {21}user_command = `EXPERT`/);
  assert.match(abap, /DATA\(lt_screen\) = screen->loop_at_screen\( \)\.\n {4}LOOP AT lt_screen INTO DATA\(ls_screen\)\./);
  assert.match(abap, /ls_screen-active = abap_false\./);
  assert.match(abap, /ls_screen-required = abap_true\./);
  assert.match(abap, /screen->modify_screen\( ls_screen \)\./);
  assert.match(abap, /\)->button\( text {2}= b_reset\n {19}event = `RESET`/);
  assert.match(abap, /parameter\( val        = p_plant\n {22}text       = `Plant`\n {22}value_help = abap_true/);
  assert.match(abap, /value_help_popup\( tab = gt_plant\n {26}col = `WERKS` \)\./);
  assert.match(abap, /METHOD at_user_command\.[\s\S]*at_selection_screen_ucomm\( ucomm \)\./);
  assert.match(abap, /METHOD at_selection_screen\.[\s\S]*at_selection_screen_ucomm\( `ONLI` \)\./);
  assert.match(abap, /METHOD at_selection_screen_ucomm\.\n\n {4}CASE ucomm\./, "sscrfields-ucomm became ucomm");
  assert.match(abap, /CLEAR: p_matnr, p_name, p_qty, p_plant, p_token\./);
});

test("list: FORMAT in a branch is a runtime color, AS CHECKBOX, AS ICON, NEW-PAGE, SKIP n", () => {
  const abap = classOf("zr2c_08_listformat");
  assert.match(abap, /DATA lv_color TYPE string\./);
  assert.match(abap, /lv_color = z2ui5_cl_cgui_list=>cs_color-positive\./);
  assert.match(abap, /list\( \)->write_as_checkbox\( gs_task-done \)\./);
  assert.match(abap, /list\( \)->write_as_icon\( `sap-icon:\/\/accept` \)\./);
  assert.match(abap, /list\( \)->new_page\( \)\./);
  assert.match(abap, /list\( \)->skip\( 2 \)\./);
  assert.match(abap, /color = z2ui5_cl_cgui_list=>cs_color-total/, "an explicit COLOR 3 wins over FORMAT");
});

test("local classes and interfaces: locals_def when the class is typed with them", () => {
  const { result } = converted.get("zr2c_09_localclass");
  assert.match(result.files["z2ui5_cl_cgui_r2c_09.clas.locals_def.abap"], /^INTERFACE lif_rounding\./);
  assert.match(result.files["z2ui5_cl_cgui_r2c_09.clas.locals_imp.abap"], /^CLASS lcl_calculator IMPLEMENTATION\./);
  assert.match(classOf("zr2c_09_localclass"), /DATA go_calc TYPE REF TO lif_rounding\./);
});

test("legacy statements: WRITE TO, global field symbols, SET PF-STATUS, AT USER-COMMAND", () => {
  const { result } = converted.get("zr2c_11_legacy");
  const abap = classOf("zr2c_11_legacy");
  assert.match(abap, /gv_text = \|\{ p_title \}\|\./);
  assert.match(abap, /METHOD start_of_selection\.\n\n {4}FIELD-SYMBOLS <gv_number> TYPE i\./);
  assert.match(abap, /s_range = VALUE #\( \( sign = `I` option = `BT` low = 1 high = 20 \) \)\./);
  assert.match(abap, /CASE ucomm\.\n {6}WHEN 'BACK'\.\n {8}leave_to_selection_screen\( \)\./);
  assert.ok(result.todos.some((t) => /SET PF-STATUS/.test(t.message)));
  assert.ok(!/PF-STATUS/.test(abap));
});

test("refusals: every statement without a counterpart, with file, row and column", () => {
  const { result } = converted.get("zr2c_10_refused");
  assert.equal(result.ok, false);
  assert.deepEqual(result.files, {}, "no class is written");
  assert.deepEqual(result.refusals.map((r) => `${r.row}:${r.col} ${r.message.split(" - ")[0]}`), [
    "26:3 ASSIGN of a field of another program ('(PROG)FIELD')",
    "28:3 CALL TRANSACTION",
    "30:3 SUBMIT",
    "32:3 EXEC SQL",
    "36:3 CALL SCREEN",
    "38:1 MODULE",
    "42:1 MODULE",
  ]);
  assert.match(result.draft["z2ui5_cl_cgui_r2c_10.clas.abap"], /" report2cloud refused \(line 36\): CALL SCREEN 100/);
});

// --------------------------------------------------- refusals, one at a time

const refusalOf = (source) => convert(source, { file: "zt.prog.abap", className: "zcl_t" }).refusals.map((r) => `${r.row}:${r.col} ${r.message}`);

test("refused: MESSAGE of a message class without MESSAGE-ID", () => {
  assert.match(refusalOf("REPORT zt.\nSTART-OF-SELECTION.\n  MESSAGE e001.\n")[0], /^3:3 MESSAGE without a message class/);
});

test("refused: LOOP AT SCREEN outside of AT SELECTION-SCREEN OUTPUT", () => {
  assert.match(refusalOf("REPORT zt.\nPARAMETERS p TYPE i.\nAT SELECTION-SCREEN.\n  LOOP AT SCREEN.\n  ENDLOOP.\n")[0], /^4:3 LOOP AT SCREEN outside of AT SELECTION-SCREEN OUTPUT/);
});

test("refused: a TABLES parameter used with its header line", () => {
  const r = refusalOf("REPORT zt.\nDATA gt TYPE STANDARD TABLE OF i.\nSTART-OF-SELECTION.\n  PERFORM f TABLES gt.\nFORM f TABLES tt STRUCTURE gt.\n  LOOP AT tt.\n  ENDLOOP.\nENDFORM.\n");
  assert.ok(r.some((x) => /^6:3 the TABLES parameter tt of FORM f is used with its header line/.test(x)), r.join("\n"));
});

test("refused: a table with header line, POPUP_TO_CONFIRM, PERFORM IN PROGRAM, FUNCTION KEY", () => {
  const r = refusalOf([
    "REPORT zt.",
    "DATA gt TYPE i OCCURS 0.",
    "SELECTION-SCREEN FUNCTION KEY 1.",
    "START-OF-SELECTION.",
    "  CALL FUNCTION 'POPUP_TO_CONFIRM' EXPORTING text_question = 'Sure?'.",
    "  PERFORM x IN PROGRAM zother.",
  ].join("\n"));
  assert.deepEqual(r.map((x) => x.split(" - ")[0]), [
    "2:1 a table with a header line (OCCURS / WITH HEADER LINE)",
    "3:1 SELECTION-SCREEN FUNCTION KEY",
    "5:3 CALL FUNCTION 'POPUP_TO_CONFIRM'",
    "6:3 PERFORM of a FORM of another program, dynamic or ON COMMIT",
  ]);
});

test("refused: TOP-OF-PAGE that does more than write a header", () => {
  assert.match(refusalOf("REPORT zt.\nDATA gv TYPE i.\nTOP-OF-PAGE.\n  gv = gv + 1.\n  WRITE gv.\n")[0], /^4:3 TOP-OF-PAGE with other statements/);
});

test("refused: a local class that reaches a global of the report", () => {
  const r = refusalOf("REPORT zt.\nDATA gv TYPE i.\nCLASS lcl DEFINITION.\n  PUBLIC SECTION.\n    CLASS-METHODS m.\nENDCLASS.\nCLASS lcl IMPLEMENTATION.\n  METHOD m.\n    gv = 1.\n  ENDMETHOD.\nENDCLASS.\n");
  assert.match(r[0], /^9:5 the local class uses gv, a global of the report/);
});

test("default class name", () => {
  assert.equal(defaultClassName("zflight_list"), "zcl_flight_list");
  assert.equal(defaultClassName("z_flights"), "zcl_flights");
  assert.equal(defaultClassName("yreport"), "ycl_report");
  assert.equal(defaultClassName("/abc/flights"), "/abc/cl_flights");
  assert.equal(defaultClassName("zvery_long_report_name_that_goes_on"), "zcl_very_long_report_name_that");
});
