CLASS ltcl_attri DEFINITION FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    DATA mv_text  TYPE string.
    DATA mt_range TYPE RANGE OF i.

ENDCLASS.


CLASS ltcl_test DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES ty_t_range_i TYPE RANGE OF i.

    METHODS range_empty_selects_all FOR TESTING.
    METHODS range_include_eq FOR TESTING.
    METHODS range_include_bt FOR TESTING.
    METHODS range_exclude FOR TESTING.
    METHODS range_only_exclude FOR TESTING.
    METHODS range_pattern FOR TESTING.
    METHODS range_to_text FOR TESTING.
    METHODS range_to_text_more_lines FOR TESTING.
    METHODS conv_to_text FOR TESTING.
    METHODS check_boolean FOR TESTING.
    METHODS t_comp FOR TESTING.
    METHODS attri_name_by_ref FOR TESTING.
    METHODS fixed_values FOR TESTING.
    METHODS fixed_values_of_range FOR TESTING.
    METHODS no_value_help FOR TESTING.

ENDCLASS.


CLASS ltcl_attri IMPLEMENTATION.
ENDCLASS.


CLASS ltcl_test IMPLEMENTATION.

  METHOD range_empty_selects_all.

    DATA lt_range TYPE ty_t_range_i.

    cl_abap_unit_assert=>assert_equals( exp = abap_true
                                        act = z2ui5_cl_cgui_context=>range_check( val   = 5
                                                                                  range = lt_range ) ).

  ENDMETHOD.

  METHOD range_include_eq.

    DATA(lt_range) = VALUE ty_t_range_i( ( sign = `I` option = `EQ` low = 5 ) ).

    cl_abap_unit_assert=>assert_equals( exp = abap_true
                                        act = z2ui5_cl_cgui_context=>range_check( val   = 5
                                                                                  range = lt_range ) ).
    cl_abap_unit_assert=>assert_equals( exp = abap_false
                                        act = z2ui5_cl_cgui_context=>range_check( val   = 6
                                                                                  range = lt_range ) ).

  ENDMETHOD.

  METHOD range_include_bt.

    DATA(lt_range) = VALUE ty_t_range_i( ( sign = `I` option = `BT` low = 10 high = 20 ) ).

    cl_abap_unit_assert=>assert_equals( exp = abap_true
                                        act = z2ui5_cl_cgui_context=>range_check( val   = 10
                                                                                  range = lt_range ) ).
    cl_abap_unit_assert=>assert_equals( exp = abap_true
                                        act = z2ui5_cl_cgui_context=>range_check( val   = 20
                                                                                  range = lt_range ) ).
    cl_abap_unit_assert=>assert_equals( exp = abap_false
                                        act = z2ui5_cl_cgui_context=>range_check( val   = 21
                                                                                  range = lt_range ) ).

  ENDMETHOD.

  METHOD range_exclude.

    DATA(lt_range) = VALUE ty_t_range_i( ( sign = `I` option = `BT` low = 10 high = 20 )
                                         ( sign = `E` option = `EQ` low = 15 ) ).

    cl_abap_unit_assert=>assert_equals( exp = abap_true
                                        act = z2ui5_cl_cgui_context=>range_check( val   = 14
                                                                                  range = lt_range ) ).
    cl_abap_unit_assert=>assert_equals( exp = abap_false
                                        act = z2ui5_cl_cgui_context=>range_check( val   = 15
                                                                                  range = lt_range ) ).

  ENDMETHOD.

  METHOD range_only_exclude.

    DATA(lt_range) = VALUE ty_t_range_i( ( sign = `E` option = `GT` low = 100 ) ).

    cl_abap_unit_assert=>assert_equals( exp = abap_true
                                        act = z2ui5_cl_cgui_context=>range_check( val   = 50
                                                                                  range = lt_range ) ).
    cl_abap_unit_assert=>assert_equals( exp = abap_false
                                        act = z2ui5_cl_cgui_context=>range_check( val   = 150
                                                                                  range = lt_range ) ).

  ENDMETHOD.

  METHOD range_pattern.

    TYPES ty_t_range_c TYPE RANGE OF string.
    DATA(lt_range) = VALUE ty_t_range_c( ( sign = `I` option = `CP` low = `L*` ) ).

    cl_abap_unit_assert=>assert_equals( exp = abap_true
                                        act = z2ui5_cl_cgui_context=>range_check( val   = `LH`
                                                                                  range = lt_range ) ).
    cl_abap_unit_assert=>assert_equals( exp = abap_false
                                        act = z2ui5_cl_cgui_context=>range_check( val   = `AA`
                                                                                  range = lt_range ) ).

  ENDMETHOD.

  METHOD range_to_text.

    DATA(lt_range) = VALUE ty_t_range_i( ( sign = `I` option = `EQ` low = 5 )
                                         ( sign = `I` option = `BT` low = 10 high = 20 )
                                         ( sign = `E` option = `EQ` low = 15 ) ).

    cl_abap_unit_assert=>assert_equals( exp = `5; 10...20; !15`
                                        act = z2ui5_cl_cgui_context=>range_to_text( lt_range ) ).

  ENDMETHOD.

  METHOD range_to_text_more_lines.

    DATA(lt_range) = VALUE ty_t_range_i( ( sign = `I` option = `EQ` low = 1 )
                                         ( sign = `I` option = `EQ` low = 2 )
                                         ( sign = `I` option = `EQ` low = 3 )
                                         ( sign = `I` option = `EQ` low = 4 )
                                         ( sign = `I` option = `EQ` low = 5 ) ).

    cl_abap_unit_assert=>assert_equals( exp = `1; 2; 3 (+2)`
                                        act = z2ui5_cl_cgui_context=>range_to_text( lt_range ) ).

  ENDMETHOD.

  METHOD conv_to_text.

    DATA lv_date TYPE d.

    cl_abap_unit_assert=>assert_equals( exp = `text`
                                        act = z2ui5_cl_cgui_context=>conv_to_text( `text` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `42`
                                        act = z2ui5_cl_cgui_context=>conv_to_text( 42 ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cgui_context=>conv_to_text( lv_date ) ).

  ENDMETHOD.

  METHOD check_boolean.

    DATA lv_flag TYPE abap_bool.
    DATA lv_text TYPE string.

    cl_abap_unit_assert=>assert_equals( exp = abap_true
                                        act = z2ui5_cl_cgui_context=>rtti_check_boolean( lv_flag ) ).
    cl_abap_unit_assert=>assert_equals( exp = abap_false
                                        act = z2ui5_cl_cgui_context=>rtti_check_boolean( lv_text ) ).

  ENDMETHOD.

  METHOD t_comp.

    TYPES:
      BEGIN OF ty_s_row,
        id   TYPE i,
        name TYPE string,
      END OF ty_s_row.
    DATA lt_row TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.

    DATA(lt_comp) = z2ui5_cl_cgui_context=>rtti_get_t_comp( lt_row ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_comp ) ).
    cl_abap_unit_assert=>assert_equals( exp = `ID`
                                        act = lt_comp[ 1 ]-name ).
    cl_abap_unit_assert=>assert_equals( exp = `NAME`
                                        act = lt_comp[ 2 ]-label ).

  ENDMETHOD.

  METHOD attri_name_by_ref.

    DATA(lo_app) = NEW ltcl_attri( ).
    DATA(lv_copy) = lo_app->mv_text.

    cl_abap_unit_assert=>assert_equals( exp = `MV_TEXT`
                                        act = z2ui5_cl_cgui_context=>attri_name_by_ref( app = lo_app
                                                                                        val = lo_app->mv_text ) ).
    cl_abap_unit_assert=>assert_equals( exp = `MT_RANGE`
                                        act = z2ui5_cl_cgui_context=>attri_name_by_ref( app = lo_app
                                                                                        val = lo_app->mt_range ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cgui_context=>attri_name_by_ref( app = lo_app
                                                                                   val = lv_copy ) ).

  ENDMETHOD.

  METHOD fixed_values.

    DATA lv_flag TYPE xsdboolean.

    DATA(lt_fix) = z2ui5_cl_cgui_context=>rtti_get_fixed_values( cl_abap_typedescr=>describe_by_data( lv_flag ) ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_fix ) ).
    READ TABLE lt_fix WITH KEY low = `X` TRANSPORTING NO FIELDS.
    cl_abap_unit_assert=>assert_subrc( ).

  ENDMETHOD.

  METHOD fixed_values_of_range.

    DATA lt_range TYPE RANGE OF xsdboolean.

    DATA(lo_descr) = z2ui5_cl_cgui_context=>rtti_get_value_descr( lt_range ).

    cl_abap_unit_assert=>assert_equals( exp = cl_abap_typedescr=>kind_elem
                                        act = lo_descr->kind ).
    cl_abap_unit_assert=>assert_equals( exp = abap_true
                                        act = z2ui5_cl_cgui_context=>rtti_check_value_help( lo_descr ) ).

  ENDMETHOD.

  METHOD no_value_help.

    DATA lv_text TYPE string.
    DATA lv_char TYPE c LENGTH 10.

    cl_abap_unit_assert=>assert_equals( exp = abap_false
                                        act = z2ui5_cl_cgui_context=>rtti_check_value_help( cl_abap_typedescr=>describe_by_data( lv_text ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = abap_false
                                        act = z2ui5_cl_cgui_context=>rtti_check_value_help( cl_abap_typedescr=>describe_by_data( lv_char ) ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cgui_context=>rtti_get_value_table( cl_abap_typedescr=>describe_by_data( lv_char ) ) ).

  ENDMETHOD.

ENDCLASS.
