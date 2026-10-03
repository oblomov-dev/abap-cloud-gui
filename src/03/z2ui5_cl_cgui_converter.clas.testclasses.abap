CLASS ltcl_test DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS source
      RETURNING
        VALUE(result) TYPE string_table.

    METHODS convert
      RETURNING
        VALUE(result) TYPE z2ui5_cl_cgui_converter=>ty_s_result.

    METHODS has
      IMPORTING
        code TYPE string
        part TYPE string.

    METHODS split_and_chain FOR TESTING.
    METHODS selection_screen FOR TESTING.
    METHODS defaults_into_initialization FOR TESTING.
    METHODS events_into_methods FOR TESTING.
    METHODS write_and_format FOR TESTING.
    METHODS messages FOR TESTING.
    METHODS forms_and_performs FOR TESTING.
    METHODS loop_at_screen FOR TESTING.
    METHODS texts_from_pool FOR TESTING.
    METHODS notes FOR TESTING.
    METHODS lists_r11 FOR TESTING.
    METHODS screen_events_r11 FOR TESTING.
    METHODS alv_and_popups FOR TESTING.
    METHODS salv_handlers FOR TESTING.
    METHODS grid_on_screen FOR TESTING.

ENDCLASS.


CLASS ltcl_test IMPLEMENTATION.

  METHOD source.

    result = VALUE #(
        ( `REPORT zflights MESSAGE-ID zfl.` )
        ( `` )
        ( `TABLES sflight.` )
        ( `DATA gt_flight TYPE STANDARD TABLE OF sflight.` )
        ( `` )
        ( `SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.` )
        ( `PARAMETERS: p_carrid TYPE s_carr_id OBLIGATORY DEFAULT 'LH',` )
        ( `            p_max(4) TYPE n DEFAULT '100'.` )
        ( `SELECT-OPTIONS s_fldate FOR sflight-fldate NO-EXTENSION.` )
        ( `SELECTION-SCREEN END OF BLOCK b1.` )
        ( `SELECTION-SCREEN SKIP 1.` )
        ( `SELECTION-SCREEN COMMENT /1(30) TEXT-c01.` )
        ( `PARAMETERS p_alv RADIOBUTTON GROUP out DEFAULT 'X' USER-COMMAND out.` )
        ( `PARAMETERS p_list RADIOBUTTON GROUP out.` )
        ( `PARAMETERS p_zebra AS CHECKBOX MODIF ID lst.` )
        ( `SELECTION-SCREEN PUSHBUTTON /1(20) TEXT-p01 USER-COMMAND reset.` )
        ( `` )
        ( `INITIALIZATION.` )
        ( `  p_max = 50.` )
        ( `` )
        ( `AT SELECTION-SCREEN OUTPUT.` )
        ( `  LOOP AT SCREEN.` )
        ( `    IF screen-group1 = 'LST' AND p_list IS INITIAL.` )
        ( `      screen-active = 0.` )
        ( `      MODIFY SCREEN.` )
        ( `    ENDIF.` )
        ( `  ENDLOOP.` )
        ( `` )
        ( `AT SELECTION-SCREEN ON p_max.` )
        ( `  IF p_max > 1000.` )
        ( `    MESSAGE e001 WITH p_max.` )
        ( `  ENDIF.` )
        ( `` )
        ( `AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_carrid.` )
        ( `  PERFORM f4_carrid.` )
        ( `` )
        ( `START-OF-SELECTION.` )
        ( `  " read the flights` )
        ( `  SELECT * FROM sflight INTO TABLE gt_flight UP TO p_max ROWS` )
        ( `    WHERE carrid = p_carrid AND fldate IN s_fldate.` )
        ( `  PERFORM output USING p_carrid CHANGING gt_flight.` )
        ( `` )
        ( `TOP-OF-PAGE.` )
        ( `  WRITE: / TEXT-h01, sy-datum.` )
        ( `  ULINE.` )
        ( `` )
        ( `AT LINE-SELECTION.` )
        ( `  MESSAGE 'Line selected' TYPE 'I'.` )
        ( `` )
        ( `FORM output USING iv_carrid TYPE s_carr_id` )
        ( `            CHANGING ct_flight LIKE gt_flight.` )
        ( `  DATA ls_flight TYPE sflight.` )
        ( `  FORMAT COLOR COL_POSITIVE.` )
        ( `  LOOP AT ct_flight INTO ls_flight.` )
        ( `    WRITE: / ls_flight-connid HOTSPOT, 20(10) ls_flight-fldate.` )
        ( `    HIDE ls_flight-connid.` )
        ( `  ENDLOOP.` )
        ( `  FORMAT RESET.` )
        ( `  SET PARAMETER ID 'CAR' FIELD iv_carrid.` )
        ( `ENDFORM.` )
        ( `` )
        ( `FORM f4_carrid.` )
        ( `  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'.` )
        ( `ENDFORM.` ) ).

  ENDMETHOD.

  METHOD convert.

    result = z2ui5_cl_cgui_converter=>convert(
        source = source( )
        class  = `zcl_flights`
        texts  = VALUE #( ( id = `I` key = `B01` entry = `Flights` )
                          ( id = `I` key = `C01` entry = `Output` )
                          ( id = `I` key = `P01` entry = `Reset` )
                          ( id = `I` key = `H01` entry = `Flight list` )
                          ( id = `S` key = `P_MAX` entry = `Maximum rows` ) ) ).

  ENDMETHOD.

  METHOD has.

    " the code without its indentation - the parts are compared word by word
    DATA lt_line TYPE string_table.
    SPLIT code AT cl_abap_char_utilities=>newline INTO TABLE lt_line.
    DATA(lv_flat) = ``.
    LOOP AT lt_line INTO DATA(lv_line).
      lv_flat = |{ lv_flat } { condense( lv_line ) }|.
    ENDLOOP.
    lv_flat = condense( lv_flat ).

    IF lv_flat NS condense( part ).
      cl_abap_unit_assert=>fail( msg = |not in the code: { part }| ).
    ENDIF.

  ENDMETHOD.

  METHOD split_and_chain.

    DATA(lt_stmt) = z2ui5_cl_cgui_converter=>split( VALUE #( ( `WRITE: 'a.b', / x. " comment.` )
                                                             ( `* a comment line.` )
                                                             ( `DATA y TYPE c.` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_stmt )
                                        exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_stmt[ 1 ]-code
                                        exp = `WRITE: 'a.b', / x` ).

    DATA(lt_chain) = z2ui5_cl_cgui_converter=>chain_expand( `WRITE: 'a,b', / x, y(10)` ).
    cl_abap_unit_assert=>assert_equals( act = lt_chain
                                        exp = VALUE string_table( ( `WRITE 'a,b'` ) ( `WRITE / x` ) ( `WRITE y(10)` ) ) ).

  ENDMETHOD.

  METHOD selection_screen.

    DATA(lv_code) = convert( )-code.

    has( code = lv_code part = `CLASS zcl_flights DEFINITION PUBLIC INHERITING FROM z2ui5_cl_cgui_report` ).
    has( code = lv_code part = `DATA p_carrid TYPE s_carr_id.` ).
    has( code = lv_code part = `DATA p_max TYPE n LENGTH 4.` ).
    has( code = lv_code part = `DATA s_fldate LIKE RANGE OF sflight-fldate.` ).
    has( code = lv_code part = `DATA p_alv TYPE abap_bool.` ).
    has( code = lv_code part = `DATA sflight TYPE sflight.` ).
    has( code = lv_code part = 'screen->block_begin( `Flights` ).' ).
    has( code = lv_code part = `screen->parameter( val = p_carrid obligatory = abap_true value_help = abap_true ).` ).
    has( code = lv_code part = 'screen->parameter( val = p_max text = `Maximum rows` ).' ).
    has( code = lv_code part = `screen->select_option( val = s_fldate no_extension = abap_true ).` ).
    has( code = lv_code part = `screen->skip( 1 ).` ).
    has( code = lv_code part = 'screen->comment( `Output` ).' ).
    has( code = lv_code part = 'screen->radiobutton( val = p_alv group = `OUT` user_command = `OUT` ).' ).
    has( code = lv_code part = 'screen->checkbox( val = p_zebra modif_id = `LST` ).' ).
    has( code = lv_code part = 'screen->button( text = `Reset` event = `RESET` ).' ).

  ENDMETHOD.

  METHOD defaults_into_initialization.

    DATA(lv_code) = convert( )-code.

    has( code = lv_code part = `METHOD initialization. p_carrid = 'LH'. p_max = '100'. p_alv = abap_true. p_max = 50.` ).

  ENDMETHOD.

  METHOD events_into_methods.

    DATA(lv_code) = convert( )-code.

    has( code = lv_code part = `METHODS at_selection_screen_output REDEFINITION.` ).
    has( code = lv_code part = `METHODS at_selection_screen_on REDEFINITION.` ).
    has( code = lv_code part = `METHODS at_value_request REDEFINITION.` ).
    has( code = lv_code part = `METHODS start_of_selection REDEFINITION.` ).
    has( code = lv_code part = `METHODS top_of_page REDEFINITION.` ).
    has( code = lv_code part = `METHODS at_line_selection REDEFINITION.` ).
    has( code = lv_code part = 'CASE field. WHEN `P_MAX`. IF p_max > 1000.' ).
    has( code = lv_code part = 'CASE field. WHEN `P_CARRID`. f4_carrid( ). WHEN OTHERS. super->at_value_request( field ). ENDCASE.' ).
    has( code = lv_code part = `" read the flights SELECT * FROM sflight INTO TABLE gt_flight UP TO p_max ROWS WHERE carrid = p_carrid AND fldate IN s_fldate.` ).

  ENDMETHOD.

  METHOD write_and_format.

    DATA(lv_code) = convert( )-code.

    has( code = lv_code part = 'list( )->new_line( ). write( `Flight list` ). write( sy-datum ). list( )->uline( ).' ).
    has( code = lv_code part = `write( val = ls_flight-connid color = z2ui5_cl_cgui_list=>cs_color-positive hotspot = abap_true ).` ).
    has( code = lv_code part = `write( val = ls_flight-fldate pos = 20 len = 10 color = z2ui5_cl_cgui_list=>cs_color-positive ).` ).
    has( code = lv_code part = `list( )->hide( ls_flight-connid ).` ).

  ENDMETHOD.

  METHOD messages.

    DATA(lv_code) = convert( )-code.

    has( code = lv_code part = 'message_t100( id = `ZFL` number = 001 type = `E` v1 = p_max ).' ).
    has( code = lv_code part = 'message( text = `Line selected` type = ''I'' ).' ).
    has( code = lv_code part = `set_parameter_id( id = 'CAR' value = iv_carrid ).` ).

  ENDMETHOD.

  METHOD forms_and_performs.

    DATA(lv_code) = convert( )-code.

    has( code = lv_code part = `METHODS output IMPORTING iv_carrid TYPE s_carr_id CHANGING ct_flight like gt_flight.` ).
    has( code = lv_code part = `METHODS f4_carrid.` ).
    has( code = lv_code part = `output( EXPORTING iv_carrid = p_carrid CHANGING ct_flight = gt_flight ).` ).
    has( code = lv_code part = `METHOD output. DATA ls_flight TYPE sflight.` ).

  ENDMETHOD.

  METHOD loop_at_screen.

    DATA(lv_code) = convert( )-code.

    has( code = lv_code part = `LOOP AT screen->loop_at_screen( ) INTO DATA(ls_screen).` ).
    has( code = lv_code part = `IF ls_screen-group1 = 'LST' AND p_list IS INITIAL.` ).
    has( code = lv_code part = `ls_screen-active = abap_false.` ).
    has( code = lv_code part = `screen->modify_screen( ls_screen ).` ).

  ENDMETHOD.

  METHOD texts_from_pool.

    DATA(lv_code) = z2ui5_cl_cgui_converter=>convert(
        source = VALUE #( ( `START-OF-SELECTION.` )
                          ( `  WRITE TEXT-001.` )
                          ( `  DATA(lv) = 'Fallback'(002).` ) )
        texts  = VALUE #( ( id = `I` key = `001` entry = `Hello` ) ) )-code.

    has( code = lv_code part = 'write( `Hello` ).' ).
    has( code = lv_code part = 'DATA(lv) = `Fallback`.' ).

  ENDMETHOD.

  METHOD notes.

    DATA(lt_note) = convert( )-notes.

    cl_abap_unit_assert=>assert_not_initial( lt_note ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_note[ table_line = `TABLES became work areas of their table (DATA ... TYPE table)` ] ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_note[ table_line = `F4IF_INT_TABLE_VALUE_REQUEST: answer at_value_request( ) with value_help_popup( tab = ... col = ... )` ] ) ) ).

  ENDMETHOD.

  METHOD lists_r11.

    DATA(lv_code) = z2ui5_cl_cgui_converter=>convert(
        source = VALUE #( ( `REPORT zlist LINE-SIZE 120 LINE-COUNT 65(2) NO STANDARD PAGE HEADING.` )
                          ( `DATA gv_sum TYPE p LENGTH 10 DECIMALS 2.` )
                          ( `DATA gv_lines TYPE i.` )
                          ( `START-OF-SELECTION.` )
                          ( `  FORMAT INTENSIFIED ON.` )
                          ( `  WRITE: / 'Amount', gv_sum CURRENCY 'EUR' NO-ZERO RIGHT-JUSTIFIED.` )
                          ( `  FORMAT INTENSIFIED OFF.` )
                          ( `  WRITE / sy-datum DD/MM/YYYY.` )
                          ( `  WRITE / gv_sum UNDER 'Amount' INPUT ON.` )
                          ( `  ULINE /5(40).` )
                          ( `  SKIP TO LINE 3.` )
                          ( `  RESERVE 5 LINES.` )
                          ( `  NEW-PAGE NO-HEADING LINE-COUNT 30.` )
                          ( `  WINDOW STARTING AT 10 5 ENDING AT 70 20.` )
                          ( `  DESCRIBE LIST NUMBER OF LINES gv_lines.` )
                          ( `END-OF-PAGE.` )
                          ( `  WRITE sy-pagno.` )
                          ( `AT LINE-SELECTION.` )
                          ( `  GET CURSOR FIELD gv_field VALUE gv_value.` ) )
        class  = `zcl_list` )-code.

    has( code = lv_code part = `METHOD start_of_selection. list( )->set_line_size( 120 ). set_line_count( 65 ).` ).
    has( code = lv_code part = 'write( val = `Amount` intensified = abap_true name = `AMOUNT` ).' ).
    has( code = lv_code part = 'write( val = gv_sum intensified = abap_true currency = `EUR` no_zero = abap_true justify = z2ui5_cl_cgui_list=>cs_justify-right ).' ).
    has( code = lv_code part = `write( val = sy-datum date_format = z2ui5_cl_cgui_list=>cs_date_format-dd_mm_yyyy ).` ).
    has( code = lv_code part = 'write( val = gv_sum input = abap_true under = `AMOUNT` ).' ).
    has( code = lv_code part = `list( )->uline( pos = 5 len = 40 ).` ).
    has( code = lv_code part = `list( )->skip_to_line( 3 ).` ).
    has( code = lv_code part = `list( )->reserve( 5 ).` ).
    has( code = lv_code part = `list( )->new_page( no_heading = abap_true line_count = 30 ).` ).
    has( code = lv_code part = `window( columns = 60 lines = 15 ).` ).
    has( code = lv_code part = `gv_lines = list( )->describe_lines( ).` ).
    has( code = lv_code part = `METHOD end_of_page. write( list( )->current_page( ) ).` ).
    has( code = lv_code part = `gv_field = get_cursor( )-field. gv_value = get_cursor( )-value.` ).

  ENDMETHOD.

  METHOD screen_events_r11.

    DATA(lv_code) = z2ui5_cl_cgui_converter=>convert(
        source = VALUE #( ( `REPORT zscreen.` )
                          ( `SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME NO INTERVALS.` )
                          ( `SELECT-OPTIONS s_carr FOR sflight-carrid MATCHCODE OBJECT h_scarr MEMORY ID car.` )
                          ( `SELECTION-SCREEN COMMENT /1(20) TEXT-001 FOR FIELD p_max.` )
                          ( `PARAMETERS p_max TYPE i.` )
                          ( `SELECTION-SCREEN END OF BLOCK b1.` )
                          ( `SELECTION-SCREEN FUNCTION KEY 1.` )
                          ( `AT SELECTION-SCREEN ON BLOCK b1.` )
                          ( `  CHECK p_max > 0.` )
                          ( `AT SELECTION-SCREEN ON RADIOBUTTON GROUP out.` )
                          ( `  CLEAR p_max.` )
                          ( `AT SELECTION-SCREEN ON VALUE-REQUEST FOR s_carr-low.` )
                          ( `  PERFORM f4_low.` )
                          ( `AT SELECTION-SCREEN ON VALUE-REQUEST FOR s_carr-high.` )
                          ( `  PERFORM f4_high.` )
                          ( `AT SELECTION-SCREEN ON HELP-REQUEST FOR p_max.` )
                          ( `  MESSAGE 'Help' TYPE 'I'.` )
                          ( `AT SELECTION-SCREEN ON EXIT-COMMAND.` )
                          ( `  CLEAR p_max.` )
                          ( `AT SELECTION-SCREEN OUTPUT.` )
                          ( `  LOOP AT SCREEN.` )
                          ( `    screen-intensified = 1.` )
                          ( `    screen-required = 2.` )
                          ( `    MODIFY SCREEN.` )
                          ( `  ENDLOOP.` )
                          ( `FORM f4_low.` )
                          ( `ENDFORM.` )
                          ( `FORM f4_high.` )
                          ( `ENDFORM.` ) )
        class  = `zcl_screen`
        texts  = VALUE #( ( id = `I` key = `001` entry = `Maximum` ) ) )-code.

    has( code = lv_code part = 'screen->block_begin( name = `B1` no_intervals = abap_true ).' ).
    has( code = lv_code part = 'matchcode = `H_SCARR` memory_id = `CAR`' ).
    has( code = lv_code part = 'for_field = `P_MAX` ).' ).
    has( code = lv_code part = 'screen->function_key( number = 1 text = `Function 1` ).' ).
    has( code = lv_code part = 'METHOD at_selection_screen_on_block. CASE block. WHEN `B1`. CHECK p_max > 0. ENDCASE.' ).
    has( code = lv_code part = 'METHOD at_selection_screen_on_radio. CASE group. WHEN `OUT`. CLEAR p_max. ENDCASE.' ).
    has( code = lv_code part = 'CASE field. WHEN `S_CARR`. IF value_request_part( ) = `LOW`. f4_low( ). ENDIF. IF value_request_part( ) = `HIGH`. f4_high( ). ENDIF. WHEN OTHERS. super->at_value_request( field ).' ).
    has( code = lv_code part = 'METHOD at_selection_screen_on_help. CASE field. WHEN `P_MAX`.' ).
    has( code = lv_code part = 'WHEN OTHERS. super->at_selection_screen_on_help( field ). ENDCASE.' ).
    has( code = lv_code part = `METHOD at_selection_screen_on_exit. CLEAR p_max.` ).
    has( code = lv_code part = `ls_screen-intensified = abap_true.` ).
    has( code = lv_code part = `ls_screen-recommended = abap_true.` ).

  ENDMETHOD.

  METHOD alv_and_popups.

    DATA(ls_result) = z2ui5_cl_cgui_converter=>convert(
        source = VALUE #( ( `REPORT zalv.` )
                          ( `DATA gt_flight TYPE STANDARD TABLE OF sflight.` )
                          ( `DATA gt_carr TYPE STANDARD TABLE OF scarr.` )
                          ( `DATA go_salv TYPE REF TO cl_salv_table.` )
                          ( `DATA gv_answer TYPE c LENGTH 1.` )
                          ( `PARAMETERS p_carr TYPE s_carr_id.` )
                          ( `AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_carr.` )
                          ( `  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'` )
                          ( `    EXPORTING retfield = 'CARRID' window_title = 'Airline'` )
                          ( `    TABLES value_tab = gt_carr.` )
                          ( `START-OF-SELECTION.` )
                          ( `  CALL FUNCTION 'POPUP_TO_CONFIRM'` )
                          ( `    EXPORTING titlebar = 'Load' text_question = 'Load the flights?'` )
                          ( `    IMPORTING answer = gv_answer.` )
                          ( `  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'` )
                          ( `    EXPORTING i_grid_title = 'Flights' it_fieldcat = gt_fcat i_callback_user_command = 'USER_COMMAND'` )
                          ( `    TABLES t_outtab = gt_flight.` )
                          ( `  CLEAR gt_flight[].` )
                          ( `  CALL FUNCTION 'POPUP_TO_DECIDE'` )
                          ( `    EXPORTING textline1 = 'Book?' text_option1 = 'Yes' text_option2 = 'Later' titel = 'Booking'` )
                          ( `    IMPORTING answer = gv_answer.` )
                          ( `  TRY.` )
                          ( `      cl_salv_table=>factory( IMPORTING r_salv_table = go_salv CHANGING t_table = gt_flight ).` )
                          ( `      go_salv->get_columns( )->set_optimize( abap_true ).` )
                          ( `      SET HANDLER lcl_events=>on_double_click FOR go_salv->get_event( ).` )
                          ( `      go_salv->display( ).` )
                          ( `    CATCH cx_salv_msg.` )
                          ( `  ENDTRY.` ) )
        class  = `zcl_alv` ).
    DATA(lv_code) = ls_result-code.

    has( code = lv_code part = 'value_help_popup( tab = gt_carr col = `CARRID` title = `Airline` ).' ).
    has( code = lv_code part = 'popup_to_confirm( question = `Load the flights?` title = `Load` ucomm = `POPUP_TO_CONFIRM` ).' ).
    has( code = lv_code part = 'alv( gt_flight )->set_title( `Flights` ) ->set_fieldcat( gt_fcat ).' ).
    has( code = lv_code part = `" CLEAR gt_flight[]. - the ALV shows the table after the run` ).
    has( code = lv_code part = 'popup_to_decide( question = `Book?` options = VALUE #( ( CONV #( `Yes` ) ) ( CONV #( `Later` ) ) ) title = `Booking` ucomm = `POPUP_TO_DECIDE` ).' ).
    has( code = lv_code part = `TRY. go_salv = z2ui5_cl_cgui_salv=>factory( alv = alv( gt_flight ) report = me ).` ).
    has( code = lv_code part = `go_salv->get_columns( )->set_optimize( abap_true ).` ).
    has( code = lv_code part = 'go_salv->get_event( )->set_handler( class = `LCL_EVENTS`' ).
    has( code = lv_code part = 'method = `ON_DOUBLE_CLICK` ). go_salv->display( ). CATCH cx_salv_msg.' ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_code
                                         exp = `*go_salv type ref to z2ui5_cl_cgui_salv*` ).
    cl_abap_unit_assert=>assert_char_np( act = lv_code
                                         exp = `*ref to cl_salv_table*` ).

    DATA(lv_notes) = concat_lines_of( table = ls_result-notes sep = ` ` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_notes
                                         exp = `*at_user_command( ucomm )*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_notes
                                         exp = `*gv_answer = popup_answer( )*` ).

  ENDMETHOD.

  METHOD salv_handlers.

    DATA(ls_result) = z2ui5_cl_cgui_converter=>convert(
        source = VALUE #( ( `REPORT zsalv.` )
                          ( `DATA gt_flight TYPE STANDARD TABLE OF sflight.` )
                          ( `DATA gr_table TYPE REF TO cl_salv_table.` )
                          ( `DATA gr_events TYPE REF TO cl_salv_events_table.` )
                          ( `DATA go_handler TYPE REF TO lcl_handler.` )
                          ( `START-OF-SELECTION.` )
                          ( `  cl_salv_table=>factory( IMPORTING r_salv_table = gr_table CHANGING t_table = gt_flight ).` )
                          ( `  gr_events = gr_table->get_event( ).` )
                          ( `  CREATE OBJECT go_handler.` )
                          ( `  SET HANDLER go_handler->on_double_click go_handler->on_function FOR gr_events.` )
                          ( `  SET HANDLER lcl_static=>on_link FOR ALL INSTANCES.` )
                          ( `  gr_table->display( ).` ) )
        class  = `zcl_salv` ).
    DATA(lv_code) = ls_result-code.

    " the events object is the SALV object - its assignment stays
    has( code = lv_code part = `gr_events = gr_table->get_event( ).` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_code
                                         exp = `*gr_events type ref to z2ui5_cl_cgui_salv*` ).
    " every handler its own set_handler( )
    has( code = lv_code part = 'gr_events->set_handler( handler = go_handler method = `ON_DOUBLE_CLICK` ).' ).
    has( code = lv_code part = 'gr_events->set_handler( handler = go_handler method = `ON_FUNCTION` ).' ).
    " FOR ALL INSTANCES - every SALV object of the report
    has( code = lv_code part = 'gr_table->set_handler( class = `LCL_STATIC` method = `ON_LINK` ).' ).
    cl_abap_unit_assert=>assert_char_np( act = lv_code
                                         exp = `*SET HANDLER*` ).

    DATA(lv_notes) = concat_lines_of( table = ls_result-notes sep = ` ` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_notes
                                         exp = `*set_handler( )*` ).

  ENDMETHOD.

  METHOD grid_on_screen.

    DATA(ls_result) = z2ui5_cl_cgui_converter=>convert(
        source = VALUE #( ( `REPORT zgrid.` )
                          ( `DATA gt_flight TYPE STANDARD TABLE OF sflight.` )
                          ( `DATA: go_cont TYPE REF TO cl_gui_custom_container,` )
                          ( `      go_grid TYPE REF TO cl_gui_alv_grid.` )
                          ( `DATA go_handler TYPE REF TO lcl_handler.` )
                          ( `START-OF-SELECTION.` )
                          ( `  SELECT * FROM sflight INTO TABLE gt_flight.` )
                          ( `  CALL SCREEN 100.` )
                          ( `MODULE status_0100 OUTPUT.` )
                          ( `  IF go_grid IS INITIAL.` )
                          ( `    CREATE OBJECT go_cont EXPORTING container_name = 'CC_ALV'.` )
                          ( `    CREATE OBJECT go_grid EXPORTING i_parent = go_cont.` )
                          ( `    CREATE OBJECT go_handler.` )
                          ( `    SET HANDLER go_handler->on_double_click go_handler->on_toolbar FOR go_grid.` )
                          ( `    CALL METHOD go_grid->set_table_for_first_display` )
                          ( `      EXPORTING i_structure_name = 'SFLIGHT'` )
                          ( `      CHANGING it_outtab = gt_flight.` )
                          ( `  ENDIF.` )
                          ( `  cl_gui_cfw=>flush( ).` )
                          ( `ENDMODULE.` )
                          ( `MODULE user_command_0100 INPUT.` )
                          ( `  LEAVE TO SCREEN 0.` )
                          ( `ENDMODULE.` ) )
        class  = `zcl_grid` ).
    DATA(lv_code) = ls_result-code.

    " the PBO module a method, CALL SCREEN its call
    has( code = lv_code part = `METHODS pbo_status_0100.` ).
    has( code = lv_code part = `pbo_status_0100( ).` ).
    " the grid on the ALV of the report, the container a comment
    has( code = lv_code part = `go_grid = z2ui5_cl_cgui_grid=>factory( report = me ).` ).
    has( code = lv_code part = `" CREATE OBJECT go_cont EXPORTING container_name = 'CC_ALV'. - a container of the SAP GUI, the grid needs none` ).
    has( code = lv_code part = 'go_grid->set_handler( handler = go_handler method = `ON_DOUBLE_CLICK` ).' ).
    has( code = lv_code part = 'go_grid->set_handler( handler = go_handler method = `ON_TOOLBAR` ).' ).
    has( code = lv_code part = `CALL METHOD go_grid->set_table_for_first_display` ).
    has( code = lv_code part = `" cl_gui_cfw=>flush( ). - no frontend to flush` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_code
                                         exp = `*go_grid type ref to z2ui5_cl_cgui_grid*` ).
    " the PAI module stays a comment
    cl_abap_unit_assert=>assert_char_cp( act = lv_code
                                         exp = `*" MODULE user_command_0100 INPUT.*` ).

    DATA(lv_notes) = concat_lines_of( table = ls_result-notes sep = ` ` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_notes
                                         exp = `*z2ui5_cl_cgui_grid*` ).

  ENDMETHOD.

ENDCLASS.
