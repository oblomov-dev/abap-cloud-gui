"! The store of the selection variants of a report. Without one the report
"! runtime keeps the variants in the browser's local storage; a server
"! store is set in initialization( ) with set_variant_store( ), e.g.
"! z2ui5_cl_cgui_variant_db=>factory( ). The store travels in the draft of
"! the app - it must be serializable.
INTERFACE z2ui5_if_cgui_variant_store PUBLIC.

  INTERFACES if_serializable_object.

  "! the variants of report the current user sees - his own ones and the
  "! shared ones of the other users
  METHODS load
    IMPORTING
      report        TYPE clike
    RETURNING
      VALUE(result) TYPE z2ui5_cl_cgui_variant=>ty_t_variant.

  "! save variant - refused when another user owns it and protected it
  METHODS save
    IMPORTING
      report  TYPE clike
      variant TYPE z2ui5_cl_cgui_variant=>ty_s_variant
    RAISING
      z2ui5_cx_cgui_error.

  "! delete the variant name - refused when another user owns it and
  "! protected it
  METHODS delete
    IMPORTING
      report TYPE clike
      name   TYPE clike
    RAISING
      z2ui5_cx_cgui_error.

  "! does the store keep shared and protected variants
  METHODS check_sharing
    RETURNING
      VALUE(result) TYPE abap_bool.

ENDINTERFACE.
