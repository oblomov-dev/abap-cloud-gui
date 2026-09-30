# abap-cloud-gui

SAP GUI style programming for [abap2UI5](https://github.com/abap2UI5/abap2UI5):
selection screens, `WRITE` lists, ALV grids and the classic report events —
on ABAP Cloud and on NetWeaver down to 7.02.

*Bringing the best of classic ABAP to modern UI5 applications* 🎯

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
comes up, **Execute** runs the report, **Back** returns to the selection
screen.

## Installation

Install with [abapGit](https://abapgit.org), in this order:

1. [abap2UI5](https://github.com/abap2UI5/abap2UI5)
2. [abap2UI5-addons/popups](https://github.com/abap2UI5-addons/popups) — the
   value helps and confirmation popups
3. this repository

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
      range popup, `OBLIGATORY`, F4 through `at_value_request`
- [x] Phase 3 — output: ALV grid (RTTI/DDIC columns, sort, filter, row click),
      `WRITE` list (colors, icons, checkboxes, pages, hotspots, `HIDE`)
- [x] Phase 4 — messages with classic semantics, `POPUP_TO_CONFIRM`

**Next**

- [ ] Selection screen: automatic F4 from domain fixed values and check tables,
      `AT SELECTION-SCREEN OUTPUT` / `LOOP AT SCREEN` (hide, read-only per
      field), `AT SELECTION-SCREEN ON field` with the value state on the field,
      `NO-DISPLAY`, `MEMORY ID`, selection variants
- [ ] ALV: user-formatted dates, times and amounts, totals and subtotals,
      hotspot per column, toolbar with own functions, Excel export, layout
      variants, editable cells
- [ ] List: `WRITE AT` positions and `UNDER`, monospace columns,
      `TOP-OF-PAGE`, secondary lists (`sy-lsind`), `AT PFnn` / keyboard
      shortcuts (F3, F8)
- [ ] Dialogs: `POPUP_GET_VALUES`, application log / message popup
- [ ] Quality: tests for the selection screen and the ALV with a client test
      double, samples in the abap2UI5 playground, documentation page
- [ ] Later: background execution (application jobs on ABAP Cloud), print /
      PDF, tree lists

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
