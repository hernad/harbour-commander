/* Copyright 2017-2019 Rafał Jopek ( rafaljopek at hotmail com ) */

/* Harbour Commander */

#include "box.ch"
#include "directry.ch"
#include "fileio.ch"
#include "hbgtinfo.ch"
#include "inkey.ch"
#include "setcurs.ch"

#define DIR_PREFIX( v )  iif( "D" $ v[ F_ATTR ], "A", "B" )

#if defined( __PLATFORM__WINDOWS )
#define OSUPPER( x )  Upper( x )
#else
#define OSUPPER( x )  ( x )
#endif


#define _nTop         1
#define _nLeft        2
#define _nBottom      3
#define _nRight       4
#define _cCurrentDir  5
#define _aDirectory   6
#define _nRowBar      7
#define _nRowNo       8
#define _cComdLine    9
#define _nComdCol     10
#define _nComdColNo   11

#define _nElements    11

/* FError() */
#define MEANING       2

#define F_STATUS      6  /* zaznacz plik, katalog */

#define FXO_SHARELOCK  0x4000  /* emulate DOS SH_DENY* mode in POSIX OS */

STATIC aPanelLeft
STATIC aPanelRight
STATIC aPanelSelect

PROCEDURE Main()

   Set( _SET_DATEFORMAT, "yyyy-mm-dd" )
   Set( _SET_SCOREBOARD, .F. )
   Set( _SET_EVENTMASK, hb_bitOr( INKEY_KEYBOARD, HB_INKEY_GTEVENT, INKEY_ALL ) )
   Set( _SET_INSERT, .T. )

   /* Setup input CP of the translation */
   hb_cdpSelect( "UTF8EX" )
   hb_gtInfo( HB_GTI_COMPATBUFFER, .F. )
   hb_gtInfo( HB_GTI_BOXCP, hb_cdpSelect() )

   /* Configure terminal and OS codepage */
   hb_SetTermCP( hb_cdpTerm() )
   Set( _SET_OSCODEPAGE, hb_cdpOS() )
   Set( _SET_DBCODEPAGE, "EN" )

   hb_gtInfo( HB_GTI_RESIZEMODE, HB_GTI_RESIZEMODE_ROWS )
   hb_gtInfo( HB_GTI_WINTITLE, "Harbour Commander" )
   hb_GtInfo( HB_GTI_ICONRES , "HCICON" ) 

   aPanelLeft := PanelInit()
   aPanelRight := PanelInit()

   /* hb_cwd() zwraca pełny bieżący katalog roboczy zawierający dysk i końcowy separator ścieżki */
   PanelFetchList( aPanelLeft, hb_cwd() )
   PanelFetchList( aPanelRight, hb_cwd() )

   AutoSize()

   aPanelSelect := aPanelLeft

   Prompt()

   hb_Scroll()
   SetPos( 0, 0 )

   RETURN

STATIC FUNCTION PanelInit()

   LOCAL aInit

   aInit := Array( _nElements )

   aInit[ _nTop        ] := 0
   aInit[ _nLeft       ] := 0
   aInit[ _nBottom     ] := 0
   aInit[ _nRight      ] := 0
   aInit[ _cCurrentDir ] := ""
   aInit[ _aDirectory  ] := {}
   aInit[ _nRowBar     ] := 1
   aInit[ _nRowNo      ] := 0
   aInit[ _cComdLine   ] := ""
   aInit[ _nComdCol    ] := 0
   aInit[ _nComdColNo  ] := 0

   RETURN aInit

STATIC PROCEDURE PanelFetchList( aPanel, cDir )

   LOCAL i, nPos, a2Dot, aDots := { ".", ".." }, iDot

   aPanel[ _cCurrentDir ] := hb_defaultValue( cDir, hb_cwd() )
   aPanel[ _aDirectory ] := hb_vfDirectory( aPanel[ _cCurrentDir ], "HSD" )

   /* dodaję do każdego elementu tablicy wartość .T. */
   FOR i := 1 TO Len( aPanel[ _aDirectory ] )  // ? na AEval()
      AAdd( aPanel[ _aDirectory ][ i ], .T. )
   NEXT

   FOR EACH iDot in aDots
      IF ( nPos := AScan( aPanel[ _aDirectory ], {| x | x[ F_NAME ] == iDot } ) ) > 0
         IF iDot:__enumIndex == 2
            a2Dot := aPanel[ _aDirectory ][ nPos ]
         ENDIF
         hb_ADel( aPanel[ _aDirectory ], nPos, .T. )
      ENDIF
   NEXT
   ASort( aPanel[ _aDirectory ],,, {| x, y | DIR_PREFIX( x ) + OSUPPER( x[ F_NAME ] ) < DIR_PREFIX( y ) + OSUPPER( y[ F_NAME ] ) } )
   IF HB_ISARRAY( a2Dot )
      hb_AIns( aPanel[ _aDirectory ], 1, a2Dot, .T. )
   ENDIF

   RETURN

STATIC PROCEDURE AutoSize()

   Resize( aPanelLeft, 0, 0, MaxRow() - 2, MaxCol() / 2 )
   Resize( aPanelRight, 0, MaxCol() / 2 + 1, MaxRow() - 2, MaxCol() )

   RETURN

STATIC PROCEDURE Resize( aPanel, nTop, nLeft, nBottom, nRight )

   aPanel[ _nTop    ] := nTop
   aPanel[ _nLeft   ] := nLeft
   aPanel[ _nBottom ] := nBottom
   aPanel[ _nRight  ] := nRight

   RETURN

