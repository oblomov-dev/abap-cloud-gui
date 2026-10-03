# report2cloud: ZR2C_01_HELLO → z2ui5_cl_cgui_r2c_01

| | |
|---|---|
| Source | `zr2c_01_hello.prog.abap` |
| Text pool | `zr2c_01_hello.prog.xml` |
| Result | **converted** - `z2ui5_cl_cgui_r2c_01.clas.abap`, `z2ui5_cl_cgui_r2c_01.clas.xml` |
| Mapped | 11 construct(s) |
| TODO | 0 |
| Release state to check | 0 object(s) |

## Release state on ABAP Cloud

The class uses no database table, DDIC type, function module, class or message class outside of abap2UI5 and this addon.

## Mapped

| Line | Classic | abap-cloud-gui |
|---|---|---|
| 6 | `REPORT zr2c_01_hello` | the class, `INHERITING FROM z2ui5_cl_cgui_report` |
| 8 | `PARAMETERS p_name TYPE string LOWER CASE OBLIGATORY` | attribute `p_name`, `screen->parameter( )` |
| 9 | `PARAMETERS p_times TYPE i DEFAULT 3` | attribute `p_times`, `screen->parameter( )` |
| 11 | `START-OF-SELECTION` | `start_of_selection( )` |
| 12 | `WRITE / 'Hello'` | `write( )` |
| 12 | `WRITE p_name` | `write( )` |
| 13 | `ULINE` | `list( )->uline( )` |
| 15 | `WRITE / 'Line'` | `write( )` |
| 15 | `WRITE sy-index` | `write( )` |
| 17 | `SKIP` | `list( )->skip( )` |
| 18 | `WRITE / 'Done.'` | `write( )` |

## Next steps

1. Work through the TODOs above; replace every object of the release table by its released successor.
2. Lint the class against ABAP Cloud: `node tools/report2cloud/cli.mjs <report> --check` (or `npm run check:cloud` with the class in `src/`) until it is clean.
3. Check the views with the abap2UI5 linter (`npx abap2ui5lint`) and run the report: `?app_start=z2ui5_cl_cgui_r2c_01`.
4. Pin the behaviour with ABAP Unit tests before the next change.
