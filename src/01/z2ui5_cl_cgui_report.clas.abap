"! Report runtime - write an abap2UI5 app the way a classic ABAP report is
"! written. Inherit from this class, declare the fields of the selection
"! screen as PUBLIC attributes and redefine the event blocks you need:
"!   initialization        once, before the selection screen is shown
"!   selection_screen      the layout: parameter( ), select_option( ), ...
"!   at_selection_screen   after F8, before the run - message( type = `E` )
"!                         keeps the user on the selection screen
"!   start_of_selection    read the data, output it with write( ) or alv( )
"!   at_line_selection     a hotspot of the list or a row of the ALV clicked
"!   at_user_command       a button of the selection screen or a confirmed
"!                         popup_to_confirm( )
"!   at_value_request      F4 on a parameter declared with value_help
"! The runtime shows the selection screen, runs the blocks on Execute (F8),
"! shows the output and goes back on Back (F3). Messages follow the classic
"! semantics: S as a toast, I and W as a box, E as a box that stops the run.
CLASS z2ui5_cl_cgui_report DEFINITION PUBLIC ABSTRACT CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    CONSTANTS:
      BEGIN OF cs_ucomm,
        execute TYPE string VALUE `CGUI_EXECUTE`,
        back    TYPE string VALUE `CGUI_BACK`,
        cancel  TYPE string VALUE `CGUI_CANCEL`,
      END OF cs_ucomm.

    "! the output of alv( ) when the table passed is no attribute of the
    "! report - a copy, bound to the grid
    DATA mr_cgui_alv TYPE REF TO data.

  PROTECTED SECTION.

    TYPES:
      BEGIN OF ty_s_cgui_msg,
        type TYPE string,
        text TYPE string,
      END OF ty_s_cgui_msg.
    TYPES ty_t_cgui_msg TYPE STANDARD TABLE OF ty_s_cgui_msg WITH EMPTY KEY.

    DATA client TYPE REF TO z2ui5_if_client.

    METHODS initialization.

    METHODS selection_screen
      IMPORTING
        screen TYPE REF TO z2ui5_cl_cgui_selscreen.

    METHODS at_selection_screen.

    METHODS start_of_selection.

    "! row is the line number of the list or the row index of the ALV table,
    "! hide the value the list hotspot was written with
    METHODS at_line_selection
      IMPORTING
        row  TYPE i
        hide TYPE string.

    METHODS at_user_command
      IMPORTING
        ucomm TYPE string.

    "! field is the name of the parameter - answer with value_help_popup( )
    "! or by setting the attribute directly
    METHODS at_value_request
      IMPORTING
        field TYPE string.

    "! WRITE - returns the list for further WRITEs, NEW-LINE, ULINE, ...
    METHODS write
      IMPORTING
        VALUE(val)    TYPE any
        color         TYPE clike     DEFAULT z2ui5_cl_cgui_list=>cs_color-none
        hotspot       TYPE abap_bool DEFAULT abap_false
        VALUE(hide)   TYPE any       OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_list.

    "! the list output of this run
    METHODS list
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_list.

    "! show tab as ALV grid - returns the ALV for its settings. Pass a PUBLIC
    "! attribute of the report: the grid binds it directly. Anything else is
    "! copied into mr_cgui_alv, whose type the draft has to rebuild with RTTI
    "! on every roundtrip
    METHODS alv
      IMPORTING
        tab           TYPE STANDARD TABLE
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_alv.

    "! MESSAGE text TYPE type - S, I, W, E or A
    METHODS message
      IMPORTING
        text TYPE clike
        type TYPE clike DEFAULT `S`.

    "! POPUP_TO_CONFIRM - on Yes, at_user_command( ) runs with ucomm
    METHODS popup_to_confirm
      IMPORTING
        question TYPE clike
        ucomm    TYPE clike
        title    TYPE clike DEFAULT `Confirm`.

    "! F4 help for the field of at_value_request( ): the user picks a row of
    "! tab, and its component col (the first one when empty) is written
    "! into the field
    METHODS value_help_popup
      IMPORTING
        tab   TYPE STANDARD TABLE
        col   TYPE clike OPTIONAL
        title TYPE clike OPTIONAL.

    "! LEAVE TO LIST-PROCESSING's way back - show the selection screen again
    METHODS leave_to_selection_screen.

    "! the title of the report, the class name when not set
    METHODS set_title
      IMPORTING
        val TYPE clike.

    " the runtime's own state - PROTECTED, not PRIVATE: the draft persists
    " the app with CALL TRANSFORMATION id, and the transpiled runtime reaches
    " PROTECTED attributes but not PRIVATE ones. The cgui prefix keeps them
    " apart from the attributes of the report that inherits
    DATA mv_cgui_screen        TYPE string.
    DATA mv_cgui_title         TYPE string.
    DATA mo_cgui_list          TYPE REF TO z2ui5_cl_cgui_list.
    DATA mo_cgui_alv           TYPE REF TO z2ui5_cl_cgui_alv.
    DATA mv_cgui_alv_name      TYPE string.
    DATA mt_cgui_field         TYPE z2ui5_cl_cgui_selscreen=>ty_t_field.
    DATA mt_cgui_msg           TYPE ty_t_cgui_msg.
    DATA mv_cgui_stop          TYPE abap_bool.
    DATA mv_cgui_nav           TYPE abap_bool.
    DATA mv_cgui_value_field   TYPE string.
    DATA mv_cgui_pending_field TYPE string.
    DATA mv_cgui_pending_kind  TYPE string.
    DATA mv_cgui_pending_col   TYPE string.

  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF cs_screen,
        selection TYPE string VALUE `SELECTION`,
        output    TYPE string VALUE `OUTPUT`,
      END OF cs_screen.

    CONSTANTS:
      BEGIN OF cs_pending,
        range TYPE string VALUE `RANGE`,
        f4    TYPE string VALUE `F4`,
      END OF cs_pending.

    METHODS on_event.

    METHODS on_navigated.

    METHODS on_execute.

    METHODS check_obligatory
      RETURNING
        VALUE(result) TYPE abap_bool.

    METHODS on_range_popup
      IMPORTING
        field TYPE string.

    METHODS on_range_result
      IMPORTING
        field TYPE string.

    METHODS on_f4_result
      IMPORTING
        field TYPE string
        col   TYPE string.

    METHODS attri_assign
      IMPORTING
        name          TYPE string
      RETURNING
        VALUE(result) TYPE REF TO data.

    METHODS view_display.

    METHODS view_display_output
      IMPORTING
        page TYPE REF TO z2ui5_cl_ui5_view_builder.

    METHODS messages_display.