STATIC PROCEDURE Prompt()

   LOCAL lContinue := .T.
   LOCAL nMaxRow := 0, nMaxCol := 0
   LOCAL nKey, nKeyStd
   LOCAL nPos
   LOCAL cFileName
   LOCAL pHandle
   LOCAL nMRow, nMCol
   LOCAL nCol
   LOCAL cSpaces
   LOCAL nErrorCode
   LOCAL cNewDrive

   DO WHILE lContinue

      DispBegin()

      IF nMaxRow != MaxRow() .OR. nMaxCol != MaxCol()

         hb_Scroll()
         AutoSize()

         PanelDisplay( aPanelLeft )
         PanelDisplay( aPanelRight )

         ComdLineDisplay( aPanelSelect )

         BottomBar()

         nMaxRow := MaxRow()
         nMaxCol := MaxCol()
      ENDIF

      DispEnd()

      ComdLineDisplay( aPanelSelect )
      PanelDisplay( aPanelSelect )

      nKey := Inkey( 0 )
      nKeyStd := hb_keyStd( nKey )

      SWITCH nKeyStd

      CASE K_ESC

         IF ! Empty( aPanelSelect[ _cComdLine ] )
            aPanelSelect[ _cComdLine ] := ""
            aPanelSelect[ _nComdCol ] := 0
            ComdLineDisplay( aPanelSelect )
         ELSE
            lContinue := .F.
         ENDIF
         EXIT

      CASE K_ENTER

         nPos := aPanelSelect[ _nRowBar ] + aPanelSelect[ _nRowNo ]
         IF Empty( aPanelSelect[ _cComdLine ] )
            /* jeżeli stoimy na pliku */
            IF At( "D", aPanelSelect[ _aDirectory ][ nPos ][ F_ATTR ] ) == 0
               // hb_run( aPanelSelect[ _cCurrentDir ] + aPanelSelect[ _aDirectory ][ nPos ][ F_NAME ] )
               hc_Exec( aPanelSelect[ _cCurrentDir ] + aPanelSelect[ _aDirectory ][ nPos ][ F_NAME ] )
            ELSE
               ChangeDir( aPanelSelect )
            ENDIF
         ELSE

            // aPanelSelect[ _cComdLine ] := aPanelSelect[ _cCurrentDir ] + aPanelSelect[ _cComdLine ]

            hb_Scroll()
            hb_run( aPanelSelect[ _cComdLine ] )
            aPanelSelect[ _cComdLine ] := ""
            Inkey( 0 )
            nMaxRow := 0
            aPanelSelect[ _nComdCol ] := 0

            PanelRefresh( aPanelSelect )
         ENDIF

         EXIT

      CASE K_TAB

         IF aPanelSelect == aPanelLeft
            aPanelSelect := aPanelRight
            aPanelSelect[ _cComdLine ] := aPanelLeft[ _cComdLine ]
            aPanelSelect[ _nComdCol ] := aPanelLeft[ _nComdCol ]
            aPanelLeft[ _cComdLine ] := ""
            aPanelLeft[ _nComdCol ] := 0
         ELSE
            aPanelSelect := aPanelLeft
            aPanelSelect[ _cComdLine ] := aPanelRight[ _cComdLine ]
            aPanelSelect[ _nComdCol ] := aPanelRight[ _nComdCol ]
            aPanelRight[ _cComdLine ] := ""
            aPanelRight[ _nComdCol ] := 0
         ENDIF

         PanelDisplay( aPanelLeft )
         PanelDisplay( aPanelRight )
         EXIT

      CASE K_MOUSEMOVE

         DispBegin()

         nMRow := MRow()
         nCol := Int( nMaxCol / 10 ) + 1

         BottomBar()
         IF nMRow > nMaxRow - 1

            cSpaces := Space( nCol - 8 )

            SWITCH Int( MCol() / nCol ) + 1
            CASE 1  ; hb_DispOutAt( nMRow, 2,            "Help  " + cSpaces, 0xb0 ) ; EXIT
            CASE 2  ; hb_DispOutAt( nMRow, nCol + 2,     "Menu  " + cSpaces, 0xb0 ) ; EXIT
            CASE 3  ; hb_DispOutAt( nMRow, nCol * 2 + 2, "View  " + cSpaces, 0xb0 ) ; EXIT
            CASE 4  ; hb_DispOutAt( nMRow, nCol * 3 + 2, "Edit  " + cSpaces, 0xb0 ) ; EXIT
            CASE 5  ; hb_DispOutAt( nMRow, nCol * 4 + 2, "Copy  " + cSpaces, 0xb0 ) ; EXIT
            CASE 6  ; hb_DispOutAt( nMRow, nCol * 5 + 2, "RenMov" + cSpaces, 0xb0 ) ; EXIT
            CASE 7  ; hb_DispOutAt( nMRow, nCol * 6 + 2, "MkDir " + cSpaces, 0xb0 ) ; EXIT
            CASE 8  ; hb_DispOutAt( nMRow, nCol * 7 + 2, "Delete" + cSpaces, 0xb0 ) ; EXIT
            CASE 9  ; hb_DispOutAt( nMRow, nCol * 8 + 2, "PullDn" + cSpaces, 0xb0 ) ; EXIT
            CASE 10 ; hb_DispOutAt( nMRow, nCol * 9 + 2, "Quit  " + cSpaces, 0xb0 ) ; EXIT
            ENDSWITCH

         ENDIF

         DispEnd()
         EXIT

      CASE K_LDBLCLK

         nPos := aPanelSelect[ _nRowBar ] + aPanelSelect[ _nRowNo ]
         /* jeżeli stoimy na pliku */
         IF At( "D", aPanelSelect[ _aDirectory ][ nPos ][ F_ATTR ] ) == 0
            // hb_run( aPanelSelect[ _cCurrentDir ] + aPanelSelect[ _aDirectory ][ nPos ][ F_NAME ] )
            hc_Exec( aPanelSelect[ _cCurrentDir ] + aPanelSelect[ _aDirectory ][ nPos ][ F_NAME ] )
         ELSE
            ChangeDir( aPanelSelect )
         ENDIF

         EXIT

      CASE K_RBUTTONDOWN

         nMRow := MRow()
         nMCol := MCol()

         IF nMRow > 0 .AND. nMRow < MaxRow() - 1 .AND. nMCol < Int( MaxCol() / 2 ) + 1
            aPanelSelect := aPanelLeft
            IF nMRow <= Len( aPanelSelect[ _aDirectory ] )
               aPanelSelect[ _nRowBar ] := nMRow
            ENDIF
         ENDIF

         IF nMRow > 0 .AND. nMRow < MaxRow() - 1 .AND. nMCol > Int( MaxCol() / 2 )
            aPanelSelect := aPanelRight
            IF nMRow <= Len( aPanelSelect[ _aDirectory ] )
               aPanelSelect[ _nRowBar ] := nMRow
            ENDIF
         ENDIF

         nPos := aPanelSelect[ _nRowBar ] + aPanelSelect[ _nRowNo ]
         IF aPanelSelect[ _aDirectory ][ nPos ][ F_NAME ] != ".." // ?

            /* oznaczam stan usunięcia aktualnego elementu w tablicy */
            IF aPanelSelect[ _aDirectory ][ nPos ][ F_STATUS ]
               aPanelSelect[ _aDirectory ][ nPos ][ F_STATUS ] := .F.
            ELSE
               /* zwracam stan usunięcia aktualnego elementu w tablicy */
               aPanelSelect[ _aDirectory ][ nPos ][ F_STATUS ] := .T.
            ENDIF

         ENDIF

         PanelDisplay( aPanelLeft )
         PanelDisplay( aPanelRight )
         EXIT

      CASE K_LBUTTONDOWN

         nMRow := MRow()
         nMCol := MCol()

         IF nMRow > 0 .AND. nMRow < MaxRow() - 1 .AND. nMCol < Int( MaxCol() / 2 ) + 1
            aPanelSelect := aPanelLeft
            IF nMRow <= Len( aPanelSelect[ _aDirectory ] )
               aPanelSelect[ _nRowBar ] := nMRow
            ENDIF
         ENDIF

         IF nMRow > 0 .AND. nMRow < MaxRow() - 1 .AND. nMCol > Int( MaxCol() / 2 )
            aPanelSelect := aPanelRight
            IF nMRow <= Len( aPanelSelect[ _aDirectory ] )
               aPanelSelect[ _nRowBar ] := nMRow
            ENDIF
         ENDIF

         /* BottomBar */
         nCol := Int( nMaxCol / 10 ) + 1
         IF nMRow > nMaxRow - 1
            SWITCH Int( MCol() / nCol ) + 1
            CASE 1  ; FunctionKey_F1() ; EXIT
            CASE 2  ; FunctionKey_F2() ; EXIT
            CASE 3  ; FunctionKey_F3( aPanelSelect ) ; EXIT
            CASE 4  ; FunctionKey_F4( aPanelSelect ) ; EXIT
            CASE 5  ; FunctionKey_F5( aPanelSelect ) ; EXIT
            CASE 6  ; FunctionKey_F6( aPanelSelect ) ; EXIT
            CASE 7  ; FunctionKey_F7( aPanelSelect ) ; EXIT
            CASE 8  ; FunctionKey_F8( aPanelSelect ) ; EXIT
            CASE 9  ; EXIT
            CASE 10
               IF HC_Alert( "The Harbour Commander", "Do you want to quit the Harbour Commander?", { "Yes", "No!" }, 0x8f ) == 1
                  lContinue := .F.
               ENDIF
               EXIT

            ENDSWITCH

         ENDIF

         PanelDisplay( aPanelLeft )
         PanelDisplay( aPanelRight )
         EXIT

      CASE K_MWFORWARD

         IF aPanelSelect[ _nRowBar ] > 1
            --aPanelSelect[ _nRowBar ]
         ELSE
            IF aPanelSelect[ _nRowNo ] >= 1
               --aPanelSelect[ _nRowNo ]
            ENDIF
         ENDIF

         EXIT

      CASE K_MWBACKWARD

         IF aPanelSelect[ _nRowBar ] < aPanelSelect[ _nBottom ] - 1 .AND. aPanelSelect[ _nRowBar ] <= Len( aPanelSelect[ _aDirectory ] ) - 1
            ++aPanelSelect[ _nRowBar ]
         ELSE
            IF aPanelSelect[ _nRowNo ] + aPanelSelect[ _nRowBar ] <= Len( aPanelSelect[ _aDirectory ] ) - 1
               ++aPanelSelect[ _nRowNo ]
            ENDIF
         ENDIF

         EXIT

      CASE K_UP

         IF aPanelSelect[ _nRowBar ] > 1
            --aPanelSelect[ _nRowBar ]
         ELSE
            IF aPanelSelect[ _nRowNo ] >= 1
               --aPanelSelect[ _nRowNo ]
            ENDIF
         ENDIF

         EXIT

      CASE K_DOWN

         IF aPanelSelect[ _nRowBar ] < aPanelSelect[ _nBottom ] - 1 .AND. aPanelSelect[ _nRowBar ] <= Len( aPanelSelect[ _aDirectory ] ) - 1
            ++aPanelSelect[ _nRowBar ]
         ELSE
            IF aPanelSelect[ _nRowNo ] + aPanelSelect[ _nRowBar ] <= Len( aPanelSelect[ _aDirectory ] ) - 1
               ++aPanelSelect[ _nRowNo ]
            ENDIF
         ENDIF

         EXIT

      CASE K_LEFT

         IF aPanelSelect[ _nComdCol ] > 0
            aPanelSelect[ _nComdCol ]--
         ELSE
            IF aPanelSelect[ _nComdColNo ] >= 1
               aPanelSelect[ _nComdColNo ]--
            ENDIF
         ENDIF

         EXIT

      CASE K_RIGHT

         IF aPanelSelect[ _nComdCol ] < nMaxCol - Len( aPanelSelect[ _cCurrentDir ] ) .AND. aPanelSelect[ _nComdCol ] < Len( aPanelSelect[ _cComdLine ] )
            aPanelSelect[ _nComdCol ]++
         ELSE
            IF aPanelSelect[ _nComdColNo ] + aPanelSelect[ _nComdCol ] < Len( aPanelSelect[ _cComdLine ] )
               aPanelSelect[ _nComdColNo ]++
            ENDIF
         ENDIF

         EXIT

      CASE K_HOME

         aPanelSelect[ _nComdCol ] := 0

         EXIT

      CASE K_END

         aPanelSelect[ _nComdCol ] := Len( aPanelSelect[ _cComdLine ] )

         EXIT

      CASE K_PGUP

         IF aPanelSelect[ _nRowBar ] <= 1
            IF aPanelSelect[ _nRowNo ] - nMaxRow >= 0
               aPanelSelect[ _nRowNo ] -= nMaxRow
            ENDIF
         ENDIF

         aPanelSelect[ _nRowBar ] := 1
         EXIT

      CASE K_PGDN

         IF aPanelSelect[ _nRowBar ] >= nMaxRow - 3
            IF aPanelSelect[ _nRowNo ] + nMaxRow  <= Len( aPanelSelect[ _aDirectory ] )
               aPanelSelect[ _nRowNo ] += nMaxRow
            ENDIF
         ENDIF

         aPanelSelect[ _nRowBar ] := Min( nMaxRow - 3, Len( aPanelSelect[ _aDirectory ] ) - aPanelSelect[ _nRowNo ] )
         EXIT

      CASE K_INS

         nPos := aPanelSelect[ _nRowBar ] + aPanelSelect[ _nRowNo ]
         IF aPanelSelect[ _aDirectory ][ nPos ][ F_NAME ] != ".." // ?

            /* oznaczam stan usunięcia aktualnego elementu w tablicy */
            IF aPanelSelect[ _aDirectory ][ nPos ][ F_STATUS ]
               aPanelSelect[ _aDirectory ][ nPos ][ F_STATUS ] := .F.
            ELSE
               /* zwracam stan usunięcia aktualnego elementu w tablicy */
               aPanelSelect[ _aDirectory ][ nPos ][ F_STATUS ] := .T.
            ENDIF

            IF aPanelSelect[ _nRowBar ] < aPanelSelect[ _nBottom ] - 1 .AND. aPanelSelect[ _nRowBar ] <= Len( aPanelSelect[ _aDirectory ] ) - 1
               ++aPanelSelect[ _nRowBar ]
            ELSE
               IF aPanelSelect[ _nRowNo ] + aPanelSelect[ _nRowBar ] <= Len( aPanelSelect[ _aDirectory ] ) - 1
                  ++aPanelSelect[ _nRowNo ]
               ENDIF
            ENDIF

         ENDIF

         EXIT

      CASE K_DEL

         IF aPanelSelect[ _nComdCol ] >= 0
            aPanelSelect[ _cComdLine ] := Stuff( aPanelSelect[ _cComdLine ], aPanelSelect[ _nComdCol ] + 1, 1, "" )
         ENDIF

         EXIT

      CASE K_BS

         IF aPanelSelect[ _nComdCol ] > 0
            aPanelSelect[ _cComdLine ] := Stuff( aPanelSelect[ _cComdLine ], aPanelSelect[ _nComdCol ], 1, "" )
            aPanelSelect[ _nComdCol ]--
         ENDIF

         EXIT

      CASE K_F1

         FunctionKey_F1()

         EXIT

      CASE K_F2

         FunctionKey_F2()

         EXIT

      CASE K_F3

         FunctionKey_F3( aPanelSelect )

         EXIT

      CASE K_F4

         FunctionKey_F4( aPanelSelect )

         EXIT

      CASE K_F5

         FunctionKey_F5( aPanelSelect )

         EXIT

      CASE K_F6

         FunctionKey_F6( aPanelSelect )

         EXIT

      CASE K_F7

         FunctionKey_F7( aPanelSelect )

         EXIT

      CASE K_F8

         FunctionKey_F8( aPanelSelect )

         EXIT

      CASE K_F9

         EXIT

      CASE K_F10
         lContinue := .F.
         EXIT

      CASE K_ALT_F1
         /* ostatni parametr ustawia okienko dialogowe: NIL środek, 0x0 po lewo i 0x1 po prawo
         AllDrives() zwraca tablicę */
         IF ( cNewDrive := HC_Alert( "Drive letter", "Choose left drive:", AllDrives(), 0x8a, 0x0 ) ) != 0

            hb_CurDrive( AllDrives()[ cNewDrive ] )
            PanelFetchList( aPanelLeft, hb_cwd() )
            PanelDisplay( aPanelLeft )

         ENDIF

         EXIT

      CASE K_ALT_F2
         /* ostatni parametr ustawia okienko dialogowe: NIL środek, 0x0 po lewo i 0x1 po prawo
         AllDrives() zwraca tablicę */
         IF ( cNewDrive := HC_Alert( "Drive letter", "Choose right drive:", AllDrives(), 0x8a, 0x1 ) ) != 0

            hb_CurDrive( AllDrives()[ cNewDrive ] )
            PanelFetchList( aPanelRight, hb_cwd() )
            PanelDisplay( aPanelRight )

         ENDIF

         EXIT

      CASE K_SH_F4

         nPos := aPanelSelect[ _nRowBar ] + aPanelSelect[ _nRowNo ]
         /* jeżeli stoimy na pliku */
         IF At( "D", aPanelSelect[ _aDirectory ][ nPos ][ F_ATTR ] ) == 0

            IF HB_ISSTRING( cFileName := MsgBox( "Create file.", aPanelSelect[ _cCurrentDir ] + aPanelSelect[ _aDirectory ][ nPos ][ F_NAME ], { "Yes", "No!" } ) )
               IF hb_vfExists( cFileName )

                  HCEdit( cFileName, .T. )

               ELSE
                  IF ( pHandle := hb_vfOpen( cFileName, FO_CREAT + FO_TRUNC + FO_WRITE ) ) != NIL

                     IF ! hb_vfClose( pHandle )
                        IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
                           HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make file, error:;" + FileError()[ nErrorCode ][ MEANING ] )
                        ELSE
                           HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make file, error:;" + hb_ntos( FError() ) )
                        ENDIF
                     ENDIF

                     PanelRefresh( aPanelSelect )

                  ELSE

                     IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
                        HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make file, error:;" + FileError()[ nErrorCode ][ MEANING ] )
                     ELSE
                        HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make file, error:;" + hb_ntos( FError() ) )
                     ENDIF

                  ENDIF
               ENDIF

            ENDIF

         ELSE
            /* jeżeli stoimy na katalogu */
            IF HB_ISSTRING( cFileName := MsgBox( "Create file.", NIL, { "Yes", "No!" } ) )
               IF ( pHandle := hb_vfOpen( aPanelSelect[ _cCurrentDir ] + cFileName, FO_CREAT + FO_TRUNC + FO_WRITE ) ) != NIL

                  IF ! hb_vfClose( pHandle )
                     IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
                        HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make file, error:;" + FileError()[ nErrorCode ][ MEANING ] )
                     ELSE
                        HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make file, error:;" + hb_ntos( FError() ) )
                     ENDIF
                  ENDIF

                  PanelRefresh( aPanelSelect )

               ELSE

                  IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
                     HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make file, error:;" + FileError()[ nErrorCode ][ MEANING ] )
                  ELSE
                     HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make file, error:;" + hb_ntos( FError() ) )
                  ENDIF

               ENDIF
            ENDIF

         ENDIF

         EXIT

      OTHERWISE

         IF ( nKeyStd >= 32 .AND. nKeyStd <= 126 ) .OR. ( nKeyStd >= 160 .AND. nKeyStd <= 255 ) .OR. ! hb_keyChar( nKeyStd ) == ""

            aPanelSelect[ _cComdLine ] := Stuff( aPanelSelect[ _cComdLine ], aPanelSelect[ _nComdCol ] + aPanelSelect[ _nComdColNo ] + 1, 0, hb_keyChar( nKeyStd ) )
            IF aPanelSelect[ _nComdCol ] < nMaxCol - Len( aPanelSelect[ _cCurrentDir ] )
               aPanelSelect[ _nComdCol ]++
            ELSE
               aPanelSelect[ _nComdColNo ]++
            ENDIF

         ENDIF

      ENDSWITCH

   ENDDO

   RETURN

