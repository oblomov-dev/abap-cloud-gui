"! Classic list output - WRITE, NEW-LINE, SKIP, ULINE, NEW-PAGE - rendered
"! with z2ui5_cl_ui5_view_builder. The list only collects what was written;
"! it binds nothing, so it can be kept as an attribute of the app between
"! roundtrips (it is serializable) and rendered again at any time:
"!   DATA(list) = z2ui5_cl_cgui_list=>factory( ).
"!   list->write( `Flights` )->new_line( )->uline( ).
"!   LOOP AT mt_flight INTO DATA(ls_flight).
"!     list->write( val = ls_flight-carrid hotspot = abap_true hide = ls_flight-connid
"!         )->write( ls_flight-fldate
"!         )->new_line( ).
"!   ENDLOOP.
"! A hotspot raises cs_event-line_selection with the line number as first
"! and the HIDE value as second event argument - AT LINE-SELECTION.
CLASS z2ui5_cl_cgui_list DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_serializable_object.

    CONSTANTS:
      BEGIN OF cs_event,
        line_selection TYPE string VALUE `CGUI_LINE_SELECTION`,
      END OF cs_event.

    "! the colors of FORMAT COLOR, as UI5 value states
    CONSTANTS:
      BEGIN OF cs_color,
        none     TYPE string VALUE ``,
        positive TYPE string VALUE `Success`,
        negative TYPE string VALUE `Error`,
        total    TYPE string VALUE `Warning`,
        key      TYPE string VALUE `Information`,
      END OF cs_color.

    TYPES:
      BEGIN OF ty_s_item,
        line    TYPE i,
        kind    TYPE string,
        text    TYPE string,
        flag    TYPE abap_bool,
        color   TYPE string,
        hotspot TYPE abap_bool,
        hide    TYPE string,
      END OF ty_s_item.
    TYPES ty_t_item TYPE STANDARD TABLE OF ty_s_item WITH EMPTY KEY.

    CLASS-METHODS factory
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_list.

    "! WRITE val - dates and times in the user's format. val and hide are
    "! passed by value: `hide = sy-tabix` must keep the row it was written
    "! in, not whatever a later LOOP left in sy-tabix
    METHODS write
      IMPORTING
        VALUE(val)    TYPE any
        color         TYPE clike     DEFAULT cs_color-none
        hotspot       TYPE abap_bool DEFAULT abap_false
        VALUE(hide)   TYPE any       OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_list.

    "! WRITE val AS CHECKBOX
    METHODS write_as_checkbox
      IMPORTING
        val           TYPE abap_bool
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_list.

    "! WRITE val AS ICON - val is a UI5 icon, e.g. `sap-icon://accept`
    METHODS write_as_icon
      IMPORTING
        val           TYPE clike
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_list.

    METHODS new_line
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_list.

    METHODS skip
      IMPORTING
        val           TYPE i DEFAULT 1
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_list.

    METHODS uline
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_list.

    METHODS new_page
      IMPORTING
        title         TYPE clike OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_cgui_list.

    "! drop everything written so far
    METHODS clear.

    METHODS get_items
      RETURNING
        VALUE(result) TYPE ty_t_item.

    "! the item behind line number val of a line selection event, the first
    "! hotspot of that line
    METHODS get_item_by_line
      IMPORTING
        val           TYPE i
      RETURNING
        VALUE(result) TYPE ty_s_item.

    "! append the list to node, a container of an existing view whose
    "! default namespace is sap.m
    METHODS render
      IMPORTING
        node   TYPE REF TO z2ui5_cl_ui5_view_builder
        client TYPE REF TO z2ui5_if_client.

    "! the list as a complete view
    METHODS stringify
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
        title         TYPE clike DEFAULT `List`
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.
    " PROTECTED, not PRIVATE: the list travels in the app's draft, and the
    " transpiled runtime reaches PROTECTED attributes but not PRIVATE ones
    DATA mt_item TYPE ty_t_item.
    DATA mv_line TYPE i VALUE 1.

  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF cs_kind,
        text     TYPE string VALUE `TEXT`,
        checkbox TYPE string VALUE `CHECKBOX`,
        icon     TYPE string VALUE `ICON`,
        skip     TYPE string VALUE `SKIP`,
        uline    TYPE string VALUE `ULINE`,
        page     TYPE string VALUE `PAGE`,
      END OF cs_kind.

    METHODS item_add
      IMPORTING
        val TYPE ty_s_item.

    METHODS render_item
      IMPORTING
        node   TYPE REF TO z2ui5_cl_ui5_view_builder
        client TYPE REF TO z2ui5_if_client
        item   TYPE ty_s_item.

ENDCLASS.


