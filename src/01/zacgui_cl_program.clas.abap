CLASS zacgui_cl_program DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF  ty_s_token,
        name             TYPE string,
        t_tokens         TYPE z2ui5_cl_util=>ty_t_token,
        t_tokens_added   TYPE z2ui5_cl_util=>ty_t_token,
        t_tokens_removed TYPE z2ui5_cl_util=>ty_t_token,
      END OF ty_s_token.
    DATA mt_tt_token TYPE STANDARD TABLE OF ty_S_token WITH EMPTY KEY.

    CLASS-DATA __ TYPE REF TO z2ui5_cl_util.

    DATA:
      BEGIN OF s_view,
        message TYPE string,
        input   TYPE string,
      END OF s_view.

    data on_nav_active type string.

    TYPES:
      BEGIN OF s_screen,
        ref_data        TYPE REF TO data,
        selname         TYPE  string,
        kind            TYPE  string,
        datatype        TYPE  string,
        length          TYPE  int4,
        decimals        TYPE  int4,
        component_type  TYPE  string,
        section_text    TYPE  string,
        group_text      TYPE  string,
        param_text      TYPE  string,
        lowercase_ind   TYPE  abap_bool,
        hidden_ind      TYPE  abap_bool,
        changeable_ind  TYPE  abap_bool,
        mandatory_ind   TYPE  abap_bool,
        checkbox_ind    TYPE  abap_bool,
        list_ind        TYPE  abap_bool,
        radio_group_ind TYPE  abap_bool,
        radio_group_id  TYPE  c LENGTH 4,
        valueStateText  TYPE  string,
        valueState      TYPE  string,
      END OF s_screen.
    DATA _screen TYPE STANDARD TABLE OF s_screen WITH EMPTY KEY.


    METHODS _throw
      IMPORTING
        v  TYPE clike OPTIONAL
        no TYPE clike OPTIONAL
          PREFERRED PARAMETER v.

    METHODS _write
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE REF TO zacgui_cl_program.

    METHODS _msg_box
      IMPORTING
        v    TYPE clike OPTIONAL
        no   TYPE clike OPTIONAL
        id   TYPE clike OPTIONAL
        type TYPE clike DEFAULT 'I'
          PREFERRED PARAMETER v.

    METHODS _msg
      IMPORTING
                v             TYPE clike OPTIONAL
                no            TYPE clike OPTIONAL
                id            TYPE clike OPTIONAL
                type          TYPE clike DEFAULT 'I'
                  PREFERRED PARAMETER v
      RETURNING VALUE(result) TYPE REF TO zacgui_cl_msg.

    METHODS _POPUP
      IMPORTING
                v             TYPE clike OPTIONAL
                no            TYPE clike OPTIONAL
                id            TYPE clike OPTIONAL
                type          TYPE clike DEFAULT 'I'
                  PREFERRED PARAMETER v
      RETURNING VALUE(result) TYPE REF TO zacgui_cl_POPUP.

    METHODS _msg_e
      IMPORTING
        v  TYPE clike OPTIONAL
        no TYPE clike OPTIONAL
        id TYPE clike OPTIONAL
          PREFERRED PARAMETER v.

    METHODS _msg_w
      IMPORTING
        v  TYPE clike OPTIONAL
        no TYPE clike OPTIONAL
        id TYPE clike OPTIONAL
          PREFERRED PARAMETER v.

    CLASS-METHODS test.

    METHODS _parameters
      IMPORTING
        v                   TYPE any
        radiobutton_group   TYPE clike OPTIONAL
        radiobutton_default TYPE abap_bool OPTIONAL
        as_checkbox         TYPE abap_bool DEFAULT abap_false
        f4                  TYPE string OPTIONAL.

    METHODS _parameters_rb
      IMPORTING
        v                   TYPE any
        radiobutton_group   TYPE clike OPTIONAL
        radiobutton_default TYPE abap_bool OPTIONAL
        as_checkbox         TYPE abap_bool DEFAULT abap_false
        f4                  TYPE string OPTIONAL.

    METHODS _parameters_cb
      IMPORTING
        v                   TYPE any
        radiobutton_group   TYPE clike OPTIONAL
        radiobutton_default TYPE abap_bool OPTIONAL
        as_checkbox         TYPE abap_bool DEFAULT abap_false
        f4                  TYPE string OPTIONAL.

    METHODS _select_options
      IMPORTING
        v        TYPE any
        name_tmp TYPE string.
