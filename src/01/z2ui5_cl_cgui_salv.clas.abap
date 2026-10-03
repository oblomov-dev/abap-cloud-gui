" cloud gui - CL_SALV_TABLE for converted reports: the methods of the SALV
" object model with their names and parameters, applied to the ALV of the
" report. One class plays all roles - table, columns, column, functions,
" display settings, sorts, aggregations, selections - so the converter
" only changes the types: TYPE REF TO cl_salv_... becomes
" TYPE REF TO z2ui5_cl_cgui_salv, and
"   cl_salv_table=>factory( IMPORTING r_salv_table = gr CHANGING t_table = gt )
" becomes
"   gr = z2ui5_cl_cgui_salv=>factory( alv = alv( gt ) report = me ).
" display( ) shows nothing - the report shows its ALV after the run. The
" events of CL_SALV_EVENTS_TABLE have no counterpart: a hotspot or double
" click arrives in at_link_click( ) / at_line_selection( ) of the report
CLASS z2ui5_cl_cgui_salv DEFINITION PUBLIC FINAL CREATE PRIVATE.

  PUBLIC SECTION.
    " its events from the report; kept in the draft of abap2UI5
    INTERFACES z2ui5_if_cgui_alv_events.

    TYPES ty_t_row TYPE STANDARD TABLE OF i WITH EMPTY KEY.

    " a handler of the events of CL_SALV_EVENTS_TABLE - kept by name, not as
    " a registration: SET HANDLER does not survive the draft of abap2UI5
    TYPES:
      BEGIN OF ty_s_handler,
        event  TYPE string,
        class  TYPE string,
        method TYPE string,
        static TYPE abap_bool,
        params TYPE string_table,
      END OF ty_s_handler.
    TYPES ty_t_handler TYPE STANDARD TABLE OF ty_s_handler WITH EMPTY KEY.

    CONSTANTS:
      BEGIN OF cs_event,
        double_click   TYPE string VALUE `DOUBLE_CLICK`,
        link_click     TYPE string VALUE `LINK_CLICK`,
        added_function TYPE string VALUE `ADDED_FUNCTION`,
      END OF cs_event.

    CLASS-METHODS factory
      IMPORTING
        alv           TYPE REF TO z2ui5_cl_cgui_alv
        report        TYPE REF TO z2ui5_cl_cgui_report OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_salv.

    "! the ALV of the report behind the SALV object
    METHODS get_alv
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_alv.

    "! the column of a column object - empty for the others
    METHODS get_columnname
      RETURNING
        VALUE(result) TYPE string.

    " ------------------------------------------------------------- table
    METHODS display.

    " the events of the table - this object itself; the converter turns
    "   SET HANDLER h FOR gr->get_event( )
    " into
    "   gr->get_event( )->set_handler( ... )
    METHODS get_event
      RETURNING
        VALUE(value) TYPE REF TO z2ui5_cl_cgui_salv.

    " the handler methods of handler (an object) or class (a class name,
    " also a local class of the report) for DOUBLE_CLICK, LINK_CLICK and
    " ADDED_FUNCTION of CL_SALV_EVENTS_TABLE - all of them, or only method
    METHODS set_handler
      IMPORTING
        handler TYPE REF TO object OPTIONAL
        class   TYPE clike OPTIONAL
        method  TYPE clike OPTIONAL.

    METHODS get_handlers
      RETURNING
        VALUE(result) TYPE ty_t_handler.

    " the event to its handlers - abap_true when one ran. Called by the
    " report: hotspot LINK_CLICK, line selection DOUBLE_CLICK, own functions
    " ADDED_FUNCTION
    METHODS raise
      IMPORTING
        event         TYPE clike
        row           TYPE i OPTIONAL
        column        TYPE clike OPTIONAL
        function      TYPE clike OPTIONAL
      RETURNING
        VALUE(result) TYPE abap_bool.

    METHODS refresh
      IMPORTING
        s_stable     TYPE any OPTIONAL
        refresh_mode TYPE any OPTIONAL ##NEEDED.

    METHODS get_columns
      RETURNING
        VALUE(value) TYPE REF TO z2ui5_cl_cgui_salv.

    METHODS get_functions
      RETURNING
        VALUE(value) TYPE REF TO z2ui5_cl_cgui_salv.

    METHODS get_display_settings
      RETURNING
        VALUE(value) TYPE REF TO z2ui5_cl_cgui_salv.

    METHODS get_sorts
      RETURNING
        VALUE(value) TYPE REF TO z2ui5_cl_cgui_salv.

    METHODS get_aggregations
      RETURNING
        VALUE(value) TYPE REF TO z2ui5_cl_cgui_salv.

    METHODS get_selections
      RETURNING
        VALUE(value) TYPE REF TO z2ui5_cl_cgui_salv.

    METHODS get_layout
      RETURNING
        VALUE(value) TYPE REF TO z2ui5_cl_cgui_salv.

    METHODS get_functional_settings
      RETURNING
        VALUE(value) TYPE REF TO z2ui5_cl_cgui_salv.

    "! the own status of the SAP GUI - kept by nobody: the functions come
    "! with add_function( )
    METHODS set_screen_status
      IMPORTING
        pfstatus      TYPE any OPTIONAL
        report        TYPE any OPTIONAL
        set_functions TYPE any OPTIONAL ##NEEDED.

    " ----------------------------------------------------------- columns
    METHODS get_column
      IMPORTING
        columnname   TYPE clike
      RETURNING
        VALUE(value) TYPE REF TO z2ui5_cl_cgui_salv.

    METHODS set_optimize
      IMPORTING
        value TYPE abap_bool DEFAULT abap_true.

    METHODS set_column_position
      IMPORTING
        columnname TYPE clike
        position   TYPE i.

    METHODS set_key_fixation
      IMPORTING
        value TYPE abap_bool DEFAULT abap_true.

    METHODS set_count_column
      IMPORTING
        value TYPE clike ##NEEDED.

    METHODS set_color_column
      IMPORTING
        value TYPE clike.

    " ------------------------------------------------------------ column
    METHODS set_long_text
      IMPORTING
        value TYPE clike.

    METHODS set_medium_text
      IMPORTING
        value TYPE clike.

    METHODS set_short_text
      IMPORTING
        value TYPE clike.

    METHODS set_tooltip
      IMPORTING
        value TYPE clike.

    METHODS set_technical
      IMPORTING
        value TYPE abap_bool DEFAULT abap_true.

    METHODS set_visible
      IMPORTING
        value TYPE abap_bool DEFAULT abap_true.

    METHODS set_output_length
      IMPORTING
        value TYPE i.

    METHODS set_key
      IMPORTING
        value TYPE abap_bool DEFAULT abap_true.

    METHODS set_zero
      IMPORTING
        value TYPE abap_bool DEFAULT abap_true.

    " if_salv_c_alignment=>left / right / centered
    METHODS set_alignment
      IMPORTING
        value TYPE i.

    " if_salv_c_cell_type=>hotspot / checkbox / ... - hotspot and link
    " become the hotspot of the ALV
    METHODS set_cell_type
      IMPORTING
        value TYPE i.

    METHODS set_currency_column
      IMPORTING
        value TYPE clike.

    METHODS set_quantity_column
      IMPORTING
        value TYPE clike.

    METHODS set_icon
      IMPORTING
        value TYPE abap_bool DEFAULT abap_true.

    " --------------------------------------------------------- functions
    METHODS set_default
      IMPORTING
        value TYPE abap_bool DEFAULT abap_true.

    METHODS set_all
      IMPORTING
        value TYPE abap_bool DEFAULT abap_true.

    METHODS add_function
      IMPORTING
        name     TYPE clike
        icon     TYPE clike OPTIONAL
        text     TYPE clike OPTIONAL
        tooltip  TYPE clike OPTIONAL
        position TYPE any OPTIONAL ##NEEDED.

    " -------------------------------------------------- display settings
    METHODS set_striped_pattern
      IMPORTING
        value TYPE abap_bool DEFAULT abap_true.

    METHODS set_list_header
      IMPORTING
        value TYPE clike.

    METHODS set_horizontal_lines
      IMPORTING
        value TYPE abap_bool DEFAULT abap_true ##NEEDED.

    METHODS set_vertical_lines
      IMPORTING
        value TYPE abap_bool DEFAULT abap_true ##NEEDED.

    " ------------------------------------------------------------- sorts
    " sequence: if_salv_c_sort=>sort_up (1) / sort_down (2)
    METHODS add_sort
      IMPORTING
        columnname   TYPE clike
        position     TYPE i OPTIONAL
        sequence     TYPE i DEFAULT 1
        subtotal     TYPE abap_bool DEFAULT abap_false
        group        TYPE any OPTIONAL
        obligatory   TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(value) TYPE REF TO z2ui5_cl_cgui_salv ##NEEDED.

    " ------------------------------------------------------ aggregations
    " aggregation: if_salv_c_aggregation=>total (1) / minimum / maximum /
    " average
    METHODS add_aggregation
      IMPORTING
        columnname   TYPE clike
        aggregation  TYPE i DEFAULT 1
      RETURNING
        VALUE(value) TYPE REF TO z2ui5_cl_cgui_salv.

    " -------------------------------------------------------- selections
    " if_salv_c_selection_mode=>single / multiple / row_column / cell / none
    METHODS set_selection_mode
      IMPORTING
        value TYPE i.

    METHODS get_selected_rows
      RETURNING
        VALUE(value) TYPE ty_t_row.

  PROTECTED SECTION.
  PRIVATE SECTION.

    DATA mo_alv    TYPE REF TO z2ui5_cl_cgui_alv.
    DATA mo_report TYPE REF TO z2ui5_cl_cgui_report.
    DATA mv_column TYPE string.
    DATA mv_text_level TYPE i.
    DATA mt_handler TYPE ty_t_handler.

    METHODS class_describe
      IMPORTING
        name          TYPE clike
      RETURNING
        VALUE(result) TYPE REF TO cl_abap_classdescr.

    METHODS text_set
      IMPORTING
        value TYPE clike
        level TYPE i.

