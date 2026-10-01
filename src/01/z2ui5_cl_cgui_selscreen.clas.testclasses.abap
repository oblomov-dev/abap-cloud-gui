CLASS ltcl_app DEFINITION FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA mv_text   TYPE string.
    DATA mv_date   TYPE d.
    DATA mv_flag   TYPE abap_bool.
    DATA mv_rb_a   TYPE abap_bool.
    DATA mv_rb_b   TYPE abap_bool.
    DATA mv_hidden TYPE string.
    DATA mt_flag   TYPE RANGE OF xsdboolean.
    DATA mt_text   TYPE RANGE OF string.

ENDCLASS.


" the client the selection screen talks to: a binding names the attribute,
" an event names the event - enough to read the rendered view
CLASS ltcl_client DEFINITION FINAL FOR TESTING.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_client PARTIALLY IMPLEMENTED.

    DATA mo_app TYPE REF TO ltcl_app.

ENDCLASS.


CLASS ltcl_test DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_app    TYPE REF TO ltcl_app.
    DATA mo_client TYPE REF TO ltcl_client.

    METHODS setup.

    METHODS screen
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_selscreen.

    METHODS loop_at_screen FOR TESTING.
    METHODS modify_hides_field FOR TESTING.
    METHODS hidden_block_leaves_no_frame FOR TESTING.
    METHODS read_only_and_invisible FOR TESTING.
    METHODS obligatory_follows_screen FOR TESTING.
    METHODS value_state FOR TESTING.
    METHODS radio_group_user_command FOR TESTING.
    METHODS checkbox_user_command FOR TESTING.
    METHODS value_help_auto FOR TESTING.
    METHODS select_option_without_help FOR TESTING.
    METHODS preview FOR TESTING.

ENDCLASS.


CLASS ltcl_app IMPLEMENTATION.

  METHOD z2ui5_if_app~main ##NEEDED.
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_client IMPLEMENTATION.

  METHOD z2ui5_if_client~get_app.

    result = mo_app.

  ENDMETHOD.

  METHOD z2ui5_if_client~_bind.

    result = |\{/{ z2ui5_cl_cgui_context=>attri_name_by_ref( app = mo_app
                                                             val = val ) }\}|.

  ENDMETHOD.

  METHOD z2ui5_if_client~_event.

    result = |EVENT:{ val }|.

  ENDMETHOD.

ENDCLASS.