ENDCLASS.


CLASS z2ui5_cl_cgui_report IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    CLEAR mt_cgui_msg.
    mv_cgui_nav = abap_false.

    IF client->check_on_init( ).
      mv_cgui_screen = cs_screen-selection.
      mv_cgui_title = cl_abap_typedescr=>describe_by_object_ref( me )->get_relative_name( ).
      initialization( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      " back from a popup - a confirmed popup_to_confirm( ) returns with
      " its ucomm as event, handled like any other user command
      on_navigated( ).
      IF client->get_event( ) IS NOT INITIAL.
        on_event( ).
      ENDIF.
      IF mv_cgui_nav = abap_false.
        view_display( ).
      ENDIF.
    ELSEIF client->check_on_event( ).
      on_event( ).
      IF mv_cgui_nav = abap_false.
        view_display( ).
      ENDIF.
    ENDIF.

    messages_display( ).

  ENDMETHOD.

  METHOD initialization ##NEEDED.
  ENDMETHOD.

  METHOD selection_screen ##NEEDED.
  ENDMETHOD.

  METHOD at_selection_screen ##NEEDED.
  ENDMETHOD.

  METHOD start_of_selection ##NEEDED.
  ENDMETHOD.

  METHOD at_line_selection ##NEEDED.
  ENDMETHOD.

  METHOD at_user_command ##NEEDED.
  ENDMETHOD.

  METHOD at_value_request ##NEEDED.
  ENDMETHOD.

  METHOD on_event.

    DATA(lv_event) = client->get_event( ).

    CASE lv_event.

      WHEN cs_ucomm-execute.
        on_execute( ).

      WHEN cs_ucomm-back.
        leave_to_selection_screen( ).

      WHEN cs_ucomm-cancel.

      WHEN z2ui5_cl_cgui_selscreen=>cs_event-select_option.
        on_range_popup( client->get_event_arg( ) ).

      WHEN z2ui5_cl_cgui_selscreen=>cs_event-value_request.
        mv_cgui_value_field = client->get_event_arg( ).
        at_value_request( mv_cgui_value_field ).
        CLEAR mv_cgui_value_field.

      WHEN z2ui5_cl_cgui_list=>cs_event-line_selection.
        at_line_selection( row  = CONV i( client->get_event_arg( ) )
                           hide = client->get_event_arg( 2 ) ).

      WHEN z2ui5_cl_cgui_alv=>cs_event-line_selection.
        at_line_selection( row  = z2ui5_cl_cgui_alv=>get_row_by_event( client )
                           hide = `` ).

      WHEN OTHERS.
        at_user_command( lv_event ).

    ENDCASE.

  ENDMETHOD.

  METHOD on_navigated.

    IF mv_cgui_pending_field IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_field) = mv_cgui_pending_field.
    DATA(lv_kind) = mv_cgui_pending_kind.
    DATA(lv_col) = mv_cgui_pending_col.
    CLEAR: mv_cgui_pending_field, mv_cgui_pending_kind, mv_cgui_pending_col.

    CASE lv_kind.
      WHEN cs_pending-range.
        on_range_result( lv_field ).
      WHEN cs_pending-f4.
        on_f4_result( field = lv_field
                      col   = lv_col ).
    ENDCASE.

  ENDMETHOD.

  METHOD on_execute.

    mv_cgui_stop = abap_false.

    IF check_obligatory( ) = abap_false.
      RETURN.
    ENDIF.

    at_selection_screen( ).
    IF mv_cgui_stop = abap_true.
      RETURN.
    ENDIF.

    CLEAR: mo_cgui_list, mo_cgui_alv, mr_cgui_alv, mv_cgui_alv_name.
    start_of_selection( ).
    IF mv_cgui_stop = abap_true.
      RETURN.
    ENDIF.

    IF mo_cgui_alv IS NOT BOUND AND ( mo_cgui_list IS NOT BOUND OR mo_cgui_list->get_items( ) IS INITIAL ).
      message( `List contains no data` ).
      RETURN.
    ENDIF.

    mv_cgui_screen = cs_screen-output.

  ENDMETHOD.

  METHOD check_obligatory.

    FIELD-SYMBOLS <val> TYPE any.

    LOOP AT mt_cgui_field REFERENCE INTO DATA(lr_field) WHERE obligatory = abap_true.
      DATA(lr_val) = attri_assign( lr_field->name ).
      IF lr_val IS NOT BOUND.
        CONTINUE.
      ENDIF.
      ASSIGN lr_val->* TO <val>.
      IF <val> IS INITIAL.
        message( text = |Fill in all required entry fields ({ lr_field->text })|
                 type = `E` ).
        RETURN.
      ENDIF.
    ENDLOOP.

    result = abap_true.

  ENDMETHOD.

  METHOD on_range_popup.

    FIELD-SYMBOLS <range> TYPE STANDARD TABLE.

    DATA(lr_range) = attri_assign( field ).
    IF lr_range IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_range->* TO <range>.

    mv_cgui_pending_field = field.
    mv_cgui_pending_kind = cs_pending-range.
    mv_cgui_nav = abap_true.
    client->nav_app_call( z2ui5_cl_popup_get_range=>factory( <range> ) ).

  ENDMETHOD.

  METHOD on_range_result.

    FIELD-SYMBOLS <range> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <line>  TYPE any.
    FIELD-SYMBOLS <comp>  TYPE any.
    DATA lr_line TYPE REF TO data.
    DATA lo_popup TYPE REF TO z2ui5_cl_popup_get_range.

    TRY.
        lo_popup ?= client->get_app_prev( ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    DATA(ls_result) = lo_popup->result( ).
    IF ls_result-check_confirmed = abap_false.
      RETURN.
    ENDIF.

    DATA(lr_range) = attri_assign( field ).
    IF lr_range IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_range->* TO <range>.
    CLEAR <range>.

    LOOP AT ls_result-t_range REFERENCE INTO DATA(lr_result).
      CREATE DATA lr_line LIKE LINE OF <range>.
      ASSIGN lr_line->* TO <line>.

      ASSIGN COMPONENT `SIGN` OF STRUCTURE <line> TO <comp>.
      <comp> = lr_result->sign.
      ASSIGN COMPONENT `OPTION` OF STRUCTURE <line> TO <comp>.
      <comp> = lr_result->option.
      ASSIGN COMPONENT `LOW` OF STRUCTURE <line> TO <comp>.
      <comp> = lr_result->low.
      ASSIGN COMPONENT `HIGH` OF STRUCTURE <line> TO <comp>.
      <comp> = lr_result->high.

      INSERT <line> INTO TABLE <range>.
    ENDLOOP.

  ENDMETHOD.

  METHOD on_f4_result.

    FIELD-SYMBOLS <row>   TYPE any.
    FIELD-SYMBOLS <value> TYPE any.
    FIELD-SYMBOLS <field> TYPE any.
    DATA lo_popup TYPE REF TO z2ui5_cl_popup_to_select.

    TRY.
        lo_popup ?= client->get_app_prev( ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    DATA(ls_result) = lo_popup->result( ).
    IF ls_result-check_confirmed = abap_false OR ls_result-row IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN ls_result-row->* TO <row>.

    IF col IS INITIAL.
      ASSIGN COMPONENT 1 OF STRUCTURE <row> TO <value>.
    ELSE.
      ASSIGN COMPONENT col OF STRUCTURE <row> TO <value>.
    ENDIF.
    IF <value> IS NOT ASSIGNED.
      RETURN.
    ENDIF.

    DATA(lr_field) = attri_assign( field ).
    IF lr_field IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_field->* TO <field>.
    <field> = <value>.

  ENDMETHOD.

  METHOD attri_assign.

    DATA lo_me TYPE REF TO object.
    FIELD-SYMBOLS <attri> TYPE any.

    lo_me = me.
    ASSIGN lo_me->(name) TO <attri>.
    IF <attri> IS ASSIGNED.
      GET REFERENCE OF <attri> INTO result.
    ENDIF.

  ENDMETHOD.

  METHOD write.

    IF hide IS SUPPLIED.
      result = list( )->write( val     = val
                               color   = color
                               hotspot = hotspot
                               hide    = hide ).
    ELSE.
      result = list( )->write( val     = val
                               color   = color
                               hotspot = hotspot ).
    ENDIF.

  ENDMETHOD.

  METHOD list.

    IF mo_cgui_list IS NOT BOUND.
      mo_cgui_list = z2ui5_cl_cgui_list=>factory( ).
    ENDIF.
    result = mo_cgui_list.

  ENDMETHOD.

  METHOD alv.

    FIELD-SYMBOLS <tab> TYPE STANDARD TABLE.

    CLEAR mr_cgui_alv.
    mv_cgui_alv_name = z2ui5_cl_cgui_context=>attri_name_by_ref( app = me
                                                                 val = tab ).
    IF mv_cgui_alv_name IS INITIAL.
      CREATE DATA mr_cgui_alv LIKE tab.
      ASSIGN mr_cgui_alv->* TO <tab>.
      <tab> = tab.
    ENDIF.

    mo_cgui_alv = z2ui5_cl_cgui_alv=>factory( )->set_title( mv_cgui_title ).
    result = mo_cgui_alv.

  ENDMETHOD.

  METHOD message.

    INSERT VALUE #( type = to_upper( type )
                    text = text ) INTO TABLE mt_cgui_msg.
    IF type = `E` OR type = `A` OR type = `e` OR type = `a`.
      mv_cgui_stop = abap_true.
    ENDIF.

  ENDMETHOD.

  METHOD popup_to_confirm.

    mv_cgui_nav = abap_true.
    client->nav_app_call( z2ui5_cl_popup_to_confirm=>factory( i_question_text = |{ question }|
                                                              i_title         = |{ title }|
                                                              i_event_confirm = |{ ucomm }|
                                                              i_event_cancel  = cs_ucomm-cancel ) ).

  ENDMETHOD.

  METHOD value_help_popup.

    IF mv_cgui_value_field IS INITIAL.
      RETURN.
    ENDIF.

    mv_cgui_pending_field = mv_cgui_value_field.
    mv_cgui_pending_kind = cs_pending-f4.
    mv_cgui_pending_col = to_upper( col ).
    mv_cgui_nav = abap_true.
    client->nav_app_call( z2ui5_cl_popup_to_select=>factory( i_tab   = tab
                                                             i_title = title ) ).

  ENDMETHOD.

  METHOD leave_to_selection_screen.

    mv_cgui_screen = cs_screen-selection.

  ENDMETHOD.

  METHOD set_title.

    mv_cgui_title = val.

  ENDMETHOD.

  METHOD view_display.

    DATA lv_button_text  TYPE string.
    DATA lv_button_icon  TYPE string.
    DATA lv_button_ucomm TYPE string.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%` ).

    DATA(page) = view->ele( `Page`
        )->a( n = `title`          t = mv_cgui_title
        )->a( n = `showNavButton`  b = xsdbool( mv_cgui_screen = cs_screen-output )
        )->a( n = `navButtonPress` v = client->_event( cs_ucomm-back ) ).

    IF mv_cgui_screen = cs_screen-output.
      view_display_output( page ).
      lv_button_text = `Back`.
      lv_button_icon = `sap-icon://nav-back`.
      lv_button_ucomm = cs_ucomm-back.
    ELSE.
      DATA(screen) = z2ui5_cl_cgui_selscreen=>factory( client ).
      selection_screen( screen ).
      mt_cgui_field = screen->get_fields( ).
      screen->render( page ).
      lv_button_text = `Execute`.
      lv_button_icon = `sap-icon://begin`.
      lv_button_ucomm = cs_ucomm-execute.
    ENDIF.

    page->ele( `footer`
        )->ele( `OverflowToolbar`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `text`  t = lv_button_text
                )->a( n = `icon`  v = lv_button_icon
                )->a( n = `type`  v = `Emphasized`
                )->a( n = `press` v = client->_event( lv_button_ucomm ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

  METHOD view_display_output.

    FIELD-SYMBOLS <tab> TYPE STANDARD TABLE.
    DATA lr_tab TYPE REF TO data.

    IF mo_cgui_alv IS BOUND.
      IF mv_cgui_alv_name IS NOT INITIAL.
        lr_tab = attri_assign( mv_cgui_alv_name ).
      ELSE.
        lr_tab = mr_cgui_alv.
      ENDIF.
      IF lr_tab IS BOUND.
        ASSIGN lr_tab->* TO <tab>.
        mo_cgui_alv->render( node   = page
                             client = client
                             tab    = <tab> ).
      ENDIF.
    ENDIF.

    IF mo_cgui_list IS BOUND.
      mo_cgui_list->render( node   = page
                            client = client ).
    ENDIF.

  ENDMETHOD.

  METHOD messages_display.

    DATA lv_text TYPE string.
    DATA lv_type TYPE string VALUE `information`.

    LOOP AT mt_cgui_msg REFERENCE INTO DATA(lr_msg).
      IF lr_msg->type = `S`.
        client->message_toast_display( lr_msg->text ).
        CONTINUE.
      ENDIF.

      IF lv_text IS NOT INITIAL.
        lv_text = lv_text && cl_abap_char_utilities=>newline.
      ENDIF.
      lv_text = lv_text && lr_msg->text.

      CASE lr_msg->type.
        WHEN `E` OR `A`.
          lv_type = `error`.
        WHEN `W`.
          IF lv_type <> `error`.
            lv_type = `warning`.
          ENDIF.
      ENDCASE.
    ENDLOOP.

    IF lv_text IS NOT INITIAL.
      client->message_box_display( text = lv_text
                                   type = lv_type ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
