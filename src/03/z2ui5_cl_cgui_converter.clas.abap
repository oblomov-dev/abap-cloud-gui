"! Converter - turns the source of a classic report into a report class of
"! the cloud gui (z2ui5_cl_cgui_report). What it translates:
"!   PARAMETERS, SELECT-OPTIONS and SELECTION-SCREEN (blocks, lines,
"!   comments, pushbuttons, SKIP, ULINE, tabbed blocks with their subscreens,
"!   screens AS WINDOW) - into selection_screen( ) and the attributes
"!   DEFAULT values - into initialization( )
"!   the event blocks - into the methods of the report runtime
"!   FORMs - into methods, PERFORMs into their calls
"!   WRITE, FORMAT, ULINE, SKIP, NEW-LINE, NEW-PAGE, HIDE - into the list
"!   MESSAGE, SET/GET PARAMETER ID, LOOP AT SCREEN, MODIFY SCREEN,
"!   LEAVE LIST-PROCESSING, CALL SELECTION-SCREEN, sy-ucomm, sy-lsind
"! Everything else is taken over as it is. What needs a look by hand is
"! listed in the notes of the result - the class is a start, not the end.
"! convert_program( ) reads a report of the system with its includes and
"! its text pool: selection texts become the texts of the fields, text
"! symbols literals.
CLASS z2ui5_cl_cgui_converter DEFINITION PUBLIC FINAL CREATE PRIVATE.

  PUBLIC SECTION.

    "! an entry of the text pool - id I text symbol, S selection text
    TYPES:
      BEGIN OF ty_s_text,
        id    TYPE string,
        key   TYPE string,
        entry TYPE string,
      END OF ty_s_text.
    TYPES ty_t_text TYPE STANDARD TABLE OF ty_s_text WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_result,
        code  TYPE string,
        notes TYPE string_table,
      END OF ty_s_result.

    "! a statement of the source: raw as written, with the comments in
    "! front of it, code without comments and with single blanks
    TYPES:
      BEGIN OF ty_s_stmt,
        raw  TYPE string,
        code TYPE string,
      END OF ty_s_stmt.
    TYPES ty_t_stmt TYPE STANDARD TABLE OF ty_s_stmt WITH EMPTY KEY.

    CLASS-METHODS convert
      IMPORTING
        source        TYPE string_table
        class         TYPE clike DEFAULT `zcl_my_report`
        texts         TYPE ty_t_text OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! the report program of the system, with its includes and text pool
    CLASS-METHODS convert_program
      IMPORTING
        program       TYPE clike
        class         TYPE clike OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! the source in statements - the period ends one, a chain stays one
    CLASS-METHODS split
      IMPORTING
        source        TYPE string_table
      RETURNING
        VALUE(result) TYPE ty_t_stmt.

    "! a chained statement as single statements - a: b, c becomes a b, a c
    CLASS-METHODS chain_expand
      IMPORTING
        code          TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

    "! the words of a statement, a literal one word
    CLASS-METHODS tokens
      IMPORTING
        code          TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_s_param,
        name  TYPE string,
        value TYPE string,
      END OF ty_s_param.
    TYPES ty_t_param TYPE STANDARD TABLE OF ty_s_param WITH EMPTY KEY.

    " a call on the screen object - screen is the dynnr it belongs to,
    " empty for the selection screen of the report
    TYPES:
      BEGIN OF ty_s_item,
        screen    TYPE string,
        method    TYPE string,
        field     TYPE string,
        params    TYPE ty_t_param,
        subscreen TYPE string,
      END OF ty_s_item.
    TYPES ty_t_item TYPE STANDARD TABLE OF ty_s_item WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_event,
        method TYPE string,
        key    TYPE string,
        lines  TYPE string_table,
      END OF ty_s_event.
    TYPES ty_t_event TYPE STANDARD TABLE OF ty_s_event WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_form_param,
        kind TYPE c LENGTH 1,
        name TYPE string,
        type TYPE string,
      END OF ty_s_form_param.
    TYPES ty_t_form_param TYPE STANDARD TABLE OF ty_s_form_param WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_form,
        name   TYPE string,
        params TYPE ty_t_form_param,
        lines  TYPE string_table,
      END OF ty_s_form.
    TYPES ty_t_form TYPE STANDARD TABLE OF ty_s_form WITH EMPTY KEY.

    DATA mt_text      TYPE ty_t_text.
    DATA mt_note      TYPE string_table.
    DATA mt_public    TYPE string_table.
    DATA mt_field     TYPE string_table.
    DATA mt_global    TYPE string_table.
    DATA mt_item      TYPE ty_t_item.
    DATA mt_init      TYPE string_table.
    DATA mt_event     TYPE ty_t_event.
    DATA mt_form      TYPE ty_t_form.
    DATA mt_local     TYPE string_table.
    DATA mt_window    TYPE string_table.
    DATA mt_tabbed    TYPE string_table.
    DATA mt_help      TYPE string_table.
    DATA mt_subscreen TYPE string_table.
    DATA mv_screen    TYPE string.
    DATA mv_msgid     TYPE string.
    DATA mv_color     TYPE string.
    DATA mv_hotspot   TYPE abap_bool.
    DATA mv_intensified TYPE abap_bool.
    DATA mv_inverse   TYPE abap_bool.
    DATA mv_input     TYPE abap_bool.
    " the fields WRITE ... UNDER refers to, the blocks with ON BLOCK
    DATA mt_under     TYPE string_table.
    DATA mt_on_block  TYPE string_table.
    " the references CL_SALV_TABLE=>FACTORY returned - their display( ) goes
    DATA mt_salv      TYPE string_table.
    DATA mt_salv_event TYPE string_table.
    " CL_GUI_ALV_GRID: the grids, the containers of the SAP GUI and the
    " PBO modules that became methods (upper case / method names)
    DATA mt_grid      TYPE string_table.
    DATA mt_container TYPE string_table.
    DATA mt_pbo       TYPE string_table.
    " the tables an ALV shows - after the run, so they must not be cleared
    DATA mt_alv_tab   TYPE string_table.
    " the code that opens start_of_selection( ) - LINE-SIZE, LINE-COUNT
    DATA mt_start     TYPE string_table.

    METHODS run
      IMPORTING
        source        TYPE string_table
        class         TYPE clike
      RETURNING
        VALUE(result) TYPE ty_s_result.

    METHODS note
      IMPORTING
        val TYPE string.

    METHODS forms_collect
      IMPORTING
        stmts TYPE ty_t_stmt.

    METHODS form_signature
      IMPORTING
        code          TYPE string
      RETURNING
        VALUE(result) TYPE ty_s_form.

    METHODS event_of
      IMPORTING
        code   TYPE string
      EXPORTING
        method TYPE string
        key    TYPE string
        found  TYPE abap_bool.

    METHODS lines_add
      IMPORTING
        method TYPE string
        key    TYPE string
        form   TYPE string
        lines  TYPE string_table.

    METHODS declaration
      IMPORTING
        stmt TYPE ty_s_stmt.

    METHODS parameters
      IMPORTING
        code TYPE string.

    METHODS select_options
      IMPORTING
        code TYPE string.

    METHODS selection_screen
      IMPORTING
        code TYPE string.

    METHODS item_add
      IMPORTING
        method    TYPE string
        field     TYPE string    OPTIONAL
        params    TYPE ty_t_param OPTIONAL
        subscreen TYPE string    OPTIONAL.

    METHODS body
      IMPORTING
        stmt          TYPE ty_s_stmt
        method        TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

    METHODS body_converted
      IMPORTING
        stmt          TYPE ty_s_stmt
        method        TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

    METHODS write
      IMPORTING
        code          TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

    METHODS format
      IMPORTING
        code TYPE string.

    METHODS message
      IMPORTING
        code          TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

    METHODS perform
      IMPORTING
        code          TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

    METHODS raw_lines
      IMPORTING
        raw           TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

    "! DATA x(10) TYPE c - the obsolete length as LENGTH
    CLASS-METHODS length_normalize
      IMPORTING
        code          TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! the lines of a block without the indentation they share
    CLASS-METHODS dedent
      IMPORTING
        lines         TYPE string_table
      RETURNING
        VALUE(result) TYPE string_table.

    CLASS-METHODS lead
      IMPORTING
        lines         TYPE string_table
      RETURNING
        VALUE(result) TYPE string.

    "! TEXT-xxx and 'literal'(xxx) as literals of the text pool
    METHODS texts_resolve
      IMPORTING
        code          TYPE string
      RETURNING
        VALUE(result) TYPE string.

    METHODS text_expr
      IMPORTING
        token         TYPE string
        length        TYPE i DEFAULT 70
      RETURNING
        VALUE(result) TYPE string.

    METHODS selection_text
      IMPORTING
        name          TYPE string
      RETURNING
        VALUE(result) TYPE string.

    METHODS type_of_for
      IMPORTING
        target        TYPE string
      RETURNING
        VALUE(result) TYPE string.

    METHODS global_add
      IMPORTING
        name TYPE string
        decl TYPE string.

    METHODS generate
      IMPORTING
        class         TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

    METHODS items_code
      IMPORTING
        screen        TYPE string
        indent        TYPE i
      RETURNING
        VALUE(result) TYPE string_table.

    METHODS call_code
      IMPORTING
        prefix        TYPE string
        params        TYPE ty_t_param
      RETURNING
        VALUE(result) TYPE string_table.

    "! an operand as written in a classic statement as cgui code: a literal
    "! as text literal, a field name in lower case
    CLASS-METHODS operand
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! the classic date format addition as cs_date_format component
    CLASS-METHODS date_format_of
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! the statements of lists that came with R11 - empty when code is none
    TYPES:
      BEGIN OF ty_s_fparam,
        section TYPE string,
        name    TYPE string,
        value   TYPE string,
      END OF ty_s_fparam.
    TYPES ty_t_fparam TYPE STANDARD TABLE OF ty_s_fparam WITH EMPTY KEY.

    "! the parameters of CALL FUNCTION - section, name, value as written
    CLASS-METHODS function_params
      IMPORTING
        code          TYPE string
      RETURNING
        VALUE(result) TYPE ty_t_fparam.

    "! CALL FUNCTION of an ALV, a popup or a value help as call of the report
    "! - empty: not one of them
    METHODS call_function
      IMPORTING
        code          TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

    "! CL_SALV_TABLE=>FACTORY and its display( ) - empty: not one of them
    METHODS salv_statement
      IMPORTING
        code          TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

    " CL_GUI_ALV_GRID and its containers - initial when code is none of it
    METHODS grid_statement
      IMPORTING
        code          TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

    " the method of the PBO module module
    CLASS-METHODS pbo_name
      IMPORTING
        module        TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    METHODS list_statement
      IMPORTING
        code          TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

    "! the parameter of a keyed event method - field, block or group
    CLASS-METHODS event_param
      IMPORTING
        method        TYPE string
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS literal
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS unquote
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS indent
      IMPORTING
        lines         TYPE string_table
        by            TYPE i
      RETURNING
        VALUE(result) TYPE string_table.

    CLASS-METHODS tok
      IMPORTING
        tokens        TYPE string_table
        index         TYPE i
      RETURNING
        VALUE(result) TYPE string.

    "! the index of word in tokens, in any case - 0 when it is not there
    CLASS-METHODS tok_index
      IMPORTING
        tokens        TYPE string_table
        word          TYPE string
      RETURNING
        VALUE(result) TYPE i.

ENDCLASS.


