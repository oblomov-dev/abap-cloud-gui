CLASS z2ui5_cl_cgui_context DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_s_data_element_text,
        header TYPE string,
        short  TYPE string,
        medium TYPE string,
        long   TYPE string,
      END OF ty_s_data_element_text.

    TYPES:
      BEGIN OF ty_s_comp,
        name      TYPE string,
        label     TYPE string,
        type_kind TYPE string,
      END OF ty_s_comp.
    TYPES ty_t_comp TYPE STANDARD TABLE OF ty_s_comp WITH EMPTY KEY.

    " the name of the PUBLIC attribute of app that val is - compared by
    " reference, so val must be the attribute itself (passed by reference),
    " not a copy of it. Empty when val is no attribute of app
    CLASS-METHODS attri_name_by_ref
      IMPORTING
        app           TYPE REF TO object
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    " the medium field label of the data element val is typed with, empty
    " for a built-in or local type
    CLASS-METHODS rtti_get_label
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS rtti_check_boolean
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS rtti_get_type_kind
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    " the elementary components of the line type of a table of structures,
    " with their DDIC label (or the component name) - the ALV field catalog
    CLASS-METHODS rtti_get_t_comp
      IMPORTING
        val           TYPE ANY TABLE
      RETURNING
        VALUE(result) TYPE ty_t_comp.

    " a value as WRITE would put it on a list - dates and times in the
    " user's format, everything else as its plain text
    CLASS-METHODS conv_to_text
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    " a range table as the one-line summary a select-option shows
    CLASS-METHODS range_to_text
      IMPORTING
        val           TYPE ANY TABLE
      RETURNING
        VALUE(result) TYPE string.

    " val IN range - the semantics of a select-option (an empty range
    " matches everything, E lines exclude), written out so it also runs where
    " IN is not complete: the transpiled JavaScript runtime only knows I/EQ,
    " E/EQ and I/CP. On an SAP system IN and SELECT ... WHERE IN do the same
    CLASS-METHODS range_check
      IMPORTING
        val           TYPE any
        range         TYPE ANY TABLE
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS rtti_get_data_element_texts
      IMPORTING
        val           TYPE clike
      RETURNING
        VALUE(result) TYPE ty_s_data_element_text.

    CLASS-METHODS rtti_get_label_by_descr
      IMPORTING
        descr         TYPE REF TO cl_abap_typedescr
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-METHODS rtti_get_dtel_texts_by_ddic
      IMPORTING
        name        TYPE string
      EXPORTING
        texts       TYPE ty_s_data_element_text
        do_fallback TYPE abap_bool.

    CLASS-METHODS rtti_get_dtel_texts_by_xco
      IMPORTING
        name        TYPE string
      EXPORTING
        texts       TYPE ty_s_data_element_text
        do_fallback TYPE abap_bool.

    CLASS-METHODS range_line_to_text
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS range_line_check
      IMPORTING
        val           TYPE any
        option        TYPE any
        low           TYPE any
        high          TYPE any
      RETURNING
        VALUE(result) TYPE abap_bool.

ENDCLASS.


