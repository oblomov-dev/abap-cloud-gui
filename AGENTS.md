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
| `src/01` | the framework: `z2ui5_cl_cgui_report` (report runtime), `_selscreen`, `_list`, `_alv`, `_variant` (selection variants), `_context` (RTTI and conversion helpers), `z2ui5_cx_cgui_error` |
| `src/02` | samples `z2ui5_cl_cgui_sample_01` … `_07` |
| `src/03` | tools: the selection screen painter `z2ui5_cl_cgui_painter` and its code generator `_painter_code` |
| `tools/report2cloud` | `report2cloud`, a Node CLI (no ABAP object) that converts a classic report into a report class of this addon - see below |
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
  `z2ui5_cl_popup_get_range`, `_to_confirm`, `_to_select`, `_input_val`.

abaplint resolves these as git dependencies. The core is **pinned to a
release tag** (the `"branch"` key of the abap2UI5 dependency, abap2UI5
CONVENTIONS §9): users install a release next to this addon, so the gates
run against that release and not against the framework's `main`. Three
configs carry the pin (`abaplint.jsonc`, `.github/abaplint/abap_cloud.jsonc`,
and the downported `<tag>-702` form in `.github/abaplint/abap_702.jsonc`);
read and move them only with `scripts/core-pin.mjs` (`get` fails when they
disagree). `bump-core.yaml` moves the pin weekly to the newest release after
the three abaplint gates passed on it, and the scheduled `abaplint` run lints
once against the core's `main` as the canary (`core-pin.mjs set main`, never
committed). Do not drop the key: abaplint then clones `main` silently. popups
and layout-management have no release tags and are resolved from `main`.

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
- **Variants live in the browser's local storage** - this repository has no
  table of its own. The invisible `z2ui5:Storage` control reads the catalog
  into the PUBLIC `mv_cgui_variants` and fires `finished` while the first
  view still renders - the wire needs `check_queue_last`, or the event is
  dropped. `STORE_DATA` is called from a handler with a payload composed as
  JSON (`z2ui5_cl_cgui_variant=>storage_json( )`), never with
  `${ _bind( ) }`: a handler's binding argument arrives as text, and an
  empty VALUE deletes the key. Keep bound and stored value equal after a
  write, or the control reports again on the next render. A variant in the
  URL is read after `initialization( )`, so it wins over `set_variant( )`.