STATIC PROCEDURE FunctionKey_F1()

   IF HC_Alert( "Report an error", ;
         "Creating an issue;" + ;
         ";Issues can be used to keep track of bugs, enhancements, or;" + ;
         "other requests.;" + ;
         ";Any GitHub user can create an issue in a public repository;" + ;
         "where issues have not been disabled.;" + ;
         ";You can open a new issue based on code from an existing pull;" + ;
         "request.;", ;
         { "Click New issue." } ) == 1

      hb_run( "start " + "https://github.com/rjopek/harbour-commander/issues/new" )

   ENDIF

   RETURN

STATIC PROCEDURE FunctionKey_F2()

   HC_MenuF2()

   RETURN

STATIC PROCEDURE FunctionKey_F3( aPanel )

   LOCAL nPos
   LOCAL aTarget := {}, aItem, aDirScan
   LOCAL nLengthName := 0

   nPos := aPanel[ _nRowBar ] + aPanel[ _nRowNo ]
   /* jeżeli stoimy na pliku */
   IF At( "D", aPanel[ _aDirectory ][ nPos ][ F_ATTR ] ) == 0

      HCEdit( aPanel[ _cCurrentDir ] + aPanel[ _aDirectory ][ nPos ][ F_NAME ], .F. )

   ELSE
      aDirScan := hb_DirScan( aPanel[ _aDirectory ][ nPos ][ F_NAME ], hb_osFileMask() )
      AScan( aDirScan, {| x | nLengthName := Max( nLengthName, Len( x[ 1 ] ) ) } )

      FOR EACH aItem IN aDirScan
         AAdd( aTarget, ;
            PadR( aItem[ F_NAME ], nLengthName ) + " " + ;
            Transform( hb_ntos( aItem[ F_SIZE ] ), "9 999 999 999" ) + " " + ;
            hb_TToC( aItem[ F_DATE ] ) + " " + ;
            aItem[ F_ATTR ] )
      NEXT

      SaveFile( aTarget, "DirScan.txt" ) // gdzie zapisywać ?

      HCEdit( "DirScan.txt", .F. )
   ENDIF

   RETURN

STATIC PROCEDURE FunctionKey_F4( aPanel )

   LOCAL nPos

   nPos := aPanel[ _nRowBar ] + aPanel[ _nRowNo ]
   /* jeżeli stoimy na pliku przejdź do edycji */
   IF At( "D", aPanel[ _aDirectory ][ nPos ][ F_ATTR ] ) == 0
      HCEdit( aPanel[ _cCurrentDir ] + aPanel[ _aDirectory ][ nPos ][ F_NAME ], .T. )
   ELSE
      HC_Alert( "No file selected", "Select the file to edit",, 0x8f )
   ENDIF

   RETURN

STATIC PROCEDURE FunctionKey_F5( aPanel )

   LOCAL nPos
   LOCAL nErrorCode

   nPos := aPanel[ _nRowBar ] + aPanel[ _nRowNo ]
   IF aPanel[ _aDirectory ][ nPos ][ F_NAME ] == ".."
      HC_Alert( "Copy", "The item to be copy has not been selected.",, 0x8f )
   ELSE

      IF aPanel == aPanelLeft
         /* jeżeli stoimy na pliku */
         IF At( "D", aPanel[ _aDirectory ][ nPos ][ F_ATTR ] ) == 0
            IF HB_ISSTRING( MsgBox( "Copy file " + '"' + aPanelLeft[ _aDirectory ][ nPos ][ F_NAME ] + '"' + " to", ;
                  aPanelRight[ _cCurrentDir ] + aPanelLeft[ _aDirectory ][ nPos ][ F_NAME ], { "Yes", "No!" } ) )

               // IF hb_vfCopyFile( aPanelLeft[ _cCurrentDir ] + aPanelLeft[ _aDirectory ][ nPos ][ F_NAME ], ;
               IF HC_CopyFile( aPanelLeft[ _cCurrentDir ] + aPanelLeft[ _aDirectory ][ nPos ][ F_NAME ], ;
                     aPanelRight[ _cCurrentDir ] + aPanelLeft[ _aDirectory ][ nPos ][ F_NAME ] ) == 0

                  PanelRefresh( aPanelRight )

               ELSE
                  IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
                     HC_Alert( "Error", "Test for errors after a binary file operation.;The file can not be copied;" + FileError()[ nErrorCode ][ MEANING ] )

                  ELSE
                     HC_Alert( "Error", "Test for errors after a binary file operation.;The file can not be copied;" + hb_ntos( FError() ) )
                  ENDIF
               ENDIF

            ENDIF
         ELSE
            IF HB_ISSTRING( MsgBox( "Copy directory " + '"' + aPanelLeft[ _aDirectory ][ nPos ][ F_NAME ] + '"' + " to", ;
                  aPanelRight[ _cCurrentDir ], { "Yes", "No!" } ) )

               IF HC_CopyDirectory( aPanelLeft[ _cCurrentDir ] + aPanelLeft[ _aDirectory ][ nPos ][ F_NAME ], ;
                     aPanelRight[ _cCurrentDir ] ) == 0 // ?

                  PanelRefresh( aPanelRight )

               ELSE
                  IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
                     HC_Alert( "Error", "Test for errors after a binary file operation.;The directory can not be copied;" + FileError()[ nErrorCode ][ MEANING ] )
                  ELSE
                     HC_Alert( "Error", "Test for errors after a binary file operation.;The directory can not be copied;" + hb_ntos( FError() ) )
                  ENDIF
               ENDIF
            ENDIF
         ENDIF
      ELSE
         /* jeżeli stoimy na pliku */
         IF At( "D", aPanel[ _aDirectory ][ nPos ][ F_ATTR ] ) == 0
            IF HB_ISSTRING( MsgBox( "Copy file " + '"' + aPanelRight[ _aDirectory ][ nPos ][ F_NAME ] + '"' + " to", ;
                  aPanelLeft[ _cCurrentDir ] + aPanelRight[ _aDirectory ][ nPos ][ F_NAME ], { "Yes", "No!" } ) )

               IF HC_CopyFile( aPanelRight[ _cCurrentDir ] + aPanelRight[ _aDirectory ][ nPos ][ F_NAME ], ;
                     aPanelLeft[ _cCurrentDir ] + aPanelRight[ _aDirectory ][ nPos ][ F_NAME ] ) == 0

                  PanelRefresh( aPanelLeft )

               ELSE
                  IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
                     HC_Alert( "Error", "Test for errors after a binary file operation.;The file can not be copied;" + FileError()[ nErrorCode ][ MEANING ] )
                  ELSE
                     HC_Alert( "Error", "Test for errors after a binary file operation.;The file can not be copied;" + hb_ntos( FError() ) )
                  ENDIF
               ENDIF
            ENDIF
         ELSE
            IF HB_ISSTRING( MsgBox( "Copy directory " + '"' + aPanelRight[ _aDirectory ][ nPos ][ F_NAME ] + '"' + " to", ;
                  aPanelLeft[ _cCurrentDir ], { "Yes", "No!" } ) )

               IF HC_CopyDirectory( aPanelRight[ _cCurrentDir ] + aPanelRight[ _aDirectory ][ nPos ][ F_NAME ], ;
                     aPanelLeft[ _cCurrentDir ] ) == 0 // ?

                  PanelRefresh( aPanelLeft )

               ELSE
                  IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
                     HC_Alert( "Error", "Test for errors after a binary file operation.;The directory can not be copied;" + FileError()[ nErrorCode ][ MEANING ] )
                  ELSE
                     HC_Alert( "Error", "Test for errors after a binary file operation.;The directory can not be copied;" + hb_ntos( FError() ) )
                  ENDIF
               ENDIF
            ENDIF
         ENDIF
      ENDIF
   ENDIF

   RETURN

