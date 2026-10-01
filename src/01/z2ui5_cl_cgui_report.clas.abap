"! Report runtime - write an abap2UI5 app the way a classic ABAP report is
"! written. Inherit from this class, declare the fields of the selection
"! screen as PUBLIC attributes and redefine the event blocks you need:
"!   initialization        once, before the selection screen is shown
"!   selection_screen      the layout: parameter( ), select_option( ), ...
"!   at_selection_screen_output
"!                         before the selection screen is shown - change
"!                         it with loop_at_screen( ) / modify_screen( )
"!   at_selection_screen_on
"!                         after F8, once per field - a message( ) of type E
"!                         marks the field and keeps the user on the screen
"!   at_selection_screen   after F8, before the run - message( type = `E` )
"!                         keeps the user on the selection screen
"!   start_of_selection    read the data, output it with write( ) or alv( )
"!   at_line_selection     a hotspot of the list or a row of the ALV clicked
"!   at_user_command       a button of the selection screen, a checkbox or
"!                         radio button with user_command, or a confirmed
"!                         popup_to_confirm( )
"!   at_value_request      F4 on a field - the default shows the standard F4
"!                         of its DDIC type: domain fixed values or value
"!                         table
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
        type  TYPE string,
        text  TYPE string,
        field TYPE string,
      END OF ty_s_cgui_msg.
    TYPES ty_t_cgui_msg TYPE STANDARD TABLE OF ty_s_cgui_msg WITH EMPTY KEY.

    TYPES:
      " character types: the popup heads a column with the DDIC label of its
      " type, the component name when it has none - and STRING for a string
      BEGIN OF ty_s_cgui_value,
        value TYPE c LENGTH 10,
        text  TYPE c LENGTH 60,
      END OF ty_s_cgui_value.
    TYPES ty_t_cgui_value TYPE STANDARD TABLE OF ty_s_cgui_value WITH EMPTY KEY.

    DATA client TYPE REF TO z2ui5_if_client.

    METHODS initialization.

    METHODS selection_screen
      IMPORTING
        screen TYPE REF TO z2ui5_cl_cgui_selscreen.

    "! AT SELECTION-SCREEN OUTPUT - runs every time the selection screen is
    "! shown, after selection_screen( ): change it with
    "! screen->loop_at_screen( ) and screen->modify_screen( )
    METHODS at_selection_screen_output
      IMPORTING
        screen TYPE REF TO z2ui5_cl_cgui_selscreen.

    "! AT SELECTION-SCREEN ON field - runs after Execute once for every field
    "! shown on the screen, field is its attribute name. A message( ) of
    "! type E belongs to the field: it is marked and the run stops
    METHODS at_selection_screen_on
      IMPORTING
        field TYPE string.

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

    "! AT SELECTION-SCREEN ON VALUE-REQUEST - F4 on a field, field is its
    "! attribute name. Answer with value_help_popup( ) or by setting the
    "! attribute directly. This implementation is the standard F4: the
    "! fixed values of the domain, else its value table (on premise) - call
    "! super->at_value_request( field ) for the fields you do not answer
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

    "! MESSAGE text TYPE type - S, I, W, E or A. field, the attribute name of
    "! a field of the selection screen, marks that field with the message;
    "! inside at_selection_screen_on( ) it is that method's field by default
    METHODS message
      IMPORTING
        text  TYPE clike
        type  TYPE clike DEFAULT `S`
        field TYPE clike OPTIONAL.

    "! POPUP_TO_CONFIRM - on Yes, at_user_command( ) runs with ucomm
    METHODS popup_to_confirm
      IMPORTING
        question TYPE clike
        ucomm    TYPE clike
        title    TYPE clike DEFAULT `Confirm`.

    "! F4 help for the field of at_value_request( ): the user picks a row of
    "! tab, and its component col (the first one when empty) is written
    "! into the field. For a select-option the user picks any number of
    "! rows, which replace its lines as I EQ
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
    DATA mv_cgui_on_field      TYPE string.

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

    METHODS value_help_ddic
      IMPORTING
        field TYPE string.

    "! tab with a column ZZSELKZ, set for every row whose col is a line
    "! I EQ of range - the selection the popup starts with
    METHODS value_help_preselect
      IMPORTING
        tab           TYPE STANDARD TABLE
        col           TYPE string
        range         TYPE STANDARD TABLE
      RETURNING
        VALUE(result) TYPE REF TO data.

    METHODS value_help_title
      IMPORTING
        field         TYPE string
      RETURNING
        VALUE(result) TYPE string.

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

    METHODS value_state_set
      IMPORTING
        screen TYPE REF TO z2ui5_cl_cgui_selscreen.

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

  METHOD at_selection_screen_output ##NEEDED.
  ENDMETHOD.

  METHOD at_selection_screen_on ##NEEDED.
  ENDMETHOD.

  METHOD at_selection_screen ##NEEDED.
  ENDMETHOD.

  METHOD start_of_selection ##NEEDED.
  ENDMETHOD.

  METHOD at_line_selection ##NEEDED.
  ENDMETHOD.

  METHOD at_user_command ##NEEDED.
  ENDMETHOD.

  METHOD at_value_request.

    value_help_ddic( field ).

  ENDMETHOD.

  METHOD value_help_ddic.

    DATA lt_value TYPE ty_t_cgui_value.
    DATA lr_tab   TYPE REF TO data.
    DATA lt_comp  TYPE cl_abap_structdescr=>component_table.
    FIELD-SYMBOLS <val> TYPE any.
    FIELD-SYMBOLS <tab> TYPE STANDARD TABLE.

    DATA(lr_val) = attri_assign( field ).
    IF lr_val IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_val->* TO <val>.
    DATA(lo_descr) = z2ui5_cl_cgui_context=>rtti_get_value_descr( <val> ).

    DATA(lt_fix) = z2ui5_cl_cgui_context=>rtti_get_fixed_values( lo_descr ).
    IF lt_fix IS NOT INITIAL.
      LOOP AT lt_fix REFERENCE INTO DATA(lr_fix).
        INSERT VALUE #( value = lr_fix->low
                        text  = lr_fix->text ) INTO TABLE lt_value.
      ENDLOOP.
      value_help_popup( tab   = lt_value
                        col   = `VALUE`
                        title = value_help_title( field ) ).
      RETURN.
    ENDIF.

    DATA(ls_table) = z2ui5_cl_cgui_context=>rtti_get_value_table( lo_descr ).
    IF ls_table-table IS NOT INITIAL.
      TRY.
          DATA(lo_struct) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( ls_table-table ) ).
          LOOP AT lo_struct->get_components( ) REFERENCE INTO DATA(lr_comp).
            READ TABLE ls_table-fields WITH KEY table_line = lr_comp->name TRANSPORTING NO FIELDS.
            IF sy-subrc = 0.
              INSERT lr_comp->* INTO TABLE lt_comp.
            ENDIF.
          ENDLOOP.
          DATA(lo_tab) = cl_abap_tabledescr=>create( cl_abap_structdescr=>create( lt_comp ) ).
          CREATE DATA lr_tab TYPE HANDLE lo_tab.
          ASSIGN lr_tab->* TO <tab>.
          SELECT (ls_table-fields) FROM (ls_table-table) INTO CORRESPONDING FIELDS OF TABLE @<tab> UP TO 500 ROWS.
        CATCH cx_root.
          UNASSIGN <tab>.
      ENDTRY.
      IF <tab> IS ASSIGNED AND <tab> IS NOT INITIAL.
        value_help_popup( tab   = <tab>
                          col   = ls_table-field
                          title = value_help_title( field ) ).
        RETURN.
      ENDIF.
    ENDIF.

    message( `No input help is available` ).

  ENDMETHOD.

  METHOD value_help_preselect.

    DATA lt_comp  TYPE cl_abap_structdescr=>component_table.
    DATA lv_flag  TYPE abap_bool.
    DATA lr_row   TYPE REF TO data.
    FIELD-SYMBOLS <tab>   TYPE STANDARD TABLE.
    FIELD-SYMBOLS <src>   TYPE any.
    FIELD-SYMBOLS <row>   TYPE any.
    FIELD-SYMBOLS <value> TYPE any.
    FIELD-SYMBOLS <selkz> TYPE any.
    FIELD-SYMBOLS <line>  TYPE any.
    FIELD-SYMBOLS <comp>  TYPE any.

    TRY.
        DATA(lo_table) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( tab ) ).
        DATA(lo_line) = CAST cl_abap_structdescr( lo_table->get_table_line_type( ) ).
        lt_comp = lo_line->get_components( ).
        READ TABLE lt_comp WITH KEY name = `ZZSELKZ` TRANSPORTING NO FIELDS.
        IF sy-subrc = 0.
          RETURN.
        ENDIF.
        INSERT VALUE #( name = `ZZSELKZ`
                        type = CAST #( cl_abap_typedescr=>describe_by_data( lv_flag ) ) ) INTO TABLE lt_comp.

        DATA(lo_new) = cl_abap_tabledescr=>create( cl_abap_structdescr=>create( lt_comp ) ).
        CREATE DATA result TYPE HANDLE lo_new.
        ASSIGN result->* TO <tab>.
      CATCH cx_root.
        CLEAR result.
        RETURN.
    ENDTRY.

    LOOP AT tab ASSIGNING <src>.
      CREATE DATA lr_row LIKE LINE OF <tab>.
      ASSIGN lr_row->* TO <row>.
      MOVE-CORRESPONDING <src> TO <row>.

      UNASSIGN <value>.
      IF col IS INITIAL.
        ASSIGN COMPONENT 1 OF STRUCTURE <row> TO <value>.
      ELSE.
        ASSIGN COMPONENT col OF STRUCTURE <row> TO <value>.
      ENDIF.
      IF <value> IS ASSIGNED.
        LOOP AT range ASSIGNING <line>.
          ASSIGN COMPONENT `SIGN` OF STRUCTURE <line> TO <comp>.
          IF <comp> <> `I`.
            CONTINUE.
          ENDIF.
          ASSIGN COMPONENT `OPTION` OF STRUCTURE <line> TO <comp>.
          IF <comp> <> `EQ`.
            CONTINUE.
          ENDIF.
          ASSIGN COMPONENT `LOW` OF STRUCTURE <line> TO <comp>.
          IF <comp> = <value>.
            ASSIGN COMPONENT `ZZSELKZ` OF STRUCTURE <row> TO <selkz>.
            <selkz> = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.

      INSERT <row> INTO TABLE <tab>.
    ENDLOOP.

  ENDMETHOD.

  METHOD value_help_title.

    READ TABLE mt_cgui_field REFERENCE INTO DATA(lr_field) WITH KEY name = field.
    IF sy-subrc = 0.
      result = lr_field->text.
    ENDIF.

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

    LOOP AT mt_cgui_field REFERENCE INTO DATA(lr_field) WHERE shown = abap_true.
      mv_cgui_on_field = lr_field->name.
      at_selection_screen_on( lr_field->name ).
      CLEAR mv_cgui_on_field.
      IF mv_cgui_stop = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.

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

    " every empty required field is marked, the message names the first
    FIELD-SYMBOLS <val> TYPE any.
    DATA lv_first TYPE string.

    LOOP AT mt_cgui_field REFERENCE INTO DATA(lr_field) WHERE obligatory = abap_true.
      DATA(lr_val) = attri_assign( lr_field->name ).
      IF lr_val IS NOT BOUND.
        CONTINUE.
      ENDIF.
      ASSIGN lr_val->* TO <val>.
      IF <val> IS NOT INITIAL.
        CONTINUE.
      ENDIF.
      IF lv_first IS INITIAL.
        lv_first = lr_field->text.
      ENDIF.
      INSERT VALUE #( type  = `E`
                      field = lr_field->name ) INTO TABLE mt_cgui_msg.
    ENDLOOP.

    IF lv_first IS INITIAL.
      result = abap_true.
      RETURN.
    ENDIF.

    message( text = |Fill in all required entry fields ({ lv_first })|
             type = `E` ).

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
    FIELD-SYMBOLS <rows>  TYPE STANDARD TABLE.
    FIELD-SYMBOLS <value> TYPE any.
    FIELD-SYMBOLS <field> TYPE any.
    FIELD-SYMBOLS <range> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <line>  TYPE any.
    FIELD-SYMBOLS <comp>  TYPE any.
    DATA lo_popup TYPE REF TO z2ui5_cl_popup_to_select.
    DATA lr_line  TYPE REF TO data.

    TRY.
        lo_popup ?= client->get_app_prev( ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    DATA(ls_result) = lo_popup->result( ).
    IF ls_result-check_confirmed = abap_false.
      RETURN.
    ENDIF.

    DATA(lr_field) = attri_assign( field ).
    IF lr_field IS NOT BOUND.
      RETURN.
    ENDIF.

    IF cl_abap_typedescr=>describe_by_data_ref( lr_field )->kind <> cl_abap_typedescr=>kind_table.
      IF ls_result-row IS NOT BOUND.
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
      ASSIGN lr_field->* TO <field>.
      <field> = <value>.
      RETURN.
    ENDIF.

    " a select-option - every row picked becomes a line I EQ
    IF ls_result-table IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN ls_result-table->* TO <rows>.
    ASSIGN lr_field->* TO <range>.
    CLEAR <range>.

    LOOP AT <rows> ASSIGNING <row>.
      UNASSIGN <value>.
      IF col IS INITIAL.
        ASSIGN COMPONENT 1 OF STRUCTURE <row> TO <value>.
      ELSE.
        ASSIGN COMPONENT col OF STRUCTURE <row> TO <value>.
      ENDIF.
      IF <value> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.

      CREATE DATA lr_line LIKE LINE OF <range>.
      ASSIGN lr_line->* TO <line>.
      ASSIGN COMPONENT `SIGN` OF STRUCTURE <line> TO <comp>.
      <comp> = `I`.
      ASSIGN COMPONENT `OPTION` OF STRUCTURE <line> TO <comp>.
      <comp> = `EQ`.
      ASSIGN COMPONENT `LOW` OF STRUCTURE <line> TO <comp>.
      <comp> = <value>.
      INSERT <line> INTO TABLE <range>.
    ENDLOOP.

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

    DATA lv_field TYPE string.

    lv_field = to_upper( field ).
    IF lv_field IS INITIAL.
      lv_field = mv_cgui_on_field.
    ENDIF.

    INSERT VALUE #( type  = to_upper( type )
                    text  = text
                    field = lv_field ) INTO TABLE mt_cgui_msg.
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

    FIELD-SYMBOLS <range> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <tab>   TYPE STANDARD TABLE.
    DATA lr_tab TYPE REF TO data.

    DATA(lr_field) = attri_assign( mv_cgui_value_field ).
    IF lr_field IS NOT BOUND.
      RETURN.
    ENDIF.
    DATA(lv_multi) = xsdbool( cl_abap_typedescr=>describe_by_data_ref( lr_field )->kind = cl_abap_typedescr=>kind_table ).

    mv_cgui_pending_field = mv_cgui_value_field.
    mv_cgui_pending_kind = cs_pending-f4.
    mv_cgui_pending_col = to_upper( col ).
    mv_cgui_nav = abap_true.

    IF lv_multi = abap_true.
      ASSIGN lr_field->* TO <range>.
      lr_tab = value_help_preselect( tab   = tab
                                     col   = mv_cgui_pending_col
                                     range = <range> ).
    ENDIF.
    IF lr_tab IS BOUND.
      ASSIGN lr_tab->* TO <tab>.
    ELSE.
      ASSIGN tab TO <tab>.
    ENDIF.

    client->nav_app_call( z2ui5_cl_popup_to_select=>factory( i_tab         = <tab>
                                                             i_title       = title
                                                             i_multiselect = lv_multi ) ).

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
      DATA(screen) = z2ui5_cl_cgui_selscreen=>factory( client          = client
                                                       value_help_auto = abap_true ).
      selection_screen( screen ).
      at_selection_screen_output( screen ).
      value_state_set( screen ).
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

  METHOD value_state_set.

    DATA lv_state TYPE string.

    LOOP AT mt_cgui_msg REFERENCE INTO DATA(lr_msg) WHERE field IS NOT INITIAL.
      CASE lr_msg->type.
        WHEN `E` OR `A`.
          lv_state = `Error`.
        WHEN `W`.
          lv_state = `Warning`.
        WHEN `S`.
          lv_state = `Success`.
        WHEN OTHERS.
          lv_state = `Information`.
      ENDCASE.
      screen->set_value_state( name  = lr_msg->field
                               text  = lr_msg->text
                               state = lv_state ).
    ENDLOOP.

  ENDMETHOD.

  METHOD messages_display.

    DATA lv_text TYPE string.
    DATA lv_type TYPE string VALUE `information`.

    LOOP AT mt_cgui_msg REFERENCE INTO DATA(lr_msg) WHERE text IS NOT INITIAL.
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
