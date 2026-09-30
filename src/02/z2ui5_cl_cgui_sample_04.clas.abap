CLASS z2ui5_cl_cgui_sample_04 DEFINITION PUBLIC
  INHERITING FROM z2ui5_cl_cgui_report
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    DATA p_name  TYPE string.
    DATA p_times TYPE i.

  PROTECTED SECTION.
    METHODS initialization REDEFINITION.
    METHODS selection_screen REDEFINITION.
    METHODS start_of_selection REDEFINITION.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_cgui_sample_04 IMPLEMENTATION.

  METHOD initialization.

    set_title( `abap-cloud-gui - Hello World Report` ).
    p_times = 3.

  ENDMETHOD.

  METHOD selection_screen.

    screen->parameter( val        = p_name
                       text       = `Your name`
                       obligatory = abap_true
        )->parameter( val  = p_times
                      text = `Lines` ).

  ENDMETHOD.

  METHOD start_of_selection.

    write( |Hello { p_name }!| )->uline( ).

    DO p_times TIMES.
      write( |Line { sy-index }| )->new_line( ).
    ENDDO.

  ENDMETHOD.

ENDCLASS.
