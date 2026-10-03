" cloud gui - an ALV object model of a converted report (CL_SALV_TABLE,
" CL_GUI_ALV_GRID) whose event handlers the report calls: the report
" knows what happened on its ALV, the object model which of its events
" that is and whom to tell
INTERFACE z2ui5_if_cgui_alv_events PUBLIC.

  " kept in the draft of abap2UI5 between two roundtrips
  INTERFACES if_serializable_object.

  CONSTANTS:
    BEGIN OF cs_kind,
      " a hotspot of a cell
      link     TYPE string VALUE `LINK`,
      " the click on a row
      double   TYPE string VALUE `DOUBLE`,
      " an own function of the toolbar
      function TYPE string VALUE `FUNCTION`,
    END OF cs_kind.

  " the ALV of the report the object model works on
  METHODS get_alv
    RETURNING
      VALUE(result) TYPE REF TO z2ui5_cl_cgui_alv.

  " what happened (cs_kind) to the handlers - abap_true when one ran
  METHODS raise
    IMPORTING
      kind          TYPE clike
      row           TYPE i OPTIONAL
      column        TYPE clike OPTIONAL
      function      TYPE clike OPTIONAL
    RETURNING
      VALUE(result) TYPE abap_bool.

ENDINTERFACE.