STATIC PROCEDURE FunctionKey_F6( aPanel )

   LOCAL nPos
   LOCAL nErrorCode

   nPos := aPanel[ _nRowBar ] + aPanel[ _nRowNo ]
   IF aPanel[ _aDirectory ][ nPos ][ F_NAME ] == ".."
      HC_Alert( "Rename or move", "The item to be copy has not been selected.",, 0x8f )
   ELSE

      IF aPanel == aPanelLeft
         /* jeżeli stoimy na pliku */
         IF At( "D", aPanel[ _aDirectory ][ nPos ][ F_ATTR ] ) == 0
            IF HB_ISSTRING( MsgBox( "Move file " + '"' + aPanelLeft[ _aDirectory ][ nPos ][ F_NAME ] + '"' + " to", ;
                  aPanelRight[ _cCurrentDir ], { "Yes", "No!" } ) )

               IF HC_CopyFile( aPanelLeft[ _cCurrentDir ] + aPanelLeft[ _aDirectory ][ nPos ][ F_NAME ], ;
                     aPanelRight[ _cCurrentDir ] + aPanelLeft[ _aDirectory ][ nPos ][ F_NAME ] ) == 0

                  PanelRefresh( aPanelRight )

                  IF hb_DirRemoveAll( aPanelLeft[ _cCurrentDir ] + aPanelLeft[ _aDirectory ][ nPos ][ F_NAME ] ) == .T.

                     PanelRefresh( aPanelLeft )

                  ELSE
                     IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
                        HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make file, error:;" + FileError()[ nErrorCode ][ MEANING ] )
                     ELSE
                        HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make file, error:;" + hb_ntos( FError() ) )
                     ENDIF
                  ENDIF

               ELSE
                  IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
                     HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make file, error:;" + FileError()[ nErrorCode ][ MEANING ] )
                  ELSE
                     HC_Alert( "Error", "Test for errors after a binary file operation.;annot make file, error:;" + hb_ntos( FError() ) )
                  ENDIF
               ENDIF

            ENDIF
         ELSE
            IF HB_ISSTRING( MsgBox( "Move directory " + '"' + aPanelLeft[ _aDirectory ][ nPos ][ F_NAME ] + '"' + " to", ;
                  aPanelRight[ _cCurrentDir ], { "Yes", "No!" } ) )

               IF HC_CopyDirectory( aPanelLeft[ _cCurrentDir ] + aPanelLeft[ _aDirectory ][ nPos ][ F_NAME ], ;
                     aPanelRight[ _cCurrentDir ] ) == 0 // ?

                  PanelRefresh( aPanelRight )

                  IF hb_DirRemoveAll( aPanelLeft[ _cCurrentDir ] + aPanelLeft[ _aDirectory ][ nPos ][ F_NAME ] ) == .T.

                     PanelRefresh( aPanelLeft )

                  ELSE
                     IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
                        HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make directory, error:;" + FileError()[ nErrorCode ][ MEANING ] )
                     ELSE
                        HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make directory, error:;" + hb_ntos( FError() ) )
                     ENDIF
                  ENDIF

               ELSE
                  IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
                     HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make directory, error:;" + FileError()[ nErrorCode ][ MEANING ] )
                  ELSE
                     HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make directory, error:;" + hb_ntos( FError() ) )
                  ENDIF
               ENDIF
            ENDIF
         ENDIF
      ELSE
         /* jeżeli stoimy na pliku */
         IF At( "D", aPanel[ _aDirectory ][ nPos ][ F_ATTR ] ) == 0
            IF HB_ISSTRING( MsgBox( "Move file " + '"' + aPanelRight[ _aDirectory ][ nPos ][ F_NAME ] + '"' + " to", ;
                  aPanelLeft[ _cCurrentDir ], { "Yes", "No!" } ) )

               IF HC_CopyFile( aPanelRight[ _cCurrentDir ] + aPanelRight[ _aDirectory ][ nPos ][ F_NAME ], ;
                     aPanelLeft[ _cCurrentDir ] + aPanelRight[ _aDirectory ][ nPos ][ F_NAME ] ) == 0

                  PanelRefresh( aPanelLeft )

                  IF hb_DirRemoveAll( aPanelRight[ _cCurrentDir ] + aPanelRight[ _aDirectory ][ nPos ][ F_NAME ] ) == .T.

                     PanelRefresh( aPanelRight )

                  ELSE
                     IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
                        HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make file, error:;" + FileError()[ nErrorCode ][ MEANING ] )
                     ELSE
                        HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make file, error:;" + hb_ntos( FError() ) )
                     ENDIF
                  ENDIF

               ELSE
                  IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
                     HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make file, error:;" + FileError()[ nErrorCode ][ MEANING ] )
                  ELSE
                     HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make file, error:;" + hb_ntos( FError() ) )
                  ENDIF
               ENDIF
            ENDIF
         ELSE
            IF HB_ISSTRING( MsgBox( "Move directory " + '"' + aPanelRight[ _aDirectory ][ nPos ][ F_NAME ] + '"' + " to", ;
                  aPanelLeft[ _cCurrentDir ], { "Yes", "No!" } ) )

               IF HC_CopyDirectory( aPanelRight[ _cCurrentDir ] + aPanelRight[ _aDirectory ][ nPos ][ F_NAME ], ;
                     aPanelLeft[ _cCurrentDir ] ) == 0 // ?

                  PanelRefresh( aPanelLeft )

                  IF hb_DirRemoveAll( aPanelRight[ _cCurrentDir ] + aPanelRight[ _aDirectory ][ nPos ][ F_NAME ] ) == .T.

                     PanelRefresh( aPanelRight )

                  ELSE
                     IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
                        HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make directory, error:;" + FileError()[ nErrorCode ][ MEANING ] )
                     ELSE
                        HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make directory, error:;" + hb_ntos( FError() ) )
                     ENDIF
                  ENDIF

               ELSE
                  IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
                     HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make directory, error:;" + FileError()[ nErrorCode ][ MEANING ] )
                  ELSE
                     HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make directory, error:;" + hb_ntos( FError() ) )
                  ENDIF
               ENDIF
            ENDIF
         ENDIF
      ENDIF
   ENDIF

   /* jeżeli usuniemy będąc wskaźnikiem RowBar na ostatniej pozycji to - 1 */
// IF Len( aPanel[ _aDirectory ] ) < aPanel[ _nRowBar ] + aPanel[ _nRowNo ]
// aPanel[ _nRowBar ] -= 1
// ENDIF

   RETURN

STATIC PROCEDURE FunctionKey_F7( aPanel )

   LOCAL cNewDir
   LOCAL nErrorCode

   IF HB_ISSTRING( cNewDir := MsgBox( "Create the directory.", NIL, { "Yes", "No!" } ) )
      IF hb_vfDirMake( aPanel[ _cCurrentDir ] + cNewDir ) == 0

         PanelRefresh( aPanel )

      ELSE
         IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
            HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make directory, error:;" + FileError()[ nErrorCode ][ MEANING ] )
         ELSE
            HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make directory, error:;" + hb_ntos( FError() ) )
         ENDIF
      ENDIF
   ENDIF

   RETURN

STATIC PROCEDURE FunctionKey_F8( aPanel )

   LOCAL nPos
   LOCAL nErrorCode

   nPos := aPanel[ _nRowBar ] + aPanel[ _nRowNo ]

   IF aPanel[ _aDirectory ][ nPos ][ F_NAME ] == ".."
      HC_Alert( "Up Directory", "The item to be deleted has not been selected." )
   ELSE
      nPos := aPanel[ _nRowBar ] + aPanel[ _nRowNo ]
      /* jeżeli stoimy na pliku */
      IF At( "D", aPanel[ _aDirectory ][ nPos ][ F_ATTR ] ) == 0

         /* oznaczam stan usunięcia aktualnego elementu w tablicy */
         IF aPanelSelect[ _aDirectory ][ nPos ][ F_STATUS ]
            aPanelSelect[ _aDirectory ][ nPos ][ F_STATUS ] := .F.
         ENDIF

         PanelDisplay( aPanel )

         IF HC_Alert( "Delete file", "Do you really want to delete the selected file:;" + '"' + aPanel[ _aDirectory ][ nPos ][ F_NAME ] + '"', { "Yes", "No!" } ) == 1

            // IF hb_vfErase( aPanel[ _cCurrentDir ] + aPanel[ _aDirectory ][ nPos ][ F_NAME ] ) == 0
            IF HC_DeleteFile( aPanelSelect ) == 0

               PanelRefresh( aPanel )

            ELSE
               IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
                  HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make file, error:;" + FileError()[ nErrorCode ][ MEANING ] )
               ELSE
                  HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make file, error:;" + hb_ntos( FError() ) )
               ENDIF
            ENDIF
         ELSE
            /* zwracam stan usunięcia aktualnego elementu w tablicy */
            aPanelSelect[ _aDirectory ][ nPos ][ F_STATUS ] := .T.
         ENDIF

      ELSE
         /* jeżeli stoimy na katalogu */
         IF HC_Alert( "Down Directory", "Do you really want to delete the selected directory:;" + '"' + aPanel[ _aDirectory ][ nPos ][ F_NAME ] + '"', { "Yes", "No!" }, 0x9f ) == 1
            IF hb_vfDirRemove( aPanel[ _cCurrentDir ] + aPanel[ _aDirectory ][ nPos ][ F_NAME ] ) == 0

               PanelRefresh( aPanel )

            ELSE
               IF HC_Alert( "Down Directory", "The following subdirectory is not empty. ;" + ;
                     '"' + aPanel[ _aDirectory ][ nPos ][ F_NAME ] + '"' + ";" + ;
                     "Do you still wish to delete it?", { "Delete", "No!" } ) == 1

                  IF hb_DirRemoveAll( aPanel[ _cCurrentDir ] + aPanel[ _aDirectory ][ nPos ][ F_NAME ] ) == .T.

                     PanelRefresh( aPanel )

                  ELSE
                     IF ( nErrorCode := AScan( FileError(), {| x | x[ 1 ] == FError() } ) ) > 0
                        HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make directory, error:;" + FileError()[ nErrorCode ][ MEANING ] )
                     ELSE
                        HC_Alert( "Error", "Test for errors after a binary file operation.;Cannot make directory, error:;" + hb_ntos( FError() ) )
                     ENDIF
                  ENDIF
               ENDIF
            ENDIF
         ENDIF
      ENDIF
   ENDIF


   /* jeżeli usuniemy będąc wskaźnikiem RowBar + RowNo na ostatniej pozycji to - 1 */
// IF Len( aPanel[ _aDirectory ] ) < aPanel[ _nRowBar ] + aPanel[ _nRowNo ]
// aPanel[ _nRowBar ] -= 1
// ENDIF

   RETURN

// STATIC PROCEDURE FunctionKey_F9( aPanel )
// RETURN

// STATIC PROCEDURE FunctionKey_F10( aPanel )
// RETURN

STATIC FUNCTION HC_CopyFile( cSourceFile, cTargetFile )

   LOCAL nRow, nCol
   LOCAL nWidth
   LOCAL nTop, nLeft, nBottom, nRight
   LOCAL cScreen
   LOCAL nReturn := 0
   LOCAL nMaxRow := MaxRow(), nMaxCol := MaxCol()
   LOCAL pSource
   LOCAL pTarget
   LOCAL nPosition
   LOCAL nBufferSize := 65536
   LOCAL cBuffer
   LOCAL tsDateTime
   LOCAL nFileSize

   nWidth := Max( Len( cSourceFile ), Len( cTargetFile ) ) + 2

   nRow := Int( nMaxRow / 3 )
   nCol := Int( ( nMaxCol - nWidth ) / 2 )

   nTop    := nRow
   nLeft   := nCol - 1
   nBottom := nRow + 7
   nRight  := nCol + nWidth

   cScreen := SaveScreen( nTop, nLeft, nBottom + 1, nRight + 2 )
   hb_DispBox( nTop, nLeft, nBottom, nRight, HB_B_DOUBLE_UNI + " ", 0x8f )
   hb_Shadow( nTop, nLeft, nBottom, nRight )

   cBuffer := Space( nBufferSize )

   /* file is opened for reading, do not deny any further attempts to open the file */
   IF ( pSource := hb_vfOpen( cSourceFile, FO_READ + FO_SHARED + FXO_SHARELOCK ) ) != NIL

      /* shared lock, file is opened for writing, deny further attempts to open the file, emulate DOS SH_DENY* mode in POSIX OS */
      IF ( pTarget := hb_vfOpen( cTargetFile, HB_FO_CREAT + FO_WRITE + FO_EXCLUSIVE + FXO_SHARELOCK ) ) != NIL

         hb_DispOutAt( ++nRow, nCol, PadC( "Copying the file", nWidth ), 0x8f )
         hb_DispOutAt( ++nRow, nCol, PadC( cSourceFile, nWidth ), 0x8f )
         hb_DispOutAt( ++nRow, nCol, PadC( "to", nWidth ), 0x8f )
         hb_DispOutAt( ++nRow, nCol, PadC( cTargetFile, nWidth ), 0x8f )

         /* FS_SET Seek from beginning of file, FS_END Seek from end of file */
         nPosition := hb_vfSeek( pSource, FS_SET, FS_END )
         nFileSize := nPosition

         hb_vfSeek( pSource, FS_SET )

         DO WHILE ( nPosition > FS_SET )

            IF nPosition < nBufferSize
               nBufferSize := nPosition
            ENDIF

            IF nBufferSize != hb_vfRead( pSource, @cBuffer, nBufferSize )
               nReturn := FError()
               EXIT
            ENDIF
            IF nBufferSize != hb_vfWrite( pTarget, @cBuffer, nBufferSize )
               nReturn := FError()
               EXIT
            ENDIF

            nPosition -= nBufferSize

            DispBegin()
            hb_DispOutAt( ++nRow, nCol, PadC( hb_ntos( 100 * ( nFileSize - nPosition ) / nFileSize ) + " %", nWidth ), 0x8a )

            hb_DispOutAt( ++nRow, nCol, Replicate( " ", nWidth ), 0x0 )
            hb_DispOutAt(   nRow, nCol, Replicate( " ", nWidth * ( nFileSize - nPosition ) / nFileSize ), 0x22 )

            DispEnd()
            nRow := Int( nMaxRow / 3 ) + 4

         ENDDO

         hb_vfClose( pTarget )
         hb_vfClose( pSource )

         /* pobierz datę czas pliku, ustaw datę czas pliku */
         hb_vfTimeGet( cSourceFile, @tsDateTime )
         hb_vfTimeSet( cTargetFile, tsDateTime )

      ELSE

         hb_vfClose( pSource )
         nReturn := FError()

      ENDIF
   ENDIF

   RestScreen( nTop, nLeft, nBottom + 1, nRight + 2, cScreen )

   RETURN nReturn