CLASS ltcl_test IMPLEMENTATION.

  METHOD setup.

    mo_app = NEW #( ).
    mo_client = NEW #( ).
    mo_client->mo_app = mo_app.

  ENDMETHOD.

  METHOD screen.

    result = z2ui5_cl_cgui_selscreen=>factory( mo_client ).
    result->block_begin( `Main`
        )->parameter( val        = mo_app->mv_text
                      text       = `Text`
                      obligatory = abap_true
                      modif_id   = `G1`
        )->parameter( val = mo_app->mv_date
                      text = `Date`
        )->comment( text     = `A comment`
                    modif_id = `G1`
        )->button( text  = `Press`
                   event = `PRESS`
        )->parameter( val        = mo_app->mv_hidden
                      no_display = abap_true
        )->block_end( ).

  ENDMETHOD.

  METHOD loop_at_screen.

    DATA(lt_screen) = screen( )->loop_at_screen( ).

    cl_abap_unit_assert=>assert_equals( exp = 4
                                        act = lines( lt_screen ) ).

    DATA(ls_screen) = lt_screen[ 1 ].
    cl_abap_unit_assert=>assert_equals( exp = `MV_TEXT`
                                        act = ls_screen-name ).
    cl_abap_unit_assert=>assert_equals( exp = `G1`
                                        act = ls_screen-group1 ).
    cl_abap_unit_assert=>assert_equals( exp = abap_true
                                        act = ls_screen-active ).
    cl_abap_unit_assert=>assert_equals( exp = abap_true
                                        act = ls_screen-input ).
    cl_abap_unit_assert=>assert_equals( exp = abap_true
                                        act = ls_screen-required ).

    cl_abap_unit_assert=>assert_equals( exp = `G1`
                                        act = lt_screen[ 3 ]-group1 ).

  ENDMETHOD.

  METHOD modify_hides_field.

    DATA(lo_screen) = screen( ).
    DATA(lt_screen) = lo_screen->loop_at_screen( ).

    LOOP AT lt_screen INTO DATA(ls_screen) WHERE group1 = `G1`.
      ls_screen-active = abap_false.
      lo_screen->modify_screen( ls_screen ).
    ENDLOOP.

    DATA(lv_view) = lo_screen->stringify( ).
    cl_abap_unit_assert=>assert_char_np( act = lv_view
                                         exp = `*{/MV_TEXT}*` ).
    cl_abap_unit_assert=>assert_char_np( act = lv_view
                                         exp = `*A comment*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_view
                                         exp = `*{/MV_DATE}*` ).
    cl_abap_unit_assert=>assert_char_np( act = lv_view
                                         exp = `*{/MV_HIDDEN}*` ).

  ENDMETHOD.

  METHOD hidden_block_leaves_no_frame.

    DATA(lo_screen) = z2ui5_cl_cgui_selscreen=>factory( mo_client ).
    lo_screen->block_begin( `Visible`
        )->parameter( mo_app->mv_text
        )->block_end(
        )->block_begin( `Hidden`
        )->parameter( val      = mo_app->mv_date
                      modif_id = `X`
        )->block_end( ).

    DATA(lt_screen) = lo_screen->loop_at_screen( ).
    LOOP AT lt_screen INTO DATA(ls_screen) WHERE group1 = `X`.
      ls_screen-active = abap_false.
      lo_screen->modify_screen( ls_screen ).
    ENDLOOP.

    DATA(lv_view) = lo_screen->stringify( ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_view
                                         exp = `*Visible*` ).
    cl_abap_unit_assert=>assert_char_np( act = lv_view
                                         exp = `*Hidden*` ).

  ENDMETHOD.

  METHOD read_only_and_invisible.

    DATA(lo_screen) = z2ui5_cl_cgui_selscreen=>factory( mo_client ).
    lo_screen->parameter( mo_app->mv_text ).

    DATA(lt_screen) = lo_screen->loop_at_screen( ).
    DATA(ls_screen) = lt_screen[ 1 ].
    ls_screen-input = abap_false.
    ls_screen-invisible = abap_true.
    lo_screen->modify_screen( ls_screen ).

    DATA(lv_view) = lo_screen->stringify( ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_view
                                         exp = `*editable="false"*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_view
                                         exp = `*type="Password"*` ).

  ENDMETHOD.

  METHOD obligatory_follows_screen.

    DATA(lo_screen) = screen( ).
    DATA(lt_screen) = lo_screen->loop_at_screen( ).

    " the date becomes required, the text read-only
    DATA(ls_screen) = lt_screen[ 2 ].
    ls_screen-required = abap_true.
    lo_screen->modify_screen( ls_screen ).
    ls_screen = lt_screen[ 1 ].
    ls_screen-input = abap_false.
    lo_screen->modify_screen( ls_screen ).

    DATA(lt_field) = lo_screen->get_fields( ).
    cl_abap_unit_assert=>assert_equals( exp = abap_false
                                        act = lt_field[ name = `MV_TEXT` ]-obligatory ).
    cl_abap_unit_assert=>assert_equals( exp = abap_true
                                        act = lt_field[ name = `MV_DATE` ]-obligatory ).
    cl_abap_unit_assert=>assert_equals( exp = abap_true
                                        act = lt_field[ name = `MV_TEXT` ]-shown ).
    cl_abap_unit_assert=>assert_equals( exp = abap_false
                                        act = lt_field[ name = `MV_HIDDEN` ]-shown ).

  ENDMETHOD.

  METHOD value_state.

    DATA(lo_screen) = screen( ).
    lo_screen->set_value_state( name = `mv_date`
                                text = `Date in the past` ).

    DATA(lv_view) = lo_screen->stringify( ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_view
                                         exp = `*valueState="Error"*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_view
                                         exp = `*valueStateText="Date in the past"*` ).

  ENDMETHOD.

  METHOD radio_group_user_command.

    mo_app->mv_rb_a = abap_true.
    DATA(lo_screen) = z2ui5_cl_cgui_selscreen=>factory( mo_client ).
    lo_screen->radiobutton( val          = mo_app->mv_rb_a
                            group        = `G`
                            user_command = `MODE`
        )->radiobutton( val   = mo_app->mv_rb_b
                        group = `G` ).

    DATA(lv_view) = lo_screen->stringify( ).
    " declared at A, it applies to the whole group - but only B, the button
    " not selected, raises it
    FIND ALL OCCURRENCES OF `select="EVENT:MODE"` IN lv_view MATCH COUNT DATA(lv_count).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lv_count ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_view
                                         exp = `*{/MV_RB_B}" editable="true" select="EVENT:MODE"*` ).

  ENDMETHOD.

  METHOD checkbox_user_command.

    DATA(lo_screen) = z2ui5_cl_cgui_selscreen=>factory( mo_client ).
    lo_screen->checkbox( val          = mo_app->mv_flag
                         user_command = `FLAG` ).

    cl_abap_unit_assert=>assert_char_cp( act = lo_screen->stringify( )
                                         exp = `*select="EVENT:FLAG"*` ).

  ENDMETHOD.

  METHOD value_help_auto.

    " XSDBOOLEAN has fixed values: F4 picks values, a button of its own
    " opens the range popup
    DATA(lo_screen) = z2ui5_cl_cgui_selscreen=>factory( client          = mo_client
                                                        value_help_auto = abap_true ).
    lo_screen->select_option( mo_app->mt_flag ).

    DATA(lv_view) = lo_screen->stringify( ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_view
                                         exp = `*valueHelpRequest="EVENT:CGUI_VALUE_REQUEST"*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_view
                                         exp = `*tooltip="Multiple selection" enabled="true" class="sapUiTinyMarginBegin" press="EVENT:CGUI_SELECT_OPTION"*` ).

  ENDMETHOD.

  METHOD select_option_without_help.

    " no fixed values - and without value_help_auto none are looked up
    DATA(lo_screen) = z2ui5_cl_cgui_selscreen=>factory( client          = mo_client
                                                        value_help_auto = abap_true ).
    lo_screen->select_option( mo_app->mt_text ).
    DATA(lo_plain) = z2ui5_cl_cgui_selscreen=>factory( mo_client ).
    lo_plain->select_option( mo_app->mt_flag ).

    DATA(lv_view) = lo_screen->stringify( ) && lo_plain->stringify( ).
    cl_abap_unit_assert=>assert_char_np( act = lv_view
                                         exp = `*CGUI_VALUE_REQUEST*` ).
    cl_abap_unit_assert=>assert_char_np( act = lv_view
                                         exp = `*Multiple selection*` ).

  ENDMETHOD.

  METHOD preview.

    " no attribute, nothing bound - a flag shows its value
    DATA lv_flag TYPE abap_bool VALUE abap_true.
    DATA lv_text TYPE c LENGTH 10.
    DATA lt_range TYPE RANGE OF i.

    DATA(lo_screen) = z2ui5_cl_cgui_selscreen=>factory( client  = mo_client
                                                        preview = abap_true ).
    lo_screen->radiobutton( lv_flag
        )->parameter( val  = lv_text
                      text = `Local`
        )->select_option( val  = lt_range
                          text = `Range` ).

    DATA(lv_view) = lo_screen->stringify( ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_view
                                         exp = `*<RadioButton*selected="true"*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_view
                                         exp = `*<Label text="Range"*` ).
    cl_abap_unit_assert=>assert_char_np( act = lv_view
                                         exp = `*{/*` ).

  ENDMETHOD.

ENDCLASS.
