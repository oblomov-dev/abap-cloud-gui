" the handler of a converted CL_GUI_ALV_GRID report
CLASS ltcl_handler DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    CLASS-DATA gv_row    TYPE i.
    CLASS-DATA gv_column TYPE string.
    CLASS-DATA gv_ucomm  TYPE string.
    CLASS-DATA gv_link   TYPE i.
    CLASS-METHODS on_double_click FOR EVENT double_click OF cl_gui_alv_grid
      IMPORTING e_row e_column.
    CLASS-METHODS on_hotspot FOR EVENT hotspot_click OF cl_gui_alv_grid
      IMPORTING es_row_no.
    CLASS-METHODS on_command FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.
    CLASS-METHODS on_toolbar FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object.
ENDCLASS.

CLASS ltcl_handler IMPLEMENTATION.
  METHOD on_double_click.
    gv_row = e_row-index.
    gv_column = e_column-fieldname.
  ENDMETHOD.
  METHOD on_hotspot.
    gv_link = es_row_no-row_id.
  ENDMETHOD.
  METHOD on_command.
    gv_ucomm = e_ucomm.
  ENDMETHOD.
  METHOD on_toolbar.
    INSERT VALUE #( butn_type = 3 ) INTO TABLE e_object->mt_toolbar.
    INSERT VALUE #( function  = 'ZBOOK'
                    icon      = '@42@'
                    text      = 'Book'
                    quickinfo = 'Book the flight' ) INTO TABLE e_object->mt_toolbar.
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_test DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_s_row,
        carrid TYPE c LENGTH 3,
        seats  TYPE i,
      END OF ty_s_row.
    TYPES ty_t_row TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.

    METHODS events_to_handlers FOR TESTING.
    METHODS icons FOR TESTING.

ENDCLASS.

CLASS ltcl_test IMPLEMENTATION.

  METHOD events_to_handlers.

    DATA lt_row  TYPE ty_t_row.
    DATA lt_fcat TYPE lvc_t_fcat.

    CLEAR: ltcl_handler=>gv_row, ltcl_handler=>gv_column, ltcl_handler=>gv_ucomm, ltcl_handler=>gv_link.
    lt_row = VALUE #( ( carrid = `LH` seats = 1 ) ( carrid = `AA` seats = 2 ) ).
    lt_fcat = VALUE #( ( fieldname = `CARRID` coltext = `Airline` hotspot = abap_true ) ).

    DATA(lo_grid) = z2ui5_cl_cgui_grid=>factory( alv = z2ui5_cl_cgui_alv=>factory( ) ).
    " as the converter writes SET HANDLER ... FOR gr_grid
    lo_grid->set_handler( class = `LTCL_HANDLER` ).
    cl_abap_unit_assert=>assert_equals( act = lines( lo_grid->get_handlers( ) )
                                        exp = 4 ).
    lo_grid->set_table_for_first_display( CHANGING  it_outtab       = lt_row
                                                    it_fieldcatalog = lt_fcat
                                          EXCEPTIONS OTHERS         = 1 ).
    cl_abap_unit_assert=>assert_subrc( exp = 0 ).

    " TOOLBAR: the button of the handler is a function of the ALV, the
    " separator is not - added once, also when the toolbar comes again
    lo_grid->set_toolbar_interactive( ).
    cl_abap_unit_assert=>assert_equals( act = lo_grid->get_functions( )
                                        exp = VALUE string_table( ( `ZBOOK` ) ) ).

    " the draft in between - the handlers are names, they survive it
    DATA(lv_xml) = ``.
    CALL TRANSFORMATION id SOURCE grid = lo_grid RESULT XML lv_xml.
    CLEAR lo_grid.
    CALL TRANSFORMATION id SOURCE XML lv_xml RESULT grid = lo_grid.
    cl_abap_unit_assert=>assert_bound( lo_grid ).
    DATA(li_events) = CAST z2ui5_if_cgui_alv_events( lo_grid ).

    " the report: a click on row 2, a hotspot in row 1, the function
    li_events->raise( kind   = z2ui5_if_cgui_alv_events=>cs_kind-double
                      row    = 2
                      column = `seats` ).
    cl_abap_unit_assert=>assert_equals( act = ltcl_handler=>gv_row
                                        exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ltcl_handler=>gv_column
                                        exp = `SEATS` ).
    li_events->raise( kind = z2ui5_if_cgui_alv_events=>cs_kind-link
                      row  = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ltcl_handler=>gv_link
                                        exp = 1 ).
    cl_abap_unit_assert=>assert_true( li_events->raise( kind     = z2ui5_if_cgui_alv_events=>cs_kind-function
                                                        function = `ZBOOK` ) ).
    cl_abap_unit_assert=>assert_equals( act = ltcl_handler=>gv_ucomm
                                        exp = `ZBOOK` ).

  ENDMETHOD.

  METHOD icons.

    cl_abap_unit_assert=>assert_equals( act = z2ui5_cl_cgui_grid=>icon_to_ui5( `ICON_REFRESH` )
                                        exp = `sap-icon://refresh` ).
    cl_abap_unit_assert=>assert_equals( act = z2ui5_cl_cgui_grid=>icon_to_ui5( `@11@` )
                                        exp = `sap-icon://delete` ).
    cl_abap_unit_assert=>assert_equals( act = z2ui5_cl_cgui_grid=>icon_to_ui5( `sap-icon://home` )
                                        exp = `sap-icon://home` ).

  ENDMETHOD.

ENDCLASS.
