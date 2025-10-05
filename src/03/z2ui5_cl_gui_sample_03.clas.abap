CLASS z2ui5_cl_gui_sample_03 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS z2ui5_cl_gui_sample_03 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    DATA(lo_alv) = NEW z2ui5_cl_gui_alv( ).
    lo_alv->factory( ).

*       o_salv->get_functions( )->set_all( abap_true ).
*        o_salv->get_columns( )->set_optimize( abap_true ).
*        o_salv->get_display_settings( )->set_list_header( |{ i_title }| ).
*        o_salv->get_display_settings( )->set_striped_pattern( abap_true ).
*        o_salv->get_selections( )->set_selection_mode( if_salv_c_selection_mode=>row_column ).

    client->view_display( lo_alv->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
