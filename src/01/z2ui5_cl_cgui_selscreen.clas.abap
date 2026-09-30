"! Selection screen - the abap2UI5 counterpart of PARAMETERS,
"! SELECT-OPTIONS and SELECTION-SCREEN, built on z2ui5_cl_ui5_view_builder.
"! Every field method takes the variable itself - a PUBLIC attribute of the
"! running app - and binds it two-way, so the user's input is in the
"! attribute when the next event arrives:
"!   z2ui5_cl_cgui_selscreen=>factory( client
"!       )->block_begin( `Selection`
"!       )->parameter( val = p_carrid obligatory = abap_true
"!       )->select_option( s_date
"!       )->checkbox( val = p_test text = `Test run`
"!       )->block_end( ).
"! render( ) appends the screen to a node of an existing view, stringify( )
"! returns it as a complete view of its own.
"! Two controls raise events the app answers: a select-option opens its
"! value help with cs_event-select_option, a parameter with value_help
"! with cs_event-value_request - both carry the attribute name as first
"! event argument. z2ui5_cl_cgui_report handles both for you.
CLASS z2ui5_cl_cgui_selscreen DEFINITION PUBLIC FINAL CREATE PRIVATE.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF cs_event,
        select_option TYPE string VALUE `CGUI_SELECT_OPTION`,
        value_request TYPE string VALUE `CGUI_VALUE_REQUEST`,
      END OF cs_event.

    TYPES:
      BEGIN OF ty_s_field,
        name       TYPE string,
        text       TYPE string,
        obligatory TYPE abap_bool,
      END OF ty_s_field.
    TYPES ty_t_field TYPE STANDARD TABLE OF ty_s_field WITH EMPTY KEY.

    CLASS-METHODS factory
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_selscreen.

    "! SELECTION-SCREEN BEGIN OF BLOCK ... WITH FRAME TITLE
    METHODS block_begin
      IMPORTING
        title         TYPE clike OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_selscreen.

    METHODS block_end
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_selscreen.

    "! SELECTION-SCREEN BEGIN OF LINE - the following fields share one row
    METHODS line_begin
      IMPORTING
        text          TYPE clike OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_selscreen.

    METHODS line_end
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_selscreen.

    "! PARAMETERS - the control follows the type: DatePicker for a date,
    "! TimePicker for a time, CheckBox for an abap_bool, Input otherwise
    METHODS parameter
      IMPORTING
        val           TYPE any
        text          TYPE clike     OPTIONAL
        obligatory    TYPE abap_bool DEFAULT abap_false
        value_help    TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_selscreen.

    "! PARAMETERS ... AS CHECKBOX
    METHODS checkbox
      IMPORTING
        val           TYPE abap_bool
        text          TYPE clike OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_selscreen.

    "! PARAMETERS ... RADIOBUTTON GROUP
    METHODS radiobutton
      IMPORTING
        val           TYPE abap_bool
        text          TYPE clike OPTIONAL
        group         TYPE clike DEFAULT `RB1`
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_selscreen.

    "! SELECT-OPTIONS - val is a range table (TYPE RANGE OF ...)
    METHODS select_option
      IMPORTING
        val           TYPE STANDARD TABLE
        text          TYPE clike     OPTIONAL
        obligatory    TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_selscreen.

    "! SELECTION-SCREEN COMMENT
    METHODS comment
      IMPORTING
        text          TYPE clike
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_selscreen.

    "! SELECTION-SCREEN PUSHBUTTON ... USER-COMMAND
    METHODS button
      IMPORTING
        text          TYPE clike
        event         TYPE clike
        icon          TYPE clike OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_selscreen.

    "! the input fields with their name and label - what a caller needs to
    "! check OBLIGATORY fields before it runs the report
    METHODS get_fields
      RETURNING
        VALUE(result) TYPE ty_t_field.

    "! append the selection screen to node, a container of an existing view
    "! whose default namespace is sap.m
    METHODS render
      IMPORTING
        node TYPE REF TO z2ui5_cl_ui5_view_builder.

    "! the selection screen as a complete view
    METHODS stringify
      IMPORTING
        title         TYPE clike DEFAULT `Selection Screen`
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF cs_kind,
        block_begin TYPE string VALUE `BLOCK_BEGIN`,
        block_end   TYPE string VALUE `BLOCK_END`,
        line_begin  TYPE string VALUE `LINE_BEGIN`,
        line_end    TYPE string VALUE `LINE_END`,
        parameter   TYPE string VALUE `PARAMETER`,
        radiobutton TYPE string VALUE `RADIOBUTTON`,
        select      TYPE string VALUE `SELECT_OPTION`,
        comment     TYPE string VALUE `COMMENT`,
        button      TYPE string VALUE `BUTTON`,
      END OF cs_kind.

    CONSTANTS:
      BEGIN OF cs_control,
        input    TYPE string VALUE `INPUT`,
        number   TYPE string VALUE `NUMBER`,
        date     TYPE string VALUE `DATE`,
        time     TYPE string VALUE `TIME`,
        checkbox TYPE string VALUE `CHECKBOX`,
      END OF cs_control.

    TYPES:
      BEGIN OF ty_s_item,
        kind       TYPE string,
        control    TYPE string,
        name       TYPE string,
        text       TYPE string,
        bind       TYPE string,
        value      TYPE string,
        group      TYPE string,
        event      TYPE string,
        icon       TYPE string,
        obligatory TYPE abap_bool,
        value_help TYPE abap_bool,
        max_length TYPE i,
      END OF ty_s_item.
    TYPES ty_t_item TYPE STANDARD TABLE OF ty_s_item WITH EMPTY KEY.

    DATA client  TYPE REF TO z2ui5_if_client.
    DATA mt_item TYPE ty_t_item.

    METHODS item_create
      IMPORTING
        val           TYPE any
        kind          TYPE string
        text          TYPE clike
      RETURNING
        VALUE(result) TYPE ty_s_item.

    METHODS name_get
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    METHODS control_by_type
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    METHODS form_open
      IMPORTING
        node          TYPE REF TO z2ui5_cl_ui5_view_builder
        title         TYPE string OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_ui5_view_builder.

    METHODS render_label
      IMPORTING
        node TYPE REF TO z2ui5_cl_ui5_view_builder
        item TYPE ty_s_item.

    METHODS render_control
      IMPORTING
        node   TYPE REF TO z2ui5_cl_ui5_view_builder
        item   TYPE ty_s_item
        inline TYPE abap_bool DEFAULT abap_false.

    METHODS render_parameter
      IMPORTING
        node TYPE REF TO z2ui5_cl_ui5_view_builder
        item TYPE ty_s_item.

    METHODS render_select_option
      IMPORTING
        node TYPE REF TO z2ui5_cl_ui5_view_builder
        item TYPE ty_s_item.