CLASS z2ui5_cl_cgui_context IMPLEMENTATION.

  METHOD attri_name_by_ref.

    DATA lr_val   TYPE REF TO data.
    DATA lr_attri TYPE REF TO data.
    FIELD-SYMBOLS <attri> TYPE any.

    IF app IS NOT BOUND.
      RETURN.
    ENDIF.

    GET REFERENCE OF val INTO lr_val.
    DATA(lo_class) = CAST cl_abap_classdescr( cl_abap_typedescr=>describe_by_object_ref( app ) ).

    LOOP AT lo_class->attributes REFERENCE INTO DATA(lr_attri_descr)
         WHERE visibility = cl_abap_classdescr=>public
           AND is_constant = abap_false.

      UNASSIGN <attri>.
      ASSIGN app->(lr_attri_descr->name) TO <attri>.
      IF <attri> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.

      GET REFERENCE OF <attri> INTO lr_attri.
      IF lr_attri = lr_val.
        result = lr_attri_descr->name.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD rtti_get_label.

    result = rtti_get_label_by_descr( cl_abap_typedescr=>describe_by_data( val ) ).

  ENDMETHOD.

  METHOD rtti_get_label_by_descr.

    IF descr->kind <> cl_abap_typedescr=>kind_elem.
      RETURN.
    ENDIF.
    IF descr->is_ddic_type( ) = abap_false.
      RETURN.
    ENDIF.
    IF descr->absolute_name CS `\TYPE-POOL=`.
      RETURN.
    ENDIF.

    DATA(lv_name) = substring_after( val = descr->absolute_name
                                     sub = `\TYPE=` ).
    IF lv_name IS INITIAL.
      RETURN.
    ENDIF.

    DATA(ls_texts) = rtti_get_data_element_texts( lv_name ).
    result = ls_texts-medium.
    IF result IS INITIAL.
      result = ls_texts-long.
    ENDIF.
    IF result = lv_name.
      CLEAR result.
    ENDIF.

  ENDMETHOD.

  METHOD rtti_check_boolean.

    DATA(lo_descr) = cl_abap_typedescr=>describe_by_data( val ).
    IF lo_descr->kind <> cl_abap_typedescr=>kind_elem.
      RETURN.
    ENDIF.

    CASE lo_descr->absolute_name.
      WHEN `\TYPE-POOL=ABAP\TYPE=ABAP_BOOL`
          OR `\TYPE=ABAP_BOOL`
          OR `\TYPE=ABAP_BOOLEAN`
          OR `\TYPE=XSDBOOLEAN`
          OR `\TYPE=BOOLEAN`
          OR `\TYPE=BOOLE_D`.
        result = abap_true.
    ENDCASE.

  ENDMETHOD.

  METHOD rtti_get_type_kind.

    result = cl_abap_typedescr=>describe_by_data( val )->type_kind.

  ENDMETHOD.

  METHOD rtti_get_t_comp.

    DATA lo_struct TYPE REF TO cl_abap_structdescr.

    DATA(lo_table) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( val ) ).
    DATA(lo_line) = lo_table->get_table_line_type( ).
    IF lo_line->kind <> cl_abap_typedescr=>kind_struct.
      RAISE EXCEPTION TYPE z2ui5_cx_cgui_error
        EXPORTING
          val = `ALV_TABLE_LINE_NO_STRUCTURE - use a table of structures`.
    ENDIF.
    lo_struct ?= lo_line.

    LOOP AT lo_struct->components REFERENCE INTO DATA(lr_comp).
      DATA(lv_name) = CONV string( lr_comp->name ).
      DATA(lo_comp) = lo_struct->get_component_type( lv_name ).
      IF lo_comp->kind <> cl_abap_typedescr=>kind_elem.
        CONTINUE.
      ENDIF.

      DATA(lv_label) = rtti_get_label_by_descr( lo_comp ).
      IF lv_label IS INITIAL.
        lv_label = lv_name.
      ENDIF.

      INSERT VALUE #( name      = lv_name
                      label     = lv_label
                      type_kind = lr_comp->type_kind ) INTO TABLE result.
    ENDLOOP.

  ENDMETHOD.

  METHOD conv_to_text.

    DATA lv_date TYPE d.
    DATA lv_time TYPE t.

    CASE cl_abap_typedescr=>describe_by_data( val )->type_kind.

      WHEN cl_abap_typedescr=>typekind_date.
        lv_date = val.
        IF lv_date IS NOT INITIAL.
          result = |{ lv_date DATE = USER }|.
        ENDIF.

      WHEN cl_abap_typedescr=>typekind_time.
        lv_time = val.
        result = |{ lv_time TIME = USER }|.

      WHEN OTHERS.
        result = |{ val }|.

    ENDCASE.

  ENDMETHOD.

  METHOD range_to_text.

    FIELD-SYMBOLS <line> TYPE any.
    DATA lv_count TYPE i.

    LOOP AT val ASSIGNING <line>.
      lv_count = lv_count + 1.
      IF lv_count > 3.
        CONTINUE.
      ENDIF.
      IF result IS NOT INITIAL.
        result = |{ result }; |.
      ENDIF.
      result = result && range_line_to_text( <line> ).
    ENDLOOP.

    IF lv_count > 3.
      result = |{ result } (+{ lv_count - 3 })|.
    ENDIF.

  ENDMETHOD.

  METHOD range_line_to_text.

    FIELD-SYMBOLS <sign>   TYPE any.
    FIELD-SYMBOLS <option> TYPE any.
    FIELD-SYMBOLS <low>    TYPE any.
    FIELD-SYMBOLS <high>   TYPE any.

    ASSIGN COMPONENT `SIGN` OF STRUCTURE val TO <sign>.
    ASSIGN COMPONENT `OPTION` OF STRUCTURE val TO <option>.
    ASSIGN COMPONENT `LOW` OF STRUCTURE val TO <low>.
    ASSIGN COMPONENT `HIGH` OF STRUCTURE val TO <high>.
    IF <sign> IS NOT ASSIGNED OR <option> IS NOT ASSIGNED
        OR <low> IS NOT ASSIGNED OR <high> IS NOT ASSIGNED.
      RETURN.
    ENDIF.

    DATA(lv_low) = conv_to_text( <low> ).
    DATA(lv_high) = conv_to_text( <high> ).

    CASE <option>.
      WHEN `EQ` OR ``.
        result = lv_low.
      WHEN `BT`.
        result = |{ lv_low }...{ lv_high }|.
      WHEN `NB`.
        result = |!({ lv_low }...{ lv_high })|.
      WHEN `CP`.
        result = lv_low.
      WHEN OTHERS.
        result = |{ <option> } { lv_low }|.
    ENDCASE.

    IF <sign> = `E`.
      result = |!{ result }|.
    ENDIF.

  ENDMETHOD.

  METHOD range_check.

    FIELD-SYMBOLS <line>   TYPE any.
    FIELD-SYMBOLS <sign>   TYPE any.
    FIELD-SYMBOLS <option> TYPE any.
    FIELD-SYMBOLS <low>    TYPE any.
    FIELD-SYMBOLS <high>   TYPE any.
    DATA lv_has_include TYPE abap_bool.
    DATA lv_included    TYPE abap_bool.
    DATA lv_match       TYPE abap_bool.

    LOOP AT range ASSIGNING <line>.
      UNASSIGN: <sign>, <option>, <low>, <high>.
      ASSIGN COMPONENT `SIGN` OF STRUCTURE <line> TO <sign>.
      ASSIGN COMPONENT `OPTION` OF STRUCTURE <line> TO <option>.
      ASSIGN COMPONENT `LOW` OF STRUCTURE <line> TO <low>.
      ASSIGN COMPONENT `HIGH` OF STRUCTURE <line> TO <high>.
      IF <sign> IS NOT ASSIGNED OR <option> IS NOT ASSIGNED
          OR <low> IS NOT ASSIGNED OR <high> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.

      lv_match = range_line_check( val    = val
                                   option = <option>
                                   low    = <low>
                                   high   = <high> ).
      IF <sign> = `E`.
        IF lv_match = abap_true.
          RETURN.
        ENDIF.
      ELSE.
        lv_has_include = abap_true.
        IF lv_match = abap_true.
          lv_included = abap_true.
        ENDIF.
      ENDIF.
    ENDLOOP.

    " no include line at all selects everything the excludes left over
    result = xsdbool( lv_has_include = abap_false OR lv_included = abap_true ).

  ENDMETHOD.

  METHOD range_line_check.

    CASE option.
      WHEN `EQ` OR ``.
        result = xsdbool( val = low ).
      WHEN `NE`.
        result = xsdbool( val <> low ).
      WHEN `GT`.
        result = xsdbool( val > low ).
      WHEN `GE`.
        result = xsdbool( val >= low ).
      WHEN `LT`.
        result = xsdbool( val < low ).
      WHEN `LE`.
        result = xsdbool( val <= low ).
      WHEN `BT`.
        result = xsdbool( val >= low AND val <= high ).
      WHEN `NB`.
        result = xsdbool( val < low OR val > high ).
      WHEN `CP`.
        result = xsdbool( val CP low ).
      WHEN `NP`.
        result = xsdbool( val NP low ).
    ENDCASE.

  ENDMETHOD.

  METHOD rtti_get_data_element_texts.

    DATA data_element_name TYPE string.
    DATA lv_do_fallback    TYPE abap_bool.

    data_element_name = val.

    TRY.
        rtti_get_dtel_texts_by_ddic( EXPORTING name        = data_element_name
                                     IMPORTING texts       = result
                                               do_fallback = lv_do_fallback ).
      CATCH cx_root.
        rtti_get_dtel_texts_by_xco( EXPORTING name        = data_element_name
                                    IMPORTING texts       = result
                                              do_fallback = lv_do_fallback ).
    ENDTRY.

    IF lv_do_fallback = abap_true AND result IS INITIAL.
      result-header = val.
      result-long   = val.
      result-medium = val.
      result-short  = val.
    ENDIF.

  ENDMETHOD.

  METHOD rtti_get_dtel_texts_by_ddic.

    DATA ddic_ref TYPE REF TO data.
    DATA: BEGIN OF ddic,
            reptext   TYPE string,
            scrtext_s TYPE string,
            scrtext_m TYPE string,
            scrtext_l TYPE string,
          END OF ddic.
    DATA struct_descr TYPE REF TO cl_abap_structdescr.
    FIELD-SYMBOLS <ddic> TYPE data.
    DATA lo_typedescr TYPE REF TO cl_abap_typedescr.

    CLEAR texts.
    do_fallback = abap_false.

    " raises on ABAP Cloud, where the caller falls back to XCO
    cl_abap_typedescr=>describe_by_name( `T100` ).

    struct_descr ?= cl_abap_structdescr=>describe_by_name( `DFIES` ).

    CREATE DATA ddic_ref TYPE HANDLE struct_descr.

    ASSIGN ddic_ref->* TO <ddic>.
    IF <ddic> IS NOT ASSIGNED.
      RETURN.
    ENDIF.

    cl_abap_elemdescr=>describe_by_name( EXPORTING  p_name     = name
                                         RECEIVING p_descr_ref = lo_typedescr
                                         EXCEPTIONS OTHERS     = 1 ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CALL METHOD lo_typedescr->(`GET_DDIC_FIELD`)
      RECEIVING
        p_flddescr   = <ddic>
      EXCEPTIONS
        not_found    = 1
        no_ddic_type = 2
        OTHERS       = 3.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    MOVE-CORRESPONDING <ddic> TO ddic.
    texts-header = ddic-reptext.
    texts-short  = ddic-scrtext_s.
    texts-medium = ddic-scrtext_m.
    texts-long   = ddic-scrtext_l.
    do_fallback  = abap_true.

  ENDMETHOD.

  METHOD rtti_get_dtel_texts_by_xco.

    DATA data_element TYPE REF TO object.
    DATA content      TYPE REF TO object.
    DATA exists       TYPE abap_bool.
    DATA lv_xco_cp_abap_dictionary TYPE string.

    CLEAR texts.
    do_fallback = abap_false.

    TRY.
        lv_xco_cp_abap_dictionary = `XCO_CP_ABAP_DICTIONARY`.
        CALL METHOD (lv_xco_cp_abap_dictionary)=>(`DATA_ELEMENT`)
          EXPORTING
            iv_name         = name
          RECEIVING
            ro_data_element = data_element.

        CALL METHOD data_element->(`IF_XCO_AD_DATA_ELEMENT~EXISTS`)
          RECEIVING
            rv_exists = exists.

        IF exists = abap_false.
          RETURN.
        ENDIF.

        CALL METHOD data_element->(`IF_XCO_AD_DATA_ELEMENT~CONTENT`)
          RECEIVING
            ro_content = content.

        CALL METHOD content->(`IF_XCO_DTEL_CONTENT~GET_HEADING_FIELD_LABEL`)
          RECEIVING
            rs_heading_field_label = texts-header.

        CALL METHOD content->(`IF_XCO_DTEL_CONTENT~GET_SHORT_FIELD_LABEL`)
          RECEIVING
            rs_short_field_label = texts-short.

        CALL METHOD content->(`IF_XCO_DTEL_CONTENT~GET_MEDIUM_FIELD_LABEL`)
          RECEIVING
            rs_medium_field_label = texts-medium.

        CALL METHOD content->(`IF_XCO_DTEL_CONTENT~GET_LONG_FIELD_LABEL`)
          RECEIVING
            rs_long_field_label = texts-long.

        do_fallback = abap_true.

      CATCH cx_root.
        do_fallback = abap_true.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
