"! Selection screen painter - build the selection screen of a report by
"! filling in its elements, look at it in the preview and take the
"! generated report class with you: the fields as PUBLIC attributes,
"! selection_screen( ) and the event blocks the elements call for.
"! Start it like any abap2UI5 app: ?app_start=z2ui5_cl_cgui_painter
CLASS z2ui5_cl_cgui_painter DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    CONSTANTS:
      BEGIN OF cs_event,
        add    TYPE string VALUE `CGUI_P_ADD`,
        sample TYPE string VALUE `CGUI_P_SAMPLE`,
        clear  TYPE string VALUE `CGUI_P_CLEAR`,
        up     TYPE string VALUE `CGUI_P_UP`,
        down   TYPE string VALUE `CGUI_P_DOWN`,
        delete TYPE string VALUE `CGUI_P_DELETE`,
        tab    TYPE string VALUE `CGUI_P_TAB`,
      END OF cs_event.

    CONSTANTS:
      BEGIN OF cs_tab,
        elements TYPE string VALUE `ELEMENTS`,
        preview  TYPE string VALUE `PREVIEW`,
        code     TYPE string VALUE `CODE`,
      END OF cs_tab.

    DATA mt_element TYPE z2ui5_cl_cgui_painter_code=>ty_t_element.
    DATA mv_class   TYPE string.
    DATA mv_tab     TYPE string.
    DATA mv_code    TYPE string.

  PROTECTED SECTION.
    DATA client     TYPE REF TO z2ui5_if_client.
    DATA mv_next_id TYPE i.
    DATA mt_message TYPE string_table.

    METHODS on_event.

    METHODS element_add
      IMPORTING
        kind         TYPE clike
        name         TYPE clike     OPTIONAL
        type         TYPE clike     OPTIONAL
        text         TYPE clike     OPTIONAL
        obligatory   TYPE abap_bool DEFAULT abap_false
        value_help   TYPE abap_bool DEFAULT abap_false
        group        TYPE clike     OPTIONAL
        modif_id     TYPE clike     OPTIONAL
        user_command TYPE clike     OPTIONAL.

    METHODS element_move
      IMPORTING
        id    TYPE i
        delta TYPE i.

    METHODS sample_load.

    METHODS refresh.

    METHODS view_display.

    METHODS render_elements
      IMPORTING
        node TYPE REF TO z2ui5_cl_ui5_view_builder.

    METHODS render_preview
      IMPORTING
        node TYPE REF TO z2ui5_cl_ui5_view_builder.

    METHODS render_code
      IMPORTING
        node TYPE REF TO z2ui5_cl_ui5_view_builder.

    METHODS render_messages
      IMPORTING
        node TYPE REF TO z2ui5_cl_ui5_view_builder.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_cgui_painter IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.

    IF client->check_on_init( ).
      mv_class = `zcl_my_report`.
      mv_tab = cs_tab-elements.
      sample_load( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

    refresh( ).
    view_display( ).

  ENDMETHOD.

  METHOD on_event.

    CASE client->get_event( ).

      WHEN cs_event-add.
        element_add( z2ui5_cl_cgui_painter_code=>cs_kind-parameter ).

      WHEN cs_event-sample.
        sample_load( ).

      WHEN cs_event-clear.
        CLEAR mt_element.

      WHEN cs_event-up.
        element_move( id    = CONV i( client->get_event_arg( ) )
                      delta = -1 ).

      WHEN cs_event-down.
        element_move( id    = CONV i( client->get_event_arg( ) )
                      delta = 1 ).

      WHEN cs_event-delete.
        DELETE mt_element WHERE id = CONV i( client->get_event_arg( ) ).

      WHEN OTHERS.
        " a tab, or a button or user command of the preview - the screen is
        " shown anew with the elements as they are now

    ENDCASE.

  ENDMETHOD.

  METHOD element_add.

    mv_next_id = mv_next_id + 1.
    INSERT VALUE #( id           = mv_next_id
                    kind         = kind
                    name         = name
                    type         = type
                    text         = text
                    obligatory   = obligatory
                    value_help   = value_help
                    group        = group
                    modif_id     = modif_id
                    user_command = user_command ) INTO TABLE mt_element.

  ENDMETHOD.

  METHOD element_move.

    READ TABLE mt_element INTO DATA(ls_element) WITH KEY id = id.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    DATA(lv_index) = sy-tabix.
    DATA(lv_target) = lv_index + delta.
    IF lv_target < 1 OR lv_target > lines( mt_element ).
      RETURN.
    ENDIF.

    DELETE mt_element INDEX lv_index.
    INSERT ls_element INTO mt_element INDEX lv_target.

  ENDMETHOD.

  METHOD sample_load.

    CLEAR mt_element.
    element_add( kind = z2ui5_cl_cgui_painter_code=>cs_kind-block_begin
                 text = `Flights` ).
    element_add( kind       = z2ui5_cl_cgui_painter_code=>cs_kind-parameter
                 name       = `p_carrid`
                 type       = `c LENGTH 3`
                 text       = `Airline`
                 value_help = abap_true ).
    element_add( kind = z2ui5_cl_cgui_painter_code=>cs_kind-select_option
                 name = `s_fldate`
                 type = `d`
                 text = `Flight date` ).
    element_add( kind       = z2ui5_cl_cgui_painter_code=>cs_kind-parameter
                 name       = `p_max`
                 type       = `i`
                 text       = `Maximum rows`
                 obligatory = abap_true ).
    element_add( z2ui5_cl_cgui_painter_code=>cs_kind-block_end ).
    element_add( kind = z2ui5_cl_cgui_painter_code=>cs_kind-block_begin
                 text = `Output` ).
    element_add( kind         = z2ui5_cl_cgui_painter_code=>cs_kind-radiobutton
                 name         = `p_alv`
                 text         = `ALV grid`
                 group        = `OUT`
                 user_command = `OUT` ).
    element_add( kind  = z2ui5_cl_cgui_painter_code=>cs_kind-radiobutton
                 name  = `p_list`
                 text  = `Classic list`
                 group = `OUT` ).
    element_add( kind     = z2ui5_cl_cgui_painter_code=>cs_kind-checkbox
                 name     = `p_zebra`
                 text     = `Zebra stripes`
                 modif_id = `LST` ).
    element_add( z2ui5_cl_cgui_painter_code=>cs_kind-block_end ).
    element_add( kind  = z2ui5_cl_cgui_painter_code=>cs_kind-button
                 text  = `Reset`
                 group = `RESET`
                 type  = `sap-icon://reset` ).

  ENDMETHOD.

  METHOD refresh.

    mt_message = z2ui5_cl_cgui_painter_code=>check( mt_element ).
    mv_code = z2ui5_cl_cgui_painter_code=>generate( class    = mv_class
                                                   elements = mt_element ).

  ENDMETHOD.

  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:core`   v = `sap.ui.core`
            )->a( n = `xmlns:ce`     v = `sap.ui.codeeditor`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%` ).

    DATA(page) = view->ele( `Page`
        )->a( n = `title`          v = `abap-cloud-gui - Selection Screen Painter`
        )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
        )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    DATA(tabs) = page->ele( `IconTabBar`
        )->a( n = `selectedKey` v = client->_bind( mv_tab )
        )->a( n = `select`      v = client->_event( cs_event-tab )
        )->a( n = `expandable`  b = abap_false
        )->ele( `items` ).

    render_elements( tabs->ele( `IconTabFilter`
        )->a( n = `key`  v = cs_tab-elements
        )->a( n = `text` v = `Elements`
        )->a( n = `icon` v = `sap-icon://list` ) ).

    render_preview( tabs->ele( `IconTabFilter`
        )->a( n = `key`  v = cs_tab-preview
        )->a( n = `text` v = `Preview`
        )->a( n = `icon` v = `sap-icon://display` ) ).

    render_code( tabs->ele( `IconTabFilter`
        )->a( n = `key`  v = cs_tab-code
        )->a( n = `text` v = `Code`
        )->a( n = `icon` v = `sap-icon://source-code` ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

  METHOD render_elements.

    DATA(table) = node->ele( `Table`
        )->a( n = `items`       v = client->_bind( mt_element )
        )->a( n = `fixedLayout` b = abap_false
        )->a( n = `noDataText`  v = `No elements yet - add one`
        )->ele( `headerToolbar`
            )->ele( `OverflowToolbar`
                )->tag( `Title`
                    )->a( n = `text` v = `Elements of the selection screen`
                )->tag( `ToolbarSpacer`
                )->tag( `Label`
                    )->a( n = `text` v = `Report class`
                )->tag( `Input`
                    )->a( n = `value` v = client->_bind( mv_class )
                    )->a( n = `width` v = `14rem`
                )->tag( `Button`
                    )->a( n = `text`  v = `Add`
                    )->a( n = `icon`  v = `sap-icon://add`
                    )->a( n = `press` v = client->_event( cs_event-add )
                )->tag( `Button`
                    )->a( n = `text`  v = `Sample`
                    )->a( n = `icon`  v = `sap-icon://example`
                    )->a( n = `press` v = client->_event( cs_event-sample )
                )->tag( `Button`
                    )->a( n = `text`  v = `Clear`
                    )->a( n = `icon`  v = `sap-icon://eraser`
                    )->a( n = `press` v = client->_event( cs_event-clear )
                )->end(
            )->end( ).

    DATA(columns) = table->ele( `columns` ).
    LOOP AT VALUE string_table( ( `Kind` ) ( `Name` ) ( `Type / Icon` ) ( `Text` ) ( `Required` ) ( `F4` )
                                ( `Group / Event` ) ( `Modif ID` ) ( `User command` ) ( `No display` ) ( `` ) ) INTO DATA(lv_header).
      columns->ele( `Column`
          )->tag( `Text`
              )->a( n = `text` t = lv_header ).
    ENDLOOP.

    DATA(cells) = table->ele( `items`
        )->ele( `ColumnListItem`
        )->ele( `cells` ).

    DATA(select) = cells->ele( `Select`
        )->a( n = `selectedKey` v = `{KIND}`
        )->a( n = `change`      v = client->_event( cs_event-tab ) ).
    LOOP AT VALUE z2ui5_cl_cgui_context=>ty_t_comp(
        ( name = z2ui5_cl_cgui_painter_code=>cs_kind-block_begin   label = `Block begin` )
        ( name = z2ui5_cl_cgui_painter_code=>cs_kind-block_end     label = `Block end` )
        ( name = z2ui5_cl_cgui_painter_code=>cs_kind-line_begin    label = `Line begin` )
        ( name = z2ui5_cl_cgui_painter_code=>cs_kind-line_end      label = `Line end` )
        ( name = z2ui5_cl_cgui_painter_code=>cs_kind-parameter     label = `Parameter` )
        ( name = z2ui5_cl_cgui_painter_code=>cs_kind-select_option label = `Select-option` )
        ( name = z2ui5_cl_cgui_painter_code=>cs_kind-checkbox      label = `Checkbox` )
        ( name = z2ui5_cl_cgui_painter_code=>cs_kind-radiobutton   label = `Radio button` )
        ( name = z2ui5_cl_cgui_painter_code=>cs_kind-comment       label = `Comment` )
        ( name = z2ui5_cl_cgui_painter_code=>cs_kind-button        label = `Push button` ) ) INTO DATA(ls_kind).
      select->tag( n = `Item` ns = `core`
          )->a( n = `key`  t = ls_kind-name
          )->a( n = `text` t = ls_kind-label ).
    ENDLOOP.

    cells->tag( `Input`
        )->a( n = `value`       v = `{NAME}`
        )->a( n = `placeholder` v = `p_name`
        )->tag( `Input`
        )->a( n = `value`       v = `{TYPE}`
        )->a( n = `placeholder` v = `c LENGTH 10`
        )->tag( `Input`
        )->a( n = `value`       v = `{TEXT}`
        )->tag( `CheckBox`
        )->a( n = `selected`    v = `{OBLIGATORY}`
        )->tag( `CheckBox`
        )->a( n = `selected`    v = `{VALUE_HELP}`
        )->tag( `Input`
        )->a( n = `value`       v = `{GROUP}`
        )->tag( `Input`
        )->a( n = `value`       v = `{MODIF_ID}`
        )->a( n = `width`       v = `5rem`
        )->tag( `Input`
        )->a( n = `value`       v = `{USER_COMMAND}`
        )->tag( `CheckBox`
        )->a( n = `selected`    v = `{NO_DISPLAY}` ).

    cells->ele( `HBox`
        )->tag( `Button`
            )->a( n = `icon`    v = `sap-icon://navigation-up-arrow`
            )->a( n = `type`    v = `Transparent`
            )->a( n = `tooltip` v = `Up`
            )->a( n = `press`   v = client->_event( val = cs_event-up
                                                    arg = `${ID}` )
        )->tag( `Button`
            )->a( n = `icon`    v = `sap-icon://navigation-down-arrow`
            )->a( n = `type`    v = `Transparent`
            )->a( n = `tooltip` v = `Down`
            )->a( n = `press`   v = client->_event( val = cs_event-down
                                                    arg = `${ID}` )
        )->tag( `Button`
            )->a( n = `icon`    v = `sap-icon://delete`
            )->a( n = `type`    v = `Transparent`
            )->a( n = `tooltip` v = `Delete`
            )->a( n = `press`   v = client->_event( val = cs_event-delete
                                                    arg = `${ID}` ) ).

  ENDMETHOD.

  METHOD render_preview.

    " the screen as the report will show it - the fields are data objects
    " of their types, not yet attributes of a report, so nothing is bound
    DATA lr_data   TYPE REF TO data.
    DATA lt_group  TYPE string_table.
    FIELD-SYMBOLS <val>   TYPE any.
    FIELD-SYMBOLS <range> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <flag>  TYPE abap_bool.

    render_messages( node ).

    DATA(screen) = z2ui5_cl_cgui_selscreen=>factory( client          = client
                                                     value_help_auto = abap_true
                                                     preview         = abap_true ).

    LOOP AT mt_element REFERENCE INTO DATA(lr_element).
      DATA(lv_text) = COND string( WHEN lr_element->text IS NOT INITIAL THEN lr_element->text
                                   ELSE lr_element->name ).

      CASE lr_element->kind.

        WHEN z2ui5_cl_cgui_painter_code=>cs_kind-block_begin.
          screen->block_begin( lr_element->text ).
        WHEN z2ui5_cl_cgui_painter_code=>cs_kind-block_end.
          screen->block_end( ).
        WHEN z2ui5_cl_cgui_painter_code=>cs_kind-line_begin.
          screen->line_begin( lr_element->text ).
        WHEN z2ui5_cl_cgui_painter_code=>cs_kind-line_end.
          screen->line_end( ).

        WHEN z2ui5_cl_cgui_painter_code=>cs_kind-parameter.
          lr_data = z2ui5_cl_cgui_painter_code=>type_create( lr_element->type ).
          IF lr_data IS NOT BOUND.
            CONTINUE.
          ENDIF.
          ASSIGN lr_data->* TO <val>.
          screen->parameter( val        = <val>
                             text       = lv_text
                             obligatory = lr_element->obligatory
                             value_help = lr_element->value_help
                             modif_id   = lr_element->modif_id
                             no_display = lr_element->no_display ).

        WHEN z2ui5_cl_cgui_painter_code=>cs_kind-select_option.
          lr_data = z2ui5_cl_cgui_painter_code=>range_create( lr_element->type ).
          IF lr_data IS NOT BOUND.
            CONTINUE.
          ENDIF.
          ASSIGN lr_data->* TO <range>.
          screen->select_option( val        = <range>
                                 text       = lv_text
                                 obligatory = lr_element->obligatory
                                 value_help = lr_element->value_help
                                 modif_id   = lr_element->modif_id
                                 no_display = lr_element->no_display ).

        WHEN z2ui5_cl_cgui_painter_code=>cs_kind-checkbox.
          CREATE DATA lr_data TYPE abap_bool.
          ASSIGN lr_data->* TO <flag>.
          screen->checkbox( val          = <flag>
                            text         = lv_text
                            modif_id     = lr_element->modif_id
                            user_command = lr_element->user_command ).

        WHEN z2ui5_cl_cgui_painter_code=>cs_kind-radiobutton.
          " the first button of a group is the selected one
          CREATE DATA lr_data TYPE abap_bool.
          ASSIGN lr_data->* TO <flag>.
          DATA(lv_group) = to_upper( lr_element->group ).
          IF lv_group IS INITIAL.
            lv_group = `RB1`.
          ENDIF.
          READ TABLE lt_group WITH KEY table_line = lv_group TRANSPORTING NO FIELDS.
          IF sy-subrc <> 0.
            <flag> = abap_true.
            INSERT lv_group INTO TABLE lt_group.
          ENDIF.
          screen->radiobutton( val          = <flag>
                               text         = lv_text
                               group        = lv_group
                               modif_id     = lr_element->modif_id
                               user_command = lr_element->user_command ).

        WHEN z2ui5_cl_cgui_painter_code=>cs_kind-comment.
          screen->comment( text     = lr_element->text
                           modif_id = lr_element->modif_id ).

        WHEN z2ui5_cl_cgui_painter_code=>cs_kind-button.
          screen->button( text     = lr_element->text
                          event    = to_upper( lr_element->group )
                          icon     = lr_element->type
                          modif_id = lr_element->modif_id ).

      ENDCASE.
    ENDLOOP.

    screen->render( node ).

  ENDMETHOD.

  METHOD render_code.

    render_messages( node ).

    node->tag( n = `CodeEditor` ns = `ce`
        )->a( n = `value`    v = client->_bind( mv_code )
        )->a( n = `type`     v = `abap`
        )->a( n = `height`   v = `600px`
        )->a( n = `editable` b = abap_false ).

  ENDMETHOD.

  METHOD render_messages.

    IF mt_message IS INITIAL.
      node->tag( `MessageStrip`
          )->a( n = `text`  v = `The selection screen is complete - copy the class into your system.`
          )->a( n = `type`  v = `Success`
          )->a( n = `class` v = `sapUiSmallMarginBottom` ).
      RETURN.
    ENDIF.

    LOOP AT mt_message INTO DATA(lv_message).
      node->tag( `MessageStrip`
          )->a( n = `text`  t = lv_message
          )->a( n = `type`  v = `Error`
          )->a( n = `class` v = `sapUiTinyMarginBottom` ).
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
