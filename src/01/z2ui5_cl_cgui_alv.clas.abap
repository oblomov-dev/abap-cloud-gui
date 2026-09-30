"! ALV grid - the abap2UI5 counterpart of CL_SALV_TABLE, built on
"! z2ui5_cl_ui5_view_builder. The columns come from the line type of the
"! table (RTTI), their headers from the DDIC labels; sorting, filtering and
"! the column menu run in the browser without a roundtrip.
"! The object only holds the settings - it binds nothing and is
"! serializable, so it can stay an attribute of the app. The table itself
"! is handed to render( ) / stringify( ) and must be a PUBLIC attribute of
"! the app (or the target of one of its data references):
"!   client->view_display( z2ui5_cl_cgui_alv=>factory(
"!       )->set_title( `Flights`
"!       )->set_column_hidden( `MANDT`
"!       )->stringify( client = client
"!                     tab    = mt_flight ) ).
"! A click on a row raises cs_event-line_selection when set_line_selection( )
"! is on; get_row_by_event( ) returns the index of that row in the table.
CLASS z2ui5_cl_cgui_alv DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_serializable_object.

    CONSTANTS:
      BEGIN OF cs_event,
        line_selection TYPE string VALUE `CGUI_ALV_LINE_SELECTION`,
      END OF cs_event.

    TYPES:
      BEGIN OF ty_s_column,
        name   TYPE string,
        text   TYPE string,
        hidden TYPE abap_bool,
      END OF ty_s_column.
    TYPES ty_t_column TYPE STANDARD TABLE OF ty_s_column WITH EMPTY KEY.

    CLASS-METHODS factory
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_alv.

    "! the index (1-based) of the row a line selection event was raised on,
    "! 0 when the event carries none
    CLASS-METHODS get_row_by_event
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE i.

    METHODS set_title
      IMPORTING
        val           TYPE clike
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_alv.

    METHODS set_column_text
      IMPORTING
        name          TYPE clike
        text          TYPE clike
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_alv.

    METHODS set_column_hidden
      IMPORTING
        name          TYPE clike
        hidden        TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_alv.

    "! rows are clickable and raise cs_event-line_selection (double click)
    METHODS set_line_selection
      IMPORTING
        val           TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_alv.

    "! the number of rows visible without scrolling
    METHODS set_visible_rows
      IMPORTING
        val           TYPE i
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_alv.

    "! append the grid to node, a container of an existing view whose
    "! default namespace is sap.m
    METHODS render
      IMPORTING
        node   TYPE REF TO z2ui5_cl_ui5_view_builder
        client TYPE REF TO z2ui5_if_client
        tab    TYPE STANDARD TABLE.

    "! the grid as a complete view
    METHODS stringify
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
        tab           TYPE STANDARD TABLE
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.
    " PROTECTED, not PRIVATE: the settings travel in the app's draft, and the
    " transpiled runtime reaches PROTECTED attributes but not PRIVATE ones
    DATA mv_title          TYPE string.
    DATA mv_line_selection TYPE abap_bool.
    DATA mv_visible_rows   TYPE i.
    DATA mt_column         TYPE ty_t_column.

  PRIVATE SECTION.

    METHODS column_get
      IMPORTING
        name          TYPE clike
      RETURNING
        VALUE(result) TYPE REF TO ty_s_column.

    METHODS render_columns
      IMPORTING
        node TYPE REF TO z2ui5_cl_ui5_view_builder
        tab  TYPE STANDARD TABLE.

ENDCLASS.