CLASS z2ui5_cl_cgui_converter IMPLEMENTATION.

  METHOD convert.

    DATA(lo_conv) = NEW z2ui5_cl_cgui_converter( ).
    lo_conv->mt_text = texts.
    result = lo_conv->run( source = source
                           class  = class ).

  ENDMETHOD.

  METHOD convert_program.

    " READ REPORT and READ TEXTPOOL - on premise only
    DATA lt_src     TYPE string_table.
    DATA lt_code    TYPE STANDARD TABLE OF char255 WITH EMPTY KEY.
    DATA lt_include TYPE STANDARD TABLE OF char255 WITH EMPTY KEY.
    DATA lt_pool    TYPE STANDARD TABLE OF textpool WITH EMPTY KEY.
    DATA lt_text    TYPE ty_t_text.
    DATA lv_name    TYPE c LENGTH 40.
    DATA lv_include TYPE c LENGTH 40.

    lv_name = to_upper( program ).
    READ REPORT lv_name INTO lt_code.
    IF sy-subrc <> 0.
      INSERT replace( val = 'Program &1 not found' sub = `&1` with = lv_name ) INTO TABLE result-notes ##NO_TEXT.
      RETURN.
    ENDIF.

    " the includes of the program in place of their INCLUDE statement
    LOOP AT lt_code INTO DATA(lv_line).
      DATA(lv_upper) = to_upper( condense( lv_line ) ).
      CLEAR lv_include.
      FIND PCRE `^INCLUDE\s+([A-Z0-9_/]+)\s*\.\s*$` IN lv_upper SUBMATCHES lv_include.
      IF sy-subrc = 0 AND lv_include <> 'STRUCTURE' AND lv_include <> 'TYPE'.
        CLEAR lt_include.
        READ REPORT lv_include INTO lt_include.
        IF sy-subrc = 0.
          INSERT |* include { to_lower( lv_include ) }| INTO TABLE lt_src.
          LOOP AT lt_include INTO DATA(lv_inc_line).
            INSERT CONV string( lv_inc_line ) INTO TABLE lt_src.
          ENDLOOP.
          CONTINUE.
        ENDIF.
      ENDIF.
      INSERT CONV string( lv_line ) INTO TABLE lt_src.
    ENDLOOP.

    READ TEXTPOOL lv_name INTO lt_pool LANGUAGE sy-langu.
    IF lt_pool IS INITIAL.
      READ TEXTPOOL lv_name INTO lt_pool LANGUAGE 'E'.
    ENDIF.
    LOOP AT lt_pool INTO DATA(ls_pool).
      DATA(lv_entry) = CONV string( ls_pool-entry ).
      IF ls_pool-id = 'S'.
        " the first eight characters of a selection text are its flags - D
        " takes the label of the DDIC
        IF strlen( lv_entry ) <= 8 OR lv_entry(1) = 'D'.
          CONTINUE.
        ENDIF.
        lv_entry = condense( substring( val = lv_entry off = 8 ) ).
      ENDIF.
      INSERT VALUE #( id    = ls_pool-id
                      key   = condense( ls_pool-key )
                      entry = lv_entry ) INTO TABLE lt_text.
    ENDLOOP.

    DATA(lv_class) = CONV string( class ).
    IF lv_class IS INITIAL.
      lv_class = |zcl_{ to_lower( lv_name ) }|.
      IF strlen( lv_class ) > 30.
        lv_class = lv_class(30).
      ENDIF.
    ENDIF.
    result = convert( source = lt_src
                      class  = lv_class
                      texts  = lt_text ).

  ENDMETHOD.

  METHOD split.

    DATA lv_code  TYPE string.
    DATA lv_quote TYPE string.
    DATA lv_start TYPE i.

    DATA(lv_nl) = cl_abap_char_utilities=>newline.
    DATA(lv_src) = concat_lines_of( table = source sep = lv_nl ).
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN lv_src WITH ` `.
    REPLACE ALL OCCURRENCES OF |\r| IN lv_src WITH ``.
    DATA(lv_len) = strlen( lv_src ).
    DATA(lv_pos) = 0.

    WHILE lv_pos < lv_len.
      DATA(lv_char) = lv_src+lv_pos(1).

      IF lv_quote IS INITIAL.
        IF ( lv_char = `*` AND ( lv_pos = 0 OR substring( val = lv_src off = lv_pos - 1 len = 1 ) = lv_nl ) )
            OR lv_char = `"`.
          " a comment up to the end of the line
          FIND lv_nl IN SECTION OFFSET lv_pos OF lv_src MATCH OFFSET DATA(lv_eol).
          IF sy-subrc <> 0.
            lv_pos = lv_len.
          ELSE.
            lv_pos = lv_eol.
          ENDIF.
          CONTINUE.
        ENDIF.
        CASE lv_char.
          WHEN `'` OR '`' OR `|`.
            lv_quote = lv_char.
            lv_code = lv_code && lv_char.
          WHEN `.`.
            DATA(lv_stmt) = condense( lv_code ).
            IF lv_stmt IS NOT INITIAL.
              INSERT VALUE #( raw  = substring( val = lv_src off = lv_start len = lv_pos - lv_start )
                              code = lv_stmt ) INTO TABLE result.
            ENDIF.
            CLEAR lv_code.
            lv_start = lv_pos + 1.
          WHEN lv_nl OR ` `.
            IF lv_code IS NOT INITIAL AND substring( val = lv_code off = strlen( lv_code ) - 1 len = 1 ) <> ` `.
              lv_code = lv_code && ` `.
            ENDIF.
          WHEN OTHERS.
            lv_code = lv_code && lv_char.
        ENDCASE.
      ELSE.
        lv_code = lv_code && lv_char.
        IF lv_quote = `|` AND lv_char = `\` AND lv_pos + 1 < lv_len.
          lv_pos = lv_pos + 1.
          lv_code = lv_code && lv_src+lv_pos(1).
        ELSEIF lv_char = lv_quote.
          IF lv_quote <> `|` AND lv_pos + 1 < lv_len AND lv_src+lv_pos(1) = substring( val = lv_src off = lv_pos + 1 len = 1 ).
            " a doubled quote is a quote of the literal
            lv_pos = lv_pos + 1.
            lv_code = lv_code && lv_char.
          ELSE.
            CLEAR lv_quote.
          ENDIF.
        ENDIF.
      ENDIF.
      lv_pos = lv_pos + 1.
    ENDWHILE.

    lv_stmt = condense( lv_code ).
    IF lv_stmt IS NOT INITIAL.
      INSERT VALUE #( raw  = substring( val = lv_src off = lv_start )
                      code = lv_stmt ) INTO TABLE result.
    ENDIF.

  ENDMETHOD.

  METHOD tokens.

    DATA lv_token TYPE string.
    DATA lv_quote TYPE string.

    DATA(lv_len) = strlen( code ).
    DATA(lv_pos) = 0.
    WHILE lv_pos < lv_len.
      DATA(lv_char) = code+lv_pos(1).
      IF lv_quote IS INITIAL AND lv_char = ` `.
        IF lv_token IS NOT INITIAL.
          INSERT lv_token INTO TABLE result.
          CLEAR lv_token.
        ENDIF.
      ELSE.
        lv_token = lv_token && lv_char.
        IF lv_quote IS INITIAL AND ( lv_char = `'` OR lv_char = '`' OR lv_char = `|` ).
          lv_quote = lv_char.
        ELSEIF lv_quote IS NOT INITIAL AND lv_char = lv_quote.
          CLEAR lv_quote.
        ENDIF.
      ENDIF.
      lv_pos = lv_pos + 1.
    ENDWHILE.
    IF lv_token IS NOT INITIAL.
      INSERT lv_token INTO TABLE result.
    ENDIF.

  ENDMETHOD.

  METHOD chain_expand.

    DATA lv_quote TYPE string.
    DATA lv_depth TYPE i.
    DATA lv_colon TYPE i VALUE -1.
    DATA lt_part  TYPE string_table.
    DATA lv_part  TYPE string.

    DATA(lv_len) = strlen( code ).
    DATA(lv_pos) = 0.
    WHILE lv_pos < lv_len.
      DATA(lv_char) = code+lv_pos(1).
      IF lv_quote IS NOT INITIAL.
        IF lv_char = lv_quote.
          CLEAR lv_quote.
        ENDIF.
        IF lv_colon >= 0.
          lv_part = lv_part && lv_char.
        ENDIF.
      ELSEIF lv_char = `'` OR lv_char = '`' OR lv_char = `|`.
        lv_quote = lv_char.
        IF lv_colon >= 0.
          lv_part = lv_part && lv_char.
        ENDIF.
      ELSEIF lv_char = `:` AND lv_colon < 0.
        lv_colon = lv_pos.
      ELSEIF lv_colon >= 0.
        IF lv_char = `(`.
          lv_depth = lv_depth + 1.
        ELSEIF lv_char = `)`.
          lv_depth = lv_depth - 1.
        ENDIF.
        IF lv_char = `,` AND lv_depth = 0.
          INSERT condense( lv_part ) INTO TABLE lt_part.
          CLEAR lv_part.
        ELSE.
          lv_part = lv_part && lv_char.
        ENDIF.
      ENDIF.
      lv_pos = lv_pos + 1.
    ENDWHILE.

    IF lv_colon < 0.
      INSERT code INTO TABLE result.
      RETURN.
    ENDIF.
    INSERT condense( lv_part ) INTO TABLE lt_part.

    DATA(lv_prefix) = condense( substring( val = code len = lv_colon ) ).
    LOOP AT lt_part INTO lv_part WHERE table_line IS NOT INITIAL.
      INSERT condense( |{ lv_prefix } { lv_part }| ) INTO TABLE result.
    ENDLOOP.

  ENDMETHOD.

  METHOD tok.

    READ TABLE tokens INTO result INDEX index.

  ENDMETHOD.

  METHOD tok_index.

    LOOP AT tokens INTO DATA(lv_token).
      IF to_upper( lv_token ) = word.
        result = sy-tabix.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD note.

    IF NOT line_exists( mt_note[ table_line = val ] ).
      INSERT val INTO TABLE mt_note.
    ENDIF.

  ENDMETHOD.

  METHOD operand.

    IF val IS INITIAL.
      RETURN.
    ENDIF.
    IF val(1) = `'`.
      result = literal( unquote( val ) ).
    ELSEIF val(1) = '`' OR val(1) = `|` OR val CO `0123456789-`.
      result = val.
    ELSE.
      result = to_lower( val ).
    ENDIF.

  ENDMETHOD.

  METHOD date_format_of.

    result = |z2ui5_cl_cgui_list=>cs_date_format-{ SWITCH string( val
        WHEN `DD/MM/YY`   THEN `dd_mm_yy`
        WHEN `MM/DD/YY`   THEN `mm_dd_yy`
        WHEN `DD/MM/YYYY` THEN `dd_mm_yyyy`
        WHEN `MM/DD/YYYY` THEN `mm_dd_yyyy`
        WHEN `DDMMYY`     THEN `ddmmyy`
        WHEN `MMDDYY`     THEN `mmddyy`
        ELSE `yymmdd` ) }|.

  ENDMETHOD.

  METHOD event_param.

    result = SWITCH #( method
                       WHEN `at_selection_screen_on_block` THEN `block`
                       WHEN `at_selection_screen_on_radio` THEN `group`
                       ELSE `field` ).

  ENDMETHOD.

  METHOD function_params.

    DATA(lt_tok) = tokens( code ).
    DATA(lv_section) = ``.
    DATA(lv_index) = 4.
    WHILE lv_index <= lines( lt_tok ).
      DATA(lv_word) = to_upper( lt_tok[ lv_index ] ).
      IF lv_word = `EXPORTING` OR lv_word = `IMPORTING` OR lv_word = `TABLES`
          OR lv_word = `CHANGING` OR lv_word = `EXCEPTIONS`.
        lv_section = lv_word.
      ELSEIF lv_index + 2 <= lines( lt_tok ) AND lt_tok[ lv_index + 1 ] = `=`.
        INSERT VALUE #( section = lv_section
                        name    = lv_word
                        value   = lt_tok[ lv_index + 2 ] ) INTO TABLE result.
        lv_index = lv_index + 2.
      ENDIF.
      lv_index = lv_index + 1.
    ENDWHILE.

  ENDMETHOD.

  METHOD call_function.

    DATA(lv_name) = to_upper( unquote( tok( tokens = tokens( code ) index = 3 ) ) ).
    DATA(lt_param) = function_params( code ).

    CASE lv_name.

      WHEN `REUSE_ALV_GRID_DISPLAY` OR `REUSE_ALV_LIST_DISPLAY` OR `REUSE_ALV_GRID_DISPLAY_LVC`.
        DATA(lv_tab) = VALUE string( lt_param[ name = `T_OUTTAB` ]-value OPTIONAL ).
        IF lv_tab IS INITIAL.
          RETURN.
        ENDIF.
        INSERT to_upper( replace( val = lv_tab sub = `[]` with = `` ) ) INTO TABLE mt_alv_tab.
        DATA(lv_call) = |alv( { to_lower( lv_tab ) } )|.
        DATA(lv_title) = VALUE string( lt_param[ name = `I_GRID_TITLE` ]-value OPTIONAL ).
        IF lv_title IS NOT INITIAL.
          lv_call = |{ lv_call }->set_title( { operand( texts_resolve( lv_title ) ) } )|.
        ENDIF.
        INSERT |{ lv_call }| INTO TABLE result.
        " field catalog, layout and sort as the classic structures
        LOOP AT VALUE string_table( ( `IT_FIELDCAT` ) ( `IT_FIELDCAT_LVC` ) ) INTO DATA(lv_classic).
          DATA(lv_value) = VALUE string( lt_param[ name = lv_classic ]-value OPTIONAL ).
          IF lv_value IS NOT INITIAL.
            INSERT |    ->set_fieldcat( { to_lower( lv_value ) } )| INTO TABLE result.
          ENDIF.
        ENDLOOP.
        LOOP AT VALUE string_table( ( `IS_LAYOUT` ) ( `IS_LAYOUT_LVC` ) ) INTO lv_classic.
          lv_value = VALUE string( lt_param[ name = lv_classic ]-value OPTIONAL ).
          IF lv_value IS NOT INITIAL.
            INSERT |    ->set_layout_classic( { to_lower( lv_value ) } )| INTO TABLE result.
          ENDIF.
        ENDLOOP.
        LOOP AT VALUE string_table( ( `IT_SORT` ) ( `IT_SORT_LVC` ) ) INTO lv_classic.
          lv_value = VALUE string( lt_param[ name = lv_classic ]-value OPTIONAL ).
          IF lv_value IS NOT INITIAL.
            INSERT |    ->set_sort_classic( { to_lower( lv_value ) } )| INTO TABLE result.
          ENDIF.
        ENDLOOP.
        result[ lines( result ) ] = |{ result[ lines( result ) ] }.|.
        LOOP AT lt_param INTO DATA(ls_param).
          CASE ls_param-name.
            WHEN `I_CALLBACK_USER_COMMAND`.
              note( |{ lv_name }: the form of I_CALLBACK_USER_COMMAND becomes at_user_command( ucomm ); a double click or hotspot (&IC1) arrives in at_link_click( row column )| ) ##NO_TEXT.
            WHEN `I_CALLBACK_PF_STATUS_SET`.
              note( |{ lv_name }: the own status becomes alv( )->add_function( name text icon ) per function| ) ##NO_TEXT.
            WHEN `I_CALLBACK_TOP_OF_PAGE` OR `I_CALLBACK_HTML_TOP_OF_PAGE`.
              note( |{ lv_name }: the header of the grid - write it in top_of_page( ) or give it to alv( )->set_title( )| ) ##NO_TEXT.
            WHEN `IS_VARIANT` OR `I_SAVE`.
              note( |{ lv_name }: layouts are kept with the layout dialog of the grid - set_layout( ) / get_layout( )| ) ##NO_TEXT.
          ENDCASE.
        ENDLOOP.

      WHEN `POPUP_TO_CONFIRM`.
        DATA(lv_question) = VALUE string( lt_param[ name = `TEXT_QUESTION` ]-value OPTIONAL ).
        IF lv_question IS INITIAL.
          RETURN.
        ENDIF.
        lv_title = VALUE string( lt_param[ name = `TITLEBAR` ]-value OPTIONAL ).
        lv_call = |popup_to_confirm( question = { operand( texts_resolve( lv_question ) ) }|.
        IF lv_title IS NOT INITIAL.
          lv_call = |{ lv_call } title = { operand( texts_resolve( lv_title ) ) }|.
        ENDIF.
        INSERT |{ lv_call } ucomm = `POPUP_TO_CONFIRM` ).| INTO TABLE result.
        DATA(lv_answer) = VALUE string( lt_param[ name = `ANSWER` ]-value OPTIONAL ).
        note( |POPUP_TO_CONFIRM: the answer comes in at_user_command( `POPUP_TO_CONFIRM` ) - { COND #( WHEN lv_answer IS NOT INITIAL THEN to_lower( lv_answer ) ELSE `answer` ) }| &&
              | = popup_answer( ) ('1' yes, '2' no, 'A' cancel); move the code after the call there| ) ##NO_TEXT.

      WHEN `POPUP_TO_DECIDE`.
        DATA(lv_text) = ``.
        LOOP AT lt_param INTO ls_param WHERE name CP `TEXTLINE*`.
          lv_text = COND #( WHEN lv_text IS INITIAL THEN operand( texts_resolve( ls_param-value ) )
                            ELSE |{ lv_text } && ` ` && { operand( texts_resolve( ls_param-value ) ) }| ).
        ENDLOOP.
        DATA(lv_option1) = VALUE string( lt_param[ name = `TEXT_OPTION1` ]-value OPTIONAL ).
        DATA(lv_option2) = VALUE string( lt_param[ name = `TEXT_OPTION2` ]-value OPTIONAL ).
        IF lv_text IS INITIAL OR lv_option1 IS INITIAL OR lv_option2 IS INITIAL.
          RETURN.
        ENDIF.
        lv_title = VALUE string( lt_param[ name = `TITEL` ]-value OPTIONAL ).
        INSERT |popup_to_decide( question = { lv_text }| INTO TABLE result.
        INSERT |                 options  = VALUE #( ( CONV #( { operand( texts_resolve( lv_option1 ) ) } ) ) ( CONV #( { operand( texts_resolve( lv_option2 ) ) } ) ) )| INTO TABLE result.
        IF lv_title IS NOT INITIAL.
          INSERT |                 title    = { operand( texts_resolve( lv_title ) ) }| INTO TABLE result.
        ENDIF.
        INSERT |                 ucomm    = `POPUP_TO_DECIDE` ).| INTO TABLE result.
        note( |POPUP_TO_DECIDE: the answer comes in at_user_command( `POPUP_TO_DECIDE` ) as popup_answer( ) ('1', '2', 'A' cancel); move the code after the call there| ) ##NO_TEXT.

      WHEN `F4IF_INT_TABLE_VALUE_REQUEST`.
        lv_tab = VALUE string( lt_param[ name = `VALUE_TAB` ]-value OPTIONAL ).
        IF lv_tab IS INITIAL.
          RETURN.
        ENDIF.
        DATA(lv_field) = VALUE string( lt_param[ name = `RETFIELD` ]-value OPTIONAL ).
        lv_call = |value_help_popup( tab = { to_lower( lv_tab ) }|.
        IF lv_field IS NOT INITIAL.
          lv_call = |{ lv_call } col = { operand( to_upper( lv_field ) ) }|.
        ENDIF.
        lv_title = VALUE string( lt_param[ name = `WINDOW_TITLE` ]-value OPTIONAL ).
        IF lv_title IS NOT INITIAL.
          lv_call = |{ lv_call } title = { operand( texts_resolve( lv_title ) ) }|.
        ENDIF.
        INSERT |{ lv_call } ).| INTO TABLE result.
        note( `F4IF_INT_TABLE_VALUE_REQUEST: value_help_popup( ) puts the chosen value into the field itself - RETURN_TAB and DYNPFIELD are not needed` ) ##NO_TEXT.

    ENDCASE.

  ENDMETHOD.

  METHOD grid_statement.

    DATA lv_var TYPE string.
    DATA lv_tab TYPE string.

    IF mt_grid IS INITIAL AND mt_container IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_upper) = to_upper( condense( code ) ).

    IF lv_upper CS `CL_GUI_CFW=>FLUSH`.
      INSERT |" { condense( code ) }. - no frontend to flush| INTO TABLE result.
      RETURN.
    ENDIF.

    " the creation: CREATE OBJECT v ... / v = NEW ...( ... )
    CLEAR lv_var.
    FIND PCRE `^CREATE\s+OBJECT\s+([A-Z0-9_/]+)` IN lv_upper SUBMATCHES lv_var.
    IF sy-subrc <> 0.
      FIND PCRE `^([A-Z0-9_/]+)\s*=\s*NEW\s` IN lv_upper SUBMATCHES lv_var.
    ENDIF.
    IF lv_var IS NOT INITIAL AND line_exists( mt_grid[ table_line = lv_var ] ).
      INSERT |{ to_lower( lv_var ) } = z2ui5_cl_cgui_grid=>factory( report = me ).| INTO TABLE result.
      note( |CL_GUI_ALV_GRID: { to_lower( lv_var ) } is a z2ui5_cl_cgui_grid now - set_table_for_first_display( ) shows the table as ALV| &&
            | of the report, with field catalog, layout and sort; refresh_table_display( ) is not needed| ) ##NO_TEXT.
      RETURN.
    ENDIF.
    IF lv_var IS NOT INITIAL AND line_exists( mt_container[ table_line = lv_var ] ).
      INSERT |" { condense( code ) }. - a container of the SAP GUI, the grid needs none| INTO TABLE result.
      note( `Containers of the SAP GUI (CL_GUI_CUSTOM_CONTAINER, CL_GUI_DOCKING_CONTAINER, ...) have no counterpart - their calls are comments` ) ##NO_TEXT.
      RETURN.
    ENDIF.

    " a call on a container, or what a container returns
    LOOP AT mt_container INTO DATA(lv_container).
      IF lv_upper CP |{ lv_container }->*| OR lv_upper CP |CALL METHOD { lv_container }->*|
          OR lv_upper CP |*= { lv_container }->*| OR lv_upper CP |FREE { lv_container }*|.
        INSERT |" { condense( code ) }.| INTO TABLE result.
        RETURN.
      ENDIF.
    ENDLOOP.

    " the table of the grid - CLEAR it after the display empties the ALV
    IF lv_upper CS `SET_TABLE_FOR_FIRST_DISPLAY`.
      FIND PCRE `IT_OUTTAB\s*=\s*([^\s)]+)` IN lv_upper SUBMATCHES lv_tab.
      IF sy-subrc = 0.
        INSERT replace( val = lv_tab sub = `[]` with = `` ) INTO TABLE mt_alv_tab.
      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD salv_statement.

    DATA lv_ref TYPE string.
    DATA lv_tab TYPE string.

    DATA(lv_upper) = to_upper( condense( code ) ).
    IF lv_upper CP `CL_SALV_TABLE=>FACTORY(*`.
      FIND PCRE `T_TABLE\s*=\s*([^\s)]+)` IN lv_upper SUBMATCHES lv_tab.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      FIND PCRE `R_SALV_TABLE\s*=\s*([^\s)]+)` IN lv_upper SUBMATCHES lv_ref.
      IF sy-subrc <> 0.
        INSERT |alv( { to_lower( lv_tab ) } ).| INTO TABLE result.
        RETURN.
      ENDIF.
      INSERT lv_ref INTO TABLE mt_salv.
      INSERT replace( val = lv_tab sub = `[]` with = `` ) INTO TABLE mt_alv_tab.
      " the SALV object on the ALV of the report - its calls stay as they are
      INSERT |{ to_lower( lv_ref ) } = z2ui5_cl_cgui_salv=>factory( alv    = alv( { to_lower( lv_tab ) } )| INTO TABLE result.
      INSERT |{ repeat( val = ` ` occ = strlen( lv_ref ) ) }                               report = me ).| INTO TABLE result.
      note( |CL_SALV_TABLE: { to_lower( lv_ref ) } is a z2ui5_cl_cgui_salv now - columns, functions, sorts, aggregations,| &&
            | display settings and selections work as before; display( ) shows the table after the run| ) ##NO_TEXT.
      RETURN.
    ENDIF.

    " the events of CL_SALV_EVENTS_TABLE: lr_events = gr->get_event( ) stays
    " (it is the z2ui5_cl_cgui_salv itself), SET HANDLER becomes set_handler( )
    IF mt_salv IS NOT INITIAL AND lv_upper CP `* = *->GET_EVENT( )`.
      INSERT to_upper( condense( substring_before( val = lv_upper sub = `=` ) ) ) INTO TABLE mt_salv_event.
      RETURN.
    ENDIF.
    IF ( mt_salv IS NOT INITIAL OR mt_grid IS NOT INITIAL ) AND lv_upper CP `SET HANDLER *`.
      DATA(lv_for) = condense( substring_after( val = code sub = ` FOR ` case = abap_false ) ).
      DATA(lv_for_upper) = to_upper( lv_for ).
      DATA(lt_target) = VALUE string_table( ).
      IF lv_for_upper CP `ALL INSTANCES*`.
        lt_target = VALUE #( FOR lv_salv IN mt_salv ( to_lower( lv_salv ) ) ).
        INSERT LINES OF VALUE string_table( FOR lv_grid IN mt_grid ( to_lower( lv_grid ) ) ) INTO TABLE lt_target.
      ELSEIF lv_for_upper CS `->GET_EVENT( )` OR line_exists( mt_salv_event[ table_line = lv_for_upper ] )
          OR line_exists( mt_grid[ table_line = lv_for_upper ] ).
        lt_target = VALUE #( ( to_lower( lv_for ) ) ).
      ELSE.
        RETURN.
      ENDIF.
      DATA(lv_handlers) = condense( substring_before( val = substring_after( val = code sub = `HANDLER` case = abap_false )
                                                      sub = ` FOR ` case = abap_false ) ).
      SPLIT lv_handlers AT space INTO TABLE DATA(lt_handler).
      DELETE lt_handler WHERE table_line IS INITIAL.
      LOOP AT lt_target INTO DATA(lv_target).
        DATA(lv_call) = lv_target.
        LOOP AT lt_handler INTO DATA(lv_handler).
          IF lv_handler CS `=>`.
            INSERT |{ lv_call }->set_handler( class  = `{ to_upper( substring_before( val = lv_handler sub = `=>` ) ) }`| INTO TABLE result.
            INSERT |{ repeat( val = ` ` occ = strlen( lv_call ) ) }               method = `{ to_upper( substring_after( val = lv_handler sub = `=>` ) ) }` ).| INTO TABLE result.
          ELSEIF lv_handler CS `->`.
            INSERT |{ lv_call }->set_handler( handler = { to_lower( substring_before( val = lv_handler sub = `->` ) ) }| INTO TABLE result.
            INSERT |{ repeat( val = ` ` occ = strlen( lv_call ) ) }               method  = `{ to_upper( substring_after( val = lv_handler sub = `->` ) ) }` ).| INTO TABLE result.
          ELSE.
            INSERT |{ lv_call }->set_handler( handler = me| INTO TABLE result.
            INSERT |{ repeat( val = ` ` occ = strlen( lv_call ) ) }               method  = `{ to_upper( lv_handler ) }` ).| INTO TABLE result.
          ENDIF.
        ENDLOOP.
      ENDLOOP.
      note( |CL_SALV_EVENTS_TABLE: SET HANDLER is set_handler( ) - DOUBLE_CLICK, LINK_CLICK and ADDED_FUNCTION reach the| &&
            | handlers as before; a handler object is created anew for each event (its attributes do not last)| ) ##NO_TEXT.
      RETURN.
    ENDIF.

  ENDMETHOD.

  METHOD list_statement.

    DATA lv_pos TYPE string.
    DATA lv_len TYPE string.
    DATA lt_param TYPE ty_t_param.

    DATA(lt_tok) = tokens( code ).
    DATA(lv_upper) = to_upper( code ).
    DATA(lv_first) = to_upper( tok( tokens = lt_tok index = 1 ) ).

    CASE lv_first.
      WHEN `ULINE`.
        " ULINE [AT] [/][pos][(len)]
        DATA(lv_index) = 2.
        IF to_upper( tok( tokens = lt_tok index = 2 ) ) = `AT`.
          lv_index = 3.
        ENDIF.
        DATA(lv_at) = tok( tokens = lt_tok index = lv_index ).
        IF lv_at IS NOT INITIAL AND lv_at(1) = `/`.
          lv_at = substring( val = lv_at off = 1 ).
        ENDIF.
        FIND PCRE `^(\d*)(?:\((\d+)\))?$` IN lv_at SUBMATCHES lv_pos lv_len.
        IF lv_pos IS NOT INITIAL.
          INSERT VALUE #( name = `pos` value = lv_pos ) INTO TABLE lt_param.
        ENDIF.
        IF lv_len IS NOT INITIAL.
          INSERT VALUE #( name = `len` value = lv_len ) INTO TABLE lt_param.
        ENDIF.
        IF lt_param IS INITIAL.
          INSERT `list( )->uline( ).` INTO TABLE result.
        ELSE.
          INSERT LINES OF call_code( prefix = `list( )->uline(`
                                     params = lt_param ) INTO TABLE result.
        ENDIF.

      WHEN `NEW-PAGE`.
        IF lv_upper CS `NO-HEADING`.
          INSERT VALUE #( name = `no_heading` value = `abap_true` ) INTO TABLE lt_param.
        ENDIF.
        DATA(lv_count) = ``.
        FIND PCRE `LINE-COUNT\s+(\S+)` IN lv_upper SUBMATCHES lv_count.
        IF lv_count IS NOT INITIAL.
          INSERT VALUE #( name = `line_count` value = operand( lv_count ) ) INTO TABLE lt_param.
        ENDIF.
        IF lt_param IS INITIAL.
          INSERT `list( )->new_page( ).` INTO TABLE result.
        ELSE.
          INSERT LINES OF call_code( prefix = `list( )->new_page(`
                                     params = lt_param ) INTO TABLE result.
        ENDIF.
        IF lv_upper CS `PRINT ON` OR lv_upper CS `PRINT OFF`.
          note( `NEW-PAGE PRINT ON: the output is printed with the Print button - Z2UI5_CGUI_PRINT` ) ##NO_TEXT.
        ELSEIF lv_upper CS `LINE-SIZE` OR lv_upper CS `NO-TITLE` OR lv_upper CS `WITH-TITLE` OR lv_upper CS `HEADING`
            AND lv_upper NS `NO-HEADING`.
          note( `NEW-PAGE: LINE-SIZE, NO-TITLE and WITH-TITLE have no counterpart - set_line_size( ) for the whole list` ) ##NO_TEXT.
        ENDIF.

      WHEN `RESERVE`.
        INSERT |list( )->reserve( { operand( tok( tokens = lt_tok index = 2 ) ) } ).| INTO TABLE result.

      WHEN `POSITION`.
        INSERT |list( )->position( { operand( tok( tokens = lt_tok index = 2 ) ) } ).| INTO TABLE result.

      WHEN `BACK`.
        INSERT |" { code }.| INTO TABLE result.
        note( `BACK has no counterpart - position with WRITE AT or UNDER` ) ##NO_TEXT.

      WHEN `WINDOW`.
        " WINDOW STARTING AT x1 y1 [ENDING AT x2 y2]
        DATA(lv_x1) = tok( tokens = lt_tok index = 4 ).
        DATA(lv_y1) = tok( tokens = lt_tok index = 5 ).
        DATA(lv_x2) = tok( tokens = lt_tok index = 8 ).
        DATA(lv_y2) = tok( tokens = lt_tok index = 9 ).
        IF lv_x2 IS INITIAL.
          INSERT `window( ).` INTO TABLE result.
        ELSEIF lv_x1 CO `0123456789` AND lv_x2 CO `0123456789` AND lv_y1 CO `0123456789` AND lv_y2 CO `0123456789`.
          INSERT LINES OF call_code( prefix = `window(`
                                     params = VALUE #( ( name = `columns` value = |{ CONV i( lv_x2 ) - CONV i( lv_x1 ) }| )
                                                       ( name = `lines`   value = |{ CONV i( lv_y2 ) - CONV i( lv_y1 ) }| ) ) ) INTO TABLE result.
        ELSE.
          INSERT LINES OF call_code( prefix = `window(`
                                     params = VALUE #( ( name = `columns` value = |{ operand( lv_x2 ) } - { operand( lv_x1 ) }| )
                                                       ( name = `lines`   value = |{ operand( lv_y2 ) } - { operand( lv_y1 ) }| ) ) ) INTO TABLE result.
        ENDIF.

      WHEN `DESCRIBE`.
        IF lv_upper CP `DESCRIBE LIST NUMBER OF LINES *`.
          INSERT |{ to_lower( tok( tokens = lt_tok index = 6 ) ) } = list( )->describe_lines( ).| INTO TABLE result.
        ELSEIF lv_upper CP `DESCRIBE LIST NUMBER OF PAGES *`.
          INSERT |{ to_lower( tok( tokens = lt_tok index = 6 ) ) } = list( )->get_page_count( ).| INTO TABLE result.
        ELSEIF lv_upper CP `DESCRIBE LIST *`.
          note( `DESCRIBE LIST: NUMBER OF LINES and PAGES have a counterpart, the rest not` ) ##NO_TEXT.
        ENDIF.

    ENDCASE.

  ENDMETHOD.

  METHOD literal.

    result = |`{ replace( val = val sub = '`' with = '``' occ = 0 ) }`|.

  ENDMETHOD.

  METHOD unquote.

    result = val.
    DATA(lv_len) = strlen( result ).
    IF lv_len >= 2 AND ( result(1) = `'` OR result(1) = '`' ).
      result = substring( val = result off = 1 len = lv_len - 2 ).
      result = replace( val = result sub = `''` with = `'` occ = 0 ).
    ENDIF.

  ENDMETHOD.

  METHOD indent.

    DATA(lv_blank) = repeat( val = ` ` occ = by ).
    LOOP AT lines INTO DATA(lv_line).
      IF lv_line IS INITIAL.
        INSERT `` INTO TABLE result.
      ELSE.
        INSERT lv_blank && lv_line INTO TABLE result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD run.

    DATA lv_method  TYPE string.
    DATA lv_key     TYPE string.
    DATA lv_form    TYPE string.
    DATA lv_context TYPE string.
    DATA lv_in_local TYPE abap_bool.
    DATA lv_found    TYPE abap_bool.
    DATA lv_in_module TYPE abap_bool.
    DATA lv_event_method TYPE string.
    DATA lv_event_key    TYPE string.

    DATA(lt_stmt) = split( source ).
    forms_collect( lt_stmt ).

    " WRITE ... UNDER g needs g written with its name, ON BLOCK b the block
    " with its name
    DATA lv_ref TYPE string.
    LOOP AT lt_stmt INTO DATA(ls_scan).
      DATA(lv_scan) = to_upper( ls_scan-code ).
      DATA(lv_offset) = 0.
      DO.
        FIND PCRE `\bUNDER\s+([^\s,.]+)` IN SECTION OFFSET lv_offset OF lv_scan
             SUBMATCHES lv_ref MATCH OFFSET DATA(lv_match) MATCH LENGTH DATA(lv_mlen).
        IF sy-subrc <> 0.
          EXIT.
        ENDIF.
        lv_ref = unquote( lv_ref ).
        IF NOT line_exists( mt_under[ table_line = lv_ref ] ).
          INSERT lv_ref INTO TABLE mt_under.
        ENDIF.
        lv_offset = lv_match + lv_mlen.
      ENDDO.
      FIND PCRE `^AT\sSELECTION-SCREEN\sON\sBLOCK\s+(\S+)` IN lv_scan SUBMATCHES lv_ref.
      IF sy-subrc = 0.
        INSERT lv_ref INTO TABLE mt_on_block.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_stmt INTO DATA(ls_stmt).
      DATA(lt_tok) = tokens( ls_stmt-code ).
      DATA(lv_first) = to_upper( tok( tokens = lt_tok index = 1 ) ).
      IF lv_first CA `:`.
        lv_first = substring_before( val = lv_first sub = `:` ).
      ENDIF.
      DATA(lv_upper) = to_upper( ls_stmt-code ).

      " local classes, interfaces and macros - taken over as they are
      IF lv_in_local = abap_true.
        INSERT LINES OF raw_lines( ls_stmt-raw ) INTO TABLE mt_local.
        IF lv_first = `ENDCLASS` OR lv_first = `ENDINTERFACE` OR lv_first = `END-OF-DEFINITION`.
          lv_in_local = abap_false.
          INSERT `` INTO TABLE mt_local.
        ENDIF.
        CONTINUE.
      ENDIF.
      IF ( lv_first = `CLASS` AND lv_upper NS ` DEFERRED` AND lv_upper NS ` LOAD` )
          OR lv_first = `INTERFACE` OR lv_first = `DEFINE`.
        lv_in_local = abap_true.
        INSERT LINES OF raw_lines( ls_stmt-raw ) INTO TABLE mt_local.
        note( `Local classes, interfaces and macros are not part of the class - they are listed after it: put them into its local types (locals_imp)` ) ##NO_TEXT.
        CONTINUE.
      ELSEIF lv_first = `CLASS`.
        INSERT LINES OF raw_lines( ls_stmt-raw ) INTO TABLE mt_local.
        CONTINUE.
      ENDIF.

      " a PBO module - a method, called where CALL SCREEN was
      IF lv_first = `MODULE` AND lv_upper CP `MODULE * OUTPUT*`.
        lv_context = `FORM`.
        lv_form = pbo_name( tok( tokens = lt_tok index = 2 ) ).
        note( `PBO modules (MODULE ... OUTPUT) are methods pbo_...( ) - CALL SCREEN calls them in its place` ) ##NO_TEXT.
        CONTINUE.
      ELSEIF lv_first = `ENDMODULE` AND lv_context = `FORM` AND lv_form CP `pbo_*`.
        CLEAR: lv_context, lv_form.
        CONTINUE.
      ENDIF.

      " the other MODULEs (PAI) belong to dynpros - there are none
      IF lv_first = `MODULE`.
        lv_in_module = abap_true.
        note( `MODULEs of dynpros have no counterpart - they are kept as comments after the class` ) ##NO_TEXT.
      ENDIF.
      IF lv_in_module = abap_true.
        LOOP AT raw_lines( ls_stmt-raw ) INTO DATA(lv_module_line).
          INSERT |" { lv_module_line }| INTO TABLE mt_local.
        ENDLOOP.
        IF lv_first = `ENDMODULE`.
          lv_in_module = abap_false.
        ENDIF.
        CONTINUE.
      ENDIF.

      " FORM ... ENDFORM become methods
      IF lv_first = `FORM`.
        lv_context = `FORM`.
        lv_form = to_lower( substring_before( val = |{ tok( tokens = lt_tok index = 2 ) } | sub = ` ` ) ).
        CONTINUE.
      ELSEIF lv_first = `ENDFORM`.
        CLEAR: lv_context, lv_form.
        CONTINUE.
      ENDIF.

      IF lv_context <> `FORM`.
        event_of( EXPORTING code   = ls_stmt-code
                  IMPORTING method = lv_event_method
                            key    = lv_event_key
                            found  = lv_found ).
        IF lv_found = abap_true.
          lv_method = lv_event_method.
          lv_key = lv_event_key.
          lv_context = `EVENT`.
          CLEAR: mv_color, mv_hotspot, mv_intensified, mv_inverse, mv_input.
          CONTINUE.
        ENDIF.

        CASE lv_first.
          WHEN `REPORT` OR `PROGRAM`.
            FIND PCRE `MESSAGE-ID\s+(\S+)` IN lv_upper SUBMATCHES mv_msgid.
            " LINE-SIZE and LINE-COUNT: set when the run starts
            DATA(lv_size) = ``.
            FIND PCRE `LINE-SIZE\s+(\d+)` IN lv_upper SUBMATCHES lv_size.
            IF lv_size IS NOT INITIAL.
              INSERT |list( )->set_line_size( { lv_size } ).| INTO TABLE mt_start.
            ENDIF.
            DATA(lv_count) = ``.
            FIND PCRE `LINE-COUNT\s+(\d+)` IN lv_upper SUBMATCHES lv_count.
            IF lv_count IS NOT INITIAL.
              INSERT |set_line_count( { lv_count } ).| INTO TABLE mt_start.
            ENDIF.
            IF lv_upper CP `*LINE-COUNT *(*)*`.
              note( `LINE-COUNT n(m): the m footer lines are what END-OF-PAGE writes` ) ##NO_TEXT.
            ENDIF.
            CONTINUE.
          WHEN `TABLES` OR `DATA` OR `TYPES` OR `CONSTANTS` OR `RANGES` OR `STATICS` OR `FIELD-SYMBOLS` OR `NODES` OR `INCLUDE` OR `TYPE-POOLS`.
            declaration( ls_stmt ).
            CONTINUE.
          WHEN `PARAMETERS` OR `PARAMETER`.
            LOOP AT chain_expand( ls_stmt-code ) INTO DATA(lv_single).
              parameters( lv_single ).
            ENDLOOP.
            CONTINUE.
          WHEN `SELECT-OPTIONS`.
            LOOP AT chain_expand( ls_stmt-code ) INTO lv_single.
              select_options( lv_single ).
            ENDLOOP.
            CONTINUE.
          WHEN `SELECTION-SCREEN`.
            LOOP AT chain_expand( ls_stmt-code ) INTO lv_single.
              selection_screen( lv_single ).
            ENDLOOP.
            CONTINUE.
        ENDCASE.

        " code outside of an event block belongs to START-OF-SELECTION
        IF lv_context IS INITIAL.
          lv_context = `EVENT`.
          lv_method = `start_of_selection`.
          CLEAR lv_key.
        ENDIF.
      ENDIF.

      lines_add( method = COND #( WHEN lv_context = `FORM` THEN `` ELSE lv_method )
                 key    = lv_key
                 form   = lv_form
                 lines  = body( stmt   = ls_stmt
                                method = COND #( WHEN lv_context = `FORM` THEN `` ELSE lv_method ) ) ).
    ENDLOOP.

    " a TAB without DEFAULT SCREEN shows the next subscreen not shown yet -
    " the classic report set it at runtime
    DATA(lt_free) = mt_subscreen.
    LOOP AT mt_item INTO DATA(ls_tab) WHERE method = `tab` AND subscreen IS NOT INITIAL.
      DELETE lt_free WHERE table_line = ls_tab-subscreen.
    ENDLOOP.
    LOOP AT mt_item REFERENCE INTO DATA(lr_tab) WHERE method = `tab` AND subscreen IS INITIAL.
      IF lt_free IS INITIAL.
        EXIT.
      ENDIF.
      lr_tab->subscreen = lt_free[ 1 ].
      DELETE lt_free INDEX 1.
      note( `A TAB without DEFAULT SCREEN shows the subscreens in the order they are declared - check the tabs` ) ##NO_TEXT.
    ENDLOOP.

    result-code = concat_lines_of( table = generate( to_lower( condense( class ) ) )
                                   sep   = cl_abap_char_utilities=>newline ).
    " the SALV object model: z2ui5_cl_cgui_salv plays every role of it
    IF mt_salv IS NOT INITIAL.
      REPLACE ALL OCCURRENCES OF PCRE
          `(?i)(REF\s+TO\s+|CAST\s+)cl_salv_(?:table|events_table|columns_table|columns|column_table|column_list|column|functions_list|functions|display_settings|sorts|sort|aggregations|aggregation|selections|layout|functional_settings)\b`
          IN result-code WITH `$1z2ui5_cl_cgui_salv`.
    ENDIF.
    " CL_GUI_ALV_GRID: z2ui5_cl_cgui_grid - FOR EVENT ... OF cl_gui_alv_grid stays
    IF mt_grid IS NOT INITIAL.
      REPLACE ALL OCCURRENCES OF PCRE `(?i)(REF\s+TO\s+|CAST\s+)cl_gui_alv_grid\b`
          IN result-code WITH `$1z2ui5_cl_cgui_grid`.
    ENDIF.
    result-notes = mt_note.

  ENDMETHOD.

  METHOD forms_collect.

    DATA lv_name TYPE string.

    LOOP AT stmts INTO DATA(ls_stmt).
      DATA(lv_upper) = to_upper( ls_stmt-code ).
      IF lv_upper CP `FORM *`.
        INSERT form_signature( ls_stmt-code ) INTO TABLE mt_form.
      ENDIF.
      " a PBO module becomes a method like a FORM without parameters
      FIND PCRE `^MODULE\s+(\S+)\s+OUTPUT\b` IN lv_upper SUBMATCHES lv_name.
      IF sy-subrc = 0 AND NOT line_exists( mt_pbo[ table_line = pbo_name( lv_name ) ] ).
        INSERT pbo_name( lv_name ) INTO TABLE mt_pbo.
        INSERT VALUE #( name = pbo_name( lv_name ) ) INTO TABLE mt_form.
      ENDIF.
      " the grids and the containers of the SAP GUI by their declaration
      FIND ALL OCCURRENCES OF PCRE `([A-Z0-9_/]+)\s+TYPE\s+REF\s+TO\s+CL_GUI_ALV_GRID\b` IN lv_upper RESULTS DATA(lt_match).
      LOOP AT lt_match INTO DATA(ls_match).
        DATA(ls_sub) = ls_match-submatches[ 1 ].
        INSERT substring( val = lv_upper off = ls_sub-offset len = ls_sub-length ) INTO TABLE mt_grid.
      ENDLOOP.
      FIND ALL OCCURRENCES OF PCRE `([A-Z0-9_/]+)\s+TYPE\s+REF\s+TO\s+CL_GUI_[A-Z_]*CONTAINER\b` IN lv_upper RESULTS lt_match.
      LOOP AT lt_match INTO ls_match.
        ls_sub = ls_match-submatches[ 1 ].
        INSERT substring( val = lv_upper off = ls_sub-offset len = ls_sub-length ) INTO TABLE mt_container.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.

  METHOD pbo_name.

    result = |pbo_{ to_lower( module ) }|.
    IF strlen( result ) > 30.
      result = result(30).
    ENDIF.

  ENDMETHOD.

  METHOD form_signature.

    " FORM name TABLES t STRUCTURE s USING VALUE(p) TYPE x CHANGING c LIKE y
    DATA lv_kind TYPE c LENGTH 1.
    DATA ls_param TYPE ty_s_form_param.

    DATA(lt_tok) = tokens( code ).
    result-name = to_lower( tok( tokens = lt_tok index = 2 ) ).
    DATA(lv_index) = 3.
    WHILE lv_index <= lines( lt_tok ).
      DATA(lv_tok) = tok( tokens = lt_tok index = lv_index ).
      DATA(lv_up) = to_upper( lv_tok ).
      CASE lv_up.
        WHEN `TABLES`.
          lv_kind = `T`.
        WHEN `USING`.
          lv_kind = `U`.
        WHEN `CHANGING`.
          lv_kind = `C`.
        WHEN `RAISING`.
          EXIT.
        WHEN `TYPE` OR `LIKE` OR `STRUCTURE`.
          " TYPE REF TO x, TYPE STANDARD TABLE OF x: the words of the type
          lv_index = lv_index + 1.
          DATA(lv_type) = tok( tokens = lt_tok index = lv_index ).
          DO.
            DATA(lv_cur) = to_upper( tok( tokens = lt_tok index = lv_index ) ).
            DATA(lv_nxt) = to_upper( tok( tokens = lt_tok index = lv_index + 1 ) ).
            IF lv_nxt IS INITIAL OR NOT ( lv_cur = `REF` OR lv_cur = `TO` OR lv_cur = `RANGE` OR lv_cur = `LINE`
                OR lv_cur = `OF` OR lv_cur = `STANDARD` OR lv_cur = `SORTED` OR lv_cur = `HASHED`
                OR lv_cur = `ANY` OR lv_cur = `INDEX` OR ( lv_cur = `TABLE` AND lv_nxt = `OF` ) ).
              EXIT.
            ENDIF.
            lv_index = lv_index + 1.
            lv_type = |{ lv_type } { tok( tokens = lt_tok index = lv_index ) }|.
          ENDDO.
          IF lines( result-params ) > 0.
            DATA(lr_last) = REF #( result-params[ lines( result-params ) ] ).
            IF lr_last->kind = `T`.
              lr_last->type = `TYPE STANDARD TABLE`.
            ELSEIF lv_up = `LIKE`.
              lr_last->type = |LIKE { lv_type }|.
            ELSE.
              lr_last->type = |TYPE { lv_type }|.
            ENDIF.
          ENDIF.
        WHEN OTHERS.
          CLEAR ls_param.
          ls_param-kind = lv_kind.
          ls_param-name = to_lower( lv_tok ).
          IF to_upper( ls_param-name ) CP `VALUE(*)`.
            ls_param-name = substring_before( val = substring_after( val = ls_param-name sub = `(` ) sub = `)` ).
          ENDIF.
          ls_param-type = COND #( WHEN lv_kind = `T` THEN `TYPE STANDARD TABLE` ELSE `TYPE any` ).
          INSERT ls_param INTO TABLE result-params.
      ENDCASE.
      lv_index = lv_index + 1.
    ENDWHILE.

  ENDMETHOD.

  METHOD event_of.

    DATA(lv_upper) = to_upper( code ).
    DATA(lt_tok) = tokens( lv_upper ).
    CLEAR: method, key.
    found = abap_true.

    IF lv_upper = `INITIALIZATION` OR lv_upper = `LOAD-OF-PROGRAM`.
      method = `initialization`.
    ELSEIF lv_upper = `START-OF-SELECTION`.
      method = `start_of_selection`.
    ELSEIF lv_upper = `END-OF-SELECTION`.
      method = `end_of_selection`.
    ELSEIF lv_upper = `TOP-OF-PAGE`.
      method = `top_of_page`.
    ELSEIF lv_upper = `TOP-OF-PAGE DURING LINE-SELECTION`.
      method = `top_of_page_line_selection`.
    ELSEIF lv_upper = `AT LINE-SELECTION`.
      method = `at_line_selection`.
    ELSEIF lv_upper = `AT USER-COMMAND` OR lv_upper CP `AT PF*`.
      method = `at_user_command`.
      IF lv_upper CP `AT PF*`.
        note( `AT PFnn is handled in at_user_command( ) - give the function its own button` ) ##NO_TEXT.
      ENDIF.
    ELSEIF lv_upper = `END-OF-PAGE`.
      method = `end_of_page`.
    ELSEIF lv_upper = `AT SELECTION-SCREEN OUTPUT`.
      method = `at_selection_screen_output`.
    ELSEIF lv_upper = `AT SELECTION-SCREEN`.
      method = `at_selection_screen`.
    ELSEIF lv_upper = `AT SELECTION-SCREEN ON EXIT-COMMAND`.
      method = `at_selection_screen_on_exit`.
    ELSEIF lv_upper CP `AT SELECTION-SCREEN ON VALUE-REQUEST FOR *`.
      " s-low and s-high stay apart - value_request_part( ) tells them
      method = `at_value_request`.
      key = tok( tokens = lt_tok index = 6 ).
      INSERT substring_before( val = |{ key }-| sub = `-` ) INTO TABLE mt_help.
    ELSEIF lv_upper CP `AT SELECTION-SCREEN ON HELP-REQUEST FOR *`.
      method = `at_selection_screen_on_help`.
      key = substring_before( val = |{ tok( tokens = lt_tok index = 6 ) }-| sub = `-` ).
    ELSEIF lv_upper CP `AT SELECTION-SCREEN ON BLOCK *`.
      method = `at_selection_screen_on_block`.
      key = tok( tokens = lt_tok index = 5 ).
    ELSEIF lv_upper CP `AT SELECTION-SCREEN ON RADIOBUTTON GROUP *`.
      method = `at_selection_screen_on_radio`.
      key = tok( tokens = lt_tok index = 6 ).
    ELSEIF lv_upper CP `AT SELECTION-SCREEN ON END OF *`.
      method = `at_selection_screen_on_end_of`.
      key = tok( tokens = lt_tok index = 6 ).
    ELSEIF lv_upper CP `AT SELECTION-SCREEN ON *`.
      method = `at_selection_screen_on`.
      key = substring_before( val = |{ tok( tokens = lt_tok index = 4 ) }-| sub = `-` ).
    ELSEIF lv_upper CP `GET *` AND lines( lt_tok ) <= 3 AND lv_upper NS `PARAMETER` AND lv_upper NS `TIME`
        AND lv_upper NS `REFERENCE` AND lv_upper NS `CURSOR` AND lv_upper NS `BIT` AND lv_upper NS `RUN`.
      method = `start_of_selection`.
      note( `GET of a logical database has no counterpart - read the data in start_of_selection( )` ) ##NO_TEXT.
    ELSE.
      found = abap_false.
    ENDIF.

  ENDMETHOD.

  METHOD lines_add.

    IF form IS NOT INITIAL.
      READ TABLE mt_form REFERENCE INTO DATA(lr_form) WITH KEY name = form.
      IF sy-subrc = 0.
        INSERT LINES OF lines INTO TABLE lr_form->lines.
      ENDIF.
      RETURN.
    ENDIF.

    READ TABLE mt_event REFERENCE INTO DATA(lr_event) WITH KEY method = method key = key.
    IF sy-subrc <> 0.
      INSERT VALUE #( method = method key = key ) INTO TABLE mt_event REFERENCE INTO lr_event.
    ENDIF.
    INSERT LINES OF lines INTO TABLE lr_event->lines.

  ENDMETHOD.

  METHOD global_add.

    IF NOT line_exists( mt_global[ table_line = to_upper( name ) ] ).
      INSERT to_upper( name ) INTO TABLE mt_global.
    ENDIF.
    INSERT decl INTO TABLE mt_public.

  ENDMETHOD.

  METHOD declaration.

    " DATA in an event block is global data of the report - attributes;
    " TABLES a work area of the table
    DATA(lt_tok) = tokens( stmt-code ).
    DATA(lv_first) = to_upper( tok( tokens = lt_tok index = 1 ) ).
    IF lv_first CA `:`.
      lv_first = substring_before( val = lv_first sub = `:` ).
    ENDIF.

    CASE lv_first.
      WHEN `INCLUDE`.
        note( `INCLUDE statements are not resolved - convert the program with convert_program( ) or paste the includes` ) ##NO_TEXT.
        RETURN.
      WHEN `TYPE-POOLS`.
        RETURN.
      WHEN `NODES`.
        note( `NODES of a logical database have no counterpart` ) ##NO_TEXT.
        RETURN.
      WHEN `FIELD-SYMBOLS`.
        note( `Global FIELD-SYMBOLS cannot be attributes - declare them in the methods that use them` ) ##NO_TEXT.
        RETURN.
      WHEN `STATICS`.
        note( `STATICS outside a FORM became attributes` ) ##NO_TEXT.
    ENDCASE.

    LOOP AT chain_expand( stmt-code ) INTO DATA(lv_single).
      DATA(lt_single) = tokens( lv_single ).
      DATA(lv_name) = to_lower( tok( tokens = lt_single index = 2 ) ).
      IF lv_name CA `(`.
        lv_name = substring_before( val = lv_name sub = `(` ).
      ENDIF.
      CASE lv_first.
        WHEN `TABLES`.
          global_add( name = lv_name
                      decl = |DATA { lv_name } TYPE { lv_name }.| ).
          note( `TABLES became work areas of their table (DATA ... TYPE table)` ) ##NO_TEXT.
        WHEN `RANGES`.
          DATA(lv_for) = tok( tokens = lt_single index = 4 ).
          global_add( name = lv_name
                      decl = |DATA { lv_name } { type_of_for( lv_for ) }.| ).
        WHEN OTHERS.
          IF to_upper( lv_single ) CS ` OCCURS ` OR to_upper( lv_single ) CS ` WITH HEADER LINE`.
            note( |{ lv_name }: OCCURS and WITH HEADER LINE are not allowed in classes - declare a table and a work area| ) ##NO_TEXT.
          ENDIF.
          DATA(lv_decl) = texts_resolve( length_normalize( lv_single ) ).
          IF lv_first = `STATICS`.
            lv_decl = |DATA{ substring( val = lv_decl off = strlen( `STATICS` ) ) }|.
          ENDIF.
          IF lv_name <> `begin` AND lv_name <> `end`.
            global_add( name = lv_name
                        decl = |{ lv_decl }.| ).
          ELSE.
            INSERT |{ lv_decl }.| INTO TABLE mt_public.
          ENDIF.
      ENDCASE.
    ENDLOOP.

  ENDMETHOD.

  METHOD type_of_for.

    " SELECT-OPTIONS ... FOR target: a field of a global structure LIKE, a
    " DDIC field or type TYPE
    DATA(lv_target) = to_lower( target ).
    DATA(lv_head) = to_upper( substring_before( val = |{ lv_target }-| sub = `-` ) ).
    IF line_exists( mt_global[ table_line = lv_head ] ).
      result = |LIKE RANGE OF { lv_target }|.
    ELSE.
      result = |TYPE RANGE OF { lv_target }|.
    ENDIF.

  ENDMETHOD.

  METHOD selection_text.

    READ TABLE mt_text INTO DATA(ls_text) WITH KEY id = `S` key = to_upper( name ).
    IF sy-subrc = 0 AND ls_text-entry IS NOT INITIAL.
      result = literal( ls_text-entry ).
    ENDIF.

  ENDMETHOD.

  METHOD text_expr.

    " TEXT-xxx from the text pool, a literal as it is, anything else is a
    " variable the report fills - an attribute now
    IF token IS INITIAL.
      result = literal( `` ).
      RETURN.
    ENDIF.
    DATA(lv_upper) = to_upper( token ).
    IF lv_upper CP `TEXT-*`.
      READ TABLE mt_text INTO DATA(ls_text) WITH KEY id = `I` key = substring_after( val = lv_upper sub = `-` ).
      IF sy-subrc = 0.
        result = literal( ls_text-entry ).
      ELSE.
        result = literal( lv_upper ).
        note( |{ lv_upper } is not in the text pool - put in the text| ) ##NO_TEXT.
      ENDIF.
    ELSEIF token(1) = `'` OR token(1) = '`'.
      result = literal( unquote( token ) ).
    ELSE.
      result = to_lower( token ).
      IF NOT line_exists( mt_global[ table_line = to_upper( token ) ] ).
        global_add( name = result
                    decl = |DATA { result } TYPE c LENGTH { length }.| ).
      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD item_add.

    INSERT VALUE #( screen    = mv_screen
                    method    = method
                    field     = to_upper( field )
                    params    = params
                    subscreen = subscreen ) INTO TABLE mt_item.

  ENDMETHOD.

  METHOD parameters.

    DATA lt_param   TYPE ty_t_param.
    DATA lv_type    TYPE string.
    DATA lv_like    TYPE string.
    DATA lv_len     TYPE string.
    DATA lv_default TYPE string.
    DATA lv_kind    TYPE string VALUE `parameter`.
    DATA lv_group   TYPE string.

    DATA(lt_tok) = tokens( code ).
    DATA(lv_name) = to_lower( tok( tokens = lt_tok index = 2 ) ).
    IF lv_name CA `(`.
      lv_len = substring_before( val = substring_after( val = lv_name sub = `(` ) sub = `)` ).
      lv_name = substring_before( val = lv_name sub = `(` ).
    ENDIF.

    DATA(lv_index) = 3.
    WHILE lv_index <= lines( lt_tok ).
      DATA(lv_up) = to_upper( tok( tokens = lt_tok index = lv_index ) ).
      DATA(lv_next) = tok( tokens = lt_tok index = lv_index + 1 ).
      CASE lv_up.
        WHEN `TYPE`.
          lv_type = lv_next.
          lv_index = lv_index + 1.
          WHILE to_upper( tok( tokens = lt_tok index = lv_index + 1 ) ) = `LENGTH`
              OR to_upper( tok( tokens = lt_tok index = lv_index + 1 ) ) = `DECIMALS`.
            lv_type = |{ lv_type } { to_upper( tok( tokens = lt_tok index = lv_index + 1 ) ) } { tok( tokens = lt_tok index = lv_index + 2 ) }|.
            lv_index = lv_index + 2.
          ENDWHILE.
        WHEN `LIKE`.
          lv_like = lv_next.
          lv_index = lv_index + 1.
        WHEN `DEFAULT`.
          lv_default = lv_next.
          lv_index = lv_index + 1.
        WHEN `OBLIGATORY`.
          INSERT VALUE #( name = `obligatory` value = `abap_true` ) INTO TABLE lt_param.
        WHEN `LOWER`.
          INSERT VALUE #( name = `lower_case` value = `abap_true` ) INTO TABLE lt_param.
          lv_index = lv_index + 1.
        WHEN `NO-DISPLAY`.
          INSERT VALUE #( name = `no_display` value = `abap_true` ) INTO TABLE lt_param.
        WHEN `AS`.
          CASE to_upper( lv_next ).
            WHEN `CHECKBOX`.
              lv_kind = `checkbox`.
            WHEN `LISTBOX`.
              INSERT VALUE #( name = `as_listbox` value = `abap_true` ) INTO TABLE lt_param.
            WHEN OTHERS.
              note( |{ lv_name }: AS { to_upper( lv_next ) } has no counterpart| ) ##NO_TEXT.
          ENDCASE.
          lv_index = lv_index + 1.
        WHEN `RADIOBUTTON`.
          lv_kind = `radiobutton`.
          lv_group = to_upper( tok( tokens = lt_tok index = lv_index + 2 ) ).
          lv_index = lv_index + 2.
        WHEN `USER-COMMAND`.
          INSERT VALUE #( name = `user_command` value = literal( to_upper( lv_next ) ) ) INTO TABLE lt_param.
          lv_index = lv_index + 1.
        WHEN `MODIF`.
          INSERT VALUE #( name = `modif_id` value = literal( to_upper( tok( tokens = lt_tok index = lv_index + 2 ) ) ) ) INTO TABLE lt_param.
          lv_index = lv_index + 2.
        WHEN `MEMORY`.
          INSERT VALUE #( name = `memory_id` value = literal( to_upper( tok( tokens = lt_tok index = lv_index + 2 ) ) ) ) INTO TABLE lt_param.
          lv_index = lv_index + 2.
        WHEN `VISIBLE`.
          INSERT VALUE #( name = `visible_length` value = tok( tokens = lt_tok index = lv_index + 2 ) ) INTO TABLE lt_param.
          lv_index = lv_index + 2.
        WHEN `MATCHCODE`.
          INSERT VALUE #( name = `matchcode` value = literal( to_upper( tok( tokens = lt_tok index = lv_index + 2 ) ) ) ) INTO TABLE lt_param.
          lv_index = lv_index + 2.
        WHEN `VALUE`.
          lv_index = lv_index + 1.
        WHEN `FOR`.
          note( |{ lv_name }: PARAMETERS FOR TABLE / NODE of a logical database have no counterpart| ) ##NO_TEXT.
          lv_index = lv_index + 1.
      ENDCASE.
      lv_index = lv_index + 1.
    ENDWHILE.

    " the declaration
    DATA(lv_decl) = ``.
    IF lv_kind <> `parameter`.
      lv_decl = `TYPE abap_bool`.
    ELSEIF lv_type IS NOT INITIAL.
      " p(10) TYPE c - the length in parentheses
      IF lv_len IS NOT INITIAL AND to_upper( lv_type ) NS `LENGTH`
          AND ( to_upper( lv_type ) = `C` OR to_upper( lv_type ) = `N` OR to_upper( lv_type ) = `X` ).
        lv_type = |{ lv_type } LENGTH { lv_len }|.
      ENDIF.
      lv_decl = |TYPE { to_lower( lv_type ) }|.
      REPLACE ALL OCCURRENCES OF ` length ` IN lv_decl WITH ` LENGTH `.
      REPLACE ALL OCCURRENCES OF ` decimals ` IN lv_decl WITH ` DECIMALS `.
    ELSEIF lv_like IS NOT INITIAL.
      lv_decl = COND #( WHEN line_exists( mt_global[ table_line = to_upper( substring_before( val = |{ lv_like }-| sub = `-` ) ) ] )
                        THEN |LIKE { to_lower( lv_like ) }|
                        ELSE |TYPE { to_lower( lv_like ) }| ).
    ELSE.
      lv_decl = |TYPE c LENGTH { COND #( WHEN lv_len IS INITIAL THEN `1` ELSE lv_len ) }|.
    ENDIF.
    INSERT |DATA { lv_name } { lv_decl }.| INTO TABLE mt_field.
    IF NOT line_exists( mt_global[ table_line = to_upper( lv_name ) ] ).
      INSERT to_upper( lv_name ) INTO TABLE mt_global.
    ENDIF.

    IF lv_default IS NOT INITIAL.
      IF lv_kind <> `parameter` AND ( to_upper( lv_default ) = `'X'` OR to_upper( lv_default ) = '`X`' ).
        INSERT |{ lv_name } = abap_true.| INTO TABLE mt_init.
      ELSE.
        INSERT |{ lv_name } = { texts_resolve( lv_default ) }.| INTO TABLE mt_init.
      ENDIF.
    ENDIF.

    DATA(lv_text) = selection_text( lv_name ).
    DATA lt_call TYPE ty_t_param.
    INSERT VALUE #( name = `val` value = lv_name ) INTO TABLE lt_call.
    IF lv_kind = `radiobutton`.
      INSERT VALUE #( name = `group` value = literal( lv_group ) ) INTO TABLE lt_call.
    ENDIF.
    IF lv_text IS NOT INITIAL.
      INSERT VALUE #( name = `text` value = lv_text ) INTO TABLE lt_call.
    ENDIF.
    LOOP AT lt_param INTO DATA(ls_param).
      IF lv_kind <> `parameter` AND ls_param-name <> `modif_id` AND ls_param-name <> `user_command`.
        CONTINUE.
      ENDIF.
      INSERT ls_param INTO TABLE lt_call.
    ENDLOOP.

    item_add( method = lv_kind
              field  = lv_name
              params = lt_call ).

  ENDMETHOD.

  METHOD select_options.

    DATA lt_call TYPE ty_t_param.
    DATA lv_low  TYPE string.
    DATA lv_high TYPE string.
    DATA lv_opt  TYPE string.
    DATA lv_sign TYPE string VALUE `I`.

    DATA(lt_tok) = tokens( code ).
    DATA(lv_name) = to_lower( tok( tokens = lt_tok index = 2 ) ).
    DATA(lv_for) = ``.
    INSERT VALUE #( name = `val` value = lv_name ) INTO TABLE lt_call.
    DATA(lv_text) = selection_text( lv_name ).
    IF lv_text IS NOT INITIAL.
      INSERT VALUE #( name = `text` value = lv_text ) INTO TABLE lt_call.
    ENDIF.

    DATA(lv_index) = 3.
    WHILE lv_index <= lines( lt_tok ).
      DATA(lv_up) = to_upper( tok( tokens = lt_tok index = lv_index ) ).
      DATA(lv_next) = tok( tokens = lt_tok index = lv_index + 1 ).
      CASE lv_up.
        WHEN `FOR`.
          lv_for = lv_next.
          lv_index = lv_index + 1.
        WHEN `DEFAULT`.
          lv_low = lv_next.
          lv_index = lv_index + 1.
        WHEN `TO`.
          lv_high = lv_next.
          lv_index = lv_index + 1.
        WHEN `OPTION`.
          lv_opt = to_upper( lv_next ).
          lv_index = lv_index + 1.
        WHEN `SIGN`.
          lv_sign = to_upper( lv_next ).
          lv_index = lv_index + 1.
        WHEN `OBLIGATORY`.
          INSERT VALUE #( name = `obligatory` value = `abap_true` ) INTO TABLE lt_call.
        WHEN `NO`.
          IF to_upper( lv_next ) = `INTERVALS`.
            INSERT VALUE #( name = `no_intervals` value = `abap_true` ) INTO TABLE lt_call.
          ENDIF.
          lv_index = lv_index + 1.
        WHEN `NO-EXTENSION`.
          INSERT VALUE #( name = `no_extension` value = `abap_true` ) INTO TABLE lt_call.
        WHEN `NO-DISPLAY`.
          INSERT VALUE #( name = `no_display` value = `abap_true` ) INTO TABLE lt_call.
        WHEN `LOWER`.
          INSERT VALUE #( name = `lower_case` value = `abap_true` ) INTO TABLE lt_call.
          lv_index = lv_index + 1.
        WHEN `MODIF`.
          INSERT VALUE #( name = `modif_id` value = literal( to_upper( tok( tokens = lt_tok index = lv_index + 2 ) ) ) ) INTO TABLE lt_call.
          lv_index = lv_index + 2.
        WHEN `MATCHCODE`.
          INSERT VALUE #( name = `matchcode` value = literal( to_upper( tok( tokens = lt_tok index = lv_index + 2 ) ) ) ) INTO TABLE lt_call.
          lv_index = lv_index + 2.
        WHEN `MEMORY`.
          INSERT VALUE #( name = `memory_id` value = literal( to_upper( tok( tokens = lt_tok index = lv_index + 2 ) ) ) ) INTO TABLE lt_call.
          lv_index = lv_index + 2.
        WHEN `VISIBLE`.
          INSERT VALUE #( name = `visible_length` value = tok( tokens = lt_tok index = lv_index + 2 ) ) INTO TABLE lt_call.
          lv_index = lv_index + 2.
      ENDCASE.
      lv_index = lv_index + 1.
    ENDWHILE.

    INSERT |DATA { lv_name } { type_of_for( lv_for ) }.| INTO TABLE mt_field.
    IF NOT line_exists( mt_global[ table_line = to_upper( lv_name ) ] ).
      INSERT to_upper( lv_name ) INTO TABLE mt_global.
    ENDIF.

    IF lv_low IS NOT INITIAL.
      IF lv_opt IS INITIAL.
        lv_opt = COND #( WHEN lv_high IS INITIAL THEN `EQ` ELSE `BT` ).
      ENDIF.
      IF lv_high IS INITIAL.
        INSERT |{ lv_name } = VALUE #( ( sign = '{ lv_sign }' option = '{ lv_opt }' low = { texts_resolve( lv_low ) } ) ).| INTO TABLE mt_init.
      ELSE.
        INSERT |{ lv_name } = VALUE #( ( sign = '{ lv_sign }' option = '{ lv_opt }' low = { texts_resolve( lv_low ) } high = { texts_resolve( lv_high ) } ) ).| INTO TABLE mt_init.
      ENDIF.
    ENDIF.

    item_add( method = `select_option`
              field  = lv_name
              params = lt_call ).

  ENDMETHOD.

  METHOD selection_screen.

    " the position of a classic screen element - /1(30), (20), POS_LOW
    DATA lt_rest TYPE string_table.
    DATA lv_len  TYPE i VALUE 70.

    DATA(lt_tok) = tokens( code ).
    DATA(lv_upper) = to_upper( code ).
    LOOP AT lt_tok INTO DATA(lv_tok) FROM 2.
      DATA(lv_tu) = to_upper( lv_tok ).
      IF lv_tu = `/` OR lv_tu = `POS_LOW` OR lv_tu = `POS_HIGH`.
        CONTINUE.
      ENDIF.
      IF matches( val = lv_tu pcre = `^/?\d*(\(\d+\))?$` ) AND lv_tu IS NOT INITIAL.
        IF lv_tu CA `(`.
          lv_len = substring_before( val = substring_after( val = lv_tu sub = `(` ) sub = `)` ).
        ENDIF.
        CONTINUE.
      ENDIF.
      INSERT lv_tok INTO TABLE lt_rest.
    ENDLOOP.
    DATA(lv_w1) = to_upper( tok( tokens = lt_rest index = 1 ) ).
    DATA(lv_w2) = to_upper( tok( tokens = lt_rest index = 2 ) ).
    DATA(lv_w3) = to_upper( tok( tokens = lt_rest index = 3 ) ).

    DATA lt_call TYPE ty_t_param.
    DATA(lv_modif) = ``.
    FIND PCRE `MODIF\sID\s(\S+)` IN lv_upper SUBMATCHES lv_modif.
    IF lv_modif IS NOT INITIAL.
      INSERT VALUE #( name = `modif_id` value = literal( lv_modif ) ) INTO TABLE lt_call.
    ENDIF.

    IF lv_w1 = `BEGIN` AND lv_w2 = `OF` AND lv_w3 = `BLOCK`.
      DATA(lv_title) = ``.
      LOOP AT lt_rest INTO lv_tok.
        IF to_upper( lv_tok ) = `TITLE`.
          lv_title = text_expr( tok( tokens = lt_rest index = sy-tabix + 1 ) ).
          EXIT.
        ENDIF.
      ENDLOOP.
      DATA lt_block TYPE ty_t_param.
      IF lv_title IS NOT INITIAL.
        INSERT VALUE #( name = `title` value = lv_title ) INTO TABLE lt_block.
      ENDIF.
      " the name for ON BLOCK, NO INTERVALS for its select-options
      DATA(lv_block) = to_upper( tok( tokens = lt_rest index = 4 ) ).
      IF line_exists( mt_on_block[ table_line = lv_block ] ).
        INSERT VALUE #( name = `name` value = literal( lv_block ) ) INTO TABLE lt_block.
      ENDIF.
      IF lv_upper CS `NO INTERVALS`.
        INSERT VALUE #( name = `no_intervals` value = `abap_true` ) INTO TABLE lt_block.
      ENDIF.
      item_add( method = `block_begin`
                params = lt_block ).
    ELSEIF lv_w1 = `BEGIN` AND lv_w2 = `OF` AND lv_w3 = `TABBED`.
      INSERT to_upper( tok( tokens = lt_rest index = 5 ) ) INTO TABLE mt_tabbed.
      item_add( `tabbed_block_begin` ).
    ELSEIF lv_w1 = `END` AND lv_w2 = `OF` AND lv_w3 = `BLOCK`.
      IF line_exists( mt_tabbed[ table_line = to_upper( tok( tokens = lt_rest index = 4 ) ) ] ).
        item_add( `tabbed_block_end` ).
      ELSE.
        item_add( `block_end` ).
      ENDIF.
    ELSEIF lv_w1 = `BEGIN` AND lv_w2 = `OF` AND lv_w3 = `LINE`.
      item_add( `line_begin` ).
    ELSEIF lv_w1 = `END` AND lv_w2 = `OF` AND lv_w3 = `LINE`.
      item_add( `line_end` ).
    ELSEIF lv_w1 = `BEGIN` AND lv_w2 = `OF` AND lv_w3 = `SCREEN`.
      " the number of the screen is no position - from the words as written
      mv_screen = tok( tokens = lt_tok index = 5 ).
      IF lv_upper NS `AS SUBSCREEN`.
        INSERT mv_screen INTO TABLE mt_window.
      ELSE.
        INSERT mv_screen INTO TABLE mt_subscreen.
      ENDIF.
    ELSEIF lv_w1 = `END` AND lv_w2 = `OF` AND lv_w3 = `SCREEN`.
      CLEAR mv_screen.
    ELSEIF lv_w1 = `COMMENT`.
      INSERT VALUE #( name = `text` value = text_expr( token  = tok( tokens = lt_rest index = 2 )
                                                       length = lv_len ) ) INTO TABLE lt_call.
      SORT lt_call BY name DESCENDING.
      DATA(lv_for) = ``.
      FIND PCRE `FOR\sFIELD\s(\S+)` IN lv_upper SUBMATCHES lv_for.
      IF lv_for IS NOT INITIAL.
        INSERT VALUE #( name = `for_field` value = literal( lv_for ) ) INTO TABLE lt_call.
      ENDIF.
      item_add( method = `comment`
                params = lt_call ).
    ELSEIF lv_w1 = `PUSHBUTTON`.
      DATA(lv_ucomm) = ``.
      FIND PCRE `USER-COMMAND\s(\S+)` IN lv_upper SUBMATCHES lv_ucomm.
      INSERT VALUE #( name = `text` value = text_expr( token  = tok( tokens = lt_rest index = 2 )
                                                       length = lv_len ) ) INTO TABLE lt_call.
      INSERT VALUE #( name = `event` value = literal( lv_ucomm ) ) INTO TABLE lt_call.
      SORT lt_call BY name DESCENDING.
      item_add( method = `button`
                params = lt_call ).
    ELSEIF lv_w1 = `SKIP`.
      " SKIP n - the number is no position
      DATA(lv_lines) = tok( tokens = lt_tok index = 3 ).
      item_add( method = `skip`
                params = COND #( WHEN lv_lines IS NOT INITIAL AND lv_lines CO `0123456789`
                                 THEN VALUE #( ( name = `val` value = lv_lines ) ) ) ).
    ELSEIF lv_w1 = `ULINE`.
      item_add( `uline` ).
    ELSEIF lv_w1 = `TAB`.
      DATA(lv_screen) = ``.
      FIND PCRE `SCREEN\s(\d+)` IN lv_upper SUBMATCHES lv_screen.
      item_add( method    = `tab`
                params    = VALUE #( ( name = `text` value = text_expr( token  = tok( tokens = lt_rest index = 2 )
                                                                        length = lv_len ) ) )
                subscreen = lv_screen ).
      IF lv_upper CS `USER-COMMAND`.
        note( `The USER-COMMAND of a TAB is not raised - the tabs switch in the browser` ) ##NO_TEXT.
      ENDIF.
    ELSEIF lv_w1 = `FUNCTION`.
      " FUNCTION KEY n - the text was set to sscrfields-functxt_0n; the
      " number is no position - from the words as written
      DATA(lv_key) = tok( tokens = lt_tok index = 4 ).
      item_add( method = `function_key`
                params = VALUE #( ( name = `number` value = lv_key )
                                  ( name = `text`   value = literal( |Function { lv_key }| ) ) ) ).
      note( |FUNCTION KEY { lv_key }: give it the text of sscrfields-functxt_0{ lv_key } - it arrives as FC0{ lv_key } in at_user_command( )| ) ##NO_TEXT.
    ELSE.
      note( |SELECTION-SCREEN { lv_w1 } has no counterpart| ) ##NO_TEXT.
    ENDIF.

  ENDMETHOD.

  METHOD texts_resolve.

    DATA lv_key  TYPE string.
    DATA lv_lit  TYPE string.
    DATA lv_repl TYPE string.

    result = code.
    " 'literal'(001) - the literal
    WHILE result CS `'(`.
      FIND PCRE `('(?:[^']|'')*')\((\w{3})\)` IN result SUBMATCHES lv_lit lv_key.
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.
      lv_repl = literal( unquote( lv_lit ) ).
      REPLACE FIRST OCCURRENCE OF |{ lv_lit }({ lv_key })| IN result WITH lv_repl.
    ENDWHILE.

    " TEXT-xxx - its text
    DO.
      FIND PCRE `(?i)\bTEXT-(\w{1,3})\b` IN result SUBMATCHES lv_key MATCH OFFSET DATA(lv_off) MATCH LENGTH DATA(lv_len).
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.
      READ TABLE mt_text INTO DATA(ls_text) WITH KEY id = `I` key = to_upper( lv_key ).
      DATA(lv_with) = COND string( WHEN sy-subrc = 0 THEN literal( ls_text-entry )
                                   ELSE literal( |TEXT-{ to_upper( lv_key ) }| ) ).
      IF sy-subrc <> 0.
        note( |TEXT-{ to_upper( lv_key ) } is not in the text pool - put in the text| ) ##NO_TEXT.
      ENDIF.
      result = |{ substring( val = result len = lv_off ) }{ lv_with }{ substring( val = result off = lv_off + lv_len ) }|.
    ENDDO.

  ENDMETHOD.

  METHOD raw_lines.

    " the statement as written, its indentation kept - the blank lines in
    " front dropped, a * comment a " comment at the column of the code
    DATA lt_line TYPE string_table.

    SPLIT raw AT cl_abap_char_utilities=>newline INTO TABLE lt_line.
    WHILE lt_line IS NOT INITIAL AND condense( lt_line[ 1 ] ) = ``.
      DELETE lt_line INDEX 1.
    ENDWHILE.
    IF lt_line IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_lead) = ``.
    LOOP AT lt_line INTO DATA(lv_line).
      IF condense( lv_line ) <> `` AND lv_line(1) <> `*`.
        FIND PCRE `^\x20*` IN lv_line MATCH LENGTH DATA(lv_blank).
        lv_lead = repeat( val = ` ` occ = lv_blank ).
        EXIT.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_line INTO lv_line.
      IF lv_line IS NOT INITIAL AND lv_line(1) = `*`.
        INSERT |{ lv_lead }"{ substring( val = lv_line off = 1 ) }| INTO TABLE result.
      ELSE.
        INSERT lv_line INTO TABLE result.
      ENDIF.
    ENDLOOP.
    " the period the split took
    DATA(lv_last) = lines( result ).
    result[ lv_last ] = |{ result[ lv_last ] }.|.

  ENDMETHOD.

  METHOD length_normalize.

    " DATA x(10) TYPE n VALUE 1 - DATA x TYPE n LENGTH 10 VALUE 1
    DATA lv_name TYPE string.
    DATA lv_len  TYPE string.

    result = code.
    DATA(lt_tok) = tokens( code ).
    DATA(lv_second) = tok( tokens = lt_tok index = 2 ).
    FIND PCRE `^(\w+)\((\d+)\)$` IN lv_second SUBMATCHES lv_name lv_len.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lv_rest) = ``.
    DATA(lv_type) = ``.
    IF to_upper( tok( tokens = lt_tok index = 3 ) ) = `TYPE`.
      lv_type = tok( tokens = lt_tok index = 4 ).
      LOOP AT lt_tok INTO DATA(lv_word) FROM 5.
        lv_rest = |{ lv_rest } { lv_word }|.
      ENDLOOP.
    ELSE.
      lv_type = `c`.
      LOOP AT lt_tok INTO lv_word FROM 3.
        lv_rest = |{ lv_rest } { lv_word }|.
      ENDLOOP.
    ENDIF.
    result = condense( |{ tok( tokens = lt_tok index = 1 ) } { lv_name } TYPE { lv_type } LENGTH { lv_len }{ lv_rest }| ).

  ENDMETHOD.

  METHOD lead.

    LOOP AT lines INTO DATA(lv_line).
      IF condense( lv_line ) <> `` AND lv_line(1) <> `"`.
        FIND PCRE `^\x20*` IN lv_line MATCH LENGTH DATA(lv_blank).
        result = repeat( val = ` ` occ = lv_blank ).
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD dedent.

    DATA lv_min TYPE i VALUE 9999.

    LOOP AT lines INTO DATA(lv_line).
      IF condense( lv_line ) = ``.
        CONTINUE.
      ENDIF.
      FIND PCRE `^\x20*` IN lv_line MATCH LENGTH DATA(lv_blank).
      lv_min = nmin( val1 = lv_min val2 = lv_blank ).
    ENDLOOP.
    IF lv_min = 9999.
      lv_min = 0.
    ENDIF.

    LOOP AT lines INTO lv_line.
      IF condense( lv_line ) = ``.
        INSERT `` INTO TABLE result.
      ELSE.
        INSERT substring( val = lv_line off = lv_min ) INTO TABLE result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD body.

    " a statement of an event block or FORM in the language of the runtime -
    " every line indented as the statement was
    result = body_converted( stmt   = stmt
                             method = method ).
    DATA(lv_lead) = lead( raw_lines( stmt-raw ) ).
    LOOP AT result REFERENCE INTO DATA(lr_line) WHERE table_line IS NOT INITIAL.
      lr_line->* = lv_lead && lr_line->*.
    ENDLOOP.

  ENDMETHOD.

  METHOD body_converted.

    " the lines without the indentation of the statement
    DATA(lt_tok) = tokens( stmt-code ).
    DATA(lv_first) = to_upper( tok( tokens = lt_tok index = 1 ) ).
    IF lv_first CA `:`.
      lv_first = substring_before( val = lv_first sub = `:` ).
    ENDIF.
    DATA(lv_upper) = to_upper( stmt-code ).

    " the comment lines in front of the statement stay
    LOOP AT raw_lines( stmt-raw ) INTO DATA(lv_comment).
      IF condense( lv_comment ) = `` OR substring( val = condense( lv_comment ) len = 1 ) <> `"`.
        EXIT.
      ENDIF.
      INSERT condense( lv_comment ) INTO TABLE result.
    ENDLOOP.

    " the ALV shows its table after the run - clearing it would leave it empty
    IF mt_alv_tab IS NOT INITIAL AND ( lv_first = `CLEAR` OR lv_first = `REFRESH` OR lv_first = `FREE` ).
      DATA(lv_cleared) = replace( val = to_upper( tok( tokens = lt_tok index = 2 ) ) sub = `[]` with = `` ).
      IF lines( lt_tok ) = 2 AND line_exists( mt_alv_tab[ table_line = lv_cleared ] ).
        INSERT |" { condense( stmt-code ) }. - the ALV shows the table after the run| INTO TABLE result.
        note( |{ lv_first } { to_lower( lv_cleared ) } after the ALV is a comment: the grid shows the table after the run| ) ##NO_TEXT.
        RETURN.
      ENDIF.
    ENDIF.

    DATA(lt_grid) = grid_statement( stmt-code ).
    IF lt_grid IS NOT INITIAL.
      INSERT LINES OF lt_grid INTO TABLE result.
      RETURN.
    ENDIF.
    DATA(lt_salv) = salv_statement( stmt-code ).
    IF lt_salv IS NOT INITIAL.
      INSERT LINES OF lt_salv INTO TABLE result.
      RETURN.
    ENDIF.

    CASE lv_first.
      WHEN `WRITE`.
        IF lv_upper CP `* TO *` AND lv_upper NS `'`.
          " WRITE ... TO: a conversion, no output
          INSERT LINES OF raw_lines( stmt-raw ) INTO TABLE result.
          RETURN.
        ENDIF.
        LOOP AT chain_expand( stmt-code ) INTO DATA(lv_single).
          INSERT LINES OF write( lv_single ) INTO TABLE result.
        ENDLOOP.
        RETURN.
      WHEN `FORMAT`.
        format( lv_upper ).
        RETURN.
      WHEN `ULINE` OR `NEW-PAGE` OR `RESERVE` OR `POSITION` OR `BACK` OR `WINDOW` OR `DESCRIBE`.
        DATA(lt_list) = list_statement( stmt-code ).
        IF lt_list IS NOT INITIAL.
          INSERT LINES OF lt_list INTO TABLE result.
          RETURN.
        ENDIF.
      WHEN `NEW-LINE`.
        INSERT `list( )->new_line( ).` INTO TABLE result.
        RETURN.
      WHEN `SKIP`.
        IF to_upper( tok( tokens = lt_tok index = 2 ) ) = `TO`.
          " SKIP TO LINE n
          INSERT |list( )->skip_to_line( { operand( tok( tokens = lt_tok index = 4 ) ) } ).| INTO TABLE result.
          RETURN.
        ENDIF.
        INSERT COND string( WHEN lines( lt_tok ) > 1 THEN |list( )->skip( { tok( tokens = lt_tok index = 2 ) } ).|
                            ELSE `list( )->skip( ).` ) INTO TABLE result.
        RETURN.
      WHEN `HIDE`.
        LOOP AT chain_expand( stmt-code ) INTO lv_single.
          INSERT |list( )->hide( { to_lower( tok( tokens = tokens( lv_single ) index = 2 ) ) } ).| INTO TABLE result.
        ENDLOOP.
        note( `HIDE: the hidden value arrives as hide in at_line_selection( ) - the fields are no longer restored` ) ##NO_TEXT.
        RETURN.
      WHEN `MESSAGE`.
        INSERT LINES OF message( stmt-code ) INTO TABLE result.
        IF result IS NOT INITIAL.
          RETURN.
        ENDIF.
      WHEN `PERFORM`.
        INSERT LINES OF perform( stmt-code ) INTO TABLE result.
        IF result IS NOT INITIAL.
          RETURN.
        ENDIF.
      WHEN `LEAVE`.
        IF lv_upper = `LEAVE TO LIST-PROCESSING` OR lv_upper CP `LEAVE TO LIST-PROCESSING *`.
          INSERT `" LEAVE TO LIST-PROCESSING - the output is shown after the run` INTO TABLE result.
          RETURN.
        ELSEIF lv_upper = `LEAVE LIST-PROCESSING` OR lv_upper = `LEAVE TO SCREEN 0`.
          INSERT `leave_to_selection_screen( ).` INTO TABLE result.
          RETURN.
        ENDIF.
      WHEN `CALL`.
        IF lv_upper CP `CALL SCREEN *`.
          IF mt_pbo IS INITIAL.
            INSERT |" { condense( stmt-code ) }. - a screen of the SAP GUI| INTO TABLE result.
          ENDIF.
          LOOP AT mt_pbo INTO DATA(lv_pbo).
            INSERT |{ lv_pbo }( ).| INTO TABLE result.
          ENDLOOP.
          note( `CALL SCREEN: its PBO modules run in its place - the layout of the screen has no counterpart, a grid on it is the ALV of the report;` &&
                ` the function codes of its PAI arrive in at_user_command( )` ) ##NO_TEXT.
          RETURN.
        ENDIF.
        IF lv_upper CP `CALL SELECTION-SCREEN *`.
          INSERT |call_selection_screen( { literal( tok( tokens = lt_tok index = 3 ) ) } ).| INTO TABLE result.
          note( `CALL SELECTION-SCREEN opens a popup - move the code that follows it into after_call_selection_screen( )` ) ##NO_TEXT.
          RETURN.
        ENDIF.
        IF lv_upper CP `CALL FUNCTION *`.
          DATA(lt_function) = call_function( stmt-code ).
          IF lt_function IS NOT INITIAL.
            INSERT LINES OF lt_function INTO TABLE result.
            RETURN.
          ENDIF.
        ENDIF.
        IF lv_upper CS `REUSE_ALV` OR lv_upper CS `CL_SALV_TABLE` OR ( lv_upper CS `CL_GUI_ALV_GRID` AND mt_grid IS INITIAL ).
          note( `ALV of the SAP GUI: show the table with alv( mt_table ) in start_of_selection( )` ) ##NO_TEXT.
        ENDIF.
        IF lv_upper CS `'POPUP_TO_CONFIRM'` OR lv_upper CS `'POPUP_TO_DECIDE'` OR lv_upper CS `'POPUP_GET_VALUES'`.
          note( `Popups: popup_to_confirm( ), popup_to_decide( ) and popup_get_values( ) answer in at_user_command( )` ) ##NO_TEXT.
        ENDIF.
        IF lv_upper CS `'RS_SET_SELSCREEN_STATUS'`.
          note( `RS_SET_SELSCREEN_STATUS: switch the functions off with set_selscreen_status( excluding = ... ) - cs_ucomm-execute, variant_get, ...` ) ##NO_TEXT.
        ENDIF.
        IF lv_upper CS `'F4IF_INT_TABLE_VALUE_REQUEST'`.
          note( `F4IF_INT_TABLE_VALUE_REQUEST: answer at_value_request( ) with value_help_popup( tab = ... col = ... )` ) ##NO_TEXT.
        ENDIF.
      WHEN `SUBMIT`.
        note( `SUBMIT of a classic report stays - a converted report is started with submit( report = ... values = ... )` ) ##NO_TEXT.
      WHEN `LOOP`.
        IF lv_upper = `LOOP AT SCREEN` OR lv_upper CP `LOOP AT SCREEN INTO *`.
          INSERT `LOOP AT screen->loop_at_screen( ) INTO DATA(ls_screen).` INTO TABLE result.
          RETURN.
        ENDIF.
      WHEN `MODIFY`.
        IF lv_upper = `MODIFY SCREEN` OR lv_upper CP `MODIFY SCREEN FROM *`.
          INSERT `screen->modify_screen( ls_screen ).` INTO TABLE result.
          RETURN.
        ENDIF.
        IF lv_upper CP `MODIFY LINE*` OR lv_upper CP `MODIFY CURRENT LINE*`.
          note( `MODIFY LINE: list( )->modify_line( line = ... index = ... value = ... color = ... ) changes the n-th field of a line` ) ##NO_TEXT.
        ENDIF.
      WHEN `SET` OR `GET`.
        DATA(lv_2nd) = to_upper( tok( tokens = lt_tok index = 2 ) ).
        IF lv_first = `SET` AND ( lv_2nd = `BLANK` OR lv_2nd = `TITLEBAR` OR lv_2nd = `PF-STATUS` OR lv_2nd = `LEFT` ).
          INSERT |" { stmt-code }.| INTO TABLE result.
          note( `SET PF-STATUS / TITLEBAR and SET BLANK LINES live in the SAP GUI - give the functions to set_pf_status( functions excluding ), the title to set_title( ); kept as comments` ) ##NO_TEXT.
          RETURN.
        ENDIF.
        " SET CURSOR FIELD f / GET CURSOR FIELD f VALUE v LINE l OFFSET o
        IF lv_upper CP `SET CURSOR FIELD *`.
          INSERT |set_cursor_field( { operand( tok( tokens = lt_tok index = 4 ) ) } ).| INTO TABLE result.
          RETURN.
        ENDIF.
        IF lv_upper CP `GET CURSOR *`.
          LOOP AT lt_tok INTO DATA(lv_cur) FROM 3.
            DATA(lv_cur_index) = sy-tabix.
            DATA(lv_cur_target) = to_lower( tok( tokens = lt_tok index = lv_cur_index + 1 ) ).
            CASE to_upper( lv_cur ).
              WHEN `FIELD`.
                INSERT |{ lv_cur_target } = get_cursor( )-field.| INTO TABLE result.
              WHEN `VALUE`.
                INSERT |{ lv_cur_target } = get_cursor( )-value.| INTO TABLE result.
              WHEN `LINE`.
                INSERT |{ lv_cur_target } = get_cursor( )-line.| INTO TABLE result.
              WHEN `OFFSET`.
                INSERT |{ lv_cur_target } = get_cursor( )-offset.| INTO TABLE result.
            ENDCASE.
          ENDLOOP.
          IF result IS NOT INITIAL.
            note( `GET CURSOR FIELD names the field as written with write( name = ... ) - the column of the ALV` ) ##NO_TEXT.
            RETURN.
          ENDIF.
        ENDIF.
        IF lv_upper CP `SET PARAMETER ID * FIELD *`.
          INSERT |set_parameter_id( id    = { tok( tokens = lt_tok index = 4 ) }| INTO TABLE result.
          INSERT |                  value = { to_lower( tok( tokens = lt_tok index = 6 ) ) } ).| INTO TABLE result.
          RETURN.
        ELSEIF lv_upper CP `GET PARAMETER ID * FIELD *`.
          INSERT |{ to_lower( tok( tokens = lt_tok index = 6 ) ) } = get_parameter_id( { tok( tokens = lt_tok index = 4 ) } ).| INTO TABLE result.
          RETURN.
        ENDIF.
      WHEN `READ` OR `SCROLL`.
        IF lv_upper CP `READ LINE*` OR lv_upper CP `READ CURRENT LINE*`.
          note( `READ LINE: list( )->read_value( line = ... index = ... ) reads the n-th field of a line, read_line( ) all of it` ) ##NO_TEXT.
        ELSEIF lv_upper CP `SCROLL LIST*`.
          note( `SCROLL LIST has no counterpart - the browser scrolls` ) ##NO_TEXT.
        ENDIF.
    ENDCASE.

    " the structure of a tabbed block (PROG, DYNNR, ACTIVETAB) is gone
    LOOP AT mt_tabbed INTO DATA(lv_tabbed).
      IF matches( val = lv_upper pcre = |.*\\b{ lv_tabbed }-(PROG\|DYNNR\|ACTIVETAB)\\b.*| ).
        INSERT |" { stmt-code }.| INTO TABLE result.
        note( |{ to_lower( lv_tabbed ) }-prog/-dynnr/-activetab: the tabs of a tabbed block switch in the browser - the statements are comments| ) ##NO_TEXT.
        RETURN.
      ENDIF.
    ENDLOOP.

    " taken over as it is - with the system fields of the runtime
    DATA lt_raw TYPE string_table.
    DATA(lt_stmt_lines) = raw_lines( stmt-raw ).
    DATA(lv_stmt_lead) = lead( lt_stmt_lines ).
    LOOP AT lt_stmt_lines INTO DATA(lv_line).
      IF condense( lv_line ) <> `` AND substring( val = condense( lv_line ) len = 1 ) = `"` AND lt_raw IS INITIAL AND result IS NOT INITIAL.
        CONTINUE.
      ENDIF.
      IF lv_stmt_lead IS NOT INITIAL AND strlen( lv_line ) >= strlen( lv_stmt_lead )
          AND substring( val = lv_line len = strlen( lv_stmt_lead ) ) = lv_stmt_lead.
        lv_line = substring( val = lv_line off = strlen( lv_stmt_lead ) ).
      ELSE.
        SHIFT lv_line LEFT DELETING LEADING ` `.
      ENDIF.
      lv_line = texts_resolve( lv_line ).
      IF method = `at_user_command`.
        REPLACE ALL OCCURRENCES OF PCRE `(?i)\bsy-ucomm\b` IN lv_line WITH `ucomm`.
        REPLACE ALL OCCURRENCES OF PCRE `(?i)\bsscrfields-ucomm\b` IN lv_line WITH `ucomm`.
      ELSEIF matches( val = lv_line pcre = `(?i).*\b(sy|sscrfields)-ucomm\b.*` ).
        note( `sy-ucomm of the selection screen: buttons and user commands arrive in at_user_command( ucomm )` ) ##NO_TEXT.
      ENDIF.
      REPLACE ALL OCCURRENCES OF PCRE `(?i)\bsy-lisel\b` IN lv_line WITH `lisel( )`.
      REPLACE ALL OCCURRENCES OF PCRE `(?i)\bsy-linno\b` IN lv_line WITH `list( )->current_line( )`.
      REPLACE ALL OCCURRENCES OF PCRE `(?i)\bsy-colno\b` IN lv_line WITH `list( )->current_column( )`.
      REPLACE ALL OCCURRENCES OF PCRE `(?i)\bsy-pagno\b` IN lv_line WITH `list( )->current_page( )`.
      IF matches( val = lv_line pcre = `(?i).*\bsy-lsind\b.*` ).
        IF matches( val = lv_line pcre = `(?i)^\s*sy-lsind\s*=.*` ).
          note( `sy-lsind cannot be set - Back returns one list level` ) ##NO_TEXT.
        ELSE.
          REPLACE ALL OCCURRENCES OF PCRE `(?i)\bsy-lsind\b` IN lv_line WITH `lsind( )`.
        ENDIF.
      ENDIF.
      IF method = `at_selection_screen_output`.
        " SCREEN-REQUIRED = 2: required, not checked
        REPLACE ALL OCCURRENCES OF PCRE `(?i)\bscreen-required\s*=\s*'?2'?` IN lv_line WITH `ls_screen-recommended = abap_true`.
        REPLACE ALL OCCURRENCES OF PCRE `(?i)\bscreen-(name|group1|active|input|required|invisible|intensified|length)\b` IN lv_line WITH `ls_screen-$1`.
        REPLACE ALL OCCURRENCES OF PCRE `(?i)(ls_screen-(?:active|input|required|invisible|intensified))\s*=\s*'?1'?(\s|\.|$)` IN lv_line WITH `$1 = abap_true$2`.
        REPLACE ALL OCCURRENCES OF PCRE `(?i)(ls_screen-(?:active|input|required|invisible|intensified))\s*=\s*'?0'?(\s|\.|$)` IN lv_line WITH `$1 = abap_false$2`.
        IF matches( val = lv_line pcre = `(?i).*\bscreen-(group2|group3|group4|output|display_3d|value_help|request|color).*` ).
          note( `screen-group2/3/4, output, display_3d and value_help have no counterpart in loop_at_screen( )` ) ##NO_TEXT.
        ENDIF.
      ENDIF.
      INSERT lv_line INTO TABLE lt_raw.
    ENDLOOP.
    INSERT LINES OF lt_raw INTO TABLE result.

  ENDMETHOD.

  METHOD format.

    " FORMAT COLOR / INTENSIFIED / INVERSE / HOTSPOT / INPUT [ON|OFF] /
    " RESET - for the WRITEs that follow in the event block
    DATA(lt_tok) = tokens( code ).
    LOOP AT lt_tok INTO DATA(lv_tok).
      DATA(lv_index) = sy-tabix.
      DATA(lv_next) = to_upper( tok( tokens = lt_tok index = lv_index + 1 ) ).
      DATA(lv_on) = xsdbool( lv_next <> `OFF` AND lv_next <> `= 0` ).
      IF lv_next = `=`.
        lv_on = xsdbool( tok( tokens = lt_tok index = lv_index + 2 ) <> `0` ).
      ENDIF.
      CASE lv_tok.
        WHEN `RESET`.
          CLEAR: mv_color, mv_hotspot, mv_intensified, mv_inverse, mv_input.
        WHEN `COLOR`.
          DATA(lv_color) = lv_next.
          IF lv_color = `=`.
            lv_color = to_upper( tok( tokens = lt_tok index = lv_index + 2 ) ).
          ENDIF.
          mv_color = SWITCH #( lv_color
                               WHEN `COL_POSITIVE` OR `5` THEN `positive`
                               WHEN `COL_NEGATIVE` OR `6` THEN `negative`
                               WHEN `COL_TOTAL` OR `3` OR `COL_GROUP` OR `7` THEN `total`
                               WHEN `COL_KEY` OR `4` OR `COL_HEADING` OR `1` THEN `key`
                               ELSE `` ).
        WHEN `HOTSPOT`.
          mv_hotspot = lv_on.
        WHEN `INTENSIFIED`.
          mv_intensified = lv_on.
        WHEN `INVERSE`.
          mv_inverse = lv_on.
        WHEN `INPUT`.
          mv_input = lv_on.
      ENDCASE.
    ENDLOOP.

  ENDMETHOD.

  METHOD write.

    " WRITE [AT] [/][pos][(len)] dobj [COLOR ...] [HOTSPOT] [AS CHECKBOX|ICON]
    DATA lv_pos   TYPE string.
    DATA lv_len   TYPE string.
    DATA lv_dobj  TYPE string.
    DATA lv_new   TYPE abap_bool.
    DATA lv_kind  TYPE string VALUE `write`.
    DATA lt_param TYPE ty_t_param.
    DATA lv_color   TYPE string.
    DATA lv_hotspot TYPE abap_bool.
    DATA lv_intensified TYPE abap_bool.
    DATA lv_inverse TYPE abap_bool.
    DATA lv_input   TYPE abap_bool.
    DATA lt_opt     TYPE ty_t_param.

    lv_color = mv_color.
    lv_hotspot = mv_hotspot.
    lv_intensified = mv_intensified.
    lv_inverse = mv_inverse.
    lv_input = mv_input.
    DATA(lt_tok) = tokens( code ).
    DATA(lv_index) = 2.
    IF to_upper( tok( tokens = lt_tok index = lv_index ) ) = `AT`.
      lv_index = lv_index + 1.
    ENDIF.

    " the position: /, /12(20), 12(20), (20) - or / in front of the dobj
    DATA(lv_tok) = tok( tokens = lt_tok index = lv_index ).
    IF matches( val = lv_tok pcre = `^/?\d*(\(\d+\))?$` ) AND lv_tok IS NOT INITIAL.
      IF lv_tok(1) = `/`.
        lv_new = abap_true.
        lv_tok = substring( val = lv_tok off = 1 ).
      ENDIF.
      FIND PCRE `^(\d*)(?:\((\d+)\))?$` IN lv_tok SUBMATCHES lv_pos lv_len.
      lv_index = lv_index + 1.
      lv_dobj = tok( tokens = lt_tok index = lv_index ).
    ELSEIF lv_tok IS NOT INITIAL AND lv_tok(1) = `/`.
      lv_new = abap_true.
      lv_dobj = substring( val = lv_tok off = 1 ).
    ELSE.
      lv_dobj = lv_tok.
    ENDIF.

    DATA(lv_from) = lv_index + 1.
    LOOP AT lt_tok INTO DATA(lv_opt) FROM lv_from.
      DATA(lv_opt_index) = sy-tabix.
      CASE to_upper( lv_opt ).
        WHEN `COLOR`.
          DATA(lv_c) = to_upper( tok( tokens = lt_tok index = lv_opt_index + 1 ) ).
          IF lv_c = `=`.
            lv_c = to_upper( tok( tokens = lt_tok index = lv_opt_index + 2 ) ).
          ENDIF.
          lv_color = SWITCH #( lv_c
                               WHEN `COL_POSITIVE` OR `5` THEN `positive`
                               WHEN `COL_NEGATIVE` OR `6` THEN `negative`
                               WHEN `COL_TOTAL` OR `3` OR `COL_GROUP` OR `7` THEN `total`
                               WHEN `COL_KEY` OR `4` OR `COL_HEADING` OR `1` THEN `key`
                               ELSE `` ).
        WHEN `HOTSPOT`.
          lv_hotspot = xsdbool( to_upper( tok( tokens = lt_tok index = lv_opt_index + 1 ) ) <> `OFF` ).
        WHEN `INTENSIFIED`.
          lv_intensified = xsdbool( to_upper( tok( tokens = lt_tok index = lv_opt_index + 1 ) ) <> `OFF` ).
        WHEN `INVERSE`.
          lv_inverse = xsdbool( to_upper( tok( tokens = lt_tok index = lv_opt_index + 1 ) ) <> `OFF` ).
        WHEN `INPUT`.
          lv_input = xsdbool( to_upper( tok( tokens = lt_tok index = lv_opt_index + 1 ) ) <> `OFF` ).
        WHEN `UNDER`.
          INSERT VALUE #( name = `under` value = literal( to_upper( unquote( tok( tokens = lt_tok index = lv_opt_index + 1 ) ) ) ) ) INTO TABLE lt_opt.
        WHEN `NO-GAP`.
          INSERT VALUE #( name = `no_gap` value = `abap_true` ) INTO TABLE lt_opt.
        WHEN `NO-ZERO`.
          INSERT VALUE #( name = `no_zero` value = `abap_true` ) INTO TABLE lt_opt.
        WHEN `NO-SIGN`.
          INSERT VALUE #( name = `no_sign` value = `abap_true` ) INTO TABLE lt_opt.
        WHEN `NO-GROUPING`.
          INSERT VALUE #( name = `no_grouping` value = `abap_true` ) INTO TABLE lt_opt.
        WHEN `LEFT-JUSTIFIED`.
          INSERT VALUE #( name = `justify` value = `z2ui5_cl_cgui_list=>cs_justify-left` ) INTO TABLE lt_opt.
        WHEN `CENTERED`.
          INSERT VALUE #( name = `justify` value = `z2ui5_cl_cgui_list=>cs_justify-center` ) INTO TABLE lt_opt.
        WHEN `RIGHT-JUSTIFIED`.
          INSERT VALUE #( name = `justify` value = `z2ui5_cl_cgui_list=>cs_justify-right` ) INTO TABLE lt_opt.
        WHEN `CURRENCY`.
          INSERT VALUE #( name = `currency` value = operand( tok( tokens = lt_tok index = lv_opt_index + 1 ) ) ) INTO TABLE lt_opt.
        WHEN `UNIT`.
          INSERT VALUE #( name = `unit` value = operand( tok( tokens = lt_tok index = lv_opt_index + 1 ) ) ) INTO TABLE lt_opt.
        WHEN `DECIMALS`.
          INSERT VALUE #( name = `decimals` value = operand( tok( tokens = lt_tok index = lv_opt_index + 1 ) ) ) INTO TABLE lt_opt.
        WHEN `ROUND`.
          INSERT VALUE #( name = `round` value = operand( tok( tokens = lt_tok index = lv_opt_index + 1 ) ) ) INTO TABLE lt_opt.
        WHEN `QUICKINFO`.
          INSERT VALUE #( name = `quickinfo` value = operand( texts_resolve( tok( tokens = lt_tok index = lv_opt_index + 1 ) ) ) ) INTO TABLE lt_opt.
        WHEN `USING`.
          IF to_upper( tok( tokens = lt_tok index = lv_opt_index + 1 ) ) = `EDIT`.
            INSERT VALUE #( name = `edit_mask` value = operand( tok( tokens = lt_tok index = lv_opt_index + 3 ) ) ) INTO TABLE lt_opt.
          ENDIF.
        WHEN `TIME`.
          IF to_upper( tok( tokens = lt_tok index = lv_opt_index + 1 ) ) = `ZONE`.
            INSERT VALUE #( name = `time_zone` value = operand( tok( tokens = lt_tok index = lv_opt_index + 2 ) ) ) INTO TABLE lt_opt.
          ENDIF.
        WHEN `DD/MM/YY` OR `MM/DD/YY` OR `DD/MM/YYYY` OR `MM/DD/YYYY` OR `DDMMYY` OR `MMDDYY` OR `YYMMDD`.
          INSERT VALUE #( name = `date_format` value = date_format_of( to_upper( lv_opt ) ) ) INTO TABLE lt_opt.
        WHEN `EXPONENT` OR `FRAMES`.
          note( `WRITE: EXPONENT and FRAMES have no counterpart` ) ##NO_TEXT.
        WHEN `AS`.
          CASE to_upper( tok( tokens = lt_tok index = lv_opt_index + 1 ) ).
            WHEN `CHECKBOX`.
              lv_kind = `checkbox`.
            WHEN `ICON`.
              lv_kind = `icon`.
              note( `WRITE ... AS ICON: write_as_icon( ) takes a UI5 icon (sap-icon://...) instead of an ICON_ constant` ) ##NO_TEXT.
            WHEN `LINE` OR `SYMBOL`.
              note( `WRITE ... AS LINE / AS SYMBOL have no counterpart` ) ##NO_TEXT.
          ENDCASE.
      ENDCASE.
    ENDLOOP.

    IF lv_new = abap_true.
      INSERT `list( )->new_line( ).` INTO TABLE result.
    ENDIF.
    IF lv_dobj IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_dobj_written) = lv_dobj.
    lv_dobj = texts_resolve( lv_dobj ).
    REPLACE ALL OCCURRENCES OF PCRE `(?i)^sy-pagno$` IN lv_dobj WITH `list( )->current_page( )`.
    REPLACE ALL OCCURRENCES OF PCRE `(?i)^sy-linno$` IN lv_dobj WITH `list( )->current_line( )`.
    REPLACE ALL OCCURRENCES OF PCRE `(?i)^sy-colno$` IN lv_dobj WITH `list( )->current_column( )`.
    REPLACE ALL OCCURRENCES OF PCRE `(?i)^sy-lisel$` IN lv_dobj WITH `lisel( )`.
    IF lv_dobj(1) = `'`.
      lv_dobj = literal( unquote( lv_dobj ) ).
    ELSEIF lv_dobj(1) <> '`' AND lv_dobj(1) <> `|`.
      lv_dobj = to_lower( lv_dobj ).
    ENDIF.

    CASE lv_kind.
      WHEN `checkbox`.
        INSERT |list( )->write_as_checkbox( { lv_dobj } ).| INTO TABLE result.
        RETURN.
      WHEN `icon`.
        INSERT |list( )->write_as_icon( { lv_dobj } ).| INTO TABLE result.
        RETURN.
    ENDCASE.

    INSERT VALUE #( name = `val` value = lv_dobj ) INTO TABLE lt_param.
    IF lv_pos IS NOT INITIAL.
      INSERT VALUE #( name = `pos` value = lv_pos ) INTO TABLE lt_param.
    ENDIF.
    IF lv_len IS NOT INITIAL.
      INSERT VALUE #( name = `len` value = lv_len ) INTO TABLE lt_param.
    ENDIF.
    IF lv_color IS NOT INITIAL.
      INSERT VALUE #( name = `color` value = |z2ui5_cl_cgui_list=>cs_color-{ lv_color }| ) INTO TABLE lt_param.
    ENDIF.
    IF lv_hotspot = abap_true.
      INSERT VALUE #( name = `hotspot` value = `abap_true` ) INTO TABLE lt_param.
    ENDIF.
    IF lv_intensified = abap_true.
      INSERT VALUE #( name = `intensified` value = `abap_true` ) INTO TABLE lt_param.
    ENDIF.
    IF lv_inverse = abap_true.
      INSERT VALUE #( name = `inverse` value = `abap_true` ) INTO TABLE lt_param.
    ENDIF.
    IF lv_input = abap_true.
      INSERT VALUE #( name = `input` value = `abap_true` ) INTO TABLE lt_param.
    ENDIF.
    INSERT LINES OF lt_opt INTO TABLE lt_param.
    " the field a later WRITE ... UNDER refers to
    DATA(lv_under_name) = to_upper( unquote( lv_dobj_written ) ).
    IF line_exists( mt_under[ table_line = lv_under_name ] ).
      INSERT VALUE #( name = `name` value = literal( lv_under_name ) ) INTO TABLE lt_param.
    ENDIF.

    IF lines( lt_param ) = 1.
      INSERT |write( { lv_dobj } ).| INTO TABLE result.
    ELSE.
      INSERT LINES OF call_code( prefix = `write(`
                                 params = lt_param ) INTO TABLE result.
    ENDIF.

  ENDMETHOD.

  METHOD message.

    " MESSAGE e001(zmsg) WITH ..., MESSAGE ID ... TYPE ... NUMBER ...,
    " MESSAGE text TYPE t - INTO and RAISING stay as they are
    DATA lv_type   TYPE string.
    DATA lv_number TYPE string.
    DATA lv_id     TYPE string.
    DATA lt_param  TYPE ty_t_param.
    DATA lv_with   TYPE i.

    DATA(lt_tok) = tokens( code ).
    DATA(lv_upper) = to_upper( code ).
    IF lv_upper CS ` INTO ` OR lv_upper CS ` RAISING `.
      RETURN.
    ENDIF.

    DATA(lv_2) = tok( tokens = lt_tok index = 2 ).
    DATA(lv_2u) = to_upper( lv_2 ).

    IF matches( val = lv_2u pcre = `^[AEISWX]\d{3}(\(.+\))?$` ).
      lv_type = lv_2u(1).
      lv_number = lv_2u+1(3).
      IF lv_2u CA `(`.
        lv_id = substring_before( val = substring_after( val = lv_2u sub = `(` ) sub = `)` ).
      ELSE.
        lv_id = mv_msgid.
      ENDIF.
      INSERT VALUE #( name = `id` value = literal( lv_id ) ) INTO TABLE lt_param.
      INSERT VALUE #( name = `number` value = lv_number ) INTO TABLE lt_param.
      INSERT VALUE #( name = `type` value = literal( lv_type ) ) INTO TABLE lt_param.
      lv_with = tok_index( tokens = lt_tok word = `WITH` ).
    ELSEIF lv_2u = `ID`.
      LOOP AT lt_tok INTO DATA(lv_tok).
        DATA(lv_i) = sy-tabix.
        CASE to_upper( lv_tok ).
          WHEN `ID`.
            INSERT VALUE #( name = `id` value = tok( tokens = lt_tok index = lv_i + 1 ) ) INTO TABLE lt_param.
          WHEN `NUMBER`.
            INSERT VALUE #( name = `number` value = tok( tokens = lt_tok index = lv_i + 1 ) ) INTO TABLE lt_param.
          WHEN `TYPE`.
            INSERT VALUE #( name = `type` value = tok( tokens = lt_tok index = lv_i + 1 ) ) INTO TABLE lt_param.
          WHEN `WITH`.
            lv_with = lv_i.
        ENDCASE.
      ENDLOOP.
    ELSE.
      " MESSAGE text TYPE t [DISPLAY LIKE d]
      DATA(lv_t) = tok_index( tokens = lt_tok word = `TYPE` ).
      IF lv_t = 0.
        RETURN.
      ENDIF.
      DATA(lv_text) = texts_resolve( lv_2 ).
      IF lv_text(1) = `'`.
        lv_text = literal( unquote( lv_text ) ).
      ENDIF.
      INSERT |message( text = { lv_text }| INTO TABLE result.
      INSERT |         type = { tok( tokens = lt_tok index = lv_t + 1 ) } ).| INTO TABLE result.
      RETURN.
    ENDIF.

    IF lv_with > 0.
      DATA(lv_v) = 0.
      DATA(lv_with_from) = lv_with + 1.
      LOOP AT lt_tok INTO lv_tok FROM lv_with_from.
        IF to_upper( lv_tok ) = `DISPLAY` OR lv_v = 4.
          EXIT.
        ENDIF.
        lv_v = lv_v + 1.
        INSERT VALUE #( name = |v{ lv_v }| value = texts_resolve( lv_tok ) ) INTO TABLE lt_param.
      ENDLOOP.
    ENDIF.

    INSERT LINES OF call_code( prefix = `message_t100(`
                               params = lt_param ) INTO TABLE result.

  ENDMETHOD.

  METHOD perform.

    " PERFORM form USING a b CHANGING c TABLES t - the call of its method
    DATA lt_param TYPE ty_t_param.
    DATA lv_kind  TYPE c LENGTH 1.
    DATA lt_actual TYPE STANDARD TABLE OF ty_s_form_param WITH EMPTY KEY.

    DATA(lt_tok) = tokens( code ).
    DATA(lv_upper) = to_upper( code ).
    IF lv_upper CS ` IN PROGRAM ` OR lv_upper CS `(` OR lv_upper CS ` IF FOUND` OR lv_upper CS ` ON COMMIT` OR lv_upper CS ` ON ROLLBACK`.
      note( `PERFORM IN PROGRAM, dynamic and ON COMMIT PERFORMs stay as they are` ) ##NO_TEXT.
      RETURN.
    ENDIF.

    DATA(lv_name) = to_lower( tok( tokens = lt_tok index = 2 ) ).
    READ TABLE mt_form INTO DATA(ls_form) WITH KEY name = lv_name.
    IF sy-subrc <> 0.
      note( |PERFORM { lv_name }: the FORM is not part of the source - it stays a PERFORM| ) ##NO_TEXT.
      RETURN.
    ENDIF.

    LOOP AT lt_tok INTO DATA(lv_tok) FROM 3.
      CASE to_upper( lv_tok ).
        WHEN `USING`.
          lv_kind = `U`.
        WHEN `CHANGING`.
          lv_kind = `C`.
        WHEN `TABLES`.
          lv_kind = `T`.
        WHEN OTHERS.
          INSERT VALUE #( kind = lv_kind name = lv_tok ) INTO TABLE lt_actual.
      ENDCASE.
    ENDLOOP.

    " the formal parameters in their order, group by group
    DATA(lt_formal_u) = VALUE ty_t_form_param( FOR ls_p IN ls_form-params WHERE ( kind = `U` ) ( ls_p ) ).
    DATA(lt_formal_c) = VALUE ty_t_form_param( FOR ls_p IN ls_form-params WHERE ( kind = `C` OR kind = `T` ) ( ls_p ) ).
    DATA(lt_actual_u) = VALUE ty_t_form_param( FOR ls_a IN lt_actual WHERE ( kind = `U` ) ( ls_a ) ).
    DATA(lt_actual_c) = VALUE ty_t_form_param( FOR ls_a IN lt_actual WHERE ( kind = `T` ) ( ls_a ) ).
    INSERT LINES OF VALUE ty_t_form_param( FOR ls_a IN lt_actual WHERE ( kind = `C` ) ( ls_a ) ) INTO TABLE lt_actual_c.
    IF lines( lt_formal_u ) <> lines( lt_actual_u ) OR lines( lt_formal_c ) <> lines( lt_actual_c ).
      note( |PERFORM { lv_name }: the parameters do not match the FORM - it stays a PERFORM| ) ##NO_TEXT.
      RETURN.
    ENDIF.

    IF lt_formal_u IS INITIAL AND lt_formal_c IS INITIAL.
      INSERT |{ lv_name }( ).| INTO TABLE result.
      RETURN.
    ENDIF.

    LOOP AT lt_formal_u INTO DATA(ls_formal).
      INSERT VALUE #( name = ls_formal-name value = to_lower( lt_actual_u[ sy-tabix ]-name ) ) INTO TABLE lt_param.
    ENDLOOP.
    IF lt_formal_c IS NOT INITIAL.
      INSERT VALUE #( name = `` value = `CHANGING` ) INTO TABLE lt_param.
      LOOP AT lt_formal_c INTO ls_formal.
        INSERT VALUE #( name = ls_formal-name value = to_lower( lt_actual_c[ sy-tabix ]-name ) ) INTO TABLE lt_param.
      ENDLOOP.
      IF lt_formal_u IS NOT INITIAL.
        INSERT VALUE #( name = `` value = `EXPORTING` ) INTO lt_param INDEX 1.
      ENDIF.
    ENDIF.

    INSERT LINES OF call_code( prefix = |{ lv_name }(|
                               params = lt_param ) INTO TABLE result.

  ENDMETHOD.

  METHOD call_code.

    " prefix( p1 = v1
    "         p2 = v2 ). - the parameters aligned, a keyword (name empty)
    " on a line of its own
    DATA lv_width TYPE i.

    LOOP AT params INTO DATA(ls_param) WHERE name IS NOT INITIAL.
      lv_width = nmax( val1 = lv_width val2 = strlen( ls_param-name ) ).
    ENDLOOP.

    DATA(lv_blank) = repeat( val = ` ` occ = strlen( prefix ) + 1 ).
    DATA(lv_first) = abap_true.
    DATA(lv_count) = lines( params ).
    LOOP AT params INTO ls_param.
      DATA(lv_index) = sy-tabix.
      DATA(lv_text) = COND string( WHEN ls_param-name IS INITIAL THEN ls_param-value
                                   ELSE |{ ls_param-name }{ repeat( val = ` ` occ = lv_width - strlen( ls_param-name ) ) } = { ls_param-value }| ).
      IF lv_index = lv_count.
        lv_text = |{ lv_text } ).|.
      ENDIF.
      IF lv_first = abap_true.
        INSERT |{ prefix } { lv_text }| INTO TABLE result.
        lv_first = abap_false.
      ELSE.
        INSERT |{ lv_blank }{ lv_text }| INTO TABLE result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD items_code.

    DATA lt_params TYPE ty_t_param.

    LOOP AT mt_item INTO DATA(ls_item) WHERE screen = screen.
      lt_params = ls_item-params.
      IF ls_item-field IS NOT INITIAL AND line_exists( mt_help[ table_line = ls_item-field ] )
          AND NOT line_exists( lt_params[ name = `value_help` ] ) AND ls_item-method <> `checkbox` AND ls_item-method <> `radiobutton`.
        INSERT VALUE #( name = `value_help` value = `abap_true` ) INTO TABLE lt_params.
      ENDIF.
      DATA(lv_prefix) = |screen->{ ls_item-method }(|.
      IF lt_params IS INITIAL.
        INSERT |{ lv_prefix } ).| INTO TABLE result.
      ELSEIF lines( lt_params ) = 1 AND ( lt_params[ 1 ]-name = `title` OR lt_params[ 1 ]-name = `val` OR lt_params[ 1 ]-name = `text` ).
        INSERT |{ lv_prefix } { lt_params[ 1 ]-value } ).| INTO TABLE result.
      ELSE.
        INSERT LINES OF call_code( prefix = lv_prefix
                                   params = lt_params ) INTO TABLE result.
      ENDIF.
      " a tab holds the fields of its subscreen
      IF ls_item-subscreen IS NOT INITIAL.
        INSERT LINES OF items_code( screen = ls_item-subscreen
                                    indent = 0 ) INTO TABLE result.
      ENDIF.
    ENDLOOP.

    result = indent( lines = result
                     by    = indent ).

  ENDMETHOD.

  METHOD generate.

    DATA lt_def  TYPE string_table.
    DATA lt_impl TYPE string_table.
    DATA lt_body TYPE string_table.
    DATA lt_case TYPE string_table.
    DATA lt_done TYPE string_table.

    " the methods: the screen, the events and the FORMs
    IF line_exists( mt_item[ screen = `` ] ).
      INSERT `METHODS selection_screen REDEFINITION.` INTO TABLE lt_def.
      INSERT `METHOD selection_screen.` INTO TABLE lt_impl.
      INSERT `` INTO TABLE lt_impl.
      INSERT LINES OF items_code( screen = `` indent = 2 ) INTO TABLE lt_impl.
      INSERT `` INTO TABLE lt_impl.
      INSERT `ENDMETHOD.` INTO TABLE lt_impl.
      INSERT `` INTO TABLE lt_impl.
    ENDIF.

    IF mt_window IS NOT INITIAL.
      INSERT `METHODS selection_screen_dynnr REDEFINITION.` INTO TABLE lt_def.
      INSERT `METHOD selection_screen_dynnr.` INTO TABLE lt_impl.
      INSERT `` INTO TABLE lt_impl.
      INSERT `  CASE dynnr.` INTO TABLE lt_impl.
      LOOP AT mt_window INTO DATA(lv_window).
        INSERT |    WHEN { literal( lv_window ) }.| INTO TABLE lt_impl.
        INSERT LINES OF items_code( screen = lv_window indent = 6 ) INTO TABLE lt_impl.
      ENDLOOP.
      INSERT `  ENDCASE.` INTO TABLE lt_impl.
      INSERT `` INTO TABLE lt_impl.
      INSERT `ENDMETHOD.` INTO TABLE lt_impl.
      INSERT `` INTO TABLE lt_impl.
    ENDIF.

    " the DEFAULT values open initialization( )
    IF mt_init IS NOT INITIAL AND NOT line_exists( mt_event[ method = `initialization` ] ).
      INSERT VALUE #( method = `initialization` ) INTO TABLE mt_event.
    ENDIF.
    SORT mt_event BY method.

    LOOP AT mt_event INTO DATA(ls_event).
      IF line_exists( lt_done[ table_line = ls_event-method ] ).
        CONTINUE.
      ENDIF.
      INSERT ls_event-method INTO TABLE lt_done.
      CLEAR lt_body.

      CASE ls_event-method.
        WHEN `on_help_request`.
          " no counterpart - kept as a comment after the class
          LOOP AT mt_event INTO DATA(ls_comment) WHERE method = ls_event-method.
            INSERT |" { ls_event-method } { ls_comment-key }| INTO TABLE mt_local.
            LOOP AT dedent( ls_comment-lines ) INTO DATA(lv_comment).
              INSERT |" { lv_comment }| INTO TABLE mt_local.
            ENDLOOP.
          ENDLOOP.
          CONTINUE.
        WHEN `at_value_request` OR `at_selection_screen_on` OR `at_selection_screen_on_help`
            OR `at_selection_screen_on_block` OR `at_selection_screen_on_radio` OR `at_selection_screen_on_end_of`.
          " one method for every field - a CASE over field (block, group);
          " s-low and s-high of ON VALUE-REQUEST share the WHEN of s
          DATA(lv_param) = event_param( ls_event-method ).
          INSERT |CASE { lv_param }.| INTO TABLE lt_body.
          DATA lt_keys TYPE string_table.
          CLEAR lt_keys.
          LOOP AT mt_event INTO DATA(ls_field) WHERE method = ls_event-method.
            DATA(lv_field_key) = to_upper( substring_before( val = |{ ls_field-key }-| sub = `-` ) ).
            IF NOT line_exists( lt_keys[ table_line = lv_field_key ] ).
              INSERT lv_field_key INTO TABLE lt_keys.
            ENDIF.
          ENDLOOP.
          LOOP AT lt_keys INTO DATA(lv_key_name).
            INSERT |  WHEN { literal( lv_key_name ) }.| INTO TABLE lt_body.
            LOOP AT mt_event INTO ls_field WHERE method = ls_event-method.
              IF to_upper( substring_before( val = |{ ls_field-key }-| sub = `-` ) ) <> lv_key_name.
                CONTINUE.
              ENDIF.
              DATA(lv_part) = to_upper( substring_after( val = ls_field-key sub = `-` ) ).
              IF lv_part = `LOW` OR lv_part = `HIGH`.
                INSERT |    IF value_request_part( ) = { literal( lv_part ) }.| INTO TABLE lt_body.
                INSERT LINES OF indent( lines = dedent( ls_field-lines ) by = 6 ) INTO TABLE lt_body.
                INSERT `    ENDIF.` INTO TABLE lt_body.
              ELSE.
                INSERT LINES OF indent( lines = dedent( ls_field-lines ) by = 4 ) INTO TABLE lt_body.
              ENDIF.
            ENDLOOP.
          ENDLOOP.
          IF ls_event-method = `at_value_request`.
            INSERT `  WHEN OTHERS.` INTO TABLE lt_body.
            INSERT `    super->at_value_request( field ).` INTO TABLE lt_body.
          ELSEIF ls_event-method = `at_selection_screen_on_help`.
            INSERT `  WHEN OTHERS.` INTO TABLE lt_body.
            INSERT `    super->at_selection_screen_on_help( field ).` INTO TABLE lt_body.
          ENDIF.
          INSERT `ENDCASE.` INTO TABLE lt_body.
        WHEN OTHERS.
          IF ls_event-method = `initialization`.
            INSERT LINES OF mt_init INTO TABLE lt_body.
            IF mt_init IS NOT INITIAL AND ls_event-lines IS NOT INITIAL.
              INSERT `` INTO TABLE lt_body.
            ENDIF.
          ENDIF.
          " LINE-SIZE and LINE-COUNT of REPORT open the run
          IF ls_event-method = `start_of_selection` AND mt_start IS NOT INITIAL.
            INSERT LINES OF mt_start INTO TABLE lt_body.
            INSERT `` INTO TABLE lt_body.
          ENDIF.
          INSERT LINES OF dedent( ls_event-lines ) INTO TABLE lt_body.
      ENDCASE.

      INSERT |METHODS { ls_event-method } REDEFINITION.| INTO TABLE lt_def.
      INSERT |METHOD { ls_event-method }.| INTO TABLE lt_impl.
      INSERT `` INTO TABLE lt_impl.
      INSERT LINES OF indent( lines = lt_body by = 2 ) INTO TABLE lt_impl.
      INSERT `` INTO TABLE lt_impl.
      INSERT `ENDMETHOD.` INTO TABLE lt_impl.
      INSERT `` INTO TABLE lt_impl.
    ENDLOOP.

    LOOP AT mt_form INTO DATA(ls_form).
      DATA(lt_formal_i) = VALUE ty_t_form_param( FOR ls_p IN ls_form-params WHERE ( kind = `U` ) ( ls_p ) ).
      DATA(lt_formal_c) = VALUE ty_t_form_param( FOR ls_p IN ls_form-params WHERE ( kind = `C` OR kind = `T` ) ( ls_p ) ).
      IF ls_form-params IS INITIAL.
        INSERT |METHODS { ls_form-name }.| INTO TABLE lt_def.
      ELSE.
        INSERT |METHODS { ls_form-name }| INTO TABLE lt_def.
        IF lt_formal_i IS NOT INITIAL.
          INSERT `  IMPORTING` INTO TABLE lt_def.
          LOOP AT lt_formal_i INTO DATA(ls_formal).
            INSERT |    { ls_formal-name } { to_lower( ls_formal-type ) }| INTO TABLE lt_def.
          ENDLOOP.
        ENDIF.
        IF lt_formal_c IS NOT INITIAL.
          INSERT `  CHANGING` INTO TABLE lt_def.
          LOOP AT lt_formal_c INTO ls_formal.
            INSERT |    { ls_formal-name } { to_lower( ls_formal-type ) }| INTO TABLE lt_def.
          ENDLOOP.
        ENDIF.
        lt_def[ lines( lt_def ) ] = |{ lt_def[ lines( lt_def ) ] }.|.
        IF line_exists( ls_form-params[ type = `TYPE any` ] ) OR line_exists( ls_form-params[ kind = `T` ] ).
          note( |{ ls_form-name }: untyped and TABLES parameters became TYPE any / TYPE STANDARD TABLE - type them| ) ##NO_TEXT.
        ENDIF.
        IF lt_formal_i IS NOT INITIAL.
          note( `USING parameters of FORMs became IMPORTING - a FORM that changes them needs CHANGING` ) ##NO_TEXT.
        ENDIF.
      ENDIF.
      INSERT |METHOD { ls_form-name }.| INTO TABLE lt_impl.
      INSERT `` INTO TABLE lt_impl.
      INSERT LINES OF indent( lines = dedent( ls_form-lines ) by = 2 ) INTO TABLE lt_impl.
      INSERT `` INTO TABLE lt_impl.
      INSERT `ENDMETHOD.` INTO TABLE lt_impl.
      INSERT `` INTO TABLE lt_impl.
    ENDLOOP.

    " the class
    INSERT |CLASS { class } DEFINITION PUBLIC| INTO TABLE result.
    INSERT `  INHERITING FROM z2ui5_cl_cgui_report` INTO TABLE result.
    INSERT `  FINAL` INTO TABLE result.
    INSERT `  CREATE PUBLIC.` INTO TABLE result.
    INSERT `` INTO TABLE result.
    INSERT `  PUBLIC SECTION.` INTO TABLE result.
    INSERT LINES OF indent( lines = mt_public by = 4 ) INTO TABLE result.
    IF mt_public IS NOT INITIAL AND mt_field IS NOT INITIAL.
      INSERT `` INTO TABLE result.
    ENDIF.
    INSERT LINES OF indent( lines = mt_field by = 4 ) INTO TABLE result.
    INSERT `` INTO TABLE result.
    INSERT `  PROTECTED SECTION.` INTO TABLE result.
    INSERT LINES OF indent( lines = lt_def by = 4 ) INTO TABLE result.
    INSERT `` INTO TABLE result.
    INSERT `  PRIVATE SECTION.` INTO TABLE result.
    INSERT `ENDCLASS.` INTO TABLE result.
    INSERT `` INTO TABLE result.
    INSERT `` INTO TABLE result.
    INSERT |CLASS { class } IMPLEMENTATION.| INTO TABLE result.
    INSERT `` INTO TABLE result.
    INSERT LINES OF indent( lines = lt_impl by = 2 ) INTO TABLE result.
    INSERT `ENDCLASS.` INTO TABLE result.

    IF mt_local IS NOT INITIAL.
      INSERT `` INTO TABLE result.
      INSERT `" ----------------------------------------------------------------------` INTO TABLE result ##NO_TEXT.
      INSERT `" taken over from the report - put it into the local types of the class` INTO TABLE result ##NO_TEXT.
      INSERT `" ----------------------------------------------------------------------` INTO TABLE result ##NO_TEXT.
      INSERT LINES OF mt_local INTO TABLE result.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
