" cloud gui - CL_GUI_ALV_GRID for converted reports: the methods of the
" grid with their names and parameters, applied to the ALV of the report.
" The converter changes the types (TYPE REF TO cl_gui_alv_grid becomes
" TYPE REF TO z2ui5_cl_cgui_grid) and the creation
"   CREATE OBJECT gr_grid EXPORTING i_parent = gr_container.
" becomes
"   gr_grid = z2ui5_cl_cgui_grid=>factory( me ).
" The containers have no counterpart - the report shows its ALV after the
" run. SET HANDLER becomes set_handler( ): DOUBLE_CLICK, HOTSPOT_CLICK,
" USER_COMMAND and TOOLBAR reach the handlers as in the SAP GUI
CLASS z2ui5_cl_cgui_grid DEFINITION PUBLIC FINAL CREATE PRIVATE.

  PUBLIC SECTION.
    " its events from the report; kept in the draft of abap2UI5
    INTERFACES z2ui5_if_cgui_alv_events.

    " a handler of the events of CL_GUI_ALV_GRID - kept by name, not as a
    " registration: SET HANDLER does not survive the draft of abap2UI5
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
        double_click  TYPE string VALUE `DOUBLE_CLICK`,
        hotspot_click TYPE string VALUE `HOTSPOT_CLICK`,
        user_command  TYPE string VALUE `USER_COMMAND`,
        toolbar       TYPE string VALUE `TOOLBAR`,
      END OF cs_event.

    " the grid on the ALV of report - or on alv itself, without a report
    CLASS-METHODS factory
      IMPORTING
        report        TYPE REF TO z2ui5_cl_cgui_report OPTIONAL
        alv           TYPE REF TO z2ui5_cl_cgui_alv OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_grid.

    " the ALV of the report behind the grid - after
    " set_table_for_first_display( )
    METHODS get_alv
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_alv.

    " the table as the ALV of the report: field catalog (LVC_T_FCAT), layout
    " (LVC_S_LAYO) and sort (LVC_T_SORT) as with the SAP GUI. Variants,
    " print settings and excluded functions are ignored
    METHODS set_table_for_first_display
      IMPORTING
        i_buffer_active      TYPE any OPTIONAL
        i_bypassing_buffer   TYPE any OPTIONAL
        i_consistency_check  TYPE any OPTIONAL
        i_structure_name     TYPE any OPTIONAL
        is_variant           TYPE any OPTIONAL
        i_save               TYPE any OPTIONAL
        i_default            TYPE any OPTIONAL
        is_layout            TYPE any OPTIONAL
        is_print             TYPE any OPTIONAL
        it_special_groups    TYPE any OPTIONAL
        it_toolbar_excluding TYPE any OPTIONAL
        it_hyperlink         TYPE any OPTIONAL
        it_alv_graphics      TYPE any OPTIONAL
        it_except_qinfo      TYPE any OPTIONAL
        ir_salv_adapter      TYPE any OPTIONAL
      CHANGING
        it_outtab            TYPE STANDARD TABLE
        it_fieldcatalog      TYPE STANDARD TABLE OPTIONAL
        it_sort              TYPE STANDARD TABLE OPTIONAL
        it_filter            TYPE STANDARD TABLE OPTIONAL
      EXCEPTIONS
        invalid_parameter_combination
        program_error
        too_many_lines.

    " the handler methods of handler (an object) or class (a class name,
    " also a local class of the report) for DOUBLE_CLICK, HOTSPOT_CLICK,
    " USER_COMMAND and TOOLBAR of CL_GUI_ALV_GRID - all of them, or only
    " method
    METHODS set_handler
      IMPORTING
        handler TYPE REF TO object OPTIONAL
        class   TYPE clike OPTIONAL
        method  TYPE clike OPTIONAL.

    METHODS get_handlers
      RETURNING
        VALUE(result) TYPE ty_t_handler.

    " the event to its handlers - abap_true when one ran
    METHODS raise
      IMPORTING
        event         TYPE clike
        row           TYPE i OPTIONAL
        column        TYPE clike OPTIONAL
        ucomm         TYPE clike OPTIONAL
      RETURNING
        VALUE(result) TYPE abap_bool.

    " TOOLBAR anew: the buttons its handlers add become functions of the ALV
    METHODS set_toolbar_interactive.

    " the functions the TOOLBAR handlers added
    METHODS get_functions
      RETURNING
        VALUE(result) TYPE string_table.

    METHODS refresh_table_display
      IMPORTING
        is_stable      TYPE any OPTIONAL
        i_soft_refresh TYPE any OPTIONAL
      EXCEPTIONS
        finished.

    METHODS get_selected_rows
      EXPORTING
        et_index_rows TYPE lvc_t_row
        et_row_no     TYPE lvc_t_roid.

    METHODS check_changed_data
      EXPORTING
        e_valid   TYPE char01
      CHANGING
        c_refresh TYPE char01 OPTIONAL.

    METHODS set_ready_for_input
      IMPORTING
        i_ready_for_input TYPE i DEFAULT 1.

    METHODS register_edit_event
      IMPORTING
        i_event_id TYPE i OPTIONAL
      EXCEPTIONS
        error.

    METHODS set_frontend_fieldcatalog
      IMPORTING
        it_fieldcatalog TYPE STANDARD TABLE.

    METHODS set_frontend_layout
      IMPORTING
        is_layout TYPE any.

    METHODS set_gridtitle
      IMPORTING
        i_gridtitle TYPE clike.

    METHODS free
      EXCEPTIONS
        cntl_error
        cntl_system_error.

    " a classic icon - ICON_REFRESH, its code @42@ - as icon of UI5
    CLASS-METHODS icon_to_ui5
      IMPORTING
        icon          TYPE clike
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.

    DATA mo_alv       TYPE REF TO z2ui5_cl_cgui_alv.
    DATA mo_report    TYPE REF TO z2ui5_cl_cgui_report.
    DATA mt_handler   TYPE ty_t_handler.
    DATA mt_function  TYPE string_table.
    DATA mv_displayed TYPE abap_bool.

    METHODS class_describe
      IMPORTING
        name          TYPE clike
      RETURNING
        VALUE(result) TYPE REF TO cl_abap_classdescr.

    METHODS toolbar_build.

