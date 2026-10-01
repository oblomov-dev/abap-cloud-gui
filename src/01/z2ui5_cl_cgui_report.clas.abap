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
"! shows the output and goes back on Back (F3). The values of the selection
"! screen can be saved as variants, kept in the browser's local storage per
"! report - start with one by set_variant( ) in initialization( ) or with
"! the URL parameter variant=NAME. Messages follow the classic semantics -
"! S as a toast, I as a box, E stops the run - and are collected in the
"! message popover of the run: a button in the footer counts them, W and E
"! open it, and a message of a field leads to the field.
CLASS z2ui5_cl_cgui_report DEFINITION PUBLIC ABSTRACT CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    CONSTANTS:
      BEGIN OF cs_ucomm,
        execute           TYPE string VALUE `CGUI_EXECUTE`,
        back              TYPE string VALUE `CGUI_BACK`,
        cancel            TYPE string VALUE `CGUI_CANCEL`,
        variant_get       TYPE string VALUE `CGUI_VARIANT_GET`,
        variant_save      TYPE string VALUE `CGUI_VARIANT_SAVE`,
        variant_delete    TYPE string VALUE `CGUI_VARIANT_DELETE`,
        variant_delete_ok TYPE string VALUE `CGUI_VARIANT_DELETE_OK`,
        variants_loaded   TYPE string VALUE `CGUI_VARIANTS_LOADED`,
        message_focus     TYPE string VALUE `CGUI_MESSAGE_FOCUS`,
        messages_open     TYPE string VALUE `CGUI_MESSAGES_OPEN`,
      END OF cs_ucomm.

    "! the prefix of the browser's local storage the variants are kept
    "! under, the key is the name of the report class
    CONSTANTS cv_cgui_variant_prefix TYPE string VALUE `z2ui5_cgui_variants`.

    "! the id of the footer button the message popover opens on, and of the
    "! popover itself
    CONSTANTS cv_cgui_messages_id TYPE string VALUE `cgui_messages`.
    CONSTANTS cv_cgui_popover_id  TYPE string VALUE `cgui_message_popover`.

    "! the output of alv( ) when the table passed is no attribute of the
    "! report - a copy, bound to the grid
    DATA mr_cgui_alv TYPE REF TO data.

    "! the variants of the report as the browser's local storage holds them
    "! (z2ui5_cl_cgui_variant=>catalog_to_string( )) - bound to the storage
    "! control that reads them, hence PUBLIC
    DATA mv_cgui_variants TYPE string.

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

    "! load the selection variant name - in initialization( ) the report
    "! starts with it, as soon as the browser has handed over the variants.
    "! A variant that does not exist is passed over without a message, so a
    "! report can start with a variant DEFAULT whenever the user saved one
    METHODS set_variant
      IMPORTING
        name TYPE clike.

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
    " the messages of the run, I, W, E and A - what the message popover
    " lists; kept while the user picks one of them
    DATA mt_cgui_log           TYPE ty_t_cgui_msg.
    DATA mv_cgui_stop          TYPE abap_bool.
    DATA mv_cgui_nav           TYPE abap_bool.
    DATA mv_cgui_value_field   TYPE string.
    DATA mv_cgui_pending_field TYPE string.
    DATA mv_cgui_pending_kind  TYPE string.
    DATA mv_cgui_pending_col   TYPE string.
    DATA mv_cgui_on_field      TYPE string.
    DATA mv_cgui_variant       TYPE string.
    DATA mv_cgui_variant_start TYPE string.
    DATA mv_cgui_variant_url   TYPE abap_bool.

  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF cs_screen,
        selection TYPE string VALUE `SELECTION`,
        output    TYPE string VALUE `OUTPUT`,
      END OF cs_screen.

    CONSTANTS:
      BEGIN OF cs_pending,
        range          TYPE string VALUE `RANGE`,
        f4             TYPE string VALUE `F4`,
        variant_get    TYPE string VALUE `VARIANT_GET`,
        variant_save   TYPE string VALUE `VARIANT_SAVE`,
        variant_delete TYPE string VALUE `VARIANT_DELETE`,
      END OF cs_pending.

    TYPES:
      " character types - the popup heads its columns with their names
      BEGIN OF ty_s_variant_row,
        variant TYPE c LENGTH 40,
        values  TYPE c LENGTH 255,
      END OF ty_s_variant_row.
    TYPES ty_t_variant_row TYPE STANDARD TABLE OF ty_s_variant_row WITH EMPTY KEY.

    METHODS on_event.

    METHODS on_navigated.

    METHODS variant_popup
      IMPORTING
        kind TYPE string.

    METHODS variant_selected
      RETURNING
        VALUE(result) TYPE string.

    METHODS variant_apply
      IMPORTING
        name          TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

    METHODS variant_save
      IMPORTING
        name TYPE string.

    METHODS variant_delete
      IMPORTING
        name TYPE string.

    METHODS variant_store
      IMPORTING
        variants TYPE z2ui5_cl_cgui_variant=>ty_t_variant.

    METHODS variant_key
      RETURNING
        VALUE(result) TYPE string.

    METHODS variant_from_url
      RETURNING
        VALUE(result) TYPE string.

    METHODS on_variants_loaded.

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

    METHODS messages_render
      IMPORTING
        page    TYPE REF TO z2ui5_cl_ui5_view_builder
        toolbar TYPE REF TO z2ui5_cl_ui5_view_builder.

    METHODS message_focus
      IMPORTING
        arg TYPE string.

    METHODS message_field_text
      IMPORTING
        field         TYPE string
      RETURNING
        VALUE(result) TYPE string.

    METHODS value_state_set
      IMPORTING
        screen TYPE REF TO z2ui5_cl_cgui_selscreen.

