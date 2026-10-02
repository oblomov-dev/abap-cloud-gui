"! Selection screen painter - the part without a screen: the elements of a
"! selection screen as the painter edits them, their check, the data
"! objects its preview shows, and the report class they become. The code
"! follows the house layout of the samples: one call per line, the
"! parameters of a call aligned under each other.
CLASS z2ui5_cl_cgui_painter_code DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF cs_kind,
        block_begin   TYPE string VALUE `BLOCK_BEGIN`,
        block_end     TYPE string VALUE `BLOCK_END`,
        line_begin    TYPE string VALUE `LINE_BEGIN`,
        line_end      TYPE string VALUE `LINE_END`,
        parameter     TYPE string VALUE `PARAMETER`,
        select_option TYPE string VALUE `SELECT_OPTION`,
        checkbox      TYPE string VALUE `CHECKBOX`,
        radiobutton   TYPE string VALUE `RADIOBUTTON`,
        comment       TYPE string VALUE `COMMENT`,
        button        TYPE string VALUE `BUTTON`,
      END OF cs_kind.

    TYPES:
      "! one element of the selection screen. type is the ABAP type of a
      "! parameter or select-option (c LENGTH 10, d, i, a DDIC type) and the
      "! icon of a button; group is the radio button group or the event of
      "! a button
      BEGIN OF ty_s_element,
        id           TYPE i,
        kind         TYPE string,
        name         TYPE string,
        type         TYPE string,
        text         TYPE string,
        obligatory   TYPE abap_bool,
        value_help   TYPE abap_bool,
        group        TYPE string,
        modif_id     TYPE string,
        user_command TYPE string,
        no_display   TYPE abap_bool,
      END OF ty_s_element.
    TYPES ty_t_element TYPE STANDARD TABLE OF ty_s_element WITH EMPTY KEY.

    "! the problems of the elements, one text each - empty when the code
    "! can be generated
    CLASS-METHODS check
      IMPORTING
        elements      TYPE ty_t_element
      RETURNING
        VALUE(result) TYPE string_table.

    "! the report class: the fields as attributes, selection_screen( ) and
    "! the event blocks the elements call for
    CLASS-METHODS generate
      IMPORTING
        class         TYPE clike
        elements      TYPE ty_t_element
      RETURNING
        VALUE(result) TYPE string.

    "! the body of selection_screen( ) - the chain on screen
    CLASS-METHODS selection_screen
      IMPORTING
        elements      TYPE ty_t_element
      RETURNING
        VALUE(result) TYPE string_table.

    "! a data object of the ABAP type spec - unbound when spec is no type
    CLASS-METHODS type_create
      IMPORTING
        spec          TYPE clike
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! a range table of the ABAP type spec - unbound when spec is no type
    CLASS-METHODS range_create
      IMPORTING
        spec          TYPE clike
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! does the element declare a field of the report
    CLASS-METHODS check_field
      IMPORTING
        kind          TYPE clike
      RETURNING
        VALUE(result) TYPE abap_bool.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_s_param,
        name  TYPE string,
        value TYPE string,
      END OF ty_s_param.
    TYPES ty_t_param TYPE STANDARD TABLE OF ty_s_param WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_call,
        method     TYPE string,
        positional TYPE abap_bool,
        params     TYPE ty_t_param,
      END OF ty_s_call.
    TYPES ty_t_call TYPE STANDARD TABLE OF ty_s_call WITH EMPTY KEY.

    CLASS-METHODS call_get
      IMPORTING
        element       TYPE ty_s_element
      RETURNING
        VALUE(result) TYPE ty_s_call.

    CLASS-METHODS declarations
      IMPORTING
        elements      TYPE ty_t_element
      RETURNING
        VALUE(result) TYPE string_table.

    CLASS-METHODS type_tokens
      IMPORTING
        spec          TYPE clike
      RETURNING
        VALUE(result) TYPE string_table.

    "! a type RANGE OF takes as it is - a name, not c LENGTH 10
    CLASS-METHODS check_type_named
      IMPORTING
        spec          TYPE clike
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS literal
      IMPORTING
        val           TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS pad
      IMPORTING
        val           TYPE clike
        width         TYPE i
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS type_normalize
      IMPORTING
        spec          TYPE clike
      RETURNING
        VALUE(result) TYPE string.

