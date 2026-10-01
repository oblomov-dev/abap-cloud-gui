# AGENTS.md — abap-cloud-gui

Single source of truth for agents working on this repository.

## What it is

An addon for [abap2UI5](https://github.com/abap2UI5/abap2UI5) that lets an app
be written like a classic ABAP report: selection screen, event blocks, `WRITE`
list, ALV grid, messages. Language of code, comments, commits and docs:
**English**.

## Layout

| Path | Content |
|---|---|
| `src/01` | the framework: `z2ui5_cl_cgui_report` (report runtime), `_selscreen`, `_list`, `_alv`, `_context` (RTTI and conversion helpers), `z2ui5_cx_cgui_error` |
| `src/02` | samples `z2ui5_cl_cgui_sample_01` … `_07` |
| `.github/abaplint` | the Cloud and 7.02 gate configs; `abaplint.jsonc` at the root is the v750 inner loop |

Naming: every class is `Z2UI5_CL_CGUI_*` / `Z2UI5_CX_CGUI_*` (abaplint
`object_naming`). Only `CLAS` and `DEVC` objects — no dictionary objects.

## Dependencies

- abap2UI5 — only its public API: `z2ui5_if_app`, `z2ui5_if_client`,
  `z2ui5_cl_ui5_view_builder`. Never the frozen `z2ui5_cl_xml_view` or
  anything under its `src/99`, never core internals such as
  `z2ui5_cl_ui5_util_context` (copy a helper into `z2ui5_cl_cgui_context`
  instead).
- [abap2UI5-addons/popups](https://github.com/abap2UI5-addons/popups) —
  `z2ui5_cl_popup_get_range`, `_to_confirm`, `_to_select`.

## Targets

ABAP Cloud, Standard ABAP and NW 7.02. Write 7.50 syntax that downports;
check with `npm run lint`, `npm run check:cloud`, `npm run check:702`. UI5 1.71
is the floor — `npm run check:abap2ui5` (the abap2UI5-linter).

## Rules learned the hard way

- **No PRIVATE instance attributes on an app class or on an object an app
  keeps.** The draft persists the app with `CALL TRANSFORMATION id`, and the
  transpiled runtime reaches PROTECTED attributes but not PRIVATE ones. The
  report runtime keeps its state PROTECTED with a `cgui` infix so it cannot
  collide with the attributes of the report that inherits.
- **Bound data is found by reference.** A field method of the selection
  screen gets the attribute itself (pass by reference) and hands it to
  `client->_bind( )`; `z2ui5_cl_cgui_context=>attri_name_by_ref( )` finds its
  name the same way. A copy (a `VALUE( )` parameter, a local variable) binds
  nothing.
- **Prefer an attribute name over a data reference** for state that
  survives a roundtrip: a `REF TO data` with an anonymous type is rebuilt with
  RTTI when the draft loads (`cl_abap_elemdescr=>get_p` is a stub in the
  transpiled runtime). `alv( )` stores the attribute name when it can.
- **Read `sy-tabix` / `sy-index` arguments first.** `write( hide = sy-tabix )`
  is read before anything else in the method: the transpiled runtime passes
  even a `VALUE( )` of type `any` by reference, and its RTTI loops.
- **Dates and times reach the model formatted**: `2026-01-05`, `12:00:00`, an
  initial one as empty. DatePicker and TimePicker use `valueFormat`
  `yyyy-MM-dd` and `HH:mm:ss`.
- **`IN` in the transpiled runtime** only knows `I EQ`, `E EQ`, `I CP`; the
  samples use `z2ui5_cl_cgui_context=>range_check( )`.
- **A radio button's `select` fires at the button it deselects too** — before
  that button's `false` reaches the model, so a roundtrip from there carries
  two selected buttons. The user command of a group is wired only to the
  buttons not selected at render time; the screen is rendered anew after
  every roundtrip, so the wiring follows the selection.
- **The standard F4 reads the DDIC dynamically.** `GET_DDIC_FIXED_VALUES`
  is called with a local copy of `DDFIXVALUE` (as abap2UI5 core does), and
  the value table goes through `DFIES` / `DDFIELDS`, which raise on ABAP
  Cloud - every lookup sits in a `TRY` and an error means "no F4". In tests
  use `XSDBOOLEAN`: it is the one data element with fixed values that both
  the abaplint API set and the transpiled runtime know.
- **`z2ui5_cl_popup_to_select` preselects through `ZZSELKZ`.** It copies the
  rows with `MOVE-CORRESPONDING` into its own table, whose `ZZSELKZ` is bound
  to `selected` - so a table that brings a `ZZSELKZ` comes up checked. The
  popup heads a column with the DDIC label of its type, and with `STRING`
  for a string: give value lists character types.
- **The report dispatcher is one IF/ELSEIF chain** over `check_on_init`,
  `check_on_navigated`, `check_on_event`, and every branch that shows the
  screen calls `view_display( )` — unless a popup app was called in the same
  roundtrip (`mv_cgui_nav`).

## Verifying at runtime

The views can be driven without an SAP system: transpile `src` plus the
popups used against `@abap2ui5/node-runtime` (the mcp-server's
`lib/npm-backend.mjs` `buildNpm`), start `lib/npm-host.mjs`, and drive the
app with Playwright. The unit tests run the same way in CI
(`.github/workflows/unit.yaml`); locally
`node <mcp-server>/scripts/ci-unit.mjs` with the same paths.
Where the UI5 CDN (`sdk.openui5.org`) is not reachable, serve the
`@openui5/*/src` packages the linter installs in `node_modules` through a
Playwright `page.route( )`, with `bypassCSP: true` for the source bootstrap.