STATIC FUNCTION HC_CopyDirectory( cSourceFile, cTargetFile )

   LOCAL aCatalog
   LOCAL nRows
   LOCAL i
   LOCAL cSubCat

   cSubCat := hb_FNameNameExt( cSourceFile )
   IF hb_DirCreate( cTargetFile + cSubCat ) != 0
      RETURN FError()
   ENDIF

   aCatalog := hb_vfDirectory( cSourceFile + hb_ps(), "HSD" )
   nRows    := Len( aCatalog )

   FOR i := 1 TO nRows
      IF aCatalog[ i ][ F_NAME ] == "." .OR. aCatalog[ i ][ F_NAME ] == ".."

      ELSEIF "D" $ aCatalog[ i ][ F_ATTR ]
         IF HC_CopyDirectory( cSourceFile + hb_ps() + aCatalog[ i ][ F_NAME ], cTargetFile + cSubCat + hb_ps() ) == -1
            RETURN FError()
         ENDIF
      ELSE

         IF HC_CopyFile( cSourceFile + hb_ps() + aCatalog[ i ][ F_NAME ], cTargetFile + cSubCat + hb_ps() + aCatalog[ i ][ F_NAME ] ) != 0
            RETURN FError()
         ENDIF

      ENDIF

   NEXT

   RETURN 0

STATIC FUNCTION HC_DeleteFile( aPanel )  // ?

   LOCAL i

   FOR i := 1 TO Len( aPanel[ _aDirectory ] )

      IF aPanel[ _aDirectory ][ i ][ F_STATUS ] == .F.

         DO WHILE hb_vfErase( aPanel[ _cCurrentDir ] + aPanel[ _aDirectory ][ i ][ F_NAME ] ) == -1 // ?
            RETURN FError()
         ENDDO

         /* jeżeli usuniemy będąc wskaźnikiem RowBar lub RowBar + RowNo na ostatniej pozycji to - 1 */
         // IF Len( aPanel[ _aDirectory ] ) < aPanel[ _nRowBar ] + aPanel[ _nRowNo ]       // jak usunąć nRowNo nRowBar ?
         aPanel[ _nRowBar ] -= 1
         // ENDIF

      ENDIF

   NEXT

   RETURN 0

STATIC PROCEDURE PanelDisplay( aPanel )

   LOCAL nRow, nPos := 1
   LOCAL nLengthName := 4 /* 4 is len of top element ".." plus brackets "[" and "]" */
   LOCAL nLengthSize := 0

   AScan( aPanel[ _aDirectory ], {| x | ;
      nLengthName := Max( nLengthName, Len( x[ 1 ] ) ), ;
      nLengthSize := Max( nLengthSize, Len( Str( x[ 2 ] ) ) ) } )

   DispBegin()

   IF aPanelSelect == aPanel
      hb_DispBox( aPanel[ _nTop ], aPanel[ _nLeft ], aPanel[ _nBottom ], aPanel[ _nRight ], HB_B_DOUBLE_UNI + " ", 0x1f )
   ELSE
      hb_DispBox( aPanel[ _nTop ], aPanel[ _nLeft ], aPanel[ _nBottom ], aPanel[ _nRight ], HB_B_SINGLE_UNI + " ", 0x1f )
   ENDIF
/* The item will be displayed from the menu selection
   hb_DispOutAt( aPanel[ _nTop ], aPanel[ _nLeft ] + 1, PadR( hb_StrShrink( aPanel[ _cCurrentDir ], 1 ), ;
      Min( aPanel[ _nRight ] - aPanel[ _nLeft ] - 1, Len( aPanel[ _cCurrentDir ] ) ) ), "GR+/W"  )
*/
   nPos += aPanel[ _nRowNo ]
   FOR nRow := aPanel[ _nTop ] + 1 TO aPanel[ _nBottom ] - 1

      IF nPos <= Len( aPanel[ _aDirectory ] )
         hb_DispOutAt( nRow, aPanel[ _nLeft ] + 1, ;
            PadR( Expression( nLengthName, nLengthSize, ;
            aPanel[ _aDirectory ][ nPos ][ F_NAME ], ;
            aPanel[ _aDirectory ][ nPos ][ F_SIZE ], ;
            aPanel[ _aDirectory ][ nPos ][ F_DATE ], ;
            aPanel[ _aDirectory ][ nPos ][ F_ATTR ] ), ;
            aPanel[ _nRight ] - aPanel[ _nLeft ] - 1 ), ;
            iif( aPanelSelect == aPanel .AND. nPos == aPanel[ _nRowBar ] + aPanel[ _nRowNo ], ;
            iif( ! aPanel[ _aDirectory ][ nPos ][ F_STATUS ], 0x3e, 0x30 ), ;
            ColoringSyntax( aPanel[ _aDirectory ][ nPos ][ F_ATTR ], aPanel[ _aDirectory ][ nPos ][ F_STATUS ] ) ) )
         ++nPos
      ELSE
         EXIT
      ENDIF

   NEXT

   // PanelTitleDisplay( aPanel )

   DispEnd()

   RETURN

STATIC PROCEDURE ComdLineDisplay( aPanel )

   LOCAL nMaxRow := MaxRow(), nMaxCol := MaxCol()

   DispBegin()

   hb_DispOutAt( nMaxRow - 1, 0, ;
      PadR( aPanel[ _cCurrentDir ] + SubStr( aPanel[ _cComdLine ], 1 + aPanel[ _nComdColNo ], nMaxCol + aPanel[ _nComdColNo ] ), nMaxCol ), 0x7 )

   SetPos( nMaxRow - 1, aPanel[ _nComdCol ] + Len( aPanel[ _cCurrentDir ] ) )

   DispEnd()

   RETURN
/* The item will be displayed from the menu selection
STATIC PROCEDURE PanelTitleDisplay( aPanel )

   LOCAL cPanelTitle
   LOCAL nWidthPanel

   nWidthPanel := aPanel[ _nRight ] - aPanel[ _nLeft ]
   cPanelTitle := PadR( aPanel[ _cCurrentDir ], Min( Len( aPanel[ _cCurrentDir ] ), nWidthPanel ), Space( 0 ) )
   IF Len( cPanelTitle ) >= nWidthPanel - 2
      cPanelTitle := SubStr( cPanelTitle, 1, nWidthPanel - 2 ) + ">"
   ENDIF

   DispBegin()

   hb_DispOutAt( aPanel[ _nTop ], aPanel[ _nLeft ] + 1, cPanelTitle, "GR+/W"  )

   DispEnd()

   RETURN
*/
STATIC FUNCTION Expression( nLengthName, nLengthSize, cName, cSize, dDate, cAttr )

   LOCAL cFileName, cFileSize, dFileDate, cFileAttr

   iif( nLengthName == 2, nLengthName := 4, nLengthName )

   cFileName := PadR( cName + Space( nLengthName ), nLengthName ) + " "

   IF cName == ".."
      cFileName := PadR( "[" + AllTrim( cFileName ) + "]" + Space( nLengthName ), nLengthName ) + " "
   ENDIF

   IF cAttr == "D" .OR. cAttr == "HD" .OR. cAttr == "HSD" .OR. cAttr == "HSDL" .OR. cAttr == "RHSA" .OR. cAttr == "RD" .OR. cAttr == "AD" .OR. cAttr == "RHD"
      cFileSize := PadL( "DIR", nLengthSize + 3 ) + " "
   ELSE
      cFileSize := PadL( Transform( cSize, "9 999 999 999" ), nLengthSize + 3 ) + " "
   ENDIF

   dFileDate := hb_TToC( dDate ) + " "
   cFileAttr := PadL( cAttr, 3 )

   RETURN cFileName + cFileSize + dFileDate + cFileAttr

STATIC FUNCTION ColoringSyntax( cAttr, lStatus )

   LOCAL nColor

   IF cAttr == "HD" .OR. cAttr == "HSD" .OR. cAttr == "HSDL" .OR. cAttr == "RHSA" .OR. cAttr == "RD"
      nColor := 0x13
   ELSE
      nColor := 0x1f
   ENDIF

   IF ! lStatus
      nColor := 0x1e
   ENDIF

   RETURN nColor

STATIC PROCEDURE PanelRefresh( aPanel )

   IF aPanelLeft[ _cCurrentDir ] == aPanelRight[ _cCurrentDir ]

      PanelFetchList( aPanelLeft, aPanelLeft[ _cCurrentDir ] )
      PanelFetchList( aPanelRight, aPanelRight[ _cCurrentDir ] )

      PanelDisplay( aPanelLeft )
      PanelDisplay( aPanelRight )

   ELSE

      PanelFetchList( aPanel, aPanel[ _cCurrentDir ] )
      PanelDisplay( aPanel )

   ENDIF

   RETURN

STATIC PROCEDURE ChangeDir( aPanel )

   LOCAL nPos, cDir, cDir0
   LOCAL nPosLast

   nPos := aPanel[ _nRowBar ] + aPanel[ _nRowNo ]
   IF At( "D", aPanel[ _aDirectory ][ nPos ][ F_ATTR ] ) == 0
      RETURN
   ENDIF
   IF aPanel[ _aDirectory ][ nPos ][ F_NAME ] == ".."
      cDir := aPanel[ _cCurrentDir ]
      cDir0 := SubStr( cDir, RAt( hb_ps(), Left( cDir, Len( cDir ) - 1 ) ) + 1 )
      cDir0 := SubStr( cDir0, 1, Len( cDir0 ) - 1 )
      cDir  := Left( cDir, RAt( hb_ps(), Left( cDir, Len( cDir ) - 1 ) ) )
      PanelFetchList( aPanel, cDir )
      nPosLast := Max( AScan( aPanel[ _aDirectory ], {| x | x[ F_NAME ] == cDir0 } ), 1 )

      IF nPosLast > aPanelSelect[ _nBottom ] - 1
         aPanelSelect[ _nRowNo ] := nPosLast % ( aPanelSelect[ _nBottom ] - 1 )
         aPanelSelect[ _nRowBar ] := aPanelSelect[ _nBottom ] - 1
      ELSE
         aPanelSelect[ _nRowNo ]  := 0
         aPanelSelect[ _nRowBar ] := nPosLast
      ENDIF

   ELSE
      cDir := aPanel[ _cCurrentDir ] + aPanel[ _aDirectory ][ nPos ][ F_NAME ] + hb_ps()
      aPanel[ _nRowBar ] := 1
      aPanel[ _nRowNo  ] := 0
      PanelFetchList( aPanel, cDir )
   ENDIF

   RETURN

STATIC FUNCTION AllDrives()

   LOCAL i
   LOCAL aArrayDrives := {}

   FOR i := 1 TO 26
      IF DiskChange( Chr( i + 64 ) )
         AAdd( aArrayDrives, Chr( i + 64 ) )
      ENDIF
   NEXT

   RETURN aArrayDrives