ENDCLASS.


CLASS z2ui5_cl_cgui_painter_code IMPLEMENTATION.

  METHOD check_field.

    result = xsdbool( kind = cs_kind-parameter
                   OR kind = cs_kind-select_option
                   OR kind = cs_kind-checkbox
                   OR kind = cs_kind-radiobutton ).

  ENDMETHOD.

  METHOD check.

    DATA lt_name   TYPE string_table.
    DATA lv_block  TYPE abap_bool.
    DATA lv_line   TYPE abap_bool.
    DATA lv_name   TYPE string.
    DATA lv_pos    TYPE string.

    LOOP AT elements REFERENCE INTO DATA(lr_element).
      lv_pos = |Line { sy-tabix }|.

      CASE lr_element->kind.

        WHEN cs_kind-block_begin.
          IF lv_block = abap_true.
            INSERT |{ lv_pos }: the block before is not closed - blocks cannot be nested| INTO TABLE result.
          ENDIF.
          IF lv_line = abap_true.
            INSERT |{ lv_pos }: a block cannot begin inside a line| INTO TABLE result.
          ENDIF.
          lv_block = abap_true.

        WHEN cs_kind-block_end.
          IF lv_block = abap_false.
            INSERT |{ lv_pos }: end of a block that was not begun| INTO TABLE result.
          ENDIF.
          IF lv_line = abap_true.
            INSERT |{ lv_pos }: the line inside the block is not closed| INTO TABLE result.
          ENDIF.
          lv_block = abap_false.
          lv_line = abap_false.

        WHEN cs_kind-line_begin.
          IF lv_line = abap_true.
            INSERT |{ lv_pos }: the line before is not closed - lines cannot be nested| INTO TABLE result.
          ENDIF.
          lv_line = abap_true.

        WHEN cs_kind-line_end.
          IF lv_line = abap_false.
            INSERT |{ lv_pos }: end of a line that was not begun| INTO TABLE result.
          ENDIF.
          lv_line = abap_false.

        WHEN cs_kind-comment.
          IF lr_element->text IS INITIAL.
            INSERT |{ lv_pos }: a comment needs a text| INTO TABLE result.
          ENDIF.

        WHEN cs_kind-button.
          IF lr_element->text IS INITIAL OR lr_element->group IS INITIAL.
            INSERT |{ lv_pos }: a button needs a text and an event (column Group / Event)| INTO TABLE result.
          ENDIF.

        WHEN cs_kind-parameter OR cs_kind-select_option OR cs_kind-checkbox OR cs_kind-radiobutton.
          lv_name = to_upper( condense( lr_element->name ) ).
          IF lv_name IS INITIAL.
            INSERT |{ lv_pos }: the field needs a name| INTO TABLE result.
            CONTINUE.
          ENDIF.
          IF strlen( lv_name ) > 27
              OR substring( val = lv_name len = 1 ) NA `ABCDEFGHIJKLMNOPQRSTUVWXYZ`
              OR lv_name CN `ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_`.
            INSERT |{ lv_pos }: { lr_element->name } is no name - a letter, then letters, digits or _, at most 27| INTO TABLE result.
          ELSEIF lv_name = `CLIENT` OR lv_name CS `CGUI`.
            INSERT |{ lv_pos }: { lr_element->name } is taken by the report runtime| INTO TABLE result.
          ENDIF.
          READ TABLE lt_name WITH KEY table_line = lv_name TRANSPORTING NO FIELDS.
          IF sy-subrc = 0.
            INSERT |{ lv_pos }: { lr_element->name } is declared twice| INTO TABLE result.
          ENDIF.
          INSERT lv_name INTO TABLE lt_name.

          IF lr_element->kind = cs_kind-parameter OR lr_element->kind = cs_kind-select_option.
            IF lr_element->type IS INITIAL.
              INSERT |{ lv_pos }: { lr_element->name } needs a type, e.g. c LENGTH 10, d, i or a DDIC type| INTO TABLE result.
            ELSEIF type_create( lr_element->type ) IS NOT BOUND.
              INSERT |{ lv_pos }: { lr_element->type } is no type known here| INTO TABLE result.
            ENDIF.
          ENDIF.

        WHEN OTHERS.
          INSERT |{ lv_pos }: { lr_element->kind } is no kind of element| INTO TABLE result.

      ENDCASE.
    ENDLOOP.

    IF lv_line = abap_true.
      INSERT `The last line is not closed` INTO TABLE result.
    ENDIF.
    IF lv_block = abap_true.
      INSERT `The last block is not closed` INTO TABLE result.
    ENDIF.

  ENDMETHOD.

  METHOD call_get.

    DATA lv_name TYPE string.

    lv_name = to_lower( condense( element-name ) ).
    result-method = to_lower( element-kind ).

    CASE element-kind.

      WHEN cs_kind-block_begin OR cs_kind-line_begin.
        IF element-text IS NOT INITIAL.
          result-positional = abap_true.
          INSERT VALUE #( value = literal( element-text ) ) INTO TABLE result-params.
        ENDIF.
        RETURN.

      WHEN cs_kind-block_end OR cs_kind-line_end.
        RETURN.

      WHEN cs_kind-comment.
        IF element-modif_id IS INITIAL.
          result-positional = abap_true.
          INSERT VALUE #( value = literal( element-text ) ) INTO TABLE result-params.
          RETURN.
        ENDIF.
        INSERT VALUE #( name = `text` value = literal( element-text ) ) INTO TABLE result-params.

      WHEN cs_kind-button.
        INSERT VALUE #( name = `text`  value = literal( element-text ) ) INTO TABLE result-params.
        INSERT VALUE #( name = `event` value = literal( to_upper( element-group ) ) ) INTO TABLE result-params.
        IF element-type IS NOT INITIAL.
          INSERT VALUE #( name = `icon` value = literal( element-type ) ) INTO TABLE result-params.
        ENDIF.

      WHEN OTHERS.
        INSERT VALUE #( name = `val` value = lv_name ) INTO TABLE result-params.
        IF element-text IS NOT INITIAL.
          INSERT VALUE #( name = `text` value = literal( element-text ) ) INTO TABLE result-params.
        ENDIF.
        IF element-kind = cs_kind-radiobutton AND element-group IS NOT INITIAL.
          INSERT VALUE #( name = `group` value = literal( to_upper( element-group ) ) ) INTO TABLE result-params.
        ENDIF.
        IF ( element-kind = cs_kind-parameter OR element-kind = cs_kind-select_option )
            AND element-obligatory = abap_true.
          INSERT VALUE #( name = `obligatory` value = `abap_true` ) INTO TABLE result-params.
        ENDIF.
        IF ( element-kind = cs_kind-parameter OR element-kind = cs_kind-select_option )
            AND element-value_help = abap_true.
          INSERT VALUE #( name = `value_help` value = `abap_true` ) INTO TABLE result-params.
        ENDIF.

    ENDCASE.

    IF element-modif_id IS NOT INITIAL.
      INSERT VALUE #( name = `modif_id` value = literal( to_upper( element-modif_id ) ) ) INTO TABLE result-params.
    ENDIF.
    IF ( element-kind = cs_kind-checkbox OR element-kind = cs_kind-radiobutton )
        AND element-user_command IS NOT INITIAL.
      INSERT VALUE #( name = `user_command` value = literal( to_upper( element-user_command ) ) ) INTO TABLE result-params.
    ENDIF.
    IF ( element-kind = cs_kind-parameter OR element-kind = cs_kind-select_option )
        AND element-no_display = abap_true.
      INSERT VALUE #( name = `no_display` value = `abap_true` ) INTO TABLE result-params.
    ENDIF.

  ENDMETHOD.

  METHOD selection_screen.

    DATA lt_call  TYPE ty_t_call.
    DATA lv_head  TYPE string.
    DATA lv_last  TYPE abap_bool.
    DATA lv_width TYPE i.
    DATA lv_line  TYPE string.

    LOOP AT elements REFERENCE INTO DATA(lr_element).
      INSERT call_get( lr_element->* ) INTO TABLE lt_call.
    ENDLOOP.

    LOOP AT lt_call REFERENCE INTO DATA(lr_call).
      lv_last = xsdbool( sy-tabix = lines( lt_call ) ).
      IF sy-tabix = 1.
        lv_head = |    screen->{ lr_call->method }(|.
      ELSE.
        lv_head = |        )->{ lr_call->method }(|.
      ENDIF.

      IF lr_call->params IS INITIAL.
        IF lv_last = abap_true.
          lv_head = |{ lv_head } ).|.
        ENDIF.
        INSERT lv_head INTO TABLE result.
        CONTINUE.
      ENDIF.

      IF lr_call->positional = abap_true.
        lv_line = |{ lv_head } { lr_call->params[ 1 ]-value }|.
        IF lv_last = abap_true.
          lv_line = |{ lv_line } ).|.
        ENDIF.
        INSERT lv_line INTO TABLE result.
        CONTINUE.
      ENDIF.

      lv_width = 0.
      LOOP AT lr_call->params REFERENCE INTO DATA(lr_param).
        IF strlen( lr_param->name ) > lv_width.
          lv_width = strlen( lr_param->name ).
        ENDIF.
      ENDLOOP.

      LOOP AT lr_call->params REFERENCE INTO lr_param.
        IF sy-tabix = 1.
          lv_line = |{ lv_head } { pad( val = lr_param->name width = lv_width ) } = { lr_param->value }|.
        ELSE.
          lv_line = |{ pad( val = `` width = strlen( lv_head ) ) } { pad( val = lr_param->name width = lv_width ) } = { lr_param->value }|.
        ENDIF.
        IF lv_last = abap_true AND sy-tabix = lines( lr_call->params ).
          lv_line = |{ lv_line } ).|.
        ENDIF.
        INSERT lv_line INTO TABLE result.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.

  METHOD declarations.

    DATA lv_width TYPE i.
    DATA lv_name  TYPE string.
    DATA lv_type  TYPE string.
    DATA lt_types TYPE string_table.
    DATA lt_data  TYPE string_table.

    LOOP AT elements REFERENCE INTO DATA(lr_element) WHERE kind = cs_kind-parameter
                                                       OR kind = cs_kind-select_option
                                                       OR kind = cs_kind-checkbox
                                                       OR kind = cs_kind-radiobutton.
      IF strlen( condense( lr_element->name ) ) > lv_width.
        lv_width = strlen( condense( lr_element->name ) ).
      ENDIF.
    ENDLOOP.

    LOOP AT elements REFERENCE INTO lr_element.
      IF check_field( lr_element->kind ) = abap_false.
        CONTINUE.
      ENDIF.
      lv_name = to_lower( condense( lr_element->name ) ).
      lv_type = type_normalize( lr_element->type ).

      CASE lr_element->kind.
        WHEN cs_kind-checkbox OR cs_kind-radiobutton.
          INSERT |    DATA { pad( val = lv_name width = lv_width ) } TYPE abap_bool.| INTO TABLE lt_data.
        WHEN cs_kind-parameter.
          INSERT |    DATA { pad( val = lv_name width = lv_width ) } TYPE { lv_type }.| INTO TABLE lt_data.
        WHEN cs_kind-select_option.
          IF check_type_named( lv_type ) = abap_true.
            INSERT |    DATA { pad( val = lv_name width = lv_width ) } TYPE RANGE OF { lv_type }.| INTO TABLE lt_data.
          ELSE.
            " RANGE OF takes a type name - c LENGTH 10 gets one first
            INSERT |    TYPES ty_{ lv_name } TYPE { lv_type }.| INTO TABLE lt_types.
            INSERT |    DATA { pad( val = lv_name width = lv_width ) } TYPE RANGE OF ty_{ lv_name }.| INTO TABLE lt_data.
          ENDIF.
      ENDCASE.
    ENDLOOP.

    INSERT LINES OF lt_types INTO TABLE result.
    IF lt_types IS NOT INITIAL AND lt_data IS NOT INITIAL.
      INSERT `` INTO TABLE result.
    ENDIF.
    INSERT LINES OF lt_data INTO TABLE result.

  ENDMETHOD.

  METHOD generate.

    DATA lt_code     TYPE string_table.
    DATA lt_modif    TYPE string_table.
    DATA lt_ucomm    TYPE string_table.
    DATA lt_button   TYPE string_table.
    DATA lv_class    TYPE string.
    DATA lv_name     TYPE string.
    DATA lv_event    TYPE string.

    lv_class = to_lower( condense( class ) ).
    IF lv_class IS INITIAL.
      lv_class = `zcl_my_report`.
    ENDIF.

    LOOP AT elements REFERENCE INTO DATA(lr_element).
      IF lr_element->modif_id IS NOT INITIAL.
        lv_event = to_upper( lr_element->modif_id ).
        READ TABLE lt_modif WITH KEY table_line = lv_event TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.
          INSERT lv_event INTO TABLE lt_modif.
        ENDIF.
      ENDIF.
      CLEAR lv_event.
      IF lr_element->kind = cs_kind-button.
        lv_event = to_upper( lr_element->group ).
        INSERT lv_event INTO TABLE lt_button.
      ELSEIF lr_element->kind = cs_kind-checkbox OR lr_element->kind = cs_kind-radiobutton.
        lv_event = to_upper( lr_element->user_command ).
      ENDIF.
      IF lv_event IS NOT INITIAL.
        READ TABLE lt_ucomm WITH KEY table_line = lv_event TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.
          INSERT lv_event INTO TABLE lt_ucomm.
        ENDIF.
      ENDIF.
    ENDLOOP.

    INSERT |CLASS { lv_class } DEFINITION PUBLIC| INTO TABLE lt_code.
    INSERT `  INHERITING FROM z2ui5_cl_cgui_report` INTO TABLE lt_code.
    INSERT `  FINAL` INTO TABLE lt_code.
    INSERT `  CREATE PUBLIC.` INTO TABLE lt_code.
    INSERT `` INTO TABLE lt_code.
    INSERT `  PUBLIC SECTION.` INTO TABLE lt_code.
    INSERT LINES OF declarations( elements ) INTO TABLE lt_code.
    INSERT `` INTO TABLE lt_code.
    INSERT `  PROTECTED SECTION.` INTO TABLE lt_code.
    INSERT `    METHODS selection_screen REDEFINITION.` INTO TABLE lt_code.
    IF lt_modif IS NOT INITIAL.
      INSERT `    METHODS at_selection_screen_output REDEFINITION.` INTO TABLE lt_code.
    ENDIF.
    INSERT `    METHODS start_of_selection REDEFINITION.` INTO TABLE lt_code.
    IF lt_ucomm IS NOT INITIAL.
      INSERT `    METHODS at_user_command REDEFINITION.` INTO TABLE lt_code.
    ENDIF.
    INSERT `` INTO TABLE lt_code.
    INSERT `  PRIVATE SECTION.` INTO TABLE lt_code.
    INSERT `ENDCLASS.` INTO TABLE lt_code.
    INSERT `` INTO TABLE lt_code.
    INSERT `` INTO TABLE lt_code.
    INSERT |CLASS { lv_class } IMPLEMENTATION.| INTO TABLE lt_code.
    INSERT `` INTO TABLE lt_code.

    INSERT `  METHOD selection_screen.` INTO TABLE lt_code.
    INSERT `` INTO TABLE lt_code.
    IF elements IS INITIAL.
      INSERT `    screen->comment( ``Add the elements of the selection screen.`` ).` INTO TABLE lt_code.
    ELSE.
      INSERT LINES OF selection_screen( elements ) INTO TABLE lt_code.
    ENDIF.
    INSERT `` INTO TABLE lt_code.
    INSERT `  ENDMETHOD.` INTO TABLE lt_code.

    IF lt_modif IS NOT INITIAL.
      INSERT `` INTO TABLE lt_code.
      INSERT `  METHOD at_selection_screen_output.` INTO TABLE lt_code.
      INSERT `` INTO TABLE lt_code.
      INSERT `    DATA(lt_screen) = screen->loop_at_screen( ).` INTO TABLE lt_code.
      INSERT `` INTO TABLE lt_code.
      INSERT `    LOOP AT lt_screen INTO DATA(ls_screen).` INTO TABLE lt_code.
      INSERT `      CASE ls_screen-group1.` INTO TABLE lt_code.
      LOOP AT lt_modif INTO lv_event.
        INSERT |        WHEN { literal( lv_event ) }.| INTO TABLE lt_code.
        INSERT `          " hide (active), make read-only (input) or required here` INTO TABLE lt_code.
        INSERT `          ls_screen-active = abap_true.` INTO TABLE lt_code.
      ENDLOOP.
      INSERT `      ENDCASE.` INTO TABLE lt_code.
      INSERT `      screen->modify_screen( ls_screen ).` INTO TABLE lt_code.
      INSERT `    ENDLOOP.` INTO TABLE lt_code.
      INSERT `` INTO TABLE lt_code.
      INSERT `  ENDMETHOD.` INTO TABLE lt_code.
    ENDIF.

    INSERT `` INTO TABLE lt_code.
    INSERT `  METHOD start_of_selection.` INTO TABLE lt_code.
    INSERT `` INTO TABLE lt_code.
    LOOP AT elements REFERENCE INTO lr_element.
      IF check_field( lr_element->kind ) = abap_false.
        CONTINUE.
      ENDIF.
      lv_name = to_lower( condense( lr_element->name ) ).
      IF lr_element->kind = cs_kind-select_option.
        INSERT |    write( \|{ lv_name }: \{ z2ui5_cl_cgui_context=>range_to_text( { lv_name } ) \}\| )->new_line( ).| INTO TABLE lt_code.
      ELSE.
        INSERT |    write( \|{ lv_name }: \{ { lv_name } \}\| )->new_line( ).| INTO TABLE lt_code.
      ENDIF.
    ENDLOOP.
    IF sy-subrc <> 0.
      INSERT `    write( ``Hello World`` ).` INTO TABLE lt_code.
    ENDIF.
    INSERT `` INTO TABLE lt_code.
    INSERT `  ENDMETHOD.` INTO TABLE lt_code.

    IF lt_ucomm IS NOT INITIAL.
      INSERT `` INTO TABLE lt_code.
      INSERT `  METHOD at_user_command.` INTO TABLE lt_code.
      INSERT `` INTO TABLE lt_code.
      INSERT `    CASE ucomm.` INTO TABLE lt_code.
      LOOP AT lt_ucomm INTO lv_event.
        INSERT |      WHEN { literal( lv_event ) }.| INTO TABLE lt_code.
        READ TABLE lt_button WITH KEY table_line = lv_event TRANSPORTING NO FIELDS.
        IF sy-subrc = 0.
          INSERT |        message( { literal( |{ lv_event } pressed| ) } ).| INTO TABLE lt_code.
        ELSE.
          INSERT `        " the selection screen is shown again - at_selection_screen_output( ) adapts it` INTO TABLE lt_code.
        ENDIF.
      ENDLOOP.
      INSERT `    ENDCASE.` INTO TABLE lt_code.
      INSERT `` INTO TABLE lt_code.
      INSERT `  ENDMETHOD.` INTO TABLE lt_code.
    ENDIF.

    INSERT `` INTO TABLE lt_code.
    INSERT `ENDCLASS.` INTO TABLE lt_code.

    result = concat_lines_of( table = lt_code
                              sep   = cl_abap_char_utilities=>newline ).

  ENDMETHOD.

  METHOD type_tokens.

    DATA lv_spec TYPE string.

    lv_spec = to_lower( condense( spec ) ).
    IF lv_spec IS INITIAL.
      RETURN.
    ENDIF.
    SPLIT lv_spec AT ` ` INTO TABLE result.
    DELETE result WHERE table_line IS INITIAL.

  ENDMETHOD.

  METHOD type_normalize.

    " lower case like the rest of the generated code, the keywords upper
    DATA(lt_token) = type_tokens( spec ).
    LOOP AT lt_token ASSIGNING FIELD-SYMBOL(<token>) WHERE table_line = `length` OR table_line = `decimals`.
      <token> = to_upper( <token> ).
    ENDLOOP.

    result = concat_lines_of( table = lt_token
                              sep   = ` ` ).

  ENDMETHOD.

  METHOD check_type_named.

    DATA(lt_token) = type_tokens( spec ).

    IF lines( lt_token ) <> 1.
      RETURN.
    ENDIF.

    CASE lt_token[ 1 ].
      WHEN `c` OR `n` OR `x` OR `p`.
        result = abap_false.
      WHEN OTHERS.
        result = abap_true.
    ENDCASE.

  ENDMETHOD.

  METHOD type_create.

    DATA lv_length   TYPE i.
    DATA lv_decimals TYPE i.
    DATA lv_name     TYPE string.

    DATA(lt_token) = type_tokens( spec ).
    IF lt_token IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        CASE lt_token[ 1 ].

          WHEN `c` OR `n` OR `x` OR `p`.
            " c LENGTH 10, p LENGTH 8 DECIMALS 2 - and nothing else
            lv_length = COND #( WHEN lt_token[ 1 ] = `p` THEN 8 ELSE 1 ).
            CASE lines( lt_token ).
              WHEN 1.
              WHEN 3 OR 5.
                IF lt_token[ 2 ] <> `length` OR lt_token[ 3 ] CN `0123456789`.
                  RETURN.
                ENDIF.
                lv_length = lt_token[ 3 ].
                IF lines( lt_token ) = 5.
                  IF lt_token[ 1 ] <> `p` OR lt_token[ 4 ] <> `decimals` OR lt_token[ 5 ] CN `0123456789`.
                    RETURN.
                  ENDIF.
                  lv_decimals = lt_token[ 5 ].
                ENDIF.
              WHEN OTHERS.
                RETURN.
            ENDCASE.
            IF lv_length < 1 OR lv_length > 255 OR ( lt_token[ 1 ] = `p` AND ( lv_length > 16 OR lv_decimals > 14 ) ).
              RETURN.
            ENDIF.

            CASE lt_token[ 1 ].
              WHEN `c`.
                CREATE DATA result TYPE c LENGTH lv_length.
              WHEN `n`.
                CREATE DATA result TYPE n LENGTH lv_length.
              WHEN `x`.
                CREATE DATA result TYPE x LENGTH lv_length.
              WHEN `p`.
                CREATE DATA result TYPE p LENGTH lv_length DECIMALS lv_decimals.
            ENDCASE.

          WHEN OTHERS.
            IF lines( lt_token ) <> 1.
              RETURN.
            ENDIF.
            CASE lt_token[ 1 ].
              WHEN `string`.
                CREATE DATA result TYPE string.
              WHEN `xstring`.
                CREATE DATA result TYPE xstring.
              WHEN `i`.
                CREATE DATA result TYPE i.
              WHEN `int8`.
                CREATE DATA result TYPE int8.
              WHEN `d`.
                CREATE DATA result TYPE d.
              WHEN `t`.
                CREATE DATA result TYPE t.
              WHEN `f`.
                CREATE DATA result TYPE f.
              WHEN `decfloat34`.
                CREATE DATA result TYPE decfloat34.
              WHEN `abap_bool`.
                CREATE DATA result TYPE abap_bool.
              WHEN OTHERS.
                " a DDIC type
                lv_name = to_upper( lt_token[ 1 ] ).
                CREATE DATA result TYPE (lv_name).
            ENDCASE.

        ENDCASE.

        IF cl_abap_typedescr=>describe_by_data_ref( result )->kind <> cl_abap_typedescr=>kind_elem.
          CLEAR result.
        ENDIF.

      CATCH cx_root.
        CLEAR result.
    ENDTRY.

  ENDMETHOD.

  METHOD range_create.

    DATA lv_sign   TYPE c LENGTH 1.
    DATA lv_option TYPE c LENGTH 2.
    DATA lt_comp   TYPE cl_abap_structdescr=>component_table.

    DATA(lr_low) = type_create( spec ).
    IF lr_low IS NOT BOUND.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_low) = CAST cl_abap_datadescr( cl_abap_typedescr=>describe_by_data_ref( lr_low ) ).
        lt_comp = VALUE #( ( name = `SIGN`   type = CAST #( cl_abap_typedescr=>describe_by_data( lv_sign ) ) )
                           ( name = `OPTION` type = CAST #( cl_abap_typedescr=>describe_by_data( lv_option ) ) )
                           ( name = `LOW`    type = lo_low )
                           ( name = `HIGH`   type = lo_low ) ).
        DATA(lo_table) = cl_abap_tabledescr=>create( cl_abap_structdescr=>create( lt_comp ) ).
        CREATE DATA result TYPE HANDLE lo_table.
      CATCH cx_root.
        CLEAR result.
    ENDTRY.

  ENDMETHOD.

  METHOD literal.

    " a backtick inside a text literal is written twice
    result = replace( val = |{ val }| sub = |`| with = |``| occ = 0 ).
    result = |`{ result }`|.

  ENDMETHOD.

  METHOD pad.

    result = val.
    IF strlen( result ) < width.
      result = result && repeat( val = ` `
                                 occ = width - strlen( result ) ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