ENDCLASS.


CLASS z2ui5_cl_cgui_report IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    CLEAR mt_cgui_msg.
    mv_cgui_nav = abap_false.
    " the messages of the run stay while the popover opens and the user
    " picks one of them
    IF client->get_event( ) <> cs_ucomm-message_focus AND client->get_event( ) <> cs_ucomm-messages_open.
      CLEAR mt_cgui_log.
    ENDIF.

    IF client->check_on_init( ).
      mv_cgui_screen = cs_screen-selection.
      mv_cgui_title = cl_abap_typedescr=>describe_by_object_ref( me )->get_relative_name( ).
      initialization( ).
      " a variant in the URL wins over the one initialization( ) set
      DATA(lv_variant) = variant_from_url( ).
      IF lv_variant IS NOT INITIAL.
        mv_cgui_variant_start = lv_variant.
        mv_cgui_variant_url = abap_true.
      ENDIF.
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
        CLEAR mv_cgui_pending_field.

      WHEN cs_ucomm-variants_loaded.
        on_variants_loaded( ).

      WHEN cs_ucomm-messages_open.
        " the screen stays as it is - the popover opens on it
        mv_cgui_nav = abap_true.
        client->follow_up_action( val   = client->cs_event-control_by_id
                                  t_arg = VALUE #( ( cv_cgui_popover_id ) ( `openBy` ) ( cv_cgui_messages_id ) ) ).

      WHEN cs_ucomm-message_focus.
        mv_cgui_nav = abap_true.
        message_focus( client->get_event_arg( ) ).

      WHEN cs_ucomm-variant_get.
        variant_popup( cs_pending-variant_get ).

      WHEN cs_ucomm-variant_save.
        variant_popup( cs_pending-variant_save ).

      WHEN cs_ucomm-variant_delete.
        variant_popup( cs_pending-variant_delete ).

      WHEN cs_ucomm-variant_delete_ok.
        variant_delete( mv_cgui_pending_field ).
        CLEAR mv_cgui_pending_field.

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

    DATA lo_input TYPE REF TO z2ui5_cl_popup_input_val.

    IF mv_cgui_pending_kind IS INITIAL.
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

      WHEN cs_pending-variant_get.
        DATA(lv_name) = variant_selected( ).
        IF lv_name IS NOT INITIAL AND variant_apply( lv_name ) = abap_true.
          message( |Variant { lv_name } loaded| ).
        ENDIF.

      WHEN cs_pending-variant_save.
        TRY.
            lo_input ?= client->get_app_prev( ).
          CATCH cx_root.
            RETURN.
        ENDTRY.
        IF lo_input->result( )-check_confirmed = abap_true.
          variant_save( condense( lo_input->result( )-value ) ).
        ENDIF.

      WHEN cs_pending-variant_delete.
        lv_name = variant_selected( ).
        IF lv_name IS NOT INITIAL.
          " the name waits in mv_cgui_pending_field for the confirmation
          mv_cgui_pending_field = lv_name.
          popup_to_confirm( question = |Delete the variant { lv_name }?|
                            ucomm    = cs_ucomm-variant_delete_ok
                            title    = `Delete Variant` ).
        ENDIF.

    ENDCASE.

  ENDMETHOD.

  METHOD variant_popup.

    DATA lt_row TYPE ty_t_variant_row.

    DATA(lt_variant) = z2ui5_cl_cgui_variant=>catalog_from_string( mv_cgui_variants ).

    IF kind = cs_pending-variant_save.
      mv_cgui_pending_kind = kind.
      mv_cgui_nav = abap_true.
      client->nav_app_call( z2ui5_cl_popup_input_val=>factory( text  = `Variant name`
                                                               val   = mv_cgui_variant
                                                               title = `Save as Variant` ) ).
      RETURN.
    ENDIF.

    IF lt_variant IS INITIAL.
      message( text = `No variants saved for this report yet`
               type = `I` ).
      RETURN.
    ENDIF.

    LOOP AT lt_variant REFERENCE INTO DATA(lr_variant).
      INSERT VALUE #( variant = lr_variant->name
                      values  = lr_variant->text ) INTO TABLE lt_row.
    ENDLOOP.

    mv_cgui_pending_kind = kind.
    mv_cgui_nav = abap_true.
    client->nav_app_call( z2ui5_cl_popup_to_select=>factory(
        i_tab   = lt_row
        i_title = COND #( WHEN kind = cs_pending-variant_delete THEN `Delete Variant` ELSE `Get Variant` ) ) ).

  ENDMETHOD.

  METHOD variant_selected.

    FIELD-SYMBOLS <row> TYPE ty_s_variant_row.
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
    result = condense( <row>-variant ).

  ENDMETHOD.

  METHOD variant_apply.

    DATA(lt_variant) = z2ui5_cl_cgui_variant=>catalog_from_string( mv_cgui_variants ).

    READ TABLE lt_variant REFERENCE INTO DATA(lr_variant) WITH KEY name = name.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    z2ui5_cl_cgui_variant=>values_set( app    = me
                                       values = lr_variant->values ).
    mv_cgui_variant = name.
    result = abap_true.

  ENDMETHOD.

  METHOD variant_save.

    DATA lt_name TYPE string_table.

    IF name IS INITIAL.
      message( text = `Enter a name for the variant`
               type = `E` ).
      RETURN.
    ENDIF.

    LOOP AT mt_cgui_field REFERENCE INTO DATA(lr_field).
      INSERT lr_field->name INTO TABLE lt_name.
    ENDLOOP.
    DATA(lt_value) = z2ui5_cl_cgui_variant=>values_get( app   = me
                                                        names = lt_name ).

    DATA(lt_variant) = z2ui5_cl_cgui_variant=>catalog_from_string( mv_cgui_variants ).
    DELETE lt_variant WHERE name = name.
    INSERT VALUE #( name   = name
                    text   = z2ui5_cl_cgui_variant=>values_to_text( values = lt_value
                                                                    fields = mt_cgui_field )
                    values = lt_value ) INTO TABLE lt_variant.
    SORT lt_variant BY name.

    variant_store( lt_variant ).
    mv_cgui_variant = name.
    message( |Variant { name } saved| ).

  ENDMETHOD.

  METHOD variant_delete.

    DATA(lt_variant) = z2ui5_cl_cgui_variant=>catalog_from_string( mv_cgui_variants ).
    DELETE lt_variant WHERE name = name.

    variant_store( lt_variant ).
    IF mv_cgui_variant = name.
      CLEAR mv_cgui_variant.
    ENDIF.
    message( |Variant { name } deleted| ).

  ENDMETHOD.

  METHOD variant_store.

    " the bound value and the stored one stay the same, so the storage
    " control has nothing to report on the next render. An empty catalog
    " removes the key
    CLEAR mv_cgui_variants.
    IF variants IS NOT INITIAL.
      mv_cgui_variants = z2ui5_cl_cgui_variant=>catalog_to_string( variants ).
    ENDIF.

    client->follow_up_action( val   = client->cs_event-store_data
                              t_arg = VALUE #( ( z2ui5_cl_cgui_variant=>storage_json( prefix = cv_cgui_variant_prefix
                                                                                      key    = variant_key( )
                                                                                      val    = mv_cgui_variants ) ) ) ).

  ENDMETHOD.

  METHOD variant_key.

    result = cl_abap_typedescr=>describe_by_object_ref( me )->get_relative_name( ).

  ENDMETHOD.

  METHOD variant_from_url.

    DATA lt_param TYPE string_table.
    DATA lv_name  TYPE string.
    DATA lv_value TYPE string.

    LOOP AT client->get( )-t_comp_params REFERENCE INTO DATA(lr_comp).
      IF to_upper( lr_comp->n ) = `VARIANT`.
        result = lr_comp->v.
        RETURN.
      ENDIF.
    ENDLOOP.

    DATA(lv_search) = client->get( )-s_config-search.
    IF lv_search IS INITIAL.
      RETURN.
    ENDIF.
    IF lv_search(1) = `?`.
      lv_search = lv_search+1.
    ENDIF.

    SPLIT lv_search AT `&` INTO TABLE lt_param.
    LOOP AT lt_param INTO DATA(lv_param).
      SPLIT lv_param AT `=` INTO lv_name lv_value.
      IF to_upper( lv_name ) = `VARIANT`.
        result = replace( val = lv_value sub = `+` with = ` ` occ = 0 ).
        result = replace( val = result sub = `%20` with = ` ` occ = 0 ).
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD on_variants_loaded.

    " the storage control has put the stored variants into mv_cgui_variants
    IF mv_cgui_variant_start IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_start) = mv_cgui_variant_start.
    CLEAR mv_cgui_variant_start.
    IF variant_apply( lv_start ) = abap_false AND mv_cgui_variant_url = abap_true.
      message( text = |Variant { lv_start } does not exist|
               type = `W` ).
    ENDIF.

  ENDMETHOD.

  METHOD set_variant.

    DATA lv_name TYPE string.

    lv_name = name.
    mv_cgui_variant_url = abap_false.
    IF mv_cgui_variants IS INITIAL OR variant_apply( lv_name ) = abap_false.
      mv_cgui_variant_start = lv_name.
    ENDIF.

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

    " one message per empty required field, each at its field
    FIELD-SYMBOLS <val> TYPE any.

    result = abap_true.
    LOOP AT mt_cgui_field REFERENCE INTO DATA(lr_field) WHERE obligatory = abap_true.
      DATA(lr_val) = attri_assign( lr_field->name ).
      IF lr_val IS NOT BOUND.
        CONTINUE.
      ENDIF.
      ASSIGN lr_val->* TO <val>.
      IF <val> IS NOT INITIAL.
        CONTINUE.
      ENDIF.
      message( text  = |Fill in the required field { lr_field->text }|
               type  = `E`
               field = lr_field->name ).
      result = abap_false.
    ENDLOOP.

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

    DATA(ls_msg) = VALUE ty_s_cgui_msg( type  = to_upper( type )
                                        text  = text
                                        field = lv_field ).
    INSERT ls_msg INTO TABLE mt_cgui_msg.
    IF ls_msg-type <> `S`.
      INSERT ls_msg INTO TABLE mt_cgui_log.
    ENDIF.
    IF ls_msg-type = `E` OR ls_msg-type = `A`.
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
            )->a( n = `xmlns:z2ui5`  v = `z2ui5.cc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%` ).

    DATA(page) = view->ele( `Page`
        )->a( n = `title`          t = mv_cgui_title
        )->a( n = `showNavButton`  b = xsdbool( mv_cgui_screen = cs_screen-output )
        )->a( n = `navButtonPress` v = client->_event( cs_ucomm-back ) ).

    " reads the variants out of the browser's local storage into
    " mv_cgui_variants and reports them when they differ from what the
    " backend has - fired while the first view still renders, so the event
    " is queued instead of dropped (check_queue_last)
    page->tag( n = `Storage` ns = `z2ui5`
        )->a( n = `type`     v = `local`
        )->a( n = `prefix`   v = cv_cgui_variant_prefix
        )->a( n = `key`      t = variant_key( )
        )->a( n = `value`    v = client->_bind( mv_cgui_variants )
        )->a( n = `finished` v = client->_event( val    = cs_ucomm-variants_loaded
                                                 s_ctrl = VALUE #( check_queue_last = abap_true ) ) ).

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

    DATA(toolbar) = page->ele( `footer`
        )->ele( `OverflowToolbar` ).

    messages_render( page    = page
                     toolbar = toolbar ).

    IF mv_cgui_screen = cs_screen-selection AND mt_cgui_field IS NOT INITIAL.
      toolbar->tag( `Button`
          )->a( n = `text`  v = `Get Variant`
          )->a( n = `icon`  v = `sap-icon://open-folder`
          )->a( n = `press` v = client->_event( cs_ucomm-variant_get )
          )->tag( `Button`
          )->a( n = `text`  v = `Save as Variant`
          )->a( n = `icon`  v = `sap-icon://save`
          )->a( n = `press` v = client->_event( cs_ucomm-variant_save )
          )->tag( `Button`
          )->a( n = `text`  v = `Delete Variant`
          )->a( n = `icon`  v = `sap-icon://delete`
          )->a( n = `press` v = client->_event( cs_ucomm-variant_delete ) ).
    ENDIF.

    toolbar->tag( `ToolbarSpacer`
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

    LOOP AT mt_cgui_log REFERENCE INTO DATA(lr_msg) WHERE field IS NOT INITIAL.
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

    " S as a toast, I as a box - and W, E, A open the message popover,
    " which lists the I messages of the run as well
    DATA lv_text    TYPE string.
    DATA lv_popover TYPE abap_bool.

    LOOP AT mt_cgui_msg REFERENCE INTO DATA(lr_msg).
      CASE lr_msg->type.
        WHEN `S`.
          client->message_toast_display( lr_msg->text ).
        WHEN `I`.
          IF lv_text IS NOT INITIAL.
            lv_text = lv_text && cl_abap_char_utilities=>newline.
          ENDIF.
          lv_text = lv_text && lr_msg->text.
        WHEN OTHERS.
          lv_popover = abap_true.
      ENDCASE.
    ENDLOOP.

    IF lv_popover = abap_true AND mv_cgui_nav = abap_false.
      " the popover is part of the screen, and opened in a roundtrip of its
      " own: opened by the response that builds the screen, it stayed open
      " without ever being rendered (the frontend holds the rendering back
      " while it swaps the view). A timer of no time raises that roundtrip
      client->follow_up_action( val   = client->cs_event-start_timer
                                t_arg = VALUE #( ( cs_ucomm-messages_open ) ( `0` ) ( `X` ) ) ).
    ELSEIF lv_text IS NOT INITIAL.
      client->message_box_display( text = lv_text
                                   type = `information` ).
    ENDIF.

  ENDMETHOD.

  METHOD messages_render.

    " the button counts the messages of the run - icon and type follow the
    " worst of them - and opens the popover in the browser, no roundtrip.
    " The popover is a dependent of the page, not a popover of its own: it
    " comes and goes with the screen it belongs to
    DATA lv_index TYPE i.

    IF mt_cgui_log IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_icon) = `sap-icon://message-information`.
    DATA(lv_type) = `Transparent`.
    READ TABLE mt_cgui_log WITH KEY type = `W` TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      lv_icon = `sap-icon://message-warning`.
      lv_type = `Default`.
    ENDIF.
    LOOP AT mt_cgui_log TRANSPORTING NO FIELDS WHERE type = `E` OR type = `A`.
      lv_icon = `sap-icon://message-error`.
      lv_type = `Reject`.
      EXIT.
    ENDLOOP.

    toolbar->tag( `Button`
        )->a( n = `id`      v = cv_cgui_messages_id
        )->a( n = `icon`    v = lv_icon
        )->a( n = `type`    v = lv_type
        )->a( n = `text`    t = |{ lines( mt_cgui_log ) }|
        )->a( n = `tooltip` v = `Messages`
        )->a( n = `press`   v = client->follow_up_action( val   = client->cs_event-control_by_id
                                                          t_arg = VALUE #( ( cv_cgui_popover_id ) ( `toggleBy` ) ( cv_cgui_messages_id ) ) ) ).

    DATA(items) = page->ele( `dependents`
        )->ele( `MessagePopover`
            )->a( n = `id`               v = cv_cgui_popover_id
            )->a( n = `placement`        v = `Top`
            )->a( n = `activeTitlePress` v = client->_event( val = cs_ucomm-message_focus
                                                             arg = `${$parameters>/item}` )
        )->ele( `items` ).

    " the id carries the index into the log: the event hands the item over
    " as its properties and its id, and the id leads back to the field
    LOOP AT mt_cgui_log REFERENCE INTO DATA(lr_msg).
      lv_index = sy-tabix.
      items->tag( `MessageItem`
          )->a( n = `id`          t = |cgui_msg_{ lv_index }|
          )->a( n = `type`        v = SWITCH #( lr_msg->type
                                                  WHEN `E` OR `A` THEN `Error`
                                                  WHEN `W` THEN `Warning`
                                                  ELSE `Information` )
          )->a( n = `title`       t = lr_msg->text
          )->a( n = `subtitle`    t = message_field_text( lr_msg->field )
          )->a( n = `activeTitle` b = xsdbool( lr_msg->field IS NOT INITIAL AND mv_cgui_screen = cs_screen-selection ) ).
    ENDLOOP.

  ENDMETHOD.

  METHOD message_focus.

    DATA lv_index TYPE string.

    client->follow_up_action( val   = client->cs_event-control_by_id
                              t_arg = VALUE #( ( cv_cgui_popover_id ) ( `close` ) ) ).

    FIND REGEX `cgui_msg_(\d+)` IN arg SUBMATCHES lv_index.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    READ TABLE mt_cgui_log REFERENCE INTO DATA(lr_msg) INDEX CONV i( lv_index ).
    IF sy-subrc <> 0 OR lr_msg->field IS INITIAL OR mv_cgui_screen <> cs_screen-selection.
      RETURN.
    ENDIF.

    client->follow_up_action( val   = client->cs_event-set_focus
                              t_arg = VALUE #( ( z2ui5_cl_cgui_selscreen=>field_id( lr_msg->field ) ) ) ).

  ENDMETHOD.

  METHOD message_field_text.

    IF field IS INITIAL.
      RETURN.
    ENDIF.
    READ TABLE mt_cgui_field REFERENCE INTO DATA(lr_field) WITH KEY name = field.
    IF sy-subrc = 0.
      result = lr_field->text.
    ELSE.
      result = field.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
