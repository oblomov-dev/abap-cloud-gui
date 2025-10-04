CLASS z2ui5_cl_gui_sample_01 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS z2ui5_cl_gui_sample_01 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).

      DATA(lo_screen) = NEW z2ui5_cl_gui_selscreen( ).
      lo_screen->screen_begin(
        )->checkbox( val = '234'
        )->parameter( ).

    ELSEIF client->get( )-event = 'ABC'.

      DATA(lo_list) = NEW z2ui5_cl_gui_list( ).
      lo_list->write( `this is a list opoutput` ).

    ENDIF.

  ENDMETHOD.

ENDCLASS.