ENDCLASS.


CLASS z2ui5_cl_cgui_selscreen IMPLEMENTATION.

  METHOD factory.

    result = NEW #( ).
    result->client = client.

  ENDMETHOD.

  METHOD block_begin.

    INSERT VALUE #( kind = cs_kind-block_begin
                    text = title ) INTO TABLE mt_item.
    result = me.

  ENDMETHOD.

  METHOD block_end.

    INSERT VALUE #( kind = cs_kind-block_end ) INTO TABLE mt_item.
    result = me.

  ENDMETHOD.

  METHOD line_begin.

    INSERT VALUE #( kind = cs_kind-line_begin
                    text = text ) INTO TABLE mt_item.
    result = me.

  ENDMETHOD.

  METHOD line_end.

    INSERT VALUE #( kind = cs_kind-line_end ) INTO TABLE mt_item.
    result = me.

  ENDMETHOD.

  METHOD parameter.

    DATA(ls_item) = item_create( val  = val
                                 kind = cs_kind-parameter
                                 text = text ).
    ls_item-control    = control_by_type( val ).
    ls_item-obligatory = obligatory.
    ls_item-value_help = value_help.

    DATA(lo_descr) = cl_abap_typedescr=>describe_by_data( val ).
    IF lo_descr->type_kind = cl_abap_typedescr=>typekind_char
        OR lo_descr->type_kind = cl_abap_typedescr=>typekind_num.
      ls_item-max_length = CAST cl_abap_elemdescr( lo_descr )->output_length.
    ENDIF.

    INSERT ls_item INTO TABLE mt_item.
    result = me.

  ENDMETHOD.

  METHOD checkbox.

    DATA(ls_item) = item_create( val  = val
                                 kind = cs_kind-parameter
                                 text = text ).
    ls_item-control = cs_control-checkbox.

    INSERT ls_item INTO TABLE mt_item.
    result = me.

  ENDMETHOD.

  METHOD radiobutton.

    DATA(ls_item) = item_create( val  = val
                                 kind = cs_kind-radiobutton
                                 text = text ).
    ls_item-group = group.

    INSERT ls_item INTO TABLE mt_item.
    result = me.

  ENDMETHOD.

  METHOD select_option.

    DATA ls_item TYPE ty_s_item.

    ls_item-kind       = cs_kind-select.
    ls_item-name       = name_get( val ).
    ls_item-obligatory = obligatory.
    ls_item-value      = z2ui5_cl_cgui_context=>range_to_text( val ).

    IF ls_item-name IS INITIAL.
      RAISE EXCEPTION TYPE z2ui5_cx_cgui_error
        EXPORTING
          val = `SELECT_OPTION_NOT_AN_ATTRIBUTE - pass a PUBLIC attribute of the app`.
    ENDIF.

    ls_item-text = text.
    IF ls_item-text IS INITIAL.
      TRY.
          DATA(lo_table) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( val ) ).
          DATA(lo_line) = CAST cl_abap_structdescr( lo_table->get_table_line_type( ) ).
          ls_item-text = z2ui5_cl_cgui_context=>rtti_get_label_by_descr( lo_line->get_component_type( `LOW` ) ).
        CATCH cx_root ##NO_HANDLER.
      ENDTRY.
    ENDIF.
    IF ls_item-text IS INITIAL.
      ls_item-text = ls_item-name.
    ENDIF.

    INSERT ls_item INTO TABLE mt_item.
    result = me.

  ENDMETHOD.

  METHOD comment.

    INSERT VALUE #( kind = cs_kind-comment
                    text = text ) INTO TABLE mt_item.
    result = me.

  ENDMETHOD.

  METHOD button.

    INSERT VALUE #( kind  = cs_kind-button
                    text  = text
                    event = event
                    icon  = icon ) INTO TABLE mt_item.
    result = me.

  ENDMETHOD.

  METHOD get_fields.

    LOOP AT mt_item REFERENCE INTO DATA(lr_item) WHERE name IS NOT INITIAL.
      INSERT VALUE #( name       = lr_item->name
                      text       = lr_item->text
                      obligatory = lr_item->obligatory ) INTO TABLE result.
    ENDLOOP.

  ENDMETHOD.

  METHOD item_create.

    result-kind = kind.
    result-name = name_get( val ).
    result-bind = client->_bind( val ).

    result-text = text.
    IF result-text IS INITIAL.
      result-text = z2ui5_cl_cgui_context=>rtti_get_label( val ).
    ENDIF.
    IF result-text IS INITIAL.
      result-text = result-name.
    ENDIF.

  ENDMETHOD.

  METHOD name_get.

    result = z2ui5_cl_cgui_context=>attri_name_by_ref( app = client->get_app( )
                                                       val = val ).

  ENDMETHOD.

  METHOD control_by_type.

    IF z2ui5_cl_cgui_context=>rtti_check_boolean( val ) = abap_true.
      result = cs_control-checkbox.
      RETURN.
    ENDIF.

    CASE z2ui5_cl_cgui_context=>rtti_get_type_kind( val ).
      WHEN cl_abap_typedescr=>typekind_date.
        result = cs_control-date.
      WHEN cl_abap_typedescr=>typekind_time.
        result = cs_control-time.
      WHEN cl_abap_typedescr=>typekind_int
          OR cl_abap_typedescr=>typekind_int1
          OR cl_abap_typedescr=>typekind_int2
          OR cl_abap_typedescr=>typekind_packed
          OR cl_abap_typedescr=>typekind_float.
        result = cs_control-number.
      WHEN OTHERS.
        result = cs_control-input.
    ENDCASE.

  ENDMETHOD.

  METHOD render.

    DATA lo_form TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA lo_line TYPE REF TO z2ui5_cl_ui5_view_builder.

    LOOP AT mt_item REFERENCE INTO DATA(lr_item).
      CASE lr_item->kind.

        WHEN cs_kind-block_begin.
          lo_form = form_open( node  = node
                               title = lr_item->text ).

        WHEN cs_kind-block_end.
          CLEAR lo_form.

        WHEN cs_kind-line_begin.
          IF lo_form IS NOT BOUND.
            lo_form = form_open( node ).
          ENDIF.
          lo_form->tag( `Label`
              )->a( n = `text` t = lr_item->text ).
          lo_line = lo_form->ele( `HBox`
              )->a( n = `alignItems` v = `Center` ).

        WHEN cs_kind-line_end.
          CLEAR lo_line.

        WHEN OTHERS.
          IF lo_form IS NOT BOUND.
            lo_form = form_open( node ).
          ENDIF.
          IF lo_line IS BOUND.
            render_control( node   = lo_line
                            item   = lr_item->*
                            inline = abap_true ).
          ELSE.
            render_label( node = lo_form
                          item = lr_item->* ).
            render_control( node = lo_form
                            item = lr_item->* ).
          ENDIF.

      ENDCASE.
    ENDLOOP.

  ENDMETHOD.

  METHOD form_open.

    result = node->ele( n = `SimpleForm` ns = `form`
        )->a( n = `xmlns:form`   v = `sap.ui.layout.form`
        )->a( n = `editable`     v = `true`
        )->a( n = `layout`       v = `ResponsiveGridLayout`
        )->a( n = `labelSpanXL`  v = `3`
        )->a( n = `labelSpanL`   v = `3`
        )->a( n = `labelSpanM`   v = `3`
        )->a( n = `emptySpanXL`  v = `4`
        )->a( n = `emptySpanL`   v = `4`
        )->a( n = `emptySpanM`   v = `2`
        )->a( n = `columnsXL`    v = `1`
        )->a( n = `columnsL`     v = `1`
        )->a( n = `columnsM`     v = `1` ).

    IF title IS NOT INITIAL.
      result->a( n = `title` t = title ).
    ENDIF.

  ENDMETHOD.

  METHOD render_label.

    DATA lv_text TYPE string.

    CASE item-kind.
      WHEN cs_kind-parameter.
        IF item-control <> cs_control-checkbox.
          lv_text = item-text.
        ENDIF.
      WHEN cs_kind-select.
        lv_text = item-text.
    ENDCASE.

    node->tag( `Label`
        )->a( n = `text`     t = lv_text
        )->a( n = `required` b = item-obligatory ).

  ENDMETHOD.

  METHOD render_control.

    IF inline = abap_true AND ( item-kind = cs_kind-select
        OR ( item-kind = cs_kind-parameter AND item-control <> cs_control-checkbox ) ).
      node->tag( `Label`
          )->a( n = `text`     t = item-text
          )->a( n = `required` b = item-obligatory
          )->a( n = `class`    v = `sapUiSmallMarginBegin sapUiTinyMarginEnd` ).
    ENDIF.

    CASE item-kind.

      WHEN cs_kind-parameter.
        render_parameter( node = node
                          item = item ).

      WHEN cs_kind-select.
        render_select_option( node = node
                              item = item ).

      WHEN cs_kind-radiobutton.
        node->tag( `RadioButton`
            )->a( n = `text`      t = item-text
            )->a( n = `groupName` t = item-group
            )->a( n = `selected`  v = item-bind ).

      WHEN cs_kind-comment.
        node->tag( `Text`
            )->a( n = `text` t = item-text ).

      WHEN cs_kind-button.
        node->tag( `Button`
            )->a( n = `text`  t = item-text
            )->a( n = `icon`  v = item-icon
            )->a( n = `press` v = client->_event( item-event ) ).

    ENDCASE.

  ENDMETHOD.

  METHOD render_parameter.

    CASE item-control.

      WHEN cs_control-checkbox.
        node->tag( `CheckBox`
            )->a( n = `text`     t = item-text
            )->a( n = `selected` v = item-bind ).

      WHEN cs_control-date.
        node->tag( `DatePicker`
            " abap2ui5lint-disable-next-line unescaped-text-in-attribute -- item-bind is the binding client->_bind( ) returned when the field was declared
            )->a( n = `value`         v = item-bind
            )->a( n = `valueFormat`   v = `yyyy-MM-dd`
            )->a( n = `displayFormat` v = `medium`
            )->a( n = `required`      b = item-obligatory ).

      WHEN cs_control-time.
        node->tag( `TimePicker`
            )->a( n = `value`         v = item-bind
            )->a( n = `valueFormat`   v = `HH:mm:ss`
            )->a( n = `displayFormat` v = `HH:mm:ss`
            )->a( n = `required`      b = item-obligatory ).

      WHEN OTHERS.
        node->tag( `Input`
            )->a( n = `value`    v = item-bind
            )->a( n = `required` b = item-obligatory ).
        IF item-control = cs_control-number.
          node->a( n = `type` v = `Number` ).
        ENDIF.
        IF item-max_length > 0.
          node->a( n = `maxLength` v = |{ item-max_length }| ).
        ENDIF.
        IF item-value_help = abap_true.
          node->a( n = `showValueHelp`    b = abap_true
              )->a( n = `valueHelpRequest` v = client->_event( val = cs_event-value_request
                                                               arg = item-name ) ).
        ENDIF.

    ENDCASE.

  ENDMETHOD.

  METHOD render_select_option.

    node->tag( `Input`
        )->a( n = `value`            t = item-value
        )->a( n = `required`         b = item-obligatory
        )->a( n = `showValueHelp`    b = abap_true
        )->a( n = `valueHelpOnly`    b = abap_true
        )->a( n = `valueHelpRequest` v = client->_event( val = cs_event-select_option
                                                         arg = item-name ) ).

  ENDMETHOD.

  METHOD stringify.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%` ).

    DATA(page) = view->ele( `Page`
        )->a( n = `title` t = title ).

    render( page ).

    result = view->stringify( ).

  ENDMETHOD.

ENDCLASS.