ENDCLASS.



CLASS z2ui5_cl_cgui_salv IMPLEMENTATION.

  METHOD factory.

    result = NEW #( ).
    result->mo_alv = alv.
    result->mo_report = report.

  ENDMETHOD.

  METHOD get_alv.

    result = mo_alv.

  ENDMETHOD.

  METHOD z2ui5_if_cgui_alv_events~get_alv.

    result = mo_alv.

  ENDMETHOD.

  METHOD z2ui5_if_cgui_alv_events~raise.

    result = raise( event    = SWITCH string( kind
                                              WHEN z2ui5_if_cgui_alv_events=>cs_kind-link THEN cs_event-link_click
                                              WHEN z2ui5_if_cgui_alv_events=>cs_kind-double THEN cs_event-double_click
                                              ELSE cs_event-added_function )
                    row      = row
                    column   = column
                    function = function ).

  ENDMETHOD.

  METHOD get_columnname.

    result = mv_column.

  ENDMETHOD.

  METHOD display ##NEEDED.
    " the report shows its ALV after the run
  ENDMETHOD.

  METHOD get_event.

    value = me.

  ENDMETHOD.

  METHOD set_handler.

    DATA lo_class TYPE REF TO cl_abap_classdescr.

    TRY.
        IF handler IS BOUND.
          lo_class ?= cl_abap_typedescr=>describe_by_object_ref( handler ).
        ELSE.
          lo_class = class_describe( class ).
        ENDIF.
      CATCH cx_sy_move_cast_error.
        RETURN.
    ENDTRY.
    IF lo_class IS NOT BOUND.
      RETURN.
    ENDIF.

    LOOP AT lo_class->methods INTO DATA(ls_method) WHERE for_event IS NOT INITIAL.
      IF method IS NOT INITIAL AND ls_method-name <> to_upper( method ).
        CONTINUE.
      ENDIF.
      IF ls_method-of_class NP `CL_SALV_EVENTS*`.
        CONTINUE.
      ENDIF.
      DATA(lv_event) = CONV string( ls_method-for_event ).
      IF lv_event <> cs_event-double_click AND lv_event <> cs_event-link_click
          AND lv_event <> cs_event-added_function.
        CONTINUE.
      ENDIF.
      DELETE mt_handler WHERE class = lo_class->absolute_name AND method = ls_method-name.
      INSERT VALUE #( event  = lv_event
                      class  = lo_class->absolute_name
                      method = ls_method-name
                      static = ls_method-is_class
                      params = VALUE #( FOR ls_param IN ls_method-parameters ( CONV #( ls_param-name ) ) ) )
             INTO TABLE mt_handler.
      " a double click needs a click on the row
      IF lv_event = cs_event-double_click.
        mo_alv->set_line_selection( ).
      ENDIF.
    ENDLOOP.

    IF mo_report IS BOUND.
      mo_report->cgui_salv_register( me ).
    ENDIF.

  ENDMETHOD.

  METHOD get_handlers.

    result = mt_handler.

  ENDMETHOD.

  METHOD class_describe.

    DATA lo_type TYPE REF TO cl_abap_typedescr.

    cl_abap_typedescr=>describe_by_name( EXPORTING  p_name         = name
                                         RECEIVING  p_descr_ref    = lo_type
                                         EXCEPTIONS type_not_found = 1
                                                    OTHERS         = 2 ).
    IF sy-subrc <> 0 AND mo_report IS BOUND.
      " a local class of the report: \CLASS-POOL=<class of the report>\CLASS=<name>
      DATA(lv_absolute) = cl_abap_typedescr=>describe_by_object_ref( mo_report )->absolute_name.
      DATA(lv_pool) = COND string( WHEN lv_absolute CS `\CLASS-POOL=`
                                   THEN substring_before( val = lv_absolute sub = `\CLASS=` )
                                   ELSE |\\CLASS-POOL={ substring_after( val = lv_absolute sub = `\CLASS=` ) }| ).
      cl_abap_typedescr=>describe_by_name( EXPORTING  p_name         = |{ lv_pool }\\CLASS={ to_upper( name ) }|
                                           RECEIVING  p_descr_ref    = lo_type
                                           EXCEPTIONS type_not_found = 1
                                                      OTHERS         = 2 ).
    ENDIF.
    IF sy-subrc = 0.
      TRY.
          result ?= lo_type.
        CATCH cx_sy_move_cast_error.
          CLEAR result.
      ENDTRY.
    ENDIF.

  ENDMETHOD.

  METHOD raise.

    DATA lt_param    TYPE abap_parmbind_tab.
    DATA lv_row      TYPE salv_de_row.
    DATA lv_column   TYPE salv_de_column.
    DATA lv_function TYPE salv_de_function.
    DATA lo_handler  TYPE REF TO object.

    lv_row = row.
    lv_column = to_upper( column ).
    lv_function = function.

    LOOP AT mt_handler INTO DATA(ls_handler) WHERE event = event.
      CLEAR lt_param.
      LOOP AT ls_handler-params INTO DATA(lv_param).
        CASE lv_param.
          WHEN `ROW`.
            INSERT VALUE #( name  = lv_param
                            kind  = cl_abap_objectdescr=>exporting
                            value = REF #( lv_row ) ) INTO TABLE lt_param.
          WHEN `COLUMN`.
            INSERT VALUE #( name  = lv_param
                            kind  = cl_abap_objectdescr=>exporting
                            value = REF #( lv_column ) ) INTO TABLE lt_param.
          WHEN `E_SALV_FUNCTION`.
            INSERT VALUE #( name  = lv_param
                            kind  = cl_abap_objectdescr=>exporting
                            value = REF #( lv_function ) ) INTO TABLE lt_param.
        ENDCASE.
      ENDLOOP.
      TRY.
          IF ls_handler-static = abap_true.
            CALL METHOD (ls_handler-class)=>(ls_handler-method) PARAMETER-TABLE lt_param.
          ELSE.
            " a fresh handler object - the one of SET HANDLER is gone with the
            " roundtrip
            CREATE OBJECT lo_handler TYPE (ls_handler-class).
            CALL METHOD lo_handler->(ls_handler-method) PARAMETER-TABLE lt_param.
          ENDIF.
          result = abap_true.
        CATCH cx_sy_dyn_call_error cx_sy_create_object_error.
          CONTINUE.
      ENDTRY.
    ENDLOOP.

  ENDMETHOD.

  METHOD refresh ##NEEDED.
    " every roundtrip shows the table as it is
  ENDMETHOD.

  METHOD get_columns.

    value = me.

  ENDMETHOD.

  METHOD get_functions.

    value = me.

  ENDMETHOD.

  METHOD get_display_settings.

    value = me.

  ENDMETHOD.

  METHOD get_sorts.

    value = me.

  ENDMETHOD.

  METHOD get_aggregations.

    value = me.

  ENDMETHOD.

  METHOD get_selections.

    value = me.

  ENDMETHOD.

  METHOD get_layout.

    value = me.

  ENDMETHOD.

  METHOD get_functional_settings.

    value = me.

  ENDMETHOD.

  METHOD set_screen_status ##NEEDED.
  ENDMETHOD.

  METHOD get_column.

    value = NEW #( ).
    value->mo_alv = mo_alv.
    value->mo_report = mo_report.
    value->mv_column = to_upper( columnname ).

  ENDMETHOD.

  METHOD set_optimize.

    mo_alv->set_optimize( value ).

  ENDMETHOD.

  METHOD set_column_position.

    mo_alv->set_column_position( name     = to_upper( columnname )
                                 position = position ).

  ENDMETHOD.

  METHOD set_key_fixation.

    " the key columns stay at the left - the default of the ALV
    IF value = abap_false.
      mo_alv->set_fixed_columns( 0 ).
    ENDIF.

  ENDMETHOD.

  METHOD set_count_column ##NEEDED.
  ENDMETHOD.

  METHOD set_color_column.

    " the field of type LVC_T_SCOL has no counterpart - a field with a
    " color code Cxyz does
    mo_alv->set_color_field( to_upper( value ) ).

  ENDMETHOD.

  METHOD text_set.

    " the long text wins, the medium the short - whatever order they come in
    IF mv_column IS INITIAL OR level < mv_text_level.
      RETURN.
    ENDIF.
    mv_text_level = level.
    mo_alv->set_column_text( name = mv_column
                             text = value ).

  ENDMETHOD.

  METHOD set_long_text.

    text_set( value = value
              level = 3 ).

  ENDMETHOD.

  METHOD set_medium_text.

    text_set( value = value
              level = 2 ).

  ENDMETHOD.

  METHOD set_short_text.

    text_set( value = value
              level = 1 ).

  ENDMETHOD.

  METHOD set_tooltip.

    mo_alv->set_column_tooltip( name = mv_column
                                text = value ).

  ENDMETHOD.

  METHOD set_technical.

    mo_alv->set_column_technical( name = mv_column
                                  val  = value ).

  ENDMETHOD.

  METHOD set_visible.

    mo_alv->set_column_hidden( name   = mv_column
                               hidden = xsdbool( value = abap_false ) ).

  ENDMETHOD.

  METHOD set_output_length.

    IF value > 0.
      " a character is about 0.6 rem wide
      mo_alv->set_column_width( name  = mv_column
                                width = |{ value * 6 / 10 + 1 }rem| ).
    ENDIF.

  ENDMETHOD.

  METHOD set_key.

    mo_alv->set_column_key( name = mv_column
                            val  = value ).

  ENDMETHOD.

  METHOD set_zero.

    mo_alv->set_column_no_zero( name = mv_column
                                val  = xsdbool( value = abap_false ) ).

  ENDMETHOD.

  METHOD set_alignment.

    mo_alv->set_column_alignment( name  = mv_column
                                  align = SWITCH #( value
                                                    WHEN 2 THEN z2ui5_cl_cgui_alv=>cs_align-right
                                                    WHEN 3 THEN z2ui5_cl_cgui_alv=>cs_align-center
                                                    ELSE z2ui5_cl_cgui_alv=>cs_align-left ) ).

  ENDMETHOD.

  METHOD set_cell_type.

    CASE value.
      WHEN 4 OR 5.
        " link, hotspot
        mo_alv->set_column_hotspot( mv_column ).
      WHEN 6.
        mo_alv->set_column_cell_type( name = mv_column
                                      type = z2ui5_cl_cgui_alv=>cs_cell_type-checkbox_hotspot ).
      WHEN 2.
        mo_alv->set_column_cell_type( name = mv_column
                                      type = z2ui5_cl_cgui_alv=>cs_cell_type-button ).
      WHEN OTHERS.
        " text, checkbox: as the type of the field says
    ENDCASE.

  ENDMETHOD.

  METHOD set_currency_column.

    mo_alv->set_column_currency( name           = mv_column
                                 currency_field = to_upper( value ) ).

  ENDMETHOD.

  METHOD set_quantity_column.

    mo_alv->set_column_quantity( name       = mv_column
                                 unit_field = to_upper( value ) ).

  ENDMETHOD.

  METHOD set_icon.

    mo_alv->set_column_icon( name = mv_column
                             val  = value ).

  ENDMETHOD.

  METHOD set_default.

    mo_alv->set_export( val = value ).

  ENDMETHOD.

  METHOD set_all.

    mo_alv->set_export( val = value ).

  ENDMETHOD.

  METHOD add_function.

    mo_alv->add_function( name    = name
                          icon    = icon
                          text    = text
                          tooltip = tooltip ).

  ENDMETHOD.

  METHOD set_striped_pattern.

    mo_alv->set_striped( value ).

  ENDMETHOD.

  METHOD set_list_header.

    mo_alv->set_title( value ).

  ENDMETHOD.

  METHOD set_horizontal_lines ##NEEDED.
  ENDMETHOD.

  METHOD set_vertical_lines ##NEEDED.
  ENDMETHOD.

  METHOD add_sort.

    mo_alv->set_sort( name       = to_upper( columnname )
                      descending = xsdbool( sequence = 2 )
                      subtotal   = subtotal ).
    value = me.

  ENDMETHOD.

  METHOD add_aggregation.

    mo_alv->set_column_aggregation( name        = to_upper( columnname )
                                    aggregation = SWITCH #( aggregation
                                                            WHEN 2 THEN z2ui5_cl_cgui_alv=>cs_aggregation-minimum
                                                            WHEN 3 THEN z2ui5_cl_cgui_alv=>cs_aggregation-maximum
                                                            WHEN 4 THEN z2ui5_cl_cgui_alv=>cs_aggregation-average
                                                            WHEN 0 THEN z2ui5_cl_cgui_alv=>cs_aggregation-none
                                                            ELSE z2ui5_cl_cgui_alv=>cs_aggregation-sum ) ).
    value = me.

  ENDMETHOD.

  METHOD set_selection_mode.

    CASE value.
      WHEN 0.
        mo_alv->set_selection_mode( val = z2ui5_cl_cgui_alv=>cs_selection_mode-none ).
      WHEN 1.
        mo_alv->set_selection_mode( val = z2ui5_cl_cgui_alv=>cs_selection_mode-single ).
      WHEN OTHERS.
        " multiple, row_column, cell
        mo_alv->set_selection_mode( val = z2ui5_cl_cgui_alv=>cs_selection_mode-multiple ).
    ENDCASE.

  ENDMETHOD.

  METHOD get_selected_rows.

    IF mo_report IS BOUND.
      value = mo_report->cgui_selected_rows( ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