ENDCLASS.



CLASS z2ui5_cl_cgui_grid IMPLEMENTATION.

  METHOD factory.

    result = NEW #( ).
    result->mo_report = report.
    result->mo_alv = alv.

  ENDMETHOD.

  METHOD get_alv.

    result = mo_alv.

  ENDMETHOD.

  METHOD z2ui5_if_cgui_alv_events~get_alv.

    result = mo_alv.

  ENDMETHOD.

  METHOD z2ui5_if_cgui_alv_events~raise.

    result = raise( event  = SWITCH string( kind
                                            WHEN z2ui5_if_cgui_alv_events=>cs_kind-link THEN cs_event-hotspot_click
                                            WHEN z2ui5_if_cgui_alv_events=>cs_kind-double THEN cs_event-double_click
                                            ELSE cs_event-user_command )
                    row    = row
                    column = column
                    ucomm  = function ).

  ENDMETHOD.

  METHOD set_table_for_first_display.

    IF mo_report IS BOUND.
      mo_alv = mo_report->cgui_alv( it_outtab ).
    ELSEIF mo_alv IS NOT BOUND.
      mo_alv = z2ui5_cl_cgui_alv=>factory( ).
    ENDIF.

    IF it_fieldcatalog IS SUPPLIED AND it_fieldcatalog IS NOT INITIAL.
      mo_alv->set_fieldcat( it_fieldcatalog ).
    ENDIF.
    IF is_layout IS SUPPLIED AND is_layout IS NOT INITIAL.
      mo_alv->set_layout_classic( is_layout ).
    ENDIF.
    IF it_sort IS SUPPLIED AND it_sort IS NOT INITIAL.
      mo_alv->set_sort_classic( it_sort ).
    ENDIF.

    mv_displayed = abap_true.
    " the handlers set before - the line selection and the toolbar
    LOOP AT mt_handler TRANSPORTING NO FIELDS WHERE event = cs_event-double_click.
      mo_alv->set_line_selection( ).
      EXIT.
    ENDLOOP.
    toolbar_build( ).
    IF mo_report IS BOUND.
      mo_report->cgui_salv_register( me ).
    ENDIF.

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
      IF ls_method-of_class <> `CL_GUI_ALV_GRID`.
        CONTINUE.
      ENDIF.
      DATA(lv_event) = CONV string( ls_method-for_event ).
      IF lv_event <> cs_event-double_click AND lv_event <> cs_event-hotspot_click
          AND lv_event <> cs_event-user_command AND lv_event <> cs_event-toolbar.
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
      IF lv_event = cs_event-double_click AND mo_alv IS BOUND.
        mo_alv->set_line_selection( ).
      ENDIF.
    ENDLOOP.

    " a toolbar handler set after the display - as set_toolbar_interactive( )
    IF mv_displayed = abap_true.
      toolbar_build( ).
    ENDIF.
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

    DATA lt_param       TYPE abap_parmbind_tab.
    DATA ls_row         TYPE lvc_s_row.
    DATA ls_col         TYPE lvc_s_col.
    DATA ls_row_no      TYPE lvc_s_roid.
    DATA lv_ucomm       TYPE sy-ucomm.
    DATA lv_interactive TYPE char01.
    DATA lo_toolbar     TYPE REF TO cl_alv_event_toolbar_set.
    DATA lo_handler     TYPE REF TO object.
    DATA lr_value       TYPE REF TO data.

    ls_row-index = row.
    ls_col-fieldname = to_upper( column ).
    ls_row_no-row_id = row.
    lv_ucomm = ucomm.
    IF event = cs_event-toolbar.
      lo_toolbar = NEW #( ).
      lv_interactive = abap_true.
    ENDIF.

    LOOP AT mt_handler INTO DATA(ls_handler) WHERE event = event.
      CLEAR lt_param.
      LOOP AT ls_handler-params INTO DATA(lv_param).
        lr_value = SWITCH #( lv_param
                             WHEN `E_ROW` OR `E_ROW_ID` THEN REF #( ls_row )
                             WHEN `E_COLUMN` OR `E_COLUMN_ID` THEN REF #( ls_col )
                             WHEN `ES_ROW_NO` THEN REF #( ls_row_no )
                             WHEN `E_UCOMM` THEN REF #( lv_ucomm )
                             WHEN `E_OBJECT` THEN REF #( lo_toolbar )
                             WHEN `E_INTERACTIVE` THEN REF #( lv_interactive ) ).
        IF lr_value IS BOUND.
          INSERT VALUE #( name  = lv_param
                          kind  = cl_abap_objectdescr=>exporting
                          value = lr_value ) INTO TABLE lt_param.
        ENDIF.
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

    " the buttons of the toolbar as functions of the ALV
    IF lo_toolbar IS BOUND AND mo_alv IS BOUND.
      LOOP AT lo_toolbar->mt_toolbar INTO DATA(ls_button) WHERE function IS NOT INITIAL AND butn_type <> 3.
        IF line_exists( mt_function[ table_line = ls_button-function ] ).
          CONTINUE.
        ENDIF.
        INSERT CONV string( ls_button-function ) INTO TABLE mt_function.
        mo_alv->add_function( name    = ls_button-function
                              text    = ls_button-text
                              icon    = icon_to_ui5( ls_button-icon )
                              tooltip = ls_button-quickinfo ).
      ENDLOOP.
    ENDIF.

  ENDMETHOD.

  METHOD toolbar_build.

    IF line_exists( mt_handler[ event = cs_event-toolbar ] ).
      raise( cs_event-toolbar ).
    ENDIF.

  ENDMETHOD.

  METHOD set_toolbar_interactive.

    toolbar_build( ).

  ENDMETHOD.

  METHOD get_functions.

    result = mt_function.

  ENDMETHOD.

  METHOD refresh_table_display ##NEEDED.
    " every roundtrip shows the table as it is
  ENDMETHOD.

  METHOD get_selected_rows.

    CLEAR: et_index_rows, et_row_no.
    IF mo_report IS NOT BOUND.
      RETURN.
    ENDIF.
    LOOP AT mo_report->cgui_selected_rows( ) INTO DATA(lv_row).
      INSERT VALUE #( index = lv_row ) INTO TABLE et_index_rows.
      INSERT VALUE #( row_id = lv_row ) INTO TABLE et_row_no.
    ENDLOOP.

  ENDMETHOD.

  METHOD check_changed_data.

    " the changed cells are in the table with every roundtrip
    e_valid = abap_true.

  ENDMETHOD.

  METHOD set_ready_for_input.

    IF mo_alv IS BOUND.
      mo_alv->set_edit( xsdbool( i_ready_for_input <> 0 ) ).
    ENDIF.

  ENDMETHOD.

  METHOD register_edit_event ##NEEDED.
    " a changed cell arrives with the next roundtrip
  ENDMETHOD.

  METHOD set_frontend_fieldcatalog.

    IF mo_alv IS BOUND.
      mo_alv->set_fieldcat( it_fieldcatalog ).
    ENDIF.

  ENDMETHOD.

  METHOD set_frontend_layout.

    IF mo_alv IS BOUND.
      mo_alv->set_layout_classic( is_layout ).
    ENDIF.

  ENDMETHOD.

  METHOD set_gridtitle.

    IF mo_alv IS BOUND.
      mo_alv->set_title( i_gridtitle ).
    ENDIF.

  ENDMETHOD.

  METHOD free ##NEEDED.
    " nothing on a frontend to free
  ENDMETHOD.

  METHOD icon_to_ui5.

    DATA lv_name TYPE string.

    lv_name = to_upper( condense( icon ) ).
    IF lv_name IS INITIAL OR icon CS `sap-icon://`.
      result = icon.
      RETURN.
    ENDIF.
    " the code of the icon, @42@ - its name from table ICON
    IF lv_name(1) = `@`.
      SELECT SINGLE name FROM icon WHERE id = @lv_name INTO @DATA(lv_icon_name).
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      lv_name = lv_icon_name.
    ENDIF.
    result = SWITCH #( lv_name
                       WHEN `ICON_REFRESH` THEN `sap-icon://refresh`
                       WHEN `ICON_CREATE` OR `ICON_INSERT_ROW` THEN `sap-icon://add`
                       WHEN `ICON_CHANGE` OR `ICON_EDIT_FILE` THEN `sap-icon://edit`
                       WHEN `ICON_DELETE` OR `ICON_DELETE_ROW` THEN `sap-icon://delete`
                       WHEN `ICON_SYSTEM_SAVE` THEN `sap-icon://save`
                       WHEN `ICON_PRINT` THEN `sap-icon://print`
                       WHEN `ICON_DISPLAY` THEN `sap-icon://display`
                       WHEN `ICON_OKAY` OR `ICON_CHECKED` OR `ICON_ACCEPT` THEN `sap-icon://accept`
                       WHEN `ICON_CANCEL` OR `ICON_REJECT` THEN `sap-icon://decline`
                       WHEN `ICON_SEARCH` THEN `sap-icon://search`
                       WHEN `ICON_EXPORT` OR `ICON_XLS` THEN `sap-icon://download`
                       WHEN `ICON_IMPORT` THEN `sap-icon://upload`
                       WHEN `ICON_COPY_OBJECT` THEN `sap-icon://copy`
                       WHEN `ICON_DETAIL` THEN `sap-icon://detail-view`
                       WHEN `ICON_EXECUTE_OBJECT` THEN `sap-icon://process`
                       WHEN `ICON_MAIL` THEN `sap-icon://email`
                       WHEN `ICON_RELEASE` THEN `sap-icon://approvals`
                       WHEN `ICON_LOCKED` THEN `sap-icon://locked`
                       WHEN `ICON_UNLOCKED` THEN `sap-icon://unlocked`
                       WHEN `ICON_FILTER` THEN `sap-icon://filter`
                       WHEN `ICON_SORT_UP` THEN `sap-icon://sort-ascending`
                       WHEN `ICON_SORT_DOWN` THEN `sap-icon://sort-descending`
                       WHEN `ICON_INFORMATION` THEN `sap-icon://message-information`
                       WHEN `ICON_WARNING` THEN `sap-icon://message-warning`
                       WHEN `ICON_MESSAGE_ERROR` THEN `sap-icon://message-error`
                       WHEN `ICON_HISTORY` THEN `sap-icon://history`
                       WHEN `ICON_LINK` THEN `sap-icon://chain-link`
                       ELSE `` ).

  ENDMETHOD.

ENDCLASS.
