CLASS zacgui_cl_popup DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    data:
        begin of ms_result,
            check_yes type abap_bool,
            check_cancel type abap_bool,
            decide_val  type i,
        end of ms_result.

    methods decide
        importing
        val type string.
    methods w.
    methods s.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zacgui_cl_popup IMPLEMENTATION.
  METHOD decide.

  ENDMETHOD.

  METHOD s.

  ENDMETHOD.

  METHOD w.

  ENDMETHOD.

ENDCLASS.
