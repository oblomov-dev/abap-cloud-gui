"! Selection variants - the values of a selection screen under a name, the
"! classic variant of a report. A variant holds every field of the screen:
"! a parameter as one value, a select-option as its lines. The variants of
"! a report form its catalog, which z2ui5_cl_cgui_report keeps in the
"! browser's local storage - this class reads the fields out of the app,
"! writes them back, and turns the catalog into the string that is stored.
CLASS z2ui5_cl_cgui_variant DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF cs_kind,
        parameter     TYPE string VALUE `P`,
        select_option TYPE string VALUE `S`,
      END OF cs_kind.

    "! one value of a variant: a parameter has one line with its value in
    "! low, a select-option one line per range line - and one line without
    "! sign when it is empty, so that loading the variant clears it
    TYPES:
      BEGIN OF ty_s_value,
        name   TYPE string,
        kind   TYPE string,
        sign   TYPE string,
        option TYPE string,
        low    TYPE string,
        high   TYPE string,
      END OF ty_s_value.
    TYPES ty_t_value TYPE STANDARD TABLE OF ty_s_value WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_variant,
        name   TYPE string,
        text   TYPE string,
        values TYPE ty_t_value,
      END OF ty_s_variant.
    TYPES ty_t_variant TYPE STANDARD TABLE OF ty_s_variant WITH EMPTY KEY.

    "! the current values of the attributes names of app
    CLASS-METHODS values_get
      IMPORTING
        app           TYPE REF TO object
        names         TYPE string_table
      RETURNING
        VALUE(result) TYPE ty_t_value.

    "! write values into the attributes of app - a value whose attribute is
    "! gone or no longer fits is left out
    CLASS-METHODS values_set
      IMPORTING
        app    TYPE REF TO object
        values TYPE ty_t_value.

    "! a one-line summary of the filled values - the text of a variant.
    "! fields gives the labels to show instead of the attribute names
    CLASS-METHODS values_to_text
      IMPORTING
        values        TYPE ty_t_value
        fields        TYPE z2ui5_cl_cgui_selscreen=>ty_t_field OPTIONAL
      RETURNING
        VALUE(result) TYPE string.

    "! the catalog as the string that is stored
    CLASS-METHODS catalog_to_string
      IMPORTING
        variants      TYPE ty_t_variant
      RETURNING
        VALUE(result) TYPE string.

    "! the catalog back from the stored string - empty when it cannot be read
    CLASS-METHODS catalog_from_string
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE ty_t_variant.

    "! the argument of the STORE_DATA frontend action that writes val under
    "! prefix and key into the browser's local storage - composed as JSON:
    "! the action takes one argument and destructures it as TYPE, PREFIX,
    "! KEY and VALUE
    CLASS-METHODS storage_json
      IMPORTING
        prefix        TYPE clike
        key           TYPE clike
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS json_escape
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-METHODS range_lines_get
      IMPORTING
        name          TYPE string
        range         TYPE ANY TABLE
      RETURNING
        VALUE(result) TYPE ty_t_value.

ENDCLASS.


