CLASS ltcl_test DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_s_row,
        carrid TYPE c LENGTH 3,
        seats  TYPE i,
        price  TYPE p LENGTH 8 DECIMALS 2,
      END OF ty_s_row.
    TYPES ty_t_row TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.

    DATA mt_row  TYPE ty_t_row.
    DATA mo_alv  TYPE REF TO z2ui5_cl_cgui_alv.
    DATA mo_salv TYPE REF TO z2ui5_cl_cgui_salv.

    METHODS setup.
    METHODS columns_as_salv FOR TESTING.
    METHODS sorts_aggregations_settings FOR TESTING.

ENDCLASS.


CLASS ltcl_test IMPLEMENTATION.

  METHOD setup.

    mt_row = VALUE #( ( carrid = `LH` seats = 10 price = `100.00` )
                      ( carrid = `AA` seats = 20 price = `300.00` )
                      ( carrid = `UA` seats = 30 price = `200.00` ) ).
    mo_alv = z2ui5_cl_cgui_alv=>factory( ).
    mo_salv = z2ui5_cl_cgui_salv=>factory( mo_alv ).

  ENDMETHOD.

  METHOD columns_as_salv.

    " the code of a SALV report, the types changed
    DATA lr_columns TYPE REF TO z2ui5_cl_cgui_salv.
    DATA lr_column  TYPE REF TO z2ui5_cl_cgui_salv.

    lr_columns = mo_salv->get_columns( ).
    lr_columns->set_optimize( abap_true ).
    lr_column ?= lr_columns->get_column( 'CARRID' ).
    lr_column->set_long_text( 'Airline' ).
    " the short text after the long one does not win
    lr_column->set_short_text( 'Al' ).
    cl_abap_unit_assert=>assert_equals( act = lr_column->get_columnname( )
                                        exp = `CARRID` ).
    lr_columns->get_column( 'SEATS' )->set_technical( if_salv_c_bool_sap=>true ).

    DATA(lt_text) = mo_alv->to_text( mt_row ).
    DATA(lv_text) = concat_lines_of( table = lt_text sep = `|` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_text
                                         exp = `*Airline*` ).
    cl_abap_unit_assert=>assert_char_np( act = lv_text
                                         exp = `*SEATS*` ).
    cl_abap_unit_assert=>assert_char_np( act = lv_text
                                         exp = `* 20 *` ).

  ENDMETHOD.

  METHOD sorts_aggregations_settings.

    mo_salv->get_sorts( )->add_sort( columnname = 'PRICE'
                                     sequence   = if_salv_c_sort=>sort_down ).
    mo_salv->get_aggregations( )->add_aggregation( columnname  = 'SEATS'
                                                   aggregation = if_salv_c_aggregation=>total ).
    mo_salv->get_display_settings( )->set_list_header( 'Flights' ).
    mo_salv->get_functions( )->set_all( abap_true ).
    mo_salv->get_selections( )->set_selection_mode( if_salv_c_selection_mode=>multiple ).
    cl_abap_unit_assert=>assert_equals( act = mo_alv->get_selection_mode( )
                                        exp = z2ui5_cl_cgui_alv=>cs_selection_mode-multiple ).
    " no report behind it - no selected rows, no dump
    cl_abap_unit_assert=>assert_initial( mo_salv->get_selections( )->get_selected_rows( ) ).
    mo_salv->display( ).

    " sorted by the price downwards: AA 300, UA 200, LH 100
    DATA(lv_text) = concat_lines_of( table = mo_alv->to_text( mt_row ) sep = `|` ).
    FIND `AA` IN lv_text MATCH OFFSET DATA(lv_aa).
    FIND `UA` IN lv_text MATCH OFFSET DATA(lv_ua).
    FIND `LH` IN lv_text MATCH OFFSET DATA(lv_lh).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_aa < lv_ua AND lv_ua < lv_lh ) ).
    " the total of the seats
    cl_abap_unit_assert=>assert_char_cp( act = lv_text
                                         exp = `*60*` ).

  ENDMETHOD.

ENDCLASS.