STATIC PROCEDURE BottomBar()

   LOCAL nRow := MaxRow()
   LOCAL cSpaces
   LOCAL nCol := Int( MaxCol() / 10 ) + 1

   cSpaces := Space( nCol - 8 )

   hb_DispOutAt( nRow, 0,        " 1", 0x7 )
   hb_DispOutAt( nRow, 2,            "Help  " + cSpaces, 0x30 )
   hb_DispOutAt( nRow, nCol,     " 2", 0x7 )
   hb_DispOutAt( nRow, nCol + 2,     "Menu  " + cSpaces, 0x30 )
   hb_DispOutAt( nRow, nCol * 2, " 3", 0x7 )
   hb_DispOutAt( nRow, nCol * 2 + 2, "View  " + cSpaces, 0x30 )
   hb_DispOutAt( nRow, nCol * 3, " 4", 0x7 )
   hb_DispOutAt( nRow, nCol * 3 + 2, "Edit  " + cSpaces, 0x30 )
   hb_DispOutAt( nRow, nCol * 4, " 5", 0x7 )
   hb_DispOutAt( nRow, nCol * 4 + 2, "Copy  " + cSpaces, 0x30 )
   hb_DispOutAt( nRow, nCol * 5, " 6", 0x7 )
   hb_DispOutAt( nRow, nCol * 5 + 2, "RenMov" + cSpaces, 0x30 )
   hb_DispOutAt( nRow, nCol * 6, " 7", 0x7 )
   hb_DispOutAt( nRow, nCol * 6 + 2, "MkDir " + cSpaces, 0x30 )
   hb_DispOutAt( nRow, nCol * 7, " 8", 0x7 )
   hb_DispOutAt( nRow, nCol * 7 + 2, "Delete" + cSpaces, 0x30 )
   hb_DispOutAt( nRow, nCol * 8, " 9", 0x7 )
   hb_DispOutAt( nRow, nCol * 8 + 2, "PullDn" + cSpaces, 0x30 )
   hb_DispOutAt( nRow, nCol * 9, "10", 0x7 )
   hb_DispOutAt( nRow, nCol * 9 + 2, "Quit  " + cSpaces, 0x30 )

   RETURN

STATIC FUNCTION MsgBox( cMessage, aMessage, aOptions )

   LOCAL nMaxRow := 0, nMaxCol := 0
   LOCAL cScreen
   LOCAL aOptionsOK := {}, aPosButtons
   LOCAL lContinue := .T.
   LOCAL i
   LOCAL nChoice := 1
   LOCAL nOpWidth, nWidth, nInitCol, expValue
   LOCAL nOldRow, nOldCol
   LOCAL nKey, nKeyStd
   LOCAL cString
   LOCAL nCol := 0, nColNo := 0

   nOldRow := Row()
   nOldCol := Col()

   FOR EACH i IN hb_defaultValue( aOptions, {} )
      IF HB_ISSTRING( i ) .AND. ! i == ""
         AAdd( aOptionsOK, i )
      ENDIF
   NEXT

   IF Len( aOptionsOK ) == 0
      aOptionsOK := { "Ok" }
   ENDIF

   /* aMessage obecnie nie jest tablicą */
   IF Empty( aMessage )
      cString := ""
   ELSE
      cString := aMessage
      nCol := Len( aMessage )
   ENDIF

   DO WHILE lContinue

      DispBegin()
      IF nMaxRow != Int( MaxRow() / 3 ) .OR. nMaxCol != Int( MaxCol() / 2 )

         nMaxRow := Int( MaxRow() / 3 )
         nMaxCol := Int( MaxCol() / 2 )

         aPosButtons := {}
         nOpWidth := 0

         cScreen := SaveScreen( nMaxRow - 2, nMaxCol - 36, nMaxRow + 4, nMaxCol + 38 )

         AEval( aOptionsOK, {| x | nOpWidth += Len( x ) + 4 } )

         nWidth := nOpWidth + 2
         nInitCol := Int( ( ( MaxCol() - ( nWidth + 2 ) ) / 2 ) + 0.5 )
         expValue := nInitCol + Int( ( nWidth - nOpWidth ) / 2 ) + 2
         AEval( aOptionsOK, {| x | AAdd( aPosButtons, expValue ), expValue += Len( x ) + 4 } )

         hb_DispBox( nMaxRow - 2, nMaxCol - 36, nMaxRow + 3, nMaxCol + 36, HB_B_SINGLE_UNI + " ", 0x8f )
         hb_Shadow( nMaxRow - 2, nMaxCol - 36, nMaxRow + 3, nMaxCol + 36 )
         hb_DispOutAt( nMaxRow - 1, nMaxCol - 34, cMessage, 0x8f )

         FOR i := 1 TO Len( aOptionsOK )
            hb_DispOutAt( nMaxRow + 2, aPosButtons[ i ], " " + aOptionsOK[ i ] + " ", iif( i == nChoice, 0x07, 0x8f ) )
         NEXT

         MsgBoxDisplay( cString, nCol, nColNo )

      ENDIF
      DispEnd()

      MsgBoxDisplay( cString, nCol, nColNo )

      nKey := Inkey( 0 )
      nKeyStd := hb_keyStd( nKey )

      SWITCH nKeyStd
      CASE K_ESC
         lContinue := .F.
         nChoice := 0
         EXIT

      CASE K_ENTER
         lContinue := .F.
         EXIT

      CASE K_F1
         EXIT

      CASE K_F10
         lContinue := .F.
         nChoice := 0
         EXIT

      CASE K_LEFT

         IF nCol > 0
            nCol--
         ELSE
            IF nColNo >= 1
               nColNo--
            ENDIF
         ENDIF

         EXIT

      CASE K_RIGHT

         IF nCol < 68 .AND. nCol < Len( cString )
            nCol++
         ELSE
            IF nColNo + nCol < Len( cString )
               nColNo++
            ENDIF
         ENDIF

         EXIT

      CASE K_HOME

         nCol := 0

         EXIT

      CASE K_END

         nCol := Len( cString )

         EXIT

      CASE K_DEL

         IF nCol >= 0
            cString := Stuff( cString, nCol + 1, 1, "" )
         ENDIF

         EXIT

      CASE K_BS

         IF nCol > 0
            cString := Stuff( cString, nCol, 1, "" )
            nCol--
         ENDIF

         EXIT

      CASE K_TAB
         IF Len( aOptionsOK ) > 1
            nChoice++
            IF nChoice > Len( aOptionsOK )
               nChoice := 1
            ENDIF
         ENDIF

         FOR i := 1 TO Len( aOptionsOK )
            hb_DispOutAt( nMaxRow + 2, aPosButtons[ i ], " " + aOptionsOK[ i ] + " ", iif( i == nChoice, 0x07, 0x8f ) )
         NEXT

         EXIT

      CASE HB_K_RESIZE

         hb_Scroll()
         AutoSize()

         PanelDisplay( aPanelLeft )
         PanelDisplay( aPanelRight )

         ComdLineDisplay( aPanelSelect )

         BottomBar()

         EXIT

      OTHERWISE

         IF ( nKeyStd >= 32 .AND. nKeyStd <= 126 ) .OR. ( nKeyStd >= 160 .AND. nKeyStd <= 255 ) .OR. ! hb_keyChar( nKeyStd ) == ""

            cString := Stuff( cString, nCol + nColNo + 1, 0, hb_keyChar( nKeyStd ) )
            IF nCol < 68
               nCol++
            ELSE
               nColNo++
            ENDIF

         ENDIF

      ENDSWITCH

   ENDDO

   RestScreen( nMaxRow - 2, nMaxCol - 36, nMaxRow + 4, nMaxCol + 38, cScreen )
   SetPos( nOldRow, nOldCol )

   RETURN iif( nChoice == 1, iif( Empty( cString ), 0, cString ), 0 ) // ??

STATIC PROCEDURE MsgBoxDisplay( cString, nCol, nColNo )

   LOCAL nMaxRow := Int( MaxRow() / 3 ), nMaxCol := Int( MaxCol() / 2 )

   DispBegin()

   hb_DispOutAt( nMaxRow, nMaxCol - 34, PadR( SubStr( cString, 1 + nColNo, 69 + nColNo ), 69 ) )

   SetPos( nMaxRow, nMaxCol - 34 + nCol )

   DispEnd()

   RETURN