*        radiobutton_group type clike optional
*        default type abap_bool optional.

    METHODS init_screen
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_xml_view.
    METHODS on_init.
    METHODS on_event
      IMPORTING
        list TYPE REF TO zdev_cl_sls_list_renderer.
    METHODS on_definintion.

    METHODS on_navigated
      IMPORTING
        val TYPE REF TO data.

    METHODS on_value_help
      IMPORTING
        val TYPE REF TO data.

    DATA:
      BEGIN OF _sy,
        title TYPE string,
        ucomm TYPE string,
        tcode TYPE string,
        uname TYPE string,
      END OF _sy.

    DATA mt_messaging TYPE z2ui5_cl_cc_messaging=>ty_t_items.

    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.

  PROTECTED SECTION.

    DATA check_initialized TYPE abap_bool.
    DATA client TYPE REF TO z2ui5_if_client.
    DATA page TYPE REF TO z2ui5_cl_xml_view.
    DATA page_before TYPE string.


  PRIVATE SECTION.
    DATA: mv_name_f4 TYPE string.
    METHODS display_popover_message.
ENDCLASS.



CLASS zacgui_cl_program IMPLEMENTATION.


  METHOD display_popover_message.

    DATA(popup) = z2ui5_cl_xml_view=>factory_popup( ).

    popup = popup->message_popover(
              placement = `Top`
               items      = client->_bind_edit( mt_messaging )
               groupitems = abap_true
               afterclose = client->_event( `POPOVER_CLOSE` )
        )->message_item(
            type        = `{TYPE}`
            title       = `{MESSAGE}`
            subtitle    = `{MESSAGE}`
            description = `{DESCRIPTION}`
            groupname   = `{GROUP}` ).

    client->popover_display( xml = popup->stringify( ) by_id = `msgPopover` ).


  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    __ = NEW #( ).
    me->client = client.

    CLEAR s_view-message.

    IF check_initialized = abap_false.
      check_initialized = abap_true.
      page = init_screen( ).
      on_definintion( ).
      on_init( ).
      client->view_display( page->stringify( ) ).
      page_before = page->stringify( ).
      RETURN.
    ENDIF.

    IF client->get( )-check_on_navigated = abap_true.
      TRY.
          DATA(lo_value_help) = CAST z2ui5_cl_pop_get_range( client->get_app( client->get( )-s_draft-id_prev_app ) ).
          IF lo_value_help->result( )-check_confirmed = abap_true.
            FIELD-SYMBOLS <lt_table> TYPE ANY TABLE.
            ASSIGN me->(mv_name_f4) TO <lt_table>.
            <lt_table> = CORRESPONDING #( lo_value_help->result( )-t_range ).
            mt_tt_token[ name = mv_name_f4 ]-t_tokens = z2ui5_cl_util=>filter_get_token_t_by_range_t( <lt_table> ).
            "set_data( ).
            client->view_model_update( ).
            RETURN.
          ENDIF.
        CATCH cx_root.
      ENDTRY.
      RETURN.
    ENDIF.

    CASE client->get( )-event.


      WHEN 'POPOVER'.
        display_popover_message(  ).

      WHEN 'ZZSUBMIT'.
        TRY.
            CASE s_view-input(2).
              WHEN `/o`.
                DATA(lv_url) = z2ui5_cl_core_srv_util=>app_get_url(
                   client    = client
                   classname = z2ui5_cl_util=>rtti_get_classname_by_ref( me )
                   ).
                client->follow_up_action( client->_event_client( val = client->cs_event-open_new_tab t_arg = VALUE #(  ( lv_url ) ) ) ).
                RETURN.
              WHEN `/n`.
                client->nav_app_leave( NEW zacgui_cl_program( ) ).
            ENDCASE.
          CATCH cx_root.
        ENDTRY.

      WHEN 'F3'.
        client->view_display( page_before ).

      WHEN 'F8'.
        page = init_screen( ).
        on_event( NEW zdev_cl_sls_list_renderer( )  ).
        client->view_display( page->stringify( ) ).
        IF mt_messaging IS NOT INITIAL.
          display_popover_message( ).
        ENDIF.
        RETURN.

      WHEN `UPDATE_TOKENS`.
        DATA(lt_arg) = client->get( )-t_event_arg.
        mv_name_f4 = lt_arg[ 1 ].

        DATA(lr_tokens) = REF #( mt_tt_token[ name = mv_name_f4 ]-t_tokens ).
        LOOP AT mt_tt_token[ name = mv_name_f4 ]-t_tokens_removed INTO DATA(ls_token).
          DELETE lr_tokens->* WHERE key = ls_token-key.
        ENDLOOP.

        LOOP AT mt_tt_token[ name = mv_name_f4 ]-t_tokens_added INTO ls_token.
          INSERT VALUE #( key = ls_token-key text = ls_token-text visible = abap_true editable = abap_true ) INTO TABLE lr_tokens->*.
        ENDLOOP.

        CLEAR mt_tt_token[ name = mv_name_f4 ]-t_tokens_removed.
        CLEAR mt_tt_token[ name = mv_name_f4 ]-t_tokens_added.


        ASSIGN me->(mv_name_f4) TO <lt_table>.
        <lt_table> = CORRESPONDING #( z2ui5_cl_util=>filter_get_range_t_by_token_t( mt_tt_token[ name = mv_name_f4 ]-t_tokens ) ).
        client->view_model_update( ).

      WHEN `FILTER_VALUE_HELP`.
        lt_arg = client->get( )-t_event_arg.
        mv_name_f4 = lt_arg[ 1 ].
        ASSIGN me->(mv_name_f4) TO <lt_table>.
        client->nav_app_call( z2ui5_cl_pop_get_range=>factory( <lt_table> ) ).

      WHEN OTHERS.
*        on_event( ).
    ENDCASE.

  ENDMETHOD.


  METHOD init_screen.

    DATA(page) = z2ui5_cl_xml_view=>factory( )->shell( )->page(
*             title          = client->_bind( _sy-title )
*             navbuttonpress = client->_event( val = 'BACK' )
*             shownavbutton = xsdbool( client->get( )-s_draft-id_prev_app_stack IS NOT INITIAL )
    ).

*    cl_abap_context_info=>get_system_url( )

    page->header_content(
*      )->overflow_toolbar(
*     )->input( width = `40%`
*     )->button( icon = 'sap-icon://save'
*     )->button( icon = 'sap-icon://media-rewind' text = `(F3)`  press = client->_event( 'F3' )
     )->button( text = `Menu`
      )->button( text = `System`
                    )->input( value = client->_bind_edit( s_view-input ) width = `10%` submit = client->_event( `ZZSUBMIT`  )
     )->button( icon = 'sap-icon://save'
      )->button( icon = 'sap-icon://popup-window'
*     )->button( text = `Edit`
*     )->button( text = `Goto`

*     )->button( text = `Help`
     )->toolbar_spacer(
     )->title( 'A4H (001)'
 )->toolbar_spacer(
 )->toolbar_spacer(
      ).

*    page->sub_header(
*       )->overflow_toolbar(
*               )->input( value = client->_bind_edit( s_view-input ) width = `10%` submit = client->_event( `ZZSUBMIT`  )
*     )->button( icon = 'sap-icon://save'
*     )->button( icon = 'sap-icon://media-rewind' text = `(F3)`  press = client->_event( 'F3' )
*     )->button( icon = 'sap-icon://collapse-group'
*     )->button( icon = 'sap-icon://decline'
*     )->button( icon = 'sap-icon://popup-window' ).

    result = page->simple_form( editable = abap_true
                    )->content( 'form' ).

    page->footer(
        )->overflow_toolbar(
           )->button(
             id = 'msgPopover'
*             text  = 'Messages'
             icon  = 'sap-icon://message-popup'
             press = client->_event( 'POPOVER' )
             type  = 'Default'
*             class = `sapUiSizeCozy`
             )->get( )->custom_data(
              )->badge_custom_data(
                                    value = '{= ${' && client->_bind_edit( val = mt_messaging path = abap_true ) && '}.length}'
*                                    value = client->_bind_edit( mv_messages_count )
                                    visible = abap_true
                                    key = 'badge' )->get_parent( )->get_parent(
         )->toolbar_spacer(
*            )->button( text = 'button'
*            )->text( client->_bind( s_view-message )
*            )->link( text = 'link' href = 'https://twitter.com/abap2UI5'
            )->toolbar_spacer(
            )->text( ''
            )->toolbar_spacer(
*       )->overflow_toolbar(
          )->button( icon = 'sap-icon://decline'
          )->button( icon = 'sap-icon://media-rewind' text = `(F3)`  press = client->_event( 'F3' )
*            )->text( 'text'
*            )->link( text = 'link' href = 'https://twitter.com/abap2UI5'
*            )->button( text = 'reject' type = 'Reject'
*            )->button( text = 'accept' type = 'Success' )
            )->button( text = '(F8)' press = client->_event( 'F8' ) icon = 'sap-icon://past'  type = 'Success'
             ).

  ENDMETHOD.


  METHOD on_init.

  ENDMETHOD.


  METHOD on_event.

  ENDMETHOD.



  METHOD _write.

    page->text( val ).

*    cl_demo_output=>write_data( val ).
*    DATA(lv_output) = cl_demo_output=>get( ).
**    display_demo_output( client ).
*
**    DATA(view) = z2ui5_cl_xml_view=>factory( ).
**    client->view_display( view->shell(
**          )->page(
**                  title          = 'abap2UI5 - CL_DEMO_OUTPUT - TODO uncomment the source code'
**                  navbuttonpress = client->_event( val = 'BACK' )
**                  shownavbutton = xsdbool( client->get( )-s_draft-id_prev_app_stack IS NOT INITIAL )
**              )->header_content(
**                  )->link(
**                      text = 'Source_Code'
**
**                      target = '_blank'
**                 )->get_parent(
*    page->_z2ui5( )->demo_output( lv_output ).
*            )->stringify( ) ).

** Abschnitt 1
*    cl_demo_output=>begin_section( '1. Überschrift' ).
*    cl_demo_output=>begin_section( '1.1 Überschrift' ).
** Text
*    cl_demo_output=>write_text( 'Text 1.1' ).
*    cl_demo_output=>write( 'Text 1.1 non proportional' ).
*    cl_demo_output=>end_section( ).
*    cl_demo_output=>end_section( ).
** Abschnitt 2
*    cl_demo_output=>begin_section( '2. Überschrift' ).
*    cl_demo_output=>begin_section( '2.1 Überschrift' ).
** Text
*    cl_demo_output=>write_text( 'Text 2.1' ).
*    cl_demo_output=>write( 'Text 2.1 non proportional' ).
*    cl_demo_output=>end_section( ).
*    cl_demo_output=>end_section( ).
*
*    TYPES: BEGIN OF ty_struct,
*             f1 TYPE string,
*             f2 TYPE i,
*           END OF ty_struct.
*
*    TYPES: ty_it_tab TYPE STANDARD TABLE OF ty_struct WITH DEFAULT KEY.
*
*    DATA(lv_struct) = VALUE ty_struct( f1 = 'Field1' f2 = 1 ).
*    DATA(it_tab) = VALUE ty_it_tab( ( f1 = 'T1' f2 = 1 )
*                                    ( f1 = 'T2' f2 = 2 )
*                                    ( f1 = 'T3' f2 = 3 ) ).
*
*    cl_demo_output=>write_data( value = -100         name = 'Zahl' ).
*    cl_demo_output=>write_data( value = 'ein String' name = 'Text' ).
*    cl_demo_output=>write_data( value = lv_struct    name = 'Struct' ).
*    cl_demo_output=>write_data( value = it_tab       name = 'Tab' ).
*
*    cl_demo_output=>write_text( 'Oben' ).
*    cl_demo_output=>line( ).
*    cl_demo_output=>write_text( 'Unten' ).
*
** alles anzeigen
*    SELECT * FROM t100 INTO TABLE @DATA(it_mara)
*    up to 50 rows.
*
*    cl_demo_output=>write_data( it_mara ).
*
** add HTML
*    cl_demo_output=>write_html( '<b>Text bold</b>' ).
*
** add HTML
*    cl_demo_output=>write_html( '<i>Text italic</i>' ).
*
*    cl_demo_output=>write_text( |blah blah blah \n| &&
*                                |blah blah blah| ).
*
*    TYPES:
*      BEGIN OF spfli_line,
*        carrid   TYPE spfli-carrid,
*        connid   TYPE spfli-connid,
*        cityfrom TYPE spfli-cityfrom,
*        cityto   TYPE spfli-cityto,
*      END OF spfli_line,
*      spfli_tab TYPE HASHED TABLE OF spfli_line
*                     WITH UNIQUE KEY carrid connid,
*      BEGIN OF struct,
*        carrname TYPE scarr-carrname,
*        spfli    TYPE REF TO spfli_tab,
*      END OF struct.
*
*    SELECT s~carrname, p~carrid, p~connid, p~cityfrom, p~cityto
*           FROM scarr AS s
*             INNER JOIN spfli AS p
*               ON s~carrid = p~carrid
*           ORDER BY s~carrname
*           INTO TABLE @DATA(itab).
*
*    cl_demo_output=>write_data( itab ).
*
*    DATA itab2 TYPE TABLE OF i WITH EMPTY KEY.
*
*    itab2 = VALUE #( ( 1 ) ( 2 ) ( 3 ) ).
*
*    DATA(json_writer) = cl_sxml_string_writer=>create(
*                          type = if_sxml=>co_xt_json ).
*    CALL TRANSFORMATION id SOURCE itab = itab2
*                           RESULT XML json_writer.
*    DATA(json) = json_writer->get_output( ).
*    mv_output = cl_demo_output=>get( ).
*    display_demo_output( client ).


  ENDMETHOD.


  METHOD _parameters.

    page->label( z2ui5_cl_util=>rtti_get_type_name( v ) ).
    page->input( value = client->_bind_edit( v ) width = `30%` ).

  ENDMETHOD.


  METHOD _select_options.


    INSERT VALUE #( name = name_tmp ) INTO TABLE mt_tt_token.
    page->_z2ui5( )->multiinput_ext(
                         addedtokens    = client->_bind_edit( val = mt_tt_token[ name = name_tmp  ]-t_tokens_added   tab = mt_tt_token tab_index = line_index( mt_tt_token[ name = name_tmp ] ) )
                         removedtokens  = client->_bind_edit( val = mt_tt_token[ name = name_tmp ]-t_tokens_removed tab = mt_tt_token tab_index = line_index( mt_tt_token[ name = name_tmp ] ) )
                         change    = client->_event( val = 'UPDATE_TOKENS' t_arg = VALUE #( ( name_tmp ) ) )
                         multiinputid    = `MultiInput-` && name_tmp  ).

    page->label( name_tmp  ).
    page->multi_input(
                  width = `30%`
                  id = `MultiInput-` && name_tmp
                  tokens           = client->_bind_edit(  val = mt_tt_token[ name = name_tmp ]-t_tokens tab = mt_tt_token tab_index = line_index( mt_tt_token[ name = name_tmp ] ) )
                  showclearicon    = abap_true
                  valuehelprequest = client->_event( val = 'FILTER_VALUE_HELP' t_arg = VALUE #( ( name_tmp ) ) )
              )->item(
                      key  = `{KEY}`
                      text = `{TEXT}`
              )->tokens(
                  )->token(
                      key      = `{KEY}`
                      text     = `{TEXT}`
                      visible  = `{VISIBLE}`
                      selected = `{SELKZ}`
                      editable = `{EDITABLE}` ).
  ENDMETHOD.


  METHOD _POPUP.

    IF result IS SUPPLIED.
      result = NEW #( ).
    ENDIF.

*    INSERT VALUE #(  message = v type = 'Warning' ) INTO TABLE mt_messaging.
*    s_view-message = v.

  ENDMETHOD.


  METHOD _msg.

    IF result IS SUPPLIED.
      result = NEW #( ).
    ENDIF.

    INSERT VALUE #(  message = v type = 'Warning' ) INTO TABLE mt_messaging.
*    s_view-message = v.

  ENDMETHOD.


  METHOD on_definintion.

  ENDMETHOD.


  METHOD _msg_e.

  ENDMETHOD.

  METHOD if_apj_dt_exec_object~get_parameters.

    " Return the supported selection parameters here
    et_parameter_def = VALUE #(
      ( selname = 'S_ID' kind = if_apj_dt_exec_object=>select_option datatype = 'C' length = 10 param_text
         = 'ID' changeable_ind = abap_true )
      ( selname = 'P_DESCR' kind = if_apj_dt_exec_object=>parameter datatype = 'C' length = 80 param_text = 'Description' lowercase_ind = abap_true changeable_ind = abap_true )
      ( selname = 'P_SIMUL' kind = if_apj_dt_exec_object=>parameter datatype = 'C' length = 1 param_text =
        'Simulate Only' checkbox_ind = abap_true changeable_ind = abap_true )
    ).

    " Return the default parameters values here
    et_parameter_val = VALUE #(
      ( selname = 'S_ID' kind = if_apj_dt_exec_object=>select_option sign = 'I' option = 'EQ' low = '1001'
      )
      ( selname = 'P_DESCR' kind = if_apj_dt_exec_object=>parameter sign = 'I' option = 'EQ' low = 'Application Job Description' )
      ( selname = 'P_SIMUL' kind = if_apj_dt_exec_object=>parameter sign = 'I' option = 'EQ' low =
        abap_true )
      ).

  ENDMETHOD.

  METHOD if_apj_rt_exec_object~execute.

    "Execution logic when the job is started
    TYPES ty_id TYPE c LENGTH 10.

    DATA s_id TYPE RANGE OF ty_id.
    DATA p_descr TYPE c LENGTH 80.
    DATA p_count TYPE i.
    DATA p_simul TYPE abap_boolean.

    " Getting the actual parameter values(Just for show. Not needed for the logic below)
    LOOP AT it_parameters INTO DATA(ls_parameter).
      CASE ls_parameter-selname.
        WHEN 'S_ID'.
          APPEND VALUE #( sign = ls_parameter-sign
                          option = ls_parameter-option
                          low = ls_parameter-low
                          high = ls_parameter-high ) TO s_id.
        WHEN 'P_DESCR'.
          p_descr = ls_parameter-low.
        WHEN 'P_SIMUL'.
          p_simul = ls_parameter-low.
      ENDCASE.
    ENDLOOP.

    "Fill attributes

    "Implement core process you want to execute with this job
    on_definintion( ).
    on_init( ).
    on_event( NEW #( )  ).


  ENDMETHOD.

  METHOD on_value_help.

  ENDMETHOD.

  METHOD test.

  ENDMETHOD.

  METHOD _msg_w.

  ENDMETHOD.

  METHOD _msg_box.

  ENDMETHOD.

  METHOD _parameters_cb.

  ENDMETHOD.

  METHOD _parameters_rb.

  ENDMETHOD.

  METHOD _throw.

  ENDMETHOD.

  METHOD on_navigated.

  ENDMETHOD.

ENDCLASS.
