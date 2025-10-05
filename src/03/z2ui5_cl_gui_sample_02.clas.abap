CLASS z2ui5_cl_gui_sample_02 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS z2ui5_cl_gui_sample_02 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    DATA(lo_list) = NEW z2ui5_cl_gui_list(
        )->write( `this is a list opoutput`
        )->skip(
        )->uline(
        )->skip( 3
        )->write( `Checkbox`
        )->write_as_checkbox(
        ).

    client->view_display( lo_list->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
