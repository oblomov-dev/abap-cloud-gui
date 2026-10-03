# report2cloud: ZR2C_03_FORMS → z2ui5_cl_cgui_r2c_03

| | |
|---|---|
| Source | `zr2c_03_forms.prog.abap` |
| Text pool | none - texts are placeholders, see the TODOs |
| Result | **converted** - `z2ui5_cl_cgui_r2c_03.clas.abap`, `z2ui5_cl_cgui_r2c_03.clas.xml` |
| Mapped | 25 construct(s) |
| TODO | 1 |
| Release state to check | 0 object(s) |

## TODO

- no selection text in the text pool for P_ITEMS, P_DISC, P_VAT - the label is the DDIC label of the type or the field name; pass the .prog.xml (--texts) or set text = in selection_screen( )

## Release state on ABAP Cloud

The class uses no database table, DDIC type, function module, class or message class outside of abap2UI5 and this addon.

## Mapped

| Line | Classic | abap-cloud-gui |
|---|---|---|
| 7 | `REPORT zr2c_03_forms` | the class, `INHERITING FROM z2ui5_cl_cgui_report` |
| 24 | `PARAMETERS p_items TYPE i DEFAULT 5 OBLIGATORY` | attribute `p_items`, `screen->parameter( )` |
| 25 | `PARAMETERS p_disc TYPE p LENGTH 3 DECIMALS 2 DEFAULT '0.05'` | attribute `p_disc`, `screen->parameter( )` |
| 26 | `PARAMETERS p_vat AS CHECKBOX DEFAULT 'X'` | attribute `p_vat`, `screen->checkbox( )` |
| 28 | `AT SELECTION-SCREEN ON p_items` | `at_selection_screen_on( field )` - WHEN `P_ITEMS` |
| 30 | `MESSAGE 'Between 1 and 50 items' TYPE 'E'` | `message( )` |
| 33 | `START-OF-SELECTION` | `start_of_selection( )` |
| 34 | `PERFORM build_items USING p_items CHANGING gt_items` | `build_items( )` |
| 35 | `PERFORM total TABLES gt_items USING p_disc CHANGING gv_net` | `total( )` |
| 41 | `PERFORM output` | `output( )` |
| 46 | `FORM build_items USING VALUE(iv_count) TYPE i CHANGING ct_items TYP...` | private method `build_items( )` |
| 62 | `FORM total TABLES it_items STRUCTURE gs_template USING iv_discount ...` | private method `total( )` |
| 67 | `RANGES lr_big FOR ls_item-quantity` | `DATA ... RANGE OF` |
| 84 | `FORM output` | private method `output( )` |
| 87 | `PERFORM write_item USING ls_item` | `write_item( )` |
| 89 | `ULINE` | `list( )->uline( )` |
| 90 | `WRITE / 'Net:'` | `write( )` |
| 90 | `WRITE gv_net` | `write( )` |
| 91 | `WRITE / 'Gross:'` | `write( )` |
| 91 | `WRITE gv_gross` | `write( )` |
| 94 | `FORM write_item USING is_item TYPE ty_item` | private method `write_item( )` |
| 95 | `WRITE / is_item-pos` | `write( )` |
| 95 | `WRITE is_item-product` | `write( )` |
| 95 | `WRITE is_item-quantity` | `write( )` |
| 95 | `WRITE is_item-price` | `write( )` |

## Next steps

1. Work through the TODOs above; replace every object of the release table by its released successor.
2. Lint the class against ABAP Cloud: `node tools/report2cloud/cli.mjs <report> --check` (or `npm run check:cloud` with the class in `src/`) until it is clean.
3. Check the views with the abap2UI5 linter (`npx abap2ui5lint`) and run the report: `?app_start=z2ui5_cl_cgui_r2c_03`.
4. Pin the behaviour with ABAP Unit tests before the next change.
