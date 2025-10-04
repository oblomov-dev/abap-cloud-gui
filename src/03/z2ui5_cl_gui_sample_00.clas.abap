CLASS z2ui5_cl_gui_sample_00 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC INHERITING FROM z2ui5_cl_gui_report.

  PUBLIC SECTION.

    METHODS on_event REDEFINITION.
    METHODS on_start REDEFINITION.
    METHODS on_navigated REDEFINITION.
    METHODS on_value_help REDEFINITION.

    DATA mv_date TYPE d.
    DATA mv_value TYPE string.
    DATA mv_flag TYPE abap_bool.
    DATA so_matnr TYPE RANGE OF matnr.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS z2ui5_cl_gui_sample_00 IMPLEMENTATION.


  METHOD on_start.

    mv_value = `init value`.

*    LOOP AT _screen REFERENCE INTO DATA(lr_screen).
*
*    ENDLOOP.
*
**    _parameters( v = mv_arbgb f4 = 'T100'  ).
*    _parameters( v = mv_value  ).
*    _parameters( v = mv_date radiobutton_group = 'GRP1' radiobutton_default = abap_true ).
*    _parameters( v = mv_flag as_checkbox = abap_true ).
*
*    _select_options( v = so_matnr  name_tmp = 'SO_MATNR' ).
**    _select_options( v = so_kunnr  name_tmp = 'SO_KUNNR' ).

  ENDMETHOD.

  METHOD on_event.

**    SELECT FROM t100 FIELDS *
**    INTO TABLE @DATA(lt_t100)
**    UP TO 10 ROWS.
*
**    "ABAP memory using buffer
*    DATA:buffer       TYPE xstring,
*         lt_input_bf  TYPE STANDARD TABLE OF I_UnitOfMeasure,
*         lt_output_bf TYPE STANDARD TABLE OF I_UnitOfMeasure.
**
**    SELECT *  FROM I_UnitOfMeasure INTO TABLE @lt_input_bf.
**    EXPORT input = lt_input_bf TO DATA BUFFER buffer.
**    IMPORT input = lt_output_bf FROM DATA BUFFER buffer.
*
*    _write( `test` )->_write( `test 2` ).
*    _write( `test` ).
**    _write( lt_t100 ).
*    _msg( 'Datensatz wurde erfolgreich gespeichert' ).
*    _msg( )->e( 'Datensatz wurde erfolgreich gespeichert' ).
*
*    _popup( `ABC` )->decide( 'ARE YOU SURE?' ).

  ENDMETHOD.

  METHOD on_value_help.

*    CASE val.
*
*      WHEN REF #( so_matnr ).
*        _screen[ ref_data = REF #( so_matnr ) ]-changeable_ind = abap_false.
*
*    ENDCASE.
*
*
**        __log->add( )
**        __log( )->e( ).
*
*    __->uuid_get_c22( ).
**        __bus( )->
*
**            __->
**    zacgui_cl_program=>test( ).

  ENDMETHOD.

  METHOD on_navigated.

*    CASE on_nav_active.
*      WHEN `ABC`.
*        IF `abc` =  _popup( `ABC` )->ms_result-check_yes.
*
*        ENDIF.
*
*    ENDCASE.
*

  ENDMETHOD.

ENDCLASS.
