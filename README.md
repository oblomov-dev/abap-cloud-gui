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
| `z2ui5_cl_cgui_report` | the report itself — `INITIALIZATION`, `AT SELECTION-SCREEN OUTPUT`, `AT SELECTION-SCREEN ON field`, `AT SELECTION-SCREEN`, `START-OF-SELECTION`, `AT LINE-SELECTION`, `AT USER-COMMAND`, `AT SELECTION-SCREEN ON VALUE-REQUEST`, `MESSAGE`, `POPUP_TO_CONFIRM` |
| `z2ui5_cl_cgui_selscreen` | `PARAMETERS`, `SELECT-OPTIONS`, `SELECTION-SCREEN BEGIN OF BLOCK / LINE`, `COMMENT`, `PUSHBUTTON`, `AS CHECKBOX`, `RADIOBUTTON GROUP`, `OBLIGATORY`, `NO-DISPLAY`, `MODIF ID`, `USER-COMMAND`, `LOOP AT SCREEN` / `MODIFY SCREEN`, F4 and the multiple selection of a select-option |
| `z2ui5_cl_cgui_list` | `WRITE`, `NEW-LINE`, `SKIP`, `ULINE`, `NEW-PAGE`, `FORMAT COLOR`, `HOTSPOT`, `HIDE`, `AS CHECKBOX`, `AS ICON` |
| `z2ui5_cl_cgui_alv` | `CL_SALV_TABLE` — columns and headers from RTTI/DDIC, sort, filter, double click |
| `z2ui5_cl_cgui_variant` | selection variants — get, save, delete, start with a variant |
| `z2ui5_cl_cgui_painter` | the selection screen painter (SE51 for selection screens) — fill in the elements, see the preview, take the generated report class |
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
| `at_selection_screen_output( screen )` | right after `selection_screen` — hide fields, make them read-only or required |
| `at_selection_screen_on( field )` | after Execute, once per field shown — `message( type = 'E' )` marks the field and stops |
| `at_selection_screen` | after Execute — `message( type = 'E' )` keeps the user on the selection screen |
| `start_of_selection` | read the data, output it with `write( )` or `alv( )` |
| `at_line_selection( row hide )` | a hotspot of the list or a row of the ALV was clicked |
| `at_user_command( ucomm )` | a button of the selection screen, a checkbox or radio button group with `user_command`, or a confirmed `popup_to_confirm( )` |
| `at_value_request( field )` | F4 on a field — the default is the standard F4 of its DDIC type; redefine it for your own and call `super->` for the rest |

Messages follow the classic semantics — `S` as a toast, `I` as a box, `E`
stops the run — and every message of a run but `S` is collected in the
**message popover**: a button at the left of the footer counts them, in red
for an error, and `W` and `E` open the popover by themselves. A message that
belongs to a field — raised in `at_selection_screen_on( )`, or with
`message( field = 'P_QTY' )` — marks that field with its text, names it in
the popover, and a click on it puts the cursor into the field. Fields
declared `obligatory` are checked before `at_selection_screen`, each empty
one with a message of its own.

### A dynamic selection screen

`MODIF ID`, `USER-COMMAND` and `LOOP AT SCREEN` work as in a classic report:
a radio button group or a checkbox with `user_command` runs
`at_user_command( )` as soon as the user changes it, and the selection screen
is built anew — `at_selection_screen_output( )` included.

```abap
METHOD selection_screen.
  screen->radiobutton( val = p_disp   text = `Display` group = `MODE` user_command = `MODE`
      )->radiobutton( val = p_create text = `Create`  group = `MODE`
      )->parameter( val = p_matnr text = `Material`    modif_id = `DIS`
      )->parameter( val = p_name  text = `Description` modif_id = `CRE` ).
ENDMETHOD.

METHOD at_selection_screen_output.
  DATA(lt_screen) = screen->loop_at_screen( ).
  LOOP AT lt_screen INTO DATA(ls_screen).
    CASE ls_screen-group1.
      WHEN `DIS`. ls_screen-active = p_disp.
      WHEN `CRE`. ls_screen-active = p_create.
    ENDCASE.
    screen->modify_screen( ls_screen ).
  ENDLOOP.
ENDMETHOD.
```

A line of `loop_at_screen( )` has `name`, `group1`, `active`, `input`,
`required` and `invisible` — as `abap_bool`, not `'0'` / `'1'`. `active` hides
the field with its label (a block with no field left disappears), `input`
makes it read-only, `required` obligatory, `invisible` masks the input like a
password.

### Value helps

Every parameter and select-option whose DDIC type has a standard F4 gets it
without code: the **fixed values of the domain**, or — on premise — its
**value table**. Fields declared with `value_help = abap_true` get F4 too and
are answered in `at_value_request( )`, with any table:

```abap
METHOD at_value_request.
  CASE field.
    WHEN `P_CARRID` OR `S_CARRID`.
      value_help_popup( tab = lt_carrier col = `CARRID` title = `Airlines` ).
    WHEN OTHERS.
      super->at_value_request( field ).   " the standard F4
  ENDCASE.
ENDMETHOD.
```

