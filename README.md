# abap-cloud-gui

**Write abap2UI5 apps the way you write a classic ABAP report.** Selection
screen, `WRITE` list, ALV grid, `START-OF-SELECTION`, `AT LINE-SELECTION`,
`MESSAGE` — the same concepts, running as a UI5 app in the browser. On ABAP
Cloud as well as on NetWeaver down to 7.02.

## Why?

ABAP Cloud has no SAP GUI: no selection screens, no `WRITE` lists, no
`CL_SALV_TABLE`. A quick report that took ten minutes on premise suddenly
needs RAP, CDS and a Fiori app. And writing UI5 views by hand means learning
a new UI model first.

abap-cloud-gui closes that gap. You write a class that looks and reads like a
report — parameters, event blocks, `write( )` — and get a UI5 app with a
selection screen, a result list or ALV grid, drilldown, value helps and
messages. No UI5 knowledge, no CDS, no RAP needed.

Good for:

- **ABAP developers on ABAP Cloud** who need a quick report or tool.
- **Moving reports to ABAP Cloud** — the event blocks and output statements
  map to methods with matching names, so a report keeps its structure.
- **Starting with abap2UI5** in familiar terms before building views yourself.

## What it is not

- **Not a way to run existing reports unchanged.** A report is rewritten as a
  class: event blocks become methods, `PARAMETERS` become attributes, `WRITE`
  becomes `write( )`. The structure stays, the syntax changes.