CLASS z2ui5_cl_cgui_alv IMPLEMENTATION.

  METHOD factory.

    result = NEW #( ).

  ENDMETHOD.

  METHOD get_row_by_event.

    DATA lt_path TYPE string_table.

    SPLIT client->get_event_arg( ) AT `/` INTO TABLE lt_path.
    IF lt_path IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_last) = lt_path[ lines( lt_path ) ].
    IF lv_last IS INITIAL OR lv_last CN `0123456789`.
      RETURN.
    ENDIF.
    result = lv_last + 1.

  ENDMETHOD.

  METHOD set_title.

    mv_title = val.
    result = me.

  ENDMETHOD.

  METHOD set_column_text.

    DATA(lr_column) = column_get( name ).
    lr_column->text = text.
    result = me.

  ENDMETHOD.

  METHOD set_column_hidden.

    DATA(lr_column) = column_get( name ).
    lr_column->hidden = hidden.
    result = me.

  ENDMETHOD.

  METHOD set_line_selection.

    mv_line_selection = val.
    result = me.

  ENDMETHOD.

  METHOD set_visible_rows.

    mv_visible_rows = val.
    result = me.

  ENDMETHOD.

  METHOD column_get.

    DATA(lv_name) = to_upper( name ).
    READ TABLE mt_column REFERENCE INTO result WITH KEY name = lv_name.
    IF sy-subrc <> 0.
      INSERT VALUE #( name = lv_name ) INTO TABLE mt_column REFERENCE INTO result.
    ENDIF.

  ENDMETHOD.

  METHOD render.

    DATA(lv_rows) = mv_visible_rows.
    IF lv_rows <= 0.
      lv_rows = lines( tab ).
      IF lv_rows > 15.
        lv_rows = 15.
      ELSEIF lv_rows < 3.
        lv_rows = 3.
      ENDIF.
    ENDIF.

    DATA(lo_table) = node->ele( n = `Table` ns = `table`
        )->a( n = `xmlns:table`        v = `sap.ui.table`
        )->a( n = `rows`               v = client->_bind( tab )
        )->a( n = `selectionMode`      v = `None`
        )->a( n = `alternateRowColors` b = abap_true
        )->a( n = `visibleRowCount`    v = |{ lv_rows }|
        )->a( n = `class`              v = `sapUiSmallMargin` ).

    IF mv_line_selection = abap_true.
      lo_table->a( n = `cellClick` v = client->_event( val = cs_event-line_selection
                                                       arg = `${$parameters>/rowBindingContext}.getPath()` ) ).
    ENDIF.

    lo_table->ele( n = `extension` ns = `table`
        )->ele( `OverflowToolbar`
            )->tag( `Title`
                )->a( n = `text` t = |{ mv_title } ({ lines( tab ) })| ).

    render_columns( node = lo_table->ele( n = `columns` ns = `table` )
                    tab  = tab ).

  ENDMETHOD.

  METHOD render_columns.

    LOOP AT z2ui5_cl_cgui_context=>rtti_get_t_comp( tab ) REFERENCE INTO DATA(lr_comp).

      DATA(lv_text) = lr_comp->label.
      READ TABLE mt_column REFERENCE INTO DATA(lr_column) WITH KEY name = lr_comp->name.
      IF sy-subrc = 0.
        IF lr_column->hidden = abap_true.
          CONTINUE.
        ENDIF.
        IF lr_column->text IS NOT INITIAL.
          lv_text = lr_column->text.
        ENDIF.
      ENDIF.

      DATA(lv_align) = `Begin`.
      CASE lr_comp->type_kind.
        WHEN cl_abap_typedescr=>typekind_int
            OR cl_abap_typedescr=>typekind_int1
            OR cl_abap_typedescr=>typekind_int2
            OR cl_abap_typedescr=>typekind_packed
            OR cl_abap_typedescr=>typekind_float.
          lv_align = `End`.
      ENDCASE.

      DATA(lo_column) = node->ele( n = `Column` ns = `table`
          )->a( n = `sortProperty`   t = lr_comp->name
          )->a( n = `filterProperty` t = lr_comp->name
          )->a( n = `hAlign`         v = lv_align ).

      lo_column->ele( n = `label` ns = `table`
          )->tag( `Label`
              )->a( n = `text` t = lv_text ).

      lo_column->ele( n = `template` ns = `table`
          )->tag( `Text`
              )->a( n = `text`     v = |\{{ lr_comp->name }\}|
              )->a( n = `wrapping` b = abap_false ).

    ENDLOOP.

  ENDMETHOD.

  METHOD stringify.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%` ).

    DATA(page) = view->ele( `Page`
        )->a( n = `title` t = mv_title ).

    render( node   = page
            client = client
            tab    = tab ).

    result = view->stringify( ).

  ENDMETHOD.

ENDCLASS.
