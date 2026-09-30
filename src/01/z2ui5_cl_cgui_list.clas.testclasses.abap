CLASS ltcl_test DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS write_lines FOR TESTING.
    METHODS hide_keeps_tabix FOR TESTING.
    METHODS clear FOR TESTING.

ENDCLASS.


CLASS ltcl_test IMPLEMENTATION.

  METHOD write_lines.

    DATA(lo_list) = z2ui5_cl_cgui_list=>factory( ).
    lo_list->write( `a`
        )->write( `b`
        )->new_line(
        )->write( val     = `c`
                  hotspot = abap_true
                  hide    = `K1` ).

    DATA(lt_item) = lo_list->get_items( ).
    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = lines( lt_item ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lt_item[ 2 ]-line ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lt_item[ 3 ]-line ).

    DATA(ls_item) = lo_list->get_item_by_line( 2 ).
    cl_abap_unit_assert=>assert_equals( exp = `c`
                                        act = ls_item-text ).
    cl_abap_unit_assert=>assert_equals( exp = `K1`
                                        act = ls_item-hide ).

  ENDMETHOD.

  METHOD hide_keeps_tabix.

    DATA lt_text TYPE string_table.

    DATA(lo_list) = z2ui5_cl_cgui_list=>factory( ).
    lt_text = VALUE #( ( `x` ) ( `y` ) ( `z` ) ).

    LOOP AT lt_text INTO DATA(lv_text).
      lo_list->write( val     = lv_text
                      hotspot = abap_true
                      hide    = sy-tabix
          )->new_line( ).
    ENDLOOP.

    cl_abap_unit_assert=>assert_equals( exp = `3`
                                        act = lo_list->get_item_by_line( 3 )-hide ).

  ENDMETHOD.

  METHOD clear.

    DATA(lo_list) = z2ui5_cl_cgui_list=>factory( ).
    lo_list->write( `a` )->uline( ).
    lo_list->clear( ).

    cl_abap_unit_assert=>assert_initial( lo_list->get_items( ) ).

  ENDMETHOD.

ENDCLASS.
