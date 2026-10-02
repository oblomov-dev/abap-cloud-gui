CLASS ltcl_test DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS chain_layout FOR TESTING.
    METHODS chain_single_call FOR TESTING.
    METHODS check_ok FOR TESTING.
    METHODS check_problems FOR TESTING.
    METHODS check_blocks FOR TESTING.
    METHODS type_create FOR TESTING.
    METHODS range_create FOR TESTING.
    METHODS generate_class FOR TESTING.
    METHODS literal_backtick FOR TESTING.

ENDCLASS.


CLASS ltcl_test IMPLEMENTATION.

  METHOD chain_layout.

    DATA(lt_line) = z2ui5_cl_cgui_painter_code=>selection_screen( VALUE #(
        ( kind = `BLOCK_BEGIN` text = `Flights` )
        ( kind = `PARAMETER` name = `P_CARRID` type = `c LENGTH 3` text = `Airline` value_help = abap_true )
        ( kind = `SELECT_OPTION` name = `s_fldate` type = `d` )
        ( kind = `BLOCK_END` )
        ( kind = `BUTTON` text = `Reset` group = `reset` type = `sap-icon://reset` ) ) ).

    cl_abap_unit_assert=>assert_equals(
        act = lt_line
        exp = VALUE string_table(
            ( `    screen->block_begin( ``Flights``` )
            ( `        )->parameter( val        = p_carrid` )
            ( `                      text       = ``Airline``` )
            ( `                      value_help = abap_true` )
            ( `        )->select_option( val = s_fldate` )
            ( `        )->block_end(` )
            ( `        )->button( text  = ``Reset``` )
            ( `                   event = ``RESET``` )
            ( `                   icon  = ``sap-icon://reset`` ).` ) ) ).

  ENDMETHOD.

  METHOD chain_single_call.

    cl_abap_unit_assert=>assert_equals(
        act = z2ui5_cl_cgui_painter_code=>selection_screen( VALUE #( ( kind = `COMMENT` text = `Hello` ) ) )
        exp = VALUE string_table( ( `    screen->comment( ``Hello`` ).` ) ) ).
    cl_abap_unit_assert=>assert_equals(
        act = z2ui5_cl_cgui_painter_code=>selection_screen( VALUE #( ( kind = `BLOCK_END` ) ) )
        exp = VALUE string_table( ( `    screen->block_end( ).` ) ) ).

  ENDMETHOD.

  METHOD check_ok.

    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cgui_painter_code=>check( VALUE #(
        ( kind = `BLOCK_BEGIN` )
        ( kind = `PARAMETER` name = `p_a` type = `c LENGTH 10` )
        ( kind = `LINE_BEGIN` text = `Range` )
        ( kind = `PARAMETER` name = `p_from` type = `i` )
        ( kind = `PARAMETER` name = `p_to` type = `p LENGTH 8 DECIMALS 2` )
        ( kind = `LINE_END` )
        ( kind = `SELECT_OPTION` name = `s_b` type = `xsdboolean` )
        ( kind = `CHECKBOX` name = `p_c` )
        ( kind = `BLOCK_END` )
        ( kind = `BUTTON` text = `Go` group = `GO` ) ) ) ).

  ENDMETHOD.

  METHOD check_problems.

    DATA(lt_message) = z2ui5_cl_cgui_painter_code=>check( VALUE #(
        ( kind = `PARAMETER` type = `i` )
        ( kind = `PARAMETER` name = `1abc` type = `i` )
        ( kind = `PARAMETER` name = `p_x` )
        ( kind = `PARAMETER` name = `P_X` type = `c LENGHT 3` )
        ( kind = `CHECKBOX` name = `client` )
        ( kind = `BUTTON` text = `Go` )
        ( kind = `COMMENT` )
        ( kind = `PARAMETER` name = `p-x` type = `i` ) ) ).

    " line 4 has two: the name is taken, and LENGHT is no keyword
    cl_abap_unit_assert=>assert_equals( exp = 9
                                        act = lines( lt_message ) ).
    cl_abap_unit_assert=>assert_char_cp( act = lt_message[ 4 ]
                                         exp = `Line 4: P_X is declared twice` ).
    cl_abap_unit_assert=>assert_char_cp( act = lt_message[ 9 ]
                                         exp = `Line 8: p-x is no name*` ).

  ENDMETHOD.

  METHOD check_blocks.

    DATA(lt_message) = z2ui5_cl_cgui_painter_code=>check( VALUE #(
        ( kind = `BLOCK_BEGIN` )
        ( kind = `BLOCK_BEGIN` )
        ( kind = `LINE_END` )
        ( kind = `LINE_BEGIN` ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = 4
                                        act = lines( lt_message ) ).

  ENDMETHOD.

  METHOD type_create.

    FIELD-SYMBOLS <val> TYPE any.

    DATA(lr_data) = z2ui5_cl_cgui_painter_code=>type_create( `c LENGTH 7` ).
    ASSIGN lr_data->* TO <val>.
    DATA(lo_descr) = cl_abap_typedescr=>describe_by_data( <val> ).
    cl_abap_unit_assert=>assert_equals( exp = cl_abap_typedescr=>typekind_char
                                        act = lo_descr->type_kind ).
    cl_abap_unit_assert=>assert_equals( exp = 7
                                        act = CAST cl_abap_elemdescr( lo_descr )->output_length ).

    lr_data = z2ui5_cl_cgui_painter_code=>type_create( `D` ).
    cl_abap_unit_assert=>assert_equals( exp = cl_abap_typedescr=>typekind_date
                                        act = cl_abap_typedescr=>describe_by_data_ref( lr_data )->type_kind ).

    cl_abap_unit_assert=>assert_bound( z2ui5_cl_cgui_painter_code=>type_create( `p LENGTH 8 DECIMALS 2` ) ).
    cl_abap_unit_assert=>assert_bound( z2ui5_cl_cgui_painter_code=>type_create( `xsdboolean` ) ).
    cl_abap_unit_assert=>assert_not_bound( z2ui5_cl_cgui_painter_code=>type_create( `c LENGTH x` ) ).
    cl_abap_unit_assert=>assert_not_bound( z2ui5_cl_cgui_painter_code=>type_create( `i DECIMALS 2` ) ).
    cl_abap_unit_assert=>assert_not_bound( z2ui5_cl_cgui_painter_code=>type_create( `no_such_type_zz` ) ).

  ENDMETHOD.

  METHOD range_create.

    FIELD-SYMBOLS <range> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <line>  TYPE any.
    FIELD-SYMBOLS <low>   TYPE any.

    DATA(lr_range) = z2ui5_cl_cgui_painter_code=>range_create( `n LENGTH 4` ).
    ASSIGN lr_range->* TO <range>.
    INSERT INITIAL LINE INTO TABLE <range> ASSIGNING <line>.
    ASSIGN COMPONENT `LOW` OF STRUCTURE <line> TO <low>.

    cl_abap_unit_assert=>assert_equals( exp = cl_abap_typedescr=>typekind_num
                                        act = cl_abap_typedescr=>describe_by_data( <low> )->type_kind ).
    cl_abap_unit_assert=>assert_not_bound( z2ui5_cl_cgui_painter_code=>range_create( `c LENGTH` ) ).

  ENDMETHOD.

  METHOD generate_class.

    DATA(lv_code) = z2ui5_cl_cgui_painter_code=>generate(
        class    = `ZCL_TEST`
        elements = VALUE #( ( kind = `SELECT_OPTION` name = `s_carrid` type = `c LENGTH 3` )
                            ( kind = `SELECT_OPTION` name = `s_date` type = `d` )
                            ( kind = `CHECKBOX` name = `p_test` modif_id = `t` user_command = `test` ) ) ).

    cl_abap_unit_assert=>assert_char_cp( act = lv_code
                                         exp = `CLASS zcl_test DEFINITION PUBLIC*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_code
                                         exp = `*TYPES ty_s_carrid TYPE c LENGTH 3.*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_code
                                         exp = `*DATA s_carrid TYPE RANGE OF ty_s_carrid.*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_code
                                         exp = `*DATA s_date   TYPE RANGE OF d.*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_code
                                         exp = `*METHODS at_selection_screen_output REDEFINITION.*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_code
                                         exp = `*WHEN ``TEST``.*` ).
    cl_abap_unit_assert=>assert_char_np( act = lv_code
                                         exp = `*TEST pressed*` ).

  ENDMETHOD.

  METHOD literal_backtick.

    DATA(lt_line) = z2ui5_cl_cgui_painter_code=>selection_screen( VALUE #( ( kind = `COMMENT` text = `a ``b`` c` ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = `    screen->comment( ``a ````b```` c`` ).`
                                        act = lt_line[ 1 ] ).

  ENDMETHOD.

ENDCLASS.