On a select-option F4 picks any number of values, which become lines
`I EQ` — the ones already selected come up checked. A button beside the
field opens the range popup, the classic multiple selection, for every
other condition.

### Selection variants

The footer of every selection screen has **Get Variant**, **Save as
Variant** and **Delete Variant**: a variant keeps every field of the screen
— parameters, select-options with all their lines, hidden `NO-DISPLAY`
fields — under a name, and the list of variants shows what each one holds.
A report starts with a variant through the URL (`&variant=Q1`) or from
`initialization( )`:

```abap
METHOD initialization.
  set_variant( `DEFAULT` ).   " if the user saved one - silently skipped if not
ENDMETHOD.
```

The variants are kept in the browser's local storage, one entry per report
class — nothing to install, on ABAP Cloud as on premise. That also means
they belong to the browser: another device or browser starts without them.

## Samples

| Class | Shows |
|---|---|
| `z2ui5_cl_cgui_sample_01` | the selection screen on its own — every field type, blocks, a line, a button |
| `z2ui5_cl_cgui_sample_02` | the list on its own — colors, checkbox, icon, pages, hotspots with `HIDE` |
| `z2ui5_cl_cgui_sample_03` | the ALV on its own — column texts, a hidden column, row click |
| `z2ui5_cl_cgui_sample_04` | the smallest report — hello world |
| `z2ui5_cl_cgui_sample_05` | a complete report — select-option, F4 help, radio buttons for ALV or list, drilldown, reset with a confirmation popup, starts with the variant `DEFAULT` |
| `z2ui5_cl_cgui_sample_06` | a dynamic selection screen — `MODIF ID`, `USER-COMMAND`, `LOOP AT SCREEN`, read-only and password fields, `NO-DISPLAY`, `AT SELECTION-SCREEN ON field` |
| `z2ui5_cl_cgui_sample_07` | value helps — standard F4 from domain fixed values and value table, own F4 for a parameter and a select-option |

## Selection screen painter

Start `z2ui5_cl_cgui_painter` (`?app_start=z2ui5_cl_cgui_painter`) and
build the selection screen of a new report without writing it first:

- **Elements** — one row per element: blocks and lines, parameters with
  their type (`c LENGTH 10`, `d`, `i`, a DDIC type), select-options,
  checkboxes, radio buttons, comments and push buttons, with text,
  `OBLIGATORY`, F4, radio group or button event, `MODIF ID`,
  `USER-COMMAND` and `NO-DISPLAY`. Rows move up and down; **Sample**
  loads a complete screen to start from.
- **Preview** — the screen as the report will show it, drawn by the same
  `z2ui5_cl_cgui_selscreen`, DDIC labels and F4 included.
- **Code** — the report class to copy into the system: the fields as
  PUBLIC attributes, `selection_screen( )` in the layout of the samples,
  and `at_selection_screen_output( )`, `start_of_selection( )` and
  `at_user_command( )` as far as the elements call for them. Names, types
  and the nesting of blocks and lines are checked first, and every problem
  is listed with its line.

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
- Selection variants live in the browser's local storage — per browser
  and device, not shared between users or kept on the server.
- Value tables are read on premise only — on ABAP Cloud the DDIC is not
  read, and the standard F4 is the domain's fixed values.
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
- [x] Phase 5 — dynamic selection screen: `AT SELECTION-SCREEN OUTPUT` with
      `LOOP AT SCREEN` / `MODIFY SCREEN` (hide, read-only, required,
      invisible), `MODIF ID`, `USER-COMMAND` at checkboxes and radio button
      groups, `NO-DISPLAY`, `AT SELECTION-SCREEN ON field` and messages with
      the value state on their field; unit tests for the selection screen
- [x] Phase 6 — value helps: standard F4 from domain fixed values (ABAP
      Cloud and on premise) and value tables (on premise), automatic for
      every DDIC-typed field; F4 with multiple selection on select-options,
      preselected, the range popup on a button of its own
- [x] Phase 7 — selection variants: get, save as, delete, start with a
      variant from the URL or `set_variant( )`, kept in the browser's local
      storage
- [x] Phase 8 — selection screen painter: elements in a table, live
      preview, the generated report class with a check of the design
- [x] Phase 9 — message popover: the messages of a run in one place,
      counted in the footer, opened by W and E, each message of a field
      leading to the field; one message per empty required field

**Next**

Selection screen

- [ ] Value helps: CDS value helps (`@Consumption.valueHelpDefinition`),
      text tables beside value tables, search helps, F4 inside the range
      popup of a select-option
- [ ] `AT SELECTION-SCREEN ON BLOCK`, `ON RADIOBUTTON GROUP`, `AS LISTBOX`
- [ ] `MEMORY ID`
- [ ] Selection variants on the server: shared and protected variants,
      a pluggable store beside the browser's local storage, dynamic date
      values (today, start of month)
- [ ] Selection screen painter: drag and drop, read an existing
      `selection_screen( )` back in, keep the design in the browser

Messages and logging

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

- [ ] Tests for the report runtime and the ALV with a client test double
      (the selection screen has them), samples in the abap2UI5 playground,
      documentation page

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