- **Not a SAP GUI clone.** It uses the classic *programming model*, the screens
  look like modern UI5. If you are looking for SE80, SE16N or SM37 in the
  browser, that is [abap2UI5-addons/sapgui](https://github.com/abap2UI5-addons/sapgui).

## Quick start

Install with [abapGit](https://abapgit.org), in this order:

1. [abap2UI5](https://github.com/abap2UI5/abap2UI5)
2. [abap2UI5-addons/popups](https://github.com/abap2UI5-addons/popups) — the
   value helps and confirmation popups
3. this repository

Then write your first report:

```abap
CLASS zcl_hello DEFINITION PUBLIC INHERITING FROM z2ui5_cl_cgui_report FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    DATA p_name  TYPE string.
    DATA p_times TYPE i.
  PROTECTED SECTION.
    METHODS selection_screen REDEFINITION.
    METHODS start_of_selection REDEFINITION.
ENDCLASS.

CLASS zcl_hello IMPLEMENTATION.

  METHOD selection_screen.
    screen->parameter( val = p_name text = `Your name` obligatory = abap_true
        )->parameter( val = p_times text = `Lines` ).
  ENDMETHOD.

  METHOD start_of_selection.
    write( |Hello { p_name }!| )->uline( ).
    DO p_times TIMES.
      write( |Line { sy-index }| )->new_line( ).
    ENDDO.
  ENDMETHOD.

ENDCLASS.
```

Start it like any abap2UI5 app (`?app_start=zcl_hello`): the selection screen
comes up, **Execute** runs the report and shows the list, **Back** returns to
the selection screen. For more, run the samples below — `z2ui5_cl_cgui_sample_05`
is a complete report.

## What is there

| Class | Classic counterpart |
|---|---|
| `z2ui5_cl_cgui_report` | the report itself — `INITIALIZATION`, `AT SELECTION-SCREEN`, `START-OF-SELECTION`, `AT LINE-SELECTION`, `AT USER-COMMAND`, `AT SELECTION-SCREEN ON VALUE-REQUEST`, `MESSAGE`, `POPUP_TO_CONFIRM` |
| `z2ui5_cl_cgui_selscreen` | `PARAMETERS`, `SELECT-OPTIONS`, `SELECTION-SCREEN BEGIN OF BLOCK / LINE`, `COMMENT`, `PUSHBUTTON`, `AS CHECKBOX`, `RADIOBUTTON GROUP`, `OBLIGATORY` |
| `z2ui5_cl_cgui_list` | `WRITE`, `NEW-LINE`, `SKIP`, `ULINE`, `NEW-PAGE`, `FORMAT COLOR`, `HOTSPOT`, `HIDE`, `AS CHECKBOX`, `AS ICON` |
| `z2ui5_cl_cgui_alv` | `CL_SALV_TABLE` — columns and headers from RTTI/DDIC, sort, filter, double click |
| `z2ui5_cl_cgui_context` | helpers — among them `range_check( )`, the `IN` of a select-option for internal tables |

All views are built with `z2ui5_cl_ui5_view_builder`. The selection screen,
the list and the ALV can also be used on their own inside any abap2UI5 app:
each has `render( )` to append itself to a view and `stringify( )` to return
a complete view.

### The report runtime

Inherit from `z2ui5_cl_cgui_report`, declare the selection screen fields as
**PUBLIC** attributes and redefine the event blocks you need:

| Method | When it runs |
|---|---|
| `initialization` | once, before the selection screen is shown — set defaults here |
| `selection_screen( screen )` | every time the selection screen is shown — the layout |
| `at_selection_screen` | after Execute — `message( type = 'E' )` keeps the user on the selection screen |
| `start_of_selection` | read the data, output it with `write( )` or `alv( )` |
| `at_line_selection( row hide )` | a hotspot of the list or a row of the ALV was clicked |
| `at_user_command( ucomm )` | a button of the selection screen, or a confirmed `popup_to_confirm( )` |
| `at_value_request( field )` | F4 on a parameter declared with `value_help` — answer with `value_help_popup( )` |

Messages follow the classic semantics: `S` as a toast, `I` and `W` as a box,
`E` as a box that stops the run. Fields declared `obligatory` are checked
before `at_selection_screen`.

## Samples

| Class | Shows |
|---|---|
| `z2ui5_cl_cgui_sample_01` | the selection screen on its own — every field type, blocks, a line, a button |
| `z2ui5_cl_cgui_sample_02` | the list on its own — colors, checkbox, icon, pages, hotspots with `HIDE` |
| `z2ui5_cl_cgui_sample_03` | the ALV on its own — column texts, a hidden column, row click |
| `z2ui5_cl_cgui_sample_04` | the smallest report — hello world |
| `z2ui5_cl_cgui_sample_05` | a complete report — select-option, F4 help, radio buttons for ALV or list, drilldown, reset with a confirmation popup |

## Compatibility

- **ABAP Cloud** and **Standard ABAP**; **NW 7.02** through a downport — the
  source is written in 7.50 syntax and every release is checked in CI (see
  below).
- **UI5 1.71** is the floor, as for abap2UI5 itself.
- The views and the report flow have been driven end to end in the
  transpiled abap2UI5 backend (Node.js) in a headless browser.

Known limitations:

- ALV cells show dates and times as the model carries them (`2026-01-05`),
  not in the user's format yet.
- In the transpiled JavaScript runtime, `IN` only knows `I EQ`, `E EQ` and
  `I CP` — use `z2ui5_cl_cgui_context=>range_check( )` for internal tables if
  the report must also run there. On an SAP system `IN` and
  `SELECT ... WHERE ... IN` work as usual.
- `alv( )` binds a PUBLIC attribute directly; any other table is copied into
  a data reference, which the draft has to rebuild with RTTI on every
  roundtrip.

## Roadmap

**Done**

- [x] Phase 0 — cleanup: `z2ui5_cl_cgui` prefix, packages `01` core / `02`
      samples, CI for v750, ABAP Cloud and 7.02, abap2UI5-linter, unit tests
- [x] Phase 1 — report runtime: event blocks, selection screen ↔ output,
      Execute / Back
- [x] Phase 2 — selection screen: parameters by type, checkbox, radio button
      groups, blocks, lines, comments, push buttons, select-options with the
      range popup, `OBLIGATORY`, F4 through `at_value_request`; fields are
      found by reference, `select_option( )` needs no name
- [x] Phase 3 — output: ALV grid (RTTI/DDIC columns, sort, filter, row click),
      `WRITE` list (colors, icons, checkboxes, pages, hotspots, `HIDE`)
- [x] Phase 4 — messages with classic semantics, `POPUP_TO_CONFIRM`

**Next**

Selection screen

- [ ] `AT SELECTION-SCREEN OUTPUT` / `LOOP AT SCREEN` with `MODIFY SCREEN`
      (hide, read-only, required per field) and an update of the screen
- [ ] Value helps: automatic F4 from domain fixed values, check tables and
      CDS value helps, shown in a popup; F4 inside the range popup of a
      select-option
- [ ] `AT SELECTION-SCREEN ON field` with the value state on the field
- [ ] `NO-DISPLAY`, `MEMORY ID`
- [ ] Selection variants: save, load, start a report with a variant
- [ ] Selection screen painter: build a selection screen visually and
      generate the `selection_screen( )` method

Messages and logging

- [ ] Message popover: all messages of a run in one place, warnings in
      yellow, each message linked to its input field
- [ ] Short API in the style of abap2UI5: `_msg( )->e( )`, `_msg_box( )->e( )`
- [ ] Application log (BAL) and [ABAP Logger](https://github.com/ABAP-Logger/ABAP-Logger)
      as a source for the message popover and a log popup; the internal
      message table is replaced by the log

Dialogs and screens

- [ ] Popups: `_popup( )->decide` (`POPUP_TO_DECIDE`), `POPUP_GET_VALUES`,
      transport request selection (from [abap2UI5-addons/popups](https://github.com/abap2UI5-addons/popups))
- [ ] `CALL SCREEN` and back, also of a screen in another class
- [ ] `CALL SELECTION-SCREEN` of another report, as a popup or by screen number

Navigation and transactions

- [ ] Command field instead of a plain input: transaction codes, `/n`, `/o`
- [ ] Command palette (`Cmd+K` / `Ctrl+K`) to search and start reports
- [ ] Input history: the last entries of a field, opened with the space bar
- [ ] Keyboard shortcuts: F8 Execute, F3 Back, `AT PFnn`
- [ ] Transaction logic: start with a variant, prefill the last entries,
      create a draft
- [ ] `SET` / `GET PARAMETER ID` with user parameters (like SU3), system
      parameters and customizing parameters

Output

- [ ] ALV: user-formatted dates, times and amounts, totals and subtotals,
      hotspot per column, toolbar with own functions, Excel export, layout
      variants, editable cells
- [ ] List: `WRITE AT` positions and `UNDER`, monospace columns,
      `TOP-OF-PAGE`, secondary lists (`sy-lsind`)

Quality

- [ ] Tests for the selection screen and the ALV with a client test double,
      samples in the abap2UI5 playground, documentation page

Later

- [ ] Background execution (application jobs on ABAP Cloud), print / PDF,
      tree lists

## Development

```bash
npm ci
npm run lint            # abaplint, v750 syntax + downport rule
npm run check:cloud     # abaplint, ABAP Cloud
npm run check:702       # downport a scratch copy to 7.02 and check it
npm run check:abap2ui5  # abap2UI5-linter over apps and views
```

The ABAP Unit tests run in CI in the transpiled abap2UI5 backend
(`.github/workflows/unit.yaml`, [abap2UI5/mcp-server](https://github.com/abap2UI5/mcp-server)).