STATIC FUNCTION HC_Alert( cTitle, xMessage, xOptions, nColorNorm, nArg )

   LOCAL nOldCursor := SetCursor( SC_NONE )

   // LOCAL nRowPos := Row(), nColPos := Col()
   LOCAL aMessage, aOptions, aPos
   LOCAL nColorHigh
   LOCAL nLenOptions, nLenMessage
   LOCAL nWidth := 0
   LOCAL nLenght := 0
   LOCAL nPos
   LOCAL i
   LOCAL nMaxRow := 0, nMaxCol := 0
   LOCAL nRow, nCol
   LOCAL nKey, nKeyStd
   LOCAL nTop, nLeft, nBottom, nRight
   LOCAL nChoice := 1
   LOCAL nMRow, nMCol

   DO CASE
   CASE ValType( cTitle ) == "U"
      cTitle := "OK"
   ENDCASE

   DO CASE
   CASE ValType( xMessage ) == "U"
      aMessage := { "" }
   CASE ValType( xMessage ) == "C"
      aMessage := hb_ATokens( xMessage, ";" )
   CASE ValType( xMessage ) == "A"
      aMessage := xMessage
   CASE ValType( xMessage ) == "N"
      aMessage := hb_ATokens( hb_CStr( xMessage ) )
   ENDCASE

   DO CASE
   CASE ValType( xOptions ) == "U"
      aOptions := { "OK" }
   CASE ValType( xOptions ) == "C"
      aOptions := hb_ATokens( xOptions, ";" )
   CASE ValType( xOptions ) == "A"
      aOptions := xOptions
   ENDCASE

   DO CASE
   CASE ValType( nColorNorm ) == "U"
      nColorNorm := 0x4f
      nColorHigh := 0x1f
   CASE ValType( nColorNorm ) == "N"
      nColorNorm := hb_bitAnd( nColorNorm, 0xff )
      nColorHigh := hb_bitAnd( hb_bitOr( hb_bitShift( nColorNorm, - 4 ), hb_bitShift( nColorNorm, 4 ) ), 0x77 )
   ENDCASE

   nLenOptions := Len( aOptions )
   FOR i := 1 TO nLenOptions
      nWidth += Len( aOptions[ i ] ) + 2
      nLenght += Len( aOptions[ i ] ) + 2
   NEXT

   /* w pętli przechodzę przez nWidth, wybieram co jest większe */
   nLenMessage := Len( aMessage )
   FOR i := 1 TO nLenMessage
      nWidth := Max( nWidth, Len( aMessage[ i ] ) )
   NEXT

   DO WHILE .T.

      DispBegin()

      /* zachowanie drugiego ustawienia ! */
      IF nMaxRow != MaxRow( .T. ) .OR. nMaxCol != iif( nArg == NIL, MaxCol( .T. ), iif( nArg == 0x0, Int( MaxCol( .T. ) / 2 ), MaxCol( .T. ) + Int( MaxCol( .T. ) / 2 ) ) )

         WSelect( 0 )

         nMaxRow := MaxRow( .T. )
         /* ostatni parametr ustawia okienko dialogowe: NIL środek, 0x0 po lewo i 0x1 po prawo */
         nMaxCol := iif( nArg == NIL, MaxCol( .T. ), iif( nArg == 0x0, Int( MaxCol( .T. ) / 2 ), MaxCol( .T. ) + Int( MaxCol( .T. ) / 2 ) ) )

         nTop    := Int( nMaxRow / 3 ) - 3
         nLeft   := Int( ( nMaxCol - nWidth ) / 2 ) - 2
         nBottom := nTop + 4 + nLenMessage
         nRight  := Int( ( nMaxCol + nWidth ) / 2 ) - 1 + 2

         WClose( 1 )
         WSetShadow( 0x8 )
         WOpen( nTop, nLeft, nBottom, nRight, .T. )

         hb_DispBox( 0, 0, nMaxRow, nMaxCol, hb_UTF8ToStrBox( " █       " ), nColorNorm )
         hb_DispOutAt( 0, 0, Center( cTitle ), hb_bitShift( nColorNorm, 4 ) )

         FOR nPos := 1 TO Len( aMessage )
            hb_DispOutAt( 1 + nPos, 0, Center( aMessage[ nPos ] ), nColorNorm )
         NEXT

      ENDIF

      /* zapisuje współrzędne przycisków aOptions */
      aPos := {}
      nRow := nPos + 2
      nCol := Int( ( MaxCol() + 1 - nLenght - nLenOptions + 1 ) / 2 )

      FOR i := 1 TO nLenOptions
         AAdd( aPos, nCol )
         hb_DispOutAt( nRow, nCol, " " + aOptions[ i ] + " ", iif( i == nChoice, nColorHigh, nColorNorm ) )
         nCol += Len( aOptions[ i ] ) + 3
      NEXT

      DispEnd()

      nKey := Inkey( 0 )
      nKeyStd := hb_keyStd( nKey )

      DO CASE
      CASE nKeyStd == K_ESC
         nChoice := 0
         EXIT

      CASE nKeyStd == K_ENTER .OR. nKeyStd == K_SPACE
         EXIT

      CASE nKeyStd == K_MOUSEMOVE

         FOR i := 1 TO nLenOptions
            IF MRow() == nPos + 2 .AND. MCol() >= aPos[ i ] .AND. MCol() <= aPos[ i ] + Len( aOptions[ i ] ) + 1
               nChoice := i
            ENDIF
         NEXT

      CASE nKeyStd == K_LBUTTONDOWN

         nMCol := MCol()
         nMRow := MRow()

         IF MRow() == 0 .AND. MCol() >= 0 .AND. MCol() <= MaxCol()

            DO WHILE MLeftDown()
               WMove( WRow() + MRow() - nMRow, WCol() + MCol() - nMCol )
            ENDDO

         ENDIF

         FOR i := 1 TO nLenOptions
            IF MRow() == nPos + 2 .AND. MCol() >= aPos[ i ] .AND. MCol() <= aPos[ i ] + Len( aOptions[ i ] ) + 1
               nChoice := i
               EXIT
            ENDIF
         NEXT

         IF nChoice == i
            EXIT
         ENDIF

      CASE ( nKeyStd == K_LEFT .OR. nKeyStd == K_SH_TAB ) .AND. nLenOptions > 1

         nChoice--
         IF nChoice == 0
            nChoice := nLenOptions
         ENDIF

      CASE ( nKeyStd == K_RIGHT .OR. nKeyStd == K_TAB ) .AND. nLenOptions > 1

         nChoice++
         IF nChoice > nLenOptions
            nChoice := 1
         ENDIF

      CASE nKeyStd == K_CTRL_UP
         WMove( WRow() - 1, WCol() )

      CASE nKeyStd == K_CTRL_DOWN
         WMove( WRow() + 1, WCol() )

      CASE nKeyStd == K_CTRL_LEFT
         WMove( WRow(), WCol() - 1 )

      CASE nKeyStd == K_CTRL_RIGHT
         WMove( WRow(), WCol() + 1 )

      CASE nKeyStd == HB_K_RESIZE

         WClose( 1 )

         AutoSize()

         PanelDisplay( aPanelLeft )
         PanelDisplay( aPanelRight )
         ComdLineDisplay( aPanelSelect )

         BottomBar()

      ENDCASE

   ENDDO

   WClose( 1 )
   SetCursor( nOldCursor )
   // SetPos( nRowPos, nColPos )

   RETURN iif( nKey == 0, 0, nChoice )

STATIC FUNCTION HC_MenuF2()

   LOCAL nOldCursor := SetCursor( SC_NONE )
   LOCAL cFile := "hc.menu"
   LOCAL cCopyExample := ""
   LOCAL aMenu, cLine
   LOCAL nMaxRow := 0, nMaxCol := 0
   LOCAL nRow := 1
   LOCAL nKey, nKeyStd
   LOCAL nColLength := 0
   LOCAL nTop, nLeft, nBottom, nRight
   LOCAL nChoice := 1
   LOCAL nRowPos := 1, nColPos := 2
   LOCAL nMRow, nMCol

   IF ! hb_vfExists( "hc.menu" )

      /* Przykład budowy menu, zapisuje ciąg znaków do zbioru dyskowego, edycja z pliku hc.menu */
      cCopyExample += "F1:Compilation of my project in Harbour" + hb_eol()
      cCopyExample += "hbmk2 hc.prg" + hb_eol()
      cCopyExample += "F2:Checking version of GCC compiler" + hb_eol()
      cCopyExample += "gcc --version" + hb_eol()
      cCopyExample += "F3:What is my OS version" + hb_eol()
      cCopyExample += "uname -a"

      /* Jeśli nie jest określona ścieżka, hb_MemoWrit() zapisuje cCopyExample w aktualnym katalogu */
      hb_MemoWrit( "hc.menu", cCopyExample )

   ENDIF

   aMenu := hb_ATokens( hb_MemoRead( cFile ), .T. )

   AScan( aMenu, {| str | nColLength := Max( nColLength, Len( str ) ) } )

   DO WHILE .T.

      DispBegin()

      IF nMaxRow != MaxRow( .T. ) .OR. nMaxCol != MaxCol( .T. )

         WSelect( 0 )

         nMaxRow := MaxRow( .T. )
         nMaxCol := MaxCol( .T. )

         nTop    := Int( nMaxRow / 3 ) - 3
         nLeft   := Int( ( nMaxCol - nColLength ) / 2 ) - 2
         nBottom := nTop + 4 + Len( aMenu )
         nRight  := Int( ( nMaxCol + nColLength ) / 2 ) - 1 + 2

         WClose( 1 )
         WSetShadow( 0x8 )
         WOpen( nTop, nLeft, nBottom, nRight, .T. )

         hb_DispBox( 0, 0, nMaxRow, nMaxCol, hb_UTF8ToStrBox( " █       " ), 0x9f )
         hb_DispOutAt( 0, 0, Center( hb_UserName() + "  Menu" ), 0xf0 )

         hb_DispBox( 1, 0, MaxRow(), MaxCol(), HB_B_SINGLE_UNI, 0x9f )

      ENDIF

      DispEnd()

      FOR EACH cLine IN aMenu

         hb_DispOutAt( nRowPos + cLine:__enumIndex(), nColPos, ;
            PadR( cLine, nColLength ), ;
            iif( cLine:__enumIndex() == nRow, 0xf, 0x9f ) )

         iif( cLine:__enumIndex() == nRow, nChoice := cLine:__enumIndex(), NIL )

      NEXT

      DispEnd()

      nKey := Inkey( 0 )
      nKeyStd := hb_keyStd( nKey )

      DO CASE
      CASE nKeyStd == K_ESC
         nChoice := 0
         EXIT

      CASE nKeyStd == K_ENTER .OR. nKeyStd == K_SPACE
         EXIT

      CASE nKeyStd == K_MOUSEMOVE

         IF nRowPos < MRow() .AND. nColPos < MCol() .AND. nRowPos + Len( aMenu ) >= MRow() .AND. nColPos + nColLength > MCol()
            nRow := MRow() - nRowPos
         ENDIF

      CASE nKeyStd == K_LBUTTONDOWN

         nMCol := MCol()
         nMRow := MRow()

         IF MRow() == 0 .AND. MCol() >= 0 .AND. MCol() <= MaxCol()

            DO WHILE MLeftDown()
               WMove( WRow() + MRow() - nMRow, WCol() + MCol() - nMCol )
            ENDDO

         ENDIF

         IF nRowPos < MRow() .AND. nColPos < MCol() .AND. nRowPos + Len( aMenu ) >= MRow() .AND. nColPos + nColLength > MCol()
            RETURN nChoice
         ENDIF

      CASE nKeyStd == K_MWFORWARD

         IF nRowPos < MRow() .AND. nColPos < MCol() .AND. nRowPos + Len( aMenu ) >= MRow() .AND. nColPos + nColLength > MCol()
            IF nRow > 1
               nRow--
            ELSE
               nRow := Len( aMenu )
            ENDIF
         ENDIF

      CASE nKeyStd == K_MWBACKWARD

         IF nRowPos < MRow() .AND. nColPos < MCol() .AND. nRowPos + Len( aMenu ) >= MRow() .AND. nColPos + nColLength > MCol()
            IF nRow < Len( aMenu )
               nRow++
            ELSE
               nRow := 1
            ENDIF
         ENDIF

      CASE nKeyStd == K_UP

         IF nRow > 1
            nRow--
         ELSE
            nRow := Len( aMenu )
         ENDIF

      CASE nKeyStd == K_DOWN

         IF nRow < Len( aMenu )
            nRow++
         ELSE
            nRow := 1
         ENDIF

      CASE nKeyStd == K_CTRL_UP
         WMove( WRow() - 1, WCol() )

      CASE nKeyStd == K_CTRL_DOWN
         WMove( WRow() + 1, WCol() )

      CASE nKeyStd == K_CTRL_LEFT
         WMove( WRow(), WCol() - 1 )

      CASE nKeyStd == K_CTRL_RIGHT
         WMove( WRow(), WCol() + 1 )

      CASE nKeyStd == HB_K_RESIZE

         WClose( 1 )

         AutoSize()

         PanelDisplay( aPanelLeft )
         PanelDisplay( aPanelRight )
         ComdLineDisplay( aPanelSelect )

         BottomBar()

      ENDCASE

   ENDDO

   WClose( 1 )
   SetCursor( nOldCursor )

   RETURN iif( nKey == 0, 0, nChoice )