CLASS z2ui5_cl_cgui_list IMPLEMENTATION.

  METHOD factory.

    result = NEW #( ).

  ENDMETHOD.

  METHOD write.

    DATA ls_item TYPE ty_s_item.

    " hide first: `hide = sy-tabix` is read before anything else can run a
    " LOOP - the transpiled runtime passes even a VALUE( ) of type any by
    " reference, and its RTTI is ABAP code that loops
    IF hide IS SUPPLIED.
      ls_item-hide = |{ hide }|.
    ENDIF.
    ls_item-kind    = cs_kind-text.
    ls_item-text    = z2ui5_cl_cgui_context=>conv_to_text( val ).
    ls_item-color   = color.
    ls_item-hotspot = hotspot.
    item_add( ls_item ).

    result = me.

  ENDMETHOD.

  METHOD write_as_checkbox.

    item_add( VALUE #( kind = cs_kind-checkbox
                       flag = val ) ).
    result = me.

  ENDMETHOD.

  METHOD write_as_icon.

    item_add( VALUE #( kind = cs_kind-icon
                       text = val ) ).
    result = me.

  ENDMETHOD.

  METHOD new_line.

    mv_line = mv_line + 1.
    result = me.

  ENDMETHOD.

  METHOD skip.

    new_line( ).
    item_add( VALUE #( kind = cs_kind-skip
                       text = |{ val }| ) ).
    new_line( ).
    result = me.

  ENDMETHOD.

  METHOD uline.

    new_line( ).
    item_add( VALUE #( kind = cs_kind-uline ) ).
    new_line( ).
    result = me.

  ENDMETHOD.

  METHOD new_page.

    new_line( ).
    item_add( VALUE #( kind = cs_kind-page
                       text = title ) ).
    new_line( ).
    result = me.

  ENDMETHOD.

  METHOD clear.

    CLEAR mt_item.
    mv_line = 1.

  ENDMETHOD.

  METHOD get_items.

    result = mt_item.

  ENDMETHOD.

  METHOD get_item_by_line.

    LOOP AT mt_item INTO result WHERE line = val AND hotspot = abap_true.
      RETURN.
    ENDLOOP.
    CLEAR result.

  ENDMETHOD.

  METHOD item_add.

    DATA(ls_item) = val.
    ls_item-line = mv_line.
    INSERT ls_item INTO TABLE mt_item.

  ENDMETHOD.

  METHOD render.

    DATA lo_line TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA lv_line TYPE i.

    DATA(lo_list) = node->ele( `VBox`
        )->a( n = `class` v = `sapUiSmallMargin` ).

    LOOP AT mt_item REFERENCE INTO DATA(lr_item).

      IF lr_item->kind = cs_kind-skip OR lr_item->kind = cs_kind-uline OR lr_item->kind = cs_kind-page.
        render_item( node   = lo_list
                     client = client
                     item   = lr_item->* ).
        CLEAR lo_line.
        CONTINUE.
      ENDIF.

      IF lo_line IS NOT BOUND OR lv_line <> lr_item->line.
        lv_line = lr_item->line.
        lo_line = lo_list->ele( `HBox`
            )->a( n = `alignItems` v = `Center` ).
      ENDIF.

      render_item( node   = lo_line
                   client = client
                   item   = lr_item->* ).
    ENDLOOP.

  ENDMETHOD.

  METHOD render_item.

    CASE item-kind.

      WHEN cs_kind-text.
        IF item-hotspot = abap_true.
          node->tag( `Link`
              )->a( n = `text`  t = item-text
              )->a( n = `class` v = `sapUiTinyMarginEnd`
              )->a( n = `press` v = client->_event( val   = cs_event-line_selection
                                                    t_arg = VALUE #( ( |{ item-line }| )
                                                                     ( item-hide ) )
                                                    s_ctrl = VALUE #( check_arg_literal = abap_true ) ) ).
        ELSEIF item-color IS NOT INITIAL.
          node->tag( `ObjectStatus`
              )->a( n = `text`  t = item-text
              )->a( n = `state` t = item-color
              )->a( n = `class` v = `sapUiTinyMarginEnd` ).
        ELSE.
          node->tag( `Text`
              )->a( n = `text`             t = item-text
              )->a( n = `renderWhitespace` b = abap_true
              )->a( n = `wrapping`         b = abap_false
              )->a( n = `class`            v = `sapUiTinyMarginEnd` ).
        ENDIF.

      WHEN cs_kind-checkbox.
        node->tag( `CheckBox`
            )->a( n = `selected` b = item-flag
            )->a( n = `editable` b = abap_false ).

      WHEN cs_kind-icon.
        node->tag( n = `Icon` ns = `core`
            )->a( n = `xmlns:core` v = `sap.ui.core`
            )->a( n = `src`        v = item-text
            )->a( n = `class`      v = `sapUiTinyMarginEnd` ).

      WHEN cs_kind-skip.
        node->tag( `HBox`
            )->a( n = `height` v = |{ item-text }rem| ).

      WHEN cs_kind-uline.
        node->tag( `Toolbar`
            )->a( n = `height` v = `2px`
            )->a( n = `design` v = `Solid` ).

      WHEN cs_kind-page.
        node->tag( `Title`
            )->a( n = `text`  t = item-text
            )->a( n = `level` v = `H3`
            )->a( n = `class` v = `sapUiSmallMarginTop` ).

    ENDCASE.

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

    render( node   = page
            client = client ).

    result = view->stringify( ).

  ENDMETHOD.

ENDCLASS.
