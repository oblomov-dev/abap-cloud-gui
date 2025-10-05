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


    DATA(lo_screen) = NEW z2ui5_cl_gui_selscreen( )->screen_begin( ).

    DATA(lo_block) = lo_screen->block_begin(
        )->checkbox( '234'
        )->parameter(
        )->select_option(
        )->comment( ).

    DATA(lo_line) = lo_block->line_begin(
        )->comment(
        )->button( ).

    lo_screen->block_begin(
        )->checkbox( val = '234'
        )->parameter(
        )->select_option(
        )->comment( ).

    client->view_display( lo_screen->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
