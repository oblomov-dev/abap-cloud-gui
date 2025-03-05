*&---------------------------------------------------------------------*
*& Report zztest
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zztest.

PARAMETERS pa_matnr TYPE matnr.


INITIALIZATION.

  DATA lt_table TYPE STANDARD TABLE OF screen WITH EMPTY KEY.
  LOOP AT SCREEN.
    INSERT screen INTO TABLE lt_table.
  ENDLOOP.

  BREAK-POINT.

START-OF-SELECTION.

  WRITE 'test'.

  NEW-PAGE.



  WRITE 'test2'.