CLASS z2ui5_cl_cgui_variant IMPLEMENTATION.

  METHOD values_get.

    FIELD-SYMBOLS <attri> TYPE any.
    FIELD-SYMBOLS <range> TYPE ANY TABLE.

    LOOP AT names INTO DATA(lv_name).
      UNASSIGN <attri>.
      ASSIGN app->(lv_name) TO <attri>.
      IF <attri> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.

      IF cl_abap_typedescr=>describe_by_data( <attri> )->kind = cl_abap_typedescr=>kind_table.
        ASSIGN <attri> TO <range>.
        INSERT LINES OF range_lines_get( name  = lv_name
                                         range = <range> ) INTO TABLE result.
      ELSE.
        INSERT VALUE #( name = lv_name
                        kind = cs_kind-parameter
                        low  = <attri> ) INTO TABLE result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD range_lines_get.

    FIELD-SYMBOLS <line> TYPE any.
    FIELD-SYMBOLS <comp> TYPE any.
    DATA ls_value TYPE ty_s_value.

    LOOP AT range ASSIGNING <line>.
      CLEAR ls_value.
      ls_value-name = name.
      ls_value-kind = cs_kind-select_option.
      ASSIGN COMPONENT `SIGN` OF STRUCTURE <line> TO <comp>.
      IF <comp> IS ASSIGNED.
        ls_value-sign = <comp>.
      ENDIF.
      UNASSIGN <comp>.
      ASSIGN COMPONENT `OPTION` OF STRUCTURE <line> TO <comp>.
      IF <comp> IS ASSIGNED.
        ls_value-option = <comp>.
      ENDIF.
      UNASSIGN <comp>.
      ASSIGN COMPONENT `LOW` OF STRUCTURE <line> TO <comp>.
      IF <comp> IS ASSIGNED.
        ls_value-low = <comp>.
      ENDIF.
      UNASSIGN <comp>.
      ASSIGN COMPONENT `HIGH` OF STRUCTURE <line> TO <comp>.
      IF <comp> IS ASSIGNED.
        ls_value-high = <comp>.
      ENDIF.
      UNASSIGN <comp>.
      INSERT ls_value INTO TABLE result.
    ENDLOOP.

    IF result IS INITIAL.
      INSERT VALUE #( name = name
                      kind = cs_kind-select_option ) INTO TABLE result.
    ENDIF.

  ENDMETHOD.

  METHOD values_set.

    FIELD-SYMBOLS <attri> TYPE any.
    FIELD-SYMBOLS <range> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <line>  TYPE any.
    FIELD-SYMBOLS <comp>  TYPE any.
    DATA lr_line   TYPE REF TO data.
    DATA lv_last   TYPE string.

    LOOP AT values REFERENCE INTO DATA(lr_value).
      UNASSIGN <attri>.
      ASSIGN app->(lr_value->name) TO <attri>.
      IF <attri> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.

      TRY.
          IF lr_value->kind = cs_kind-parameter.
            IF cl_abap_typedescr=>describe_by_data( <attri> )->kind <> cl_abap_typedescr=>kind_table.
              <attri> = lr_value->low.
            ENDIF.
            CONTINUE.
          ENDIF.

          IF cl_abap_typedescr=>describe_by_data( <attri> )->kind <> cl_abap_typedescr=>kind_table.
            CONTINUE.
          ENDIF.
          ASSIGN <attri> TO <range>.
          " the first line of a select-option clears it
          IF lr_value->name <> lv_last.
            CLEAR <range>.
            lv_last = lr_value->name.
          ENDIF.
          IF lr_value->sign IS INITIAL.
            CONTINUE.
          ENDIF.

          CREATE DATA lr_line LIKE LINE OF <range>.
          ASSIGN lr_line->* TO <line>.
          ASSIGN COMPONENT `SIGN` OF STRUCTURE <line> TO <comp>.
          <comp> = lr_value->sign.
          ASSIGN COMPONENT `OPTION` OF STRUCTURE <line> TO <comp>.
          <comp> = lr_value->option.
          ASSIGN COMPONENT `LOW` OF STRUCTURE <line> TO <comp>.
          <comp> = lr_value->low.
          ASSIGN COMPONENT `HIGH` OF STRUCTURE <line> TO <comp>.
          <comp> = lr_value->high.
          INSERT <line> INTO TABLE <range>.
        CATCH cx_root ##NO_HANDLER.
      ENDTRY.
    ENDLOOP.

  ENDMETHOD.

  METHOD values_to_text.

    DATA lv_part TYPE string.
    DATA lv_name TYPE string.

    LOOP AT values REFERENCE INTO DATA(lr_value)
         WHERE low IS NOT INITIAL OR high IS NOT INITIAL.
      lv_name = lr_value->name.
      READ TABLE fields REFERENCE INTO DATA(lr_field) WITH KEY name = lr_value->name.
      IF sy-subrc = 0 AND lr_field->text IS NOT INITIAL.
        lv_name = lr_field->text.
      ENDIF.

      IF lr_value->high IS INITIAL.
        lv_part = |{ lv_name } { lr_value->option } { lr_value->low }|.
      ELSE.
        lv_part = |{ lv_name } { lr_value->option } { lr_value->low } - { lr_value->high }|.
      ENDIF.
      IF lr_value->kind = cs_kind-parameter.
        lv_part = |{ lv_name } = { lr_value->low }|.
      ELSEIF lr_value->sign = `E`.
        lv_part = |{ lv_part } (excl.)|.
      ENDIF.
      CONDENSE lv_part.

      IF result IS INITIAL.
        result = lv_part.
      ELSE.
        result = |{ result }, { lv_part }|.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD catalog_to_string.

    CALL TRANSFORMATION id SOURCE variants = variants RESULT XML result.

  ENDMETHOD.

  METHOD catalog_from_string.

    IF val IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        CALL TRANSFORMATION id SOURCE XML val RESULT variants = result.
      CATCH cx_root.
        CLEAR result.
    ENDTRY.

  ENDMETHOD.

  METHOD storage_json.

    result = |\{"TYPE":"local","PREFIX":"{ json_escape( |{ prefix }| ) }",| &&
             |"KEY":"{ json_escape( |{ key }| ) }","VALUE":"{ json_escape( val ) }"\}|.

  ENDMETHOD.

  METHOD json_escape.

    " the backslash first, or it would escape the escapes added after it
    result = replace( val = val    sub = `\`  with = `\\` occ = 0 ).
    result = replace( val = result sub = |\n| with = `\n`  occ = 0 ).
    result = replace( val = result sub = |\r| with = `\r`  occ = 0 ).
    result = replace( val = result sub = |\t| with = `\t`  occ = 0 ).
    result = replace( val = result sub = `"`  with = `\"`  occ = 0 ).

  ENDMETHOD.

ENDCLASS.