- **The painter's code must compile as it is.** A change to
  `z2ui5_cl_cgui_painter_code` is checked by generating a class (the
  painter's Sample, plus a select-option with `c LENGTH`) and running the
  three abaplint gates over it as a class of `src/02`, not only by the unit
  tests. The preview uses `z2ui5_cl_cgui_selscreen` with `preview`: nothing
  is bound, a flag renders its value literally.
- **The message popover is part of the screen and opens in a roundtrip of
  its own.** It is a dependent of the page; the footer button toggles it in
  the browser (`control_by_id` `toggleBy`, no roundtrip). Opened by the
  response that builds the screen - `openBy` as a follow-up action, or a
  popover through `popover_display( )` - it stayed open without ever being
  rendered after the first time, because the frontend holds the rendering
  back while it swaps the view. So a run with W or E arms `start_timer`
  with 0 ms and `CGUI_MESSAGES_OPEN` opens it without drawing the screen
  again. The click on a message reaches the backend with the item as its
  argument (`${$parameters>/item}` arrives as JSON with the item's id),
  whose `cgui_msg_<n>` is the index into the log; the field control has the
  id `z2ui5_cl_cgui_selscreen=>field_id( )` for `SET_FOCUS`.
- **ABAP Doc goes after the colon of a chained declaration.** `"!` in
  front of `TYPES:` / `CONSTANTS:` is "in the wrong position" for the
  extended check; write `TYPES:` and the `"!` lines below it, in front of
  `BEGIN OF`. abaplint `wrong_abapdoc_position` checks it in all three gates.
- **No regular expressions.** POSIX (`FIND REGEX`, `matches( regex = )`,
  `cl_abap_regex`) is deprecated from 7.55 on and warns in the extended
  check; PCRE does not exist on 7.02. Use `FIND`, `CS` / `CN` / `CA` /
  `NA` and `substring( )`. abaplint has no rule for it:
  `npm run check:regex` (`scripts/check-regex.mjs`) fails on any regex in
  `src`.
- **The report dispatcher is one IF/ELSEIF chain** over `check_on_init`,
  `check_on_navigated`, `check_on_event`, and every branch that shows the
  screen calls `view_display( )` — unless a popup app was called in the same
  roundtrip (`mv_cgui_nav`).

## report2cloud

`tools/report2cloud` converts a classic report (`.prog.abap`, its text pool
from the `.prog.xml`) into a class inheriting from `z2ui5_cl_cgui_report`:
`npm run report2cloud -- zreport.prog.abap [--class zcl_x] [--out dir]`. It
parses with `@abaplint/core` at the version of `@abaplint/cli`, writes the
class in abapGit format plus a migration report, and refuses with
`file:row:col` what has no counterpart (dynpros, batch input, `SUBMIT`,
native SQL, ...). The mapping table and the refusals are in its README.

- **It writes against the API of `src/01` as it is.** A change to a
  signature of `z2ui5_cl_cgui_report`, `_selscreen`, `_list` or `_alv`
  (a parameter renamed, a method dropped) breaks the generated classes:
  `npm run test:report2cloud` lints every class of its corpus in a scratch
  copy of this repository - v750 with every rule of `abaplint.jsonc` (no
  finding allowed; `test/ddic` has stubs of the flight tables), ABAP Cloud
  with `.github/abaplint/abap_cloud.jsonc` (only the unreleased tables the
  migration report lists), the 7.02 gate and the abap2UI5 linter (no
  finding). Change the converter with the API, then
  `UPDATE_SNAPSHOTS=1 node --test tools/report2cloud/test/convert.test.mjs`
  and review the snapshot diff.
- **A class that lints is not a class that runs.**
  `npm run test:report2cloud:runtime` (opt-in; needs an mcp-server checkout
  at `MCP_SERVER_HOME` or `../mcp-server`, git and network) transpiles the
  corpus classes with `src/01`, the popups and the seeded flight table stubs
  against `@abap2ui5/node-runtime` and operates every report through the
  JSON protocol of the frontend (mcp-server's app client): fields, Execute,
  hotspots, grid rows, the F4 popup (a table of the agent snapshot, picked
  with `app_act({ event, row })`), the message popover (`snapshot.messages`,
  source `popover`), Back and a second run, each against expectations
  written by hand from what the classic report prints. It found, past a
  green lint: report globals that grew from one Execute to the next (the
  classic report restarts after its list - `start_of_selection( )` now
  clears them), END-OF-SELECTION skipped after a RETURN (it is a method of
  its own then), a TOP-OF-PAGE header shown as a list of its own
  (`top_of_page( )` is an event of `z2ui5_cl_cgui_report` now, called before
  the first line), `MESSAGE s013 ... INTO` without the class of
  MESSAGE-ID, `sy-repid` (undefined in the runtime, the class pool on a
  system), a generic `TYPE p` parameter (the transpiler cannot describe it -
  the class fails before its first screen) and `IN` on a select-option
  (the runtime's `IN` knows `I EQ`, `E EQ`, `I CP` - `range_check( )`, the
  rule above). Run it after a change to the converter or to `src/01`.
- **It follows the rules above**: report globals become PUBLIC attributes
  (never PRIVATE), the selection screen binds them by reference, ABAP SQL is
  written in strict mode, chains follow the house layout of the painter.
- **The generated files are abapGit's format** - BOM in the sidecar, LF,
  no trailing blanks, no line over 255 characters; the tests check every
  generated file.
- CI: `.github/workflows/report2cloud.yaml`.

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