STATIC PROCEDURE HCEdit( cFileName, lArg )

   LOCAL cString
   LOCAL aString
   LOCAL lContinue := .T.
   LOCAL nMaxRow := 0, nMaxCol := 0
   LOCAL nRow := 1, nCol := 0, nRowNo := 0, nColNo := 0
   LOCAL cStringEditingRow
   LOCAL cSubString
   LOCAL lToggleInsert := .F.
   LOCAL nKey, nKeyStd
   LOCAL nOldRow, nOldCol
   LOCAL cScreen
   LOCAL tsDateTime

   nOldRow := Row()
   nOldCol := Col()
   cScreen := SaveScreen( 0, 0, MaxRow(), MaxCol() )

   IF HB_ISSTRING( cFileName ) // ?

      cString := hb_MemoRead( cFileName )

      aString := hb_ATokens( cString, .T. )

      DO WHILE lContinue

         IF nMaxRow != MaxRow() .OR. nMaxCol != MaxCol()
            nMaxRow := MaxRow()
            nMaxCol := MaxCol()

            IF nRow > nMaxRow - 1
               nRow := nMaxRow - 1
            ENDIF

            HCEditDisplay( aString, nRow, nCol, nRowNo )

         ENDIF

         DispBegin()
         hb_DispOutAt( 0, 0, ;
            PadR( cFileName + "  ", nMaxCol + 1 ), 0x30 )

         HCEditDisplay( aString, nRow, nCol, nRowNo )

         hb_vfTimeGet( cFileName, @tsDateTime )
         hb_DispOutAt( nMaxRow, 0, ;
            PadR( " Row(" + hb_ntos( nRow + nRowNo ) + ") Col(" + hb_ntos( nCol + 1 ) + ") Size(" + hb_ntos( hb_vfSize( cFileName ) ) + ") Date(" + hb_TToC( tsDateTime ) + ")", nMaxCol + 1 ), 0x30 )
         DispEnd()

         nKey := Inkey( 0 )
         nKeyStd := hb_keyStd( nKey )

         SWITCH nKeyStd

         CASE K_ESC
            lContinue := .F.
            EXIT

         CASE K_LBUTTONDOWN

            IF MRow() > 0 .AND. MCol() > 0 .AND. MRow() < Len( aString ) + 1 .AND. MCol() < nMaxCol
               nRow := MRow()
               nCol := Len( aString[ nRowNo + nRow ] )
            ENDIF

            EXIT

         CASE K_MWFORWARD

            IF nRowNo >= 1
               nRowNo--
            ENDIF

            EXIT

         CASE K_MWBACKWARD

            IF nRow + nRowNo < Len( aString )
               nRowNo++
            ENDIF

            EXIT

         CASE K_UP

            IF nRow > 1
               nRow--
            ELSE
               IF nRowNo >= 1
                  nRowNo--
               ENDIF
            ENDIF

            IF aString[ nRowNo + nRow ] == ""
               nCol  := 0
            ELSE
               IF nCol > Len( aString[ nRowNo + nRow ] )
                  nCol := Len( aString[ nRowNo + nRow ] )
               ENDIF
            ENDIF

            EXIT

         CASE K_LEFT

            IF nCol > 0
               nCol--
            ELSE
               IF nColNo > 0
                  nColNo--
               ENDIF
            ENDIF

            EXIT

         CASE K_DOWN

            IF nRow < nMaxRow - 1 .AND. nRow < Len( aString )
               nRow++
            ELSE
               IF nRowNo + nRow < Len( aString )
                  nRowNo++
               ENDIF
            ENDIF

            IF aString[ nRowNo + nRow ] == ""
               nCol := 0
            ELSE
               IF nCol > Len( aString[ nRowNo + nRow ] )
                  nCol := Len( aString[ nRowNo + nRow ] )
               ENDIF
            ENDIF

            EXIT

         CASE K_RIGHT

            IF nCol < Len( aString[ nRowNo + nRow ] )
               nCol++
            ENDIF

            EXIT

         CASE K_HOME

            nCol := 0

            EXIT

         CASE K_END

            nCol := Len( aString[ nRowNo + nRow ] )

            EXIT

         CASE K_PGUP

            IF nRow <= 1
               IF nRowNo - nMaxRow >= 0
                  nRowNo -= nMaxRow
               ENDIF
            ENDIF
            nRow := 1

            EXIT

         CASE K_PGDN

            IF nRow >= nMaxRow - 1
               IF nRowNo + nMaxRow  <= Len( aString )
                  nRowNo += nMaxRow
               ENDIF
            ENDIF
            nRow := Min( nMaxRow - 1, Len( aString ) - nRowNo )

            hb_Scroll( 1, 0, nMaxRow, nMaxCol )

            EXIT

         CASE K_CTRL_PGUP

            nRow := 0
            nRowNo := 0

            EXIT

         CASE K_CTRL_PGDN

            nRow := nMaxRow - 1
            nRowNo := Len( aString ) - nMaxRow + 1

            EXIT

         CASE K_ENTER

            IF lArg
               IF aString[ nRowNo + nRow ] == "" .OR. nCol == 0

                  hb_AIns( aString, nRowNo + nRow, "", .T. )
                  nRow++
               ELSE
                  IF nCol == Len( aString[ nRowNo + nRow ] )
                     hb_AIns( aString, nRowNo + nRow + 1, "", .T. )
                     nRow++
                     nCol := 0
                  ELSE
                     cSubString := Right( aString[ nRowNo + nRow ], Len( aString[ nRowNo + nRow ] ) - nCol )
                     cStringEditingRow := aString[ nRowNo + nRow ]
                     aString[ nRowNo + nRow ] := Stuff( cStringEditingRow, nCol + 1, Len( aString[ nRowNo + nRow ] ) - nCol, "" )
                     hb_AIns( aString, nRowNo + nRow + 1, cSubString, .T. )
                     nRow++
                     nCol := 0
                  ENDIF
               ENDIF

               SaveFile( aString, cFileName )

            ENDIF
            EXIT

         CASE K_INS
            IF lArg
               IF lToggleInsert
                  SetCursor( SC_NORMAL )
                  lToggleInsert := .F.
               ELSE
                  SetCursor( SC_INSERT )
                  lToggleInsert := .T.
               ENDIF
            ENDIF
            EXIT

         CASE K_DEL
            IF lArg
               IF aString[ nRowNo + nRow ] == ""
                  IF nRow >= 0
                     hb_ADel( aString, nRowNo + nRow, .T. )
                  ENDIF
               ELSE
                  IF nCol == Len( aString[ nRowNo + nRow ] )

                     aString[ nRowNo + nRow ] += aString[ nRowNo + nRow + 1 ]

                     hb_ADel( aString, nRowNo + nRow + 1, .T. )
                  ELSE
                     cStringEditingRow := aString[ nRowNo + nRow ]
                     aString[ nRowNo + nRow ] := Stuff( cStringEditingRow, nCol + 1, 1, "" )
                  ENDIF
               ENDIF

               SaveFile( aString, cFileName )

            ENDIF
            EXIT

         CASE K_BS
            IF lArg
               IF aString[ nRowNo + nRow ] == ""
                  IF nRow > 1
                     hb_ADel( aString, nRowNo + nRow, .T. )
                     nRow--
                     nCol := Len( aString[ nRowNo + nRow ] )
                  ENDIF
               ELSE
                  IF nCol > 0
                     cStringEditingRow := aString[ nRowNo + nRow ]
                     aString[ nRowNo + nRow ] := Stuff( cStringEditingRow, nCol, 1, "" )
                     nCol--
                  ELSE
                     IF nRow > 1
                        IF aString[ nRowNo + nRow - 1 ] == ""
                           nCol := 0
                        ELSE
                           nCol := Len( aString[ nRowNo + nRow - 1 ] )
                        ENDIF

                        aString[ nRowNo + nRow - 1 ] += aString[ nRowNo + nRow ]

                        hb_ADel( aString, nRowNo + nRow, .T. )
                        nRow--
                     ENDIF
                  ENDIF
               ENDIF

               SaveFile( aString, cFileName )

            ENDIF
            EXIT

         CASE K_TAB
            IF lArg
               cStringEditingRow := aString[ nRowNo + nRow ]

               aString[ nRowNo + nRow ] := Stuff( cStringEditingRow, nCol + 1, iif( lToggleInsert, 1, 0 ), "   " )
               nCol += 3

               SaveFile( aString, cFileName )

            ENDIF
            EXIT

         OTHERWISE

            IF lArg
               IF ( nKeyStd >= 32 .AND. nKeyStd <= 126 ) .OR. ( nKeyStd >= 160 .AND. nKeyStd <= 255 ) .OR. ! hb_keyChar( nKeyStd ) == ""

                  cStringEditingRow := aString[ nRowNo + nRow ]
                  aString[ nRowNo + nRow ] := Stuff( cStringEditingRow, nCol + 1, iif( lToggleInsert, 1, 0 ), hb_keyChar( nKeyStd ) )
                  nCol++

                  SaveFile( aString, cFileName )

               ENDIF
            ENDIF

         ENDSWITCH

      ENDDO

   ELSE
      HC_Alert( "Error reading:;" + cFileName )
      RETURN
   ENDIF

   RestScreen( 0, 0, MaxRow(), MaxCol(), cScreen )
   SetPos( nOldRow, nOldCol )

   RETURN

STATIC PROCEDURE HCEditDisplay( aString, nRow, nCol, nRowNo )

   LOCAL i
   LOCAL nMaxRow := MaxRow(), nMaxCol := MaxCol()
   LOCAL nLine

   hb_Scroll( 2, 0, nMaxRow - 2, nMaxCol )

   FOR i := 1 TO nMaxRow

      nLine := i + nRowNo

      IF nLine <= Len( aString )
         hb_DispOutAt( i, 0, ;
            PadR( aString[ nLine ], nMaxCol + 1 ), ;
            iif( i == nRow, 0x8f, 0x7 ) )
      ELSE
         hb_Scroll( i, 0, nMaxRow, nMaxCol + 1 )
         hb_DispOutAt( i, 1, ">> EOF <<", 0x01 )
         EXIT
      ENDIF

   NEXT

   SetPos( nRow, nCol )

   RETURN

STATIC PROCEDURE SaveFile( aString, cFileName )

   LOCAL cString := ""

   AEval( aString, {| e | cString += e + hb_eol() } )
   hb_MemoWrit( cFileName, cString )

   RETURN

STATIC FUNCTION FileError()
   RETURN { ;
      {   0, "The operation completed successfully." }, ;
      {   2, "The system cannot find the file specified." }, ;
      {   3, "The system cannot find the path specified." }, ;
      {   4, "The system cannot open the file." }, ;
      {   5, "Access is denied." }, ;
      {   6, "The handle is invalid." }, ;
      {   8, "Not enough storage is available to process this command." }, ;
      {  15, "The system cannot find the drive specified." }, ;
      {  16, "The directory cannot be removed." }, ;
      {  17, "The system cannot move the file to a different disk drive." }, ;
      {  18, "There are no more files." }, ;
      {  19, "Attempted to write to a write-protected disk." }, ;
      {  21, "The device is not ready." }, ;
      {  23, "Data error (cyclic redundancy check)." }, ;
      {  29, "The system cannot write to the specified device." }, ;
      {  30, "The system cannot read from the specified device." }, ;
      {  32, "The process cannot access the file because ; it is being used by another process." }, ;
      {  33, "The process cannot access the file because ; another process has locked a portion of the file." }, ;
      {  36, "Too many files opened for sharing." }, ;
      {  38, "Reached the end of the file." }, ;
      {  62, "Space to store the file waiting to be printed ; is not available on the server." }, ;
      {  63, "Your file waiting to be printed was deleted." }, ;
      {  80, "The file exists." }, ;
      {  82, "The directory or file cannot be created." }, ;
      { 110, "The system cannot open the device or file specified." }, ;
      { 111, "The file name is too long" }, ;
      { 113, "No more internal file identifiers available." }, ;
      { 114, "The target internal file identifier is incorrect." }, ;
      { 123, "The filename, directory name, ; or volume label syntax is incorrect." }, ;
      { 130, "Attempt to use a file handle to an open disk ; partition for an operation other than raw disk I/O." }, ;
      { 131, "An attempt was made to move the file pointer ; before the beginning of the file." }, ;
      { 132, "The file pointer cannot be set on the specified ; device or file." }, ;
      { 138, "The system tried to join a drive ; to a directory on a joined drive." }, ;
      { 139, "The system tried to substitute a drive ; to a directory on a substituted drive." }, ;
      { 140, "The system tried to join a drive ; to a directory on a substituted drive." }, ;
      { 141, "The system tried to SUBST a drive ; to a directory on a joined drive." }, ;
      { 143, "The system cannot join or substitute a drive ; to or for a directory on the same drive." }, ;
      { 144, "The directory is not a subdirectory of the root directory." }, ;
      { 145, "The directory is not empty." }, ;
      { 150, "System trace information was not specified ; in your CONFIG.SYS file, or tracing is disallowed." }, ;
      { 154, "The volume label you entered exceeds ; the label character limit of the target file system." }, ;
      { 167, "Unable to lock a region of a file." }, ;
      { 174, "The file system does not support ; atomic changes to the lock type." }, ;
      }

// ====================================
FUNCTION Q( xPar )
   RETURN Alert( hb_ValToExp( xPar ) )
// ====================================

PROCEDURE hc_Exec( cArg )
#if defined( __PLATFORM__WINDOWS )
   IF " " $ cArg
      cArg := '"' + cArg + '"'
   ENDIF
   IF (wapi_ShellExecute( 0, , cArg, , hb_cwd(), 1 ) < 32)
      /* wapi_ShellExecute() failed! try hb_run(), just in case... */
      hb_Run( cArg )
   ENDIF
#else
   hb_Run( cArg )
#endif

   RETURN


